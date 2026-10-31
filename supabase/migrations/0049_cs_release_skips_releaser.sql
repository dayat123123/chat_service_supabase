alter table cs.tickets
  add column released_by uuid references cs.agents (user_id);

create or replace function cs.set_status(p_ticket_id uuid, p_to text, p_event text, p_data jsonb default '{}',
                                         p_owner uuid default null)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  t cs.tickets;
begin
  select * into t from cs.tickets where id = p_ticket_id for update;
  if not found then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if not cs.transition_allowed(t.status, p_to) then
    perform private.api_error(409, 'invalid_transition', format('Tiket berstatus %s tidak bisa menjadi %s', t.status, p_to));
  end if;
  update cs.tickets
     set status = p_to,
         owner_agent_id = case when p_to = 'open' then null
                               when p_to in ('claimed', 'waiting_customer') then coalesce(p_owner, owner_agent_id)
                               else owner_agent_id end,
         last_owner_id = case when p_to = 'claimed' then coalesce(p_owner, owner_agent_id, last_owner_id) else last_owner_id end,
         claimed_at = case when p_to = 'claimed'
                                and (t.status in ('open', 'resolved') or (p_owner is not null and p_owner <> t.owner_agent_id))
                           then now() else claimed_at end,
         first_claimed_at = case when p_to = 'claimed' then coalesce(first_claimed_at, now()) else first_claimed_at end,
         queued_at = case when p_to = 'open' then now() else queued_at end,
         resolved_at = case when p_to = 'resolved' then now() when p_to in ('open', 'claimed') then null else resolved_at end,
         closed_at = case when p_to = 'closed' then now() end,
         returned_reason = null,
         released_by = null,
         version = version + 1,
         updated_at = now()
   where id = p_ticket_id
  returning * into t;
  perform cs.log_event(t.id, p_event, coalesce(p_data, '{}') || jsonb_build_object('status', p_to));
  return t;
end;
$$;

create or replace function cs.release_ticket(p_ticket_id uuid, p_reason text, p_version integer)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_agent}');
  t      cs.tickets := cs.owned_ticket(p_ticket_id, v_me, p_version);
  v_text text := btrim(coalesce(p_reason, ''));
begin
  if char_length(v_text) not between 3 and 300 then
    perform private.api_error(400, 'reason_required', 'Tulis alasan melepas tiket (3–300 karakter)');
  end if;
  perform cs.cancel_transfers(t.id, 'Tiket dilepas ke antrean');
  t := cs.set_status(t.id, 'open', 'released', jsonb_build_object('reason', v_text, 'agent_id', v_me));
  update cs.tickets set returned_reason = v_text, released_by = v_me where id = t.id returning * into t;
  perform cs.audit('ticket.release', t.id, t.customer_id, jsonb_build_object('reason', v_text));
  perform cs.after_owner_change(t, v_me, 'ticket_released', 'ticket_released');
  return t;
end;
$$;

create or replace function cs.auto_assign_open()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  w       record;
  v_agent uuid;
  v_count integer := 0;
begin
  for w in
    select t.id, t.required_skill, t.language, t.released_by from cs.tickets t
    where t.status = 'open'
    order by t.priority, t.queued_at
    for update skip locked
  loop
    select a.user_id into v_agent
    from cs.agents a
    join cs.agent_status st on st.agent_id = a.user_id
    left join cs.agent_skills k on k.agent_id = a.user_id and k.skill = w.required_skill
    where cs.is_reachable(a.user_id, w.language)
      and a.user_id is distinct from w.released_by
    order by (k.level is null), k.level desc, st.active_tickets, st.last_claimed_at nulls first
    limit 1
    for update of st skip locked;
    continue when v_agent is null;
    perform cs.change_owner(w.id, v_agent, 'assigned', jsonb_build_object('agent_id', v_agent, 'auto', true));
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
