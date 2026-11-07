create table cs.compliance_ticket_access (
  agent_id  uuid not null references cs.agents (user_id) on delete cascade,
  ticket_id uuid not null references cs.tickets (id) on delete cascade,
  opened_at timestamptz not null default now(),
  primary key (agent_id, ticket_id)
);

alter table cs.compliance_ticket_access enable row level security;
revoke all on cs.compliance_ticket_access from public, anon, authenticated;

create or replace function cs.compliance_opened(p_ticket_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from cs.compliance_ticket_access a
                 where a.agent_id = cs.current_agent_id()
                   and a.ticket_id = p_ticket_id
                   and a.opened_at > now() - interval '12 hours');
$$;

create or replace function cs.can_read_room(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when cs.current_agent_id() is null then false
    when cs.has_role('{cs_super_admin}') then
      exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'support')
    else (cs.has_role('{cs_agent}')
          and (cs.agent_can_read_room(p_room_id)
               or exists (select 1 from cs.tickets t where t.room_id = p_room_id and t.status = 'open')))
      or (cs.has_role('{compliance}')
          and (exists (select 1 from cs.tickets t where t.room_id = p_room_id and t.flags && '{complaint,fraud}')
               or exists (select 1 from cs.compliance_ticket_access a
                          join cs.tickets t on t.id = a.ticket_id
                          where t.room_id = p_room_id
                            and a.agent_id = cs.current_agent_id()
                            and a.opened_at > now() - interval '12 hours')))
  end;
$$;

create or replace function cs.can_read_ticket(p_room_id uuid, p_ticket_id uuid, p_status text, p_flags text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when cs.current_agent_id() is null then false
    when cs.has_role('{cs_super_admin}') then true
    else (cs.has_role('{cs_agent}') and (p_status = 'open' or cs.agent_can_read_room(p_room_id)))
      or (cs.has_role('{compliance}') and (p_flags && '{complaint,fraud}' or cs.compliance_opened(p_ticket_id)))
  end;
$$;

create or replace function cs.can_read_notes(p_customer_id uuid, p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when cs.current_agent_id() is null then false
    when cs.has_role('{cs_super_admin}') then true
    else (cs.has_role('{cs_agent}')
          and cs.agent_can_read_room((select r.id from public.chat_rooms r
                                      where r.type = 'support' and r.customer_id = p_customer_id)))
      or (cs.has_role('{compliance}') and p_session_id is not null
          and (exists (select 1 from cs.tickets t where t.id = p_session_id and t.flags && '{complaint,fraud}')
               or cs.compliance_opened(p_session_id)))
  end;
$$;

create or replace function cs.compliance_case_row(t cs.tickets)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id,
    'ticket_number', t.ticket_number,
    'case', cs.is_case(t),
    'room_id', t.room_id,
    'version', t.version,
    'status', t.status,
    'priority', t.priority,
    'flags', to_jsonb(t.flags),
    'topic', t.topic,
    'topic_name', (select tp.name_id from cs.support_topics tp where tp.code = t.topic),
    'language', t.language,
    'fake_cs', coalesce(t.context ->> 'report' = 'fake_cs', false),
    'customer', (select jsonb_build_object('id', p.id, 'display_name', p.display_name, 'username', p.username,
                                           'deleted', p.deleted_at is not null)
                 from public.profiles p where p.id = t.customer_id),
    'agent', (select jsonb_build_object('id', a.user_id, 'display_name', a.display_name, 'agent_code', a.agent_code)
              from cs.agents a where a.user_id = coalesce(t.owner_agent_id, t.last_owner_id)),
    'created_at', t.created_at,
    'complaint_received_at', t.complaint_received_at,
    'complaint_due_at', t.complaint_due_at,
    'complaint_extended_at', t.complaint_extended_at,
    'resolved_at', t.resolved_at,
    'closed_at', t.closed_at,
    'outcome', t.outcome,
    'rating', t.rating,
    'deadline', cs.complaint_deadline(t),
    'review', (select jsonb_build_object('verdict', r.verdict, 'note', r.note, 'created_at', r.created_at,
                                         'reviewer', cs.agent_name(r.reviewer_id))
               from cs.compliance_reviews r where r.ticket_id = t.id
               order by r.created_at desc limit 1));
$$;

create or replace function cs.read_compliance_ticket(p_ticket_id uuid)
returns cs.tickets
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t cs.tickets;
begin
  select * into t from cs.tickets where id = p_ticket_id;
  if not found or not (cs.is_case(t) or cs.compliance_opened(t.id)) then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  return t;
end;
$$;

create or replace function cs_api.compliance_case(p_ticket_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{compliance}');
  v_days integer := cs.setting_int('complaint.extension_days');
  t      cs.tickets;
begin
  select * into t from cs.tickets where id = p_ticket_id;
  if not found then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if cs.is_case(t) then
    perform cs.audit('compliance.case_view', t.id, t.customer_id);
  else
    delete from cs.compliance_ticket_access
     where agent_id = v_me and opened_at <= now() - interval '12 hours';
    insert into cs.compliance_ticket_access (agent_id, ticket_id)
    values (v_me, t.id)
    on conflict (agent_id, ticket_id) do update set opened_at = now();
    perform cs.audit('compliance.ticket_view', t.id, t.customer_id);
  end if;
  return cs.compliance_case_row(t) || jsonb_build_object(
    'resolution_summary', t.resolution_summary,
    'returned_reason', t.returned_reason,
    'rating_comment', t.rating_comment,
    'context', t.context,
    'complaint_extension_reason', t.complaint_extension_reason,
    'extension_days', v_days,
    'can_extend', 'complaint' = any (t.flags)
                  and t.status in ('open', 'claimed', 'waiting_customer')
                  and t.complaint_extended_at is null
                  and now() <= t.complaint_due_at
                  and coalesce(v_days, 0) > 0,
    'events', coalesce((select jsonb_agg(jsonb_build_object('type', e.type, 'actor_type', e.actor_type,
                                                            'actor_name', cs.agent_name(e.actor_id),
                                                            'data', e.data, 'created_at', e.created_at)
                                         order by e.created_at, e.id)
                        from cs.session_events e where e.session_id = t.id), '[]'),
    'notes', coalesce((select jsonb_agg(jsonb_build_object(
                                'id', n.id, 'session_id', n.session_id, 'kind', n.kind, 'body', n.body,
                                'created_at', n.created_at,
                                'author', case when a.user_id is not null
                                               then jsonb_build_object('display_name', a.display_name,
                                                                       'agent_code', a.agent_code) end)
                              order by n.created_at)
                       from cs.agent_notes n
                       left join cs.agents a on a.user_id = n.author_id
                       where n.session_id = t.id), '[]'),
    'reviews', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'verdict', r.verdict, 'note', r.note,
                                                             'created_at', r.created_at,
                                                             'reviewer', cs.agent_name(r.reviewer_id))
                                          order by r.created_at desc)
                         from cs.compliance_reviews r where r.ticket_id = t.id), '[]'));
end;
$$;

create or replace function cs_api.compliance_transcript_exported(p_ticket_id uuid, p_sha256 text, p_messages integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{compliance}');
  t    cs.tickets;
begin
  if p_sha256 is null or p_sha256 !~ '^[0-9a-f]{64}$' then
    perform private.api_error(400, 'invalid_hash', 'Sidik transkrip harus SHA-256 (64 karakter hex)');
  end if;
  t := cs.read_compliance_ticket(p_ticket_id);
  perform cs.audit('compliance.transcript_export', t.id, t.customer_id,
                   jsonb_build_object('sha256', p_sha256, 'messages', greatest(coalesce(p_messages, 0), 0)));
  return jsonb_build_object('ticket_id', t.id, 'sha256', p_sha256, 'exported_at', now());
end;
$$;

create or replace function cs_api.compliance_cases(
  p_kind  text default 'all',
  p_state text default 'all',
  p_from  date default null,
  p_to    date default null,
  p_query text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance}');
  v_kind  text := coalesce(p_kind, 'all');
  v_flags text[] := case v_kind
                      when 'all' then '{complaint,fraud}'::text[]
                      when 'complaint' then '{complaint}'::text[]
                      when 'fraud' then '{fraud}'::text[]
                    end;
  v_state text := coalesce(p_state, 'all');
  v_like  text := cs.like_pattern(p_query);
  v_total integer;
  v_rows  jsonb;
begin
  if v_flags is null and v_kind <> 'tickets' then
    perform private.api_error(400, 'invalid_kind', 'Jenis kasus tidak dikenal');
  end if;
  if v_state not in ('all', 'active', 'attention', 'done', 'unreviewed') then
    perform private.api_error(400, 'invalid_state', 'Keadaan kasus tidak dikenal');
  end if;
  if (p_from is null) <> (p_to is null) or p_to < p_from or p_to - p_from > 365 then
    perform private.api_error(400, 'invalid_range', 'Periode kasus 1–366 hari');
  end if;
  with c as (
    select t as ticket,
           t.status in ('open', 'claimed', 'waiting_customer') as active,
           cs.complaint_deadline(t) ->> 'state' as state,
           exists (select 1 from cs.compliance_reviews r where r.ticket_id = t.id) as reviewed,
           t.complaint_due_at,
           t.created_at
    from cs.tickets t
    join public.profiles p on p.id = t.customer_id
    where (v_flags is null or t.flags && v_flags)
      and (p_from is null
           or (t.created_at >= p_from::timestamp at time zone 'Asia/Jakarta'
               and t.created_at < (p_to + 1)::timestamp at time zone 'Asia/Jakarta'))
      and (v_like is null or t.ticket_number ilike v_like or p.display_name ilike v_like or p.username::text ilike v_like)
  ), s as (
    select * from c
    where case v_state
            when 'active' then c.active
            when 'attention' then c.state in ('overdue', 'due_soon')
            when 'done' then not c.active
            when 'unreviewed' then not c.active and not c.reviewed
            else true
          end
  )
  select (select count(*) from s),
         coalesce((select jsonb_agg(cs.compliance_case_row(x.ticket)
                                    order by x.active desc, x.complaint_due_at nulls last, x.created_at desc)
                   from (select * from s
                         order by s.active desc, s.complaint_due_at nulls last, s.created_at desc
                         limit 1000) x), '[]')
    into v_total, v_rows;
  return jsonb_build_object('rows', v_rows, 'total', v_total, 'truncated', v_total > 1000);
end;
$$;

revoke execute on function cs.compliance_opened(uuid) from public;
revoke execute on function cs.read_compliance_ticket(uuid) from public;
