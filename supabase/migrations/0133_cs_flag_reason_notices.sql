create table cs.compliance_notices (
  id         bigint generated always as identity primary key,
  ticket_id  uuid not null references cs.tickets (id) on delete cascade,
  flag       text not null check (flag in ('complaint', 'fraud')),
  reason     text check (reason is null or char_length(reason) between 1 and 300),
  source     text not null check (source in ('agent', 'customer', 'system')),
  actor_id   uuid,
  created_at timestamptz not null default now()
);

create index compliance_notices_created_idx on cs.compliance_notices (created_at desc);

create table cs.compliance_notice_reads (
  agent_id     uuid primary key,
  last_seen_id bigint not null default 0,
  seen_at      timestamptz not null default now()
);

alter table cs.compliance_notices enable row level security;
alter table cs.compliance_notice_reads enable row level security;
revoke all on cs.compliance_notices, cs.compliance_notice_reads from public, anon, authenticated;

drop function cs.flag_ticket(uuid, text);

create function cs.flag_ticket(p_ticket_id uuid, p_flag text, p_reason text default null)
returns cs.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  t        cs.tickets;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_actor  text := cs.actor_type();
  v_notice bigint;
begin
  if p_flag not in ('complaint', 'fraud') then
    perform private.api_error(400, 'invalid_flag', 'Tanda tiket tidak dikenal');
  end if;
  select * into t from cs.tickets where id = p_ticket_id for update;
  if not found then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if t.status in ('resolved', 'closed') then
    perform private.api_error(409, 'ticket_not_active', 'Tiket sudah selesai');
  end if;
  if p_flag = any (t.flags) then
    return t;
  end if;
  update cs.tickets
     set flags = array(select distinct f from unnest(flags || p_flag) f order by f),
         priority = case when p_flag = 'fraud' then 'P1' else least(priority, 'P2') end,
         required_skill = case when p_flag = 'fraud' or not ('fraud' = any (flags)) then p_flag else required_skill end,
         complaint_received_at = case when p_flag = 'complaint' then now() else complaint_received_at end,
         complaint_due_at = case when p_flag = 'complaint'
                                 then cs.regulatory_deadline(now(), cs.setting_int('complaint.days'))
                                 else complaint_due_at end,
         version = version + 1,
         updated_at = now()
   where id = p_ticket_id
  returning * into t;
  perform cs.log_event(t.id, 'flagged', jsonb_strip_nulls(jsonb_build_object('flag', p_flag, 'priority', t.priority,
                                                                             'reason', v_reason)));
  insert into cs.compliance_notices (ticket_id, flag, reason, source, actor_id)
  values (t.id, p_flag, v_reason,
          case when v_actor in ('agent', 'customer') then v_actor else 'system' end,
          case when v_actor in ('agent', 'customer') then auth.uid() end)
  returning id into v_notice;
  perform realtime.send(jsonb_build_object('id', v_notice, 'ticket_id', t.id, 'flag', p_flag),
                        'case_flagged', 'cs:compliance', true);
  if p_flag = 'complaint' then
    perform cs.system_message(t, 'complaint', cs.complaint_note(t));
  end if;
  perform cs.broadcast_ticket(t, 'ticket_updated');
  return t;
end;
$$;

drop function cs_api.flag_ticket(uuid, text);

create function cs_api.flag_ticket(p_ticket_id uuid, p_flag text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{cs_agent,cs_super_admin}');
  v_reason text := btrim(coalesce(p_reason, ''));
  t        cs.tickets;
begin
  if char_length(v_reason) not between 5 and 300 then
    perform private.api_error(400, 'reason_required', 'Alasan 5–300 karakter');
  end if;
  t := cs.owned_ticket(p_ticket_id, v_me, null, true);
  if p_flag = any (t.flags) then
    perform private.api_error(409, 'already_flagged', 'Tiket sudah bertanda ini');
  end if;
  t := cs.flag_ticket(t.id, p_flag, v_reason);
  perform cs.audit('ticket.flag', t.id, t.customer_id, jsonb_build_object('flag', p_flag, 'reason', v_reason));
  return cs.ticket_agent_view(t);
end;
$$;

create or replace function cs.can_access_topic(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_parts text[] := regexp_match(coalesce(p_topic, ''),
    '^cs:(room|agent):([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$');
begin
  if p_topic = 'cs:queue' then
    return cs.has_role('{cs_agent,cs_super_admin}');
  end if;
  if p_topic = 'cs:compliance' then
    return cs.has_role('{compliance,cs_super_admin}');
  end if;
  if v_parts is null then
    return false;
  end if;
  if v_parts[1] = 'agent' then
    return coalesce(v_parts[2]::uuid = cs.current_agent_id(), false);
  end if;
  return exists (select 1 from public.chat_rooms r
                 where r.id = v_parts[2]::uuid and r.type = 'support' and r.customer_id = auth.uid())
      or cs.can_read_room(v_parts[2]::uuid);
end;
$$;

create or replace function cs.tickets_notice_new_case()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor text := cs.actor_type();
  v_flag  text;
  v_id    bigint;
begin
  foreach v_flag in array new.flags loop
    continue when v_flag not in ('complaint', 'fraud');
    insert into cs.compliance_notices (ticket_id, flag, source, actor_id)
    values (new.id, v_flag, case when v_actor in ('agent', 'customer') then v_actor else 'system' end,
            case when v_actor in ('agent', 'customer') then auth.uid() end)
    returning id into v_id;
    perform realtime.send(jsonb_build_object('id', v_id, 'ticket_id', new.id, 'flag', v_flag),
                          'case_flagged', 'cs:compliance', true);
  end loop;
  return null;
end;
$$;

create trigger tickets_80_notice_new_case
  after insert on cs.tickets
  for each row when (cardinality(new.flags) > 0)
  execute function cs.tickets_notice_new_case();

create or replace function cs_api.compliance_notices()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_seen bigint := coalesce((select r.last_seen_id from cs.compliance_notice_reads r where r.agent_id = v_me), 0);
begin
  return jsonb_build_object(
    'unseen', (select count(*) from cs.compliance_notices n where n.id > v_seen),
    'last_seen_id', v_seen,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', n.id, 'ticket_id', n.ticket_id, 'ticket_number', t.ticket_number, 'flag', n.flag,
               'reason', n.reason, 'source', n.source,
               'actor_name', case when n.source = 'agent' then cs.agent_name(n.actor_id) end,
               'created_at', n.created_at, 'seen', n.id <= v_seen)
             order by n.id desc)
      from (select * from cs.compliance_notices x order by x.id desc limit 30) n
      join cs.tickets t on t.id = n.ticket_id), '[]'));
end;
$$;

create or replace function cs_api.compliance_notices_seen()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{compliance,cs_super_admin}');
  v_max bigint := coalesce((select max(n.id) from cs.compliance_notices n), 0);
begin
  insert into cs.compliance_notice_reads (agent_id, last_seen_id) values (v_me, v_max)
  on conflict (agent_id) do update
    set last_seen_id = greatest(cs.compliance_notice_reads.last_seen_id, excluded.last_seen_id), seen_at = now();
  return cs_api.compliance_notices();
end;
$$;

revoke execute on function cs.flag_ticket(uuid, text, text) from public;
revoke execute on function cs_api.flag_ticket(uuid, text, text) from public;
revoke execute on function cs_api.compliance_notices() from public;
revoke execute on function cs_api.compliance_notices_seen() from public;
grant execute on function cs_api.flag_ticket(uuid, text, text) to authenticated;
grant execute on function cs_api.compliance_notices() to authenticated;
grant execute on function cs_api.compliance_notices_seen() to authenticated;
revoke execute on function cs.tickets_notice_new_case() from public;
