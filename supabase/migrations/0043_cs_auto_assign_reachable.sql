insert into cs.cs_settings (key, value, description) values
  ('assignment.heartbeat_seconds', '90',
   'Penugasan otomatis hanya ke CS Online yang heartbeat web CS-nya lebih baru dari sekian detik. Browser memperlambat tab di latar belakang hingga sekitar satu heartbeat per menit, jadi nilainya harus di atas 60')
on conflict (key) do nothing;

create or replace function cs.is_reachable(p_agent uuid, p_language text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select cs.can_take_tickets(p_agent)
     and exists (select 1 from cs.agents a
                 join cs.agent_status st on st.agent_id = a.user_id
                 where a.user_id = p_agent
                   and p_language = any (a.languages)
                   and st.last_heartbeat_at > now() - make_interval(secs => cs.setting_int('assignment.heartbeat_seconds')));
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
    select t.id, t.required_skill, t.language from cs.tickets t
    where t.status = 'open'
    order by t.priority, t.queued_at
    for update skip locked
  loop
    select a.user_id into v_agent
    from cs.agents a
    join cs.agent_status st on st.agent_id = a.user_id
    left join cs.agent_skills k on k.agent_id = a.user_id and k.skill = w.required_skill
    where cs.is_reachable(a.user_id, w.language)
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

create or replace function cs.assign_when_auto()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claims text := current_setting('request.jwt.claims', true);
  v_sub    text := current_setting('request.jwt.claim.sub', true);
  v_role   text := current_setting('request.jwt.claim.role', true);
begin
  if cs.setting('assignment.mode') #>> '{}' = 'auto_assign' then
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claim.sub', '', true);
    perform set_config('request.jwt.claim.role', '', true);
    perform cs.auto_assign_open();
    perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);
    perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
    perform set_config('request.jwt.claim.role', coalesce(v_role, ''), true);
  end if;
  return null;
end;
$$;

create or replace function cs.open_ticket(p_customer uuid, p_topic text, p_language text, p_flags text[],
                                          p_context jsonb, p_first_text text)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  tp     cs.support_topics;
  v_room uuid;
  v_prio record;
  v_body text;
  v_old  uuid;
  t      cs.tickets;
begin
  select * into tp from cs.support_topics where code = p_topic and active;
  if not found then
    perform private.api_error(400, 'invalid_topic', 'Topik bantuan tidak dikenal');
  end if;
  v_room := cs.ensure_room(p_customer);
  select * into t from cs.tickets where room_id = v_room and status in ('open', 'claimed', 'waiting_customer') for update;
  if found then
    return t;
  end if;
  perform cs.check_rate('cs_ticket', p_customer);
  for v_old in select x.id from cs.tickets x where x.room_id = v_room and x.status = 'resolved' loop
    perform cs.finalize_ticket(v_old, 'superseded');
  end loop;

  select * into v_prio from cs.initial_priority(
    p_topic,
    coalesce(p_flags, '{}') || case when exists (select 1 from cs.vip_customers v where v.customer_id = p_customer)
                                    then array['vip'] else array[]::text[] end,
    p_first_text, now());

  insert into cs.tickets (room_id, customer_id, topic, language, priority, flags, required_skill, context,
                          ticket_number, complaint_received_at, complaint_due_at)
  values (v_room, p_customer, tp.code, coalesce(p_language, 'id'), v_prio.priority, v_prio.flags,
          case when 'fraud' = any (v_prio.flags) then 'fraud'
               when 'complaint' = any (v_prio.flags) then 'complaint'
               else tp.skill end,
          coalesce(p_context, '{}'), cs.next_ticket_number(),
          case when 'complaint' = any (v_prio.flags) then now() end,
          case when 'complaint' = any (v_prio.flags)
               then cs.regulatory_deadline(now(), cs.setting_int('complaint.days')) end)
  on conflict (room_id) where status in ('open', 'claimed', 'waiting_customer') do nothing
  returning * into t;
  if t.id is null then
    select * into t from cs.tickets where room_id = v_room and status in ('open', 'claimed', 'waiting_customer');
    return t;
  end if;

  perform cs.log_event(t.id, 'opened', jsonb_build_object('topic', t.topic, 'priority', t.priority, 'flags', t.flags));
  v_body := cs.message_text(t, 'ticket_opened',
    jsonb_build_object('name', coalesce((select p.display_name from public.profiles p where p.id = p_customer), '')));
  if not cs.is_open(now()) and not exists (select 1 from cs.agents a where cs.is_reachable(a.user_id, t.language)) then
    v_body := v_body || ' ' || cs.message_text(t, 'out_of_hours',
      jsonb_build_object('next_open', cs.format_time(cs.next_open_at(now()), t.language)));
  end if;
  if 'complaint' = any (t.flags) then
    v_body := v_body || ' ' || cs.message_text(t, 'complaint', cs.complaint_note(t));
  end if;
  perform cs.post_system(t, 'ticket_opened', v_body, 'system',
    case when tp.help_url is null then '{}'::jsonb else jsonb_build_object('url', tp.help_url) end);
  perform cs.broadcast_ticket(t, 'ticket_opened');
  return t;
end;
$$;

create or replace function cs.run_sweep()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r          record;
  v_expired  integer := 0;
  v_closed   integer := 0;
  v_released integer := 0;
  v_assigned integer := 0;
  v_minutes  integer := coalesce(cs.setting_int('ticket.auto_release_offline_minutes'), 0);
begin
  for r in
    update cs.ticket_transfers set result = 'expired', responded_at = now()
     where result is null and expires_at <= now()
    returning ticket_id, from_agent_id, id
  loop
    perform cs.log_event(r.ticket_id, 'transfer_expired');
    perform realtime.send(jsonb_build_object('event', 'transfer_expired', 'transfer_id', r.id, 'ticket_id', r.ticket_id),
                          'transfer', 'cs:agent:' || r.from_agent_id::text, true);
    v_expired := v_expired + 1;
  end loop;

  for r in
    select t.id from cs.tickets t
    where t.status = 'resolved' and t.resolved_at < now() - make_interval(hours => cs.setting_int('ticket.reopen_hours'))
    for update skip locked
  loop
    perform cs.finalize_ticket(r.id, 'reopen_window_passed');
    v_closed := v_closed + 1;
  end loop;

  if v_minutes > 0 then
    for r in
      select distinct t.owner_agent_id as agent_id from cs.tickets t
      where t.status in ('claimed', 'waiting_customer') and cs.agent_is_away(t.owner_agent_id, v_minutes)
    loop
      v_released := v_released + cs.release_owner_tickets(r.agent_id,
        format('Pemilik offline lebih dari %s menit', v_minutes));
    end loop;
  end if;

  if cs.setting('assignment.mode') #>> '{}' = 'auto_assign' then
    v_assigned := cs.auto_assign_open();
  end if;

  return jsonb_build_object('transfers_expired', v_expired, 'tickets_closed', v_closed,
                            'tickets_released', v_released, 'tickets_assigned', v_assigned);
end;
$$;

revoke execute on function cs.is_reachable(uuid, text) from public;
