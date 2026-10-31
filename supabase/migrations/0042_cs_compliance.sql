alter table cs.tickets
  add column complaint_extended_at timestamptz,
  add column complaint_extension_reason text,
  add constraint tickets_complaint_extension_check check (
    (complaint_extended_at is null) = (complaint_extension_reason is null)
    and (complaint_extension_reason is null or char_length(btrim(complaint_extension_reason)) between 10 and 500));

insert into cs.cs_settings (key, value, description) values
  ('complaint.extension_days', '10',
   'Perpanjangan tenggat pengaduan (hari kerja), paling banyak satu kali per pengaduan. 0 = tidak bisa diperpanjang. Usulan default, wajib dikonfirmasi kepatuhan'),
  ('messages.complaint_extended',
   '{"id": "Penyelesaian pengaduan Anda membutuhkan waktu lebih lama. Kami akan menyelesaikannya paling lambat {due_at}.", "en": "Resolving your complaint needs more time. We will resolve it no later than {due_at}."}',
   'Pesan saat tenggat pengaduan diperpanjang')
on conflict (key) do nothing;

create table cs.compliance_reviews (
  id          uuid primary key default gen_random_uuid(),
  ticket_id   uuid not null references cs.tickets (id) on delete restrict,
  reviewer_id uuid not null references cs.agents (user_id),
  verdict     text not null check (verdict in ('compliant', 'needs_action', 'violation')),
  note        text not null check (char_length(btrim(note)) between 5 and 1000),
  created_at  timestamptz not null default clock_timestamp()
);

create index compliance_reviews_ticket_idx on cs.compliance_reviews (ticket_id, created_at desc);

create table cs.policy_confirmations (
  id           bigint generated always as identity primary key,
  key          text not null references cs.cs_settings (key),
  version      integer not null,
  value        jsonb not null,
  note         text check (char_length(note) <= 500),
  confirmed_by uuid not null references cs.agents (user_id),
  confirmed_at timestamptz not null default clock_timestamp(),
  unique (key, version)
);

alter table cs.compliance_reviews enable row level security;
alter table cs.policy_confirmations enable row level security;

create policy compliance_reviews_select on cs.compliance_reviews
  for select to authenticated
  using ((select cs.has_role('{compliance,cs_super_admin}')));

create policy policy_confirmations_select on cs.policy_confirmations
  for select to authenticated
  using ((select cs.has_role('{compliance,cs_super_admin}')));

grant select on cs.compliance_reviews, cs.policy_confirmations to authenticated;

create trigger compliance_reviews_append_only
before update or delete on cs.compliance_reviews
for each row execute function cs.reject_change();

create trigger compliance_reviews_no_truncate
before truncate on cs.compliance_reviews
for each statement execute function cs.reject_change();

create trigger policy_confirmations_append_only
before update or delete on cs.policy_confirmations
for each row execute function cs.reject_change();

create trigger policy_confirmations_no_truncate
before truncate on cs.policy_confirmations
for each statement execute function cs.reject_change();

create or replace function cs.policy_rules()
returns table (key text, min_value integer, max_value integer, unit text, sort_order integer)
language sql
immutable
set search_path = ''
as $$
  values ('complaint.days', 1, 20, 'business_days', 1),
         ('complaint.extension_days', 0, 20, 'business_days', 2),
         ('retention.chat_years', 5, 30, 'years', 3);
$$;

create or replace function cs.is_case(t cs.tickets)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select t.flags && '{complaint,fraud}'::text[];
$$;

create or replace function cs.complaint_deadline(t cs.tickets, p_now timestamptz default now())
returns jsonb
language sql
stable
set search_path = ''
as $$
  select case
    when t.complaint_due_at is null then null
    when t.status in ('resolved', 'closed') then
      case when coalesce(t.resolved_at, t.closed_at) <= t.complaint_due_at
        then jsonb_build_object('state', 'met', 'business_days', 0)
        else jsonb_build_object('state', 'missed', 'business_days',
               cs.business_days_between(cs.local_date(t.complaint_due_at), cs.local_date(coalesce(t.resolved_at, t.closed_at))))
      end
    when p_now > t.complaint_due_at then
      jsonb_build_object('state', 'overdue', 'business_days',
        cs.business_days_between(cs.local_date(t.complaint_due_at), cs.local_date(p_now)))
    else (
      select jsonb_build_object('state', case when d.n <= 1 then 'due_soon' else 'running' end, 'business_days', d.n)
      from (select cs.business_days_between(cs.local_date(p_now), cs.local_date(t.complaint_due_at)) as n) d)
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

create or replace function cs.compliance_policy_view(p_key text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'key', s.key,
    'value', s.value,
    'description', s.description,
    'version', s.version,
    'updated_at', s.updated_at,
    'updated_by', cs.agent_name(s.updated_by),
    'min', r.min_value,
    'max', r.max_value,
    'unit', r.unit,
    'confirmed', exists (select 1 from cs.policy_confirmations c where c.key = s.key and c.version = s.version),
    'confirmation', (select jsonb_build_object('version', c.version, 'value', c.value, 'note', c.note,
                                               'confirmed_at', c.confirmed_at, 'confirmed_by', cs.agent_name(c.confirmed_by))
                     from cs.policy_confirmations c where c.key = s.key
                     order by c.version desc limit 1))
  from cs.policy_rules() r
  join cs.cs_settings s on s.key = r.key
  where r.key = p_key;
$$;

create or replace function cs.read_case(p_ticket_id uuid)
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
  if not found or not cs.is_case(t) then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  return t;
end;
$$;

create or replace function cs.like_pattern(p_term text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when char_length(btrim(coalesce(p_term, ''))) >= 2
    then '%' || replace(replace(replace(left(btrim(p_term), 80), '\', '\\'), '%', '\%'), '_', '\_') || '%'
  end;
$$;

create or replace function cs_api.compliance_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance}');
  v_since timestamptz := now() - interval '30 days';
begin
  return (
    with f as (
      select t as ticket,
             t.status in ('open', 'claimed', 'waiting_customer') as active,
             cs.complaint_deadline(t) ->> 'state' as state,
             exists (select 1 from cs.compliance_reviews r where r.ticket_id = t.id) as reviewed
      from cs.tickets t
      where cs.is_case(t)
    )
    select jsonb_build_object(
      'generated_at', now(),
      'active_complaints', (select count(*) from f where f.active and 'complaint' = any ((f.ticket).flags)),
      'due_soon', (select count(*) from f where f.state = 'due_soon'),
      'overdue', (select count(*) from f where f.state = 'overdue'),
      'on_time', (select jsonb_build_object('met', count(*) filter (where f.state = 'met'), 'total', count(*))
                  from f
                  where f.state in ('met', 'missed')
                    and coalesce((f.ticket).resolved_at, (f.ticket).closed_at) >= v_since),
      'active_fraud', (select count(*) from f where f.active and 'fraud' = any ((f.ticket).flags)),
      'fake_cs_reports', (select count(*) from f
                          where (f.ticket).context ->> 'report' = 'fake_cs' and (f.ticket).created_at >= v_since),
      'secret_blocked', (select count(*) from cs.cs_audit_log l
                         where l.action = 'message.secret_request_blocked' and l.created_at >= v_since),
      'unreviewed', (select count(*) from f where not f.active and not f.reviewed),
      'policies_unconfirmed', (select count(*) from cs.policy_rules() r
                               join cs.cs_settings s on s.key = r.key
                               where not exists (select 1 from cs.policy_confirmations c
                                                 where c.key = s.key and c.version = s.version)),
      'deadlines', coalesce((select jsonb_agg(cs.compliance_case_row(x.ticket) order by (x.ticket).complaint_due_at)
                             from (select * from f
                                   where f.active and (f.ticket).complaint_due_at is not null
                                   order by (f.ticket).complaint_due_at limit 8) x), '[]'),
      'fraud', coalesce((select jsonb_agg(cs.compliance_case_row(x.ticket)
                                          order by (x.ticket).priority, (x.ticket).created_at)
                         from (select * from f
                               where f.active and 'fraud' = any ((f.ticket).flags)
                               order by (f.ticket).priority, (f.ticket).created_at limit 8) x), '[]'),
      'to_review', coalesce((select jsonb_agg(cs.compliance_case_row(x.ticket)
                                              order by coalesce((x.ticket).resolved_at, (x.ticket).closed_at) desc)
                             from (select * from f
                                   where not f.active and not f.reviewed
                                   order by coalesce((f.ticket).resolved_at, (f.ticket).closed_at) desc limit 8) x), '[]'),
      'secret_agents', coalesce((
        select jsonb_agg(jsonb_build_object('id', a.user_id, 'display_name', a.display_name, 'agent_code', a.agent_code,
                                            'count', x.n, 'last_at', x.last_at)
                         order by x.n desc, x.last_at desc)
        from (select l.actor_id, count(*) as n, max(l.created_at) as last_at
              from cs.cs_audit_log l
              where l.action = 'message.secret_request_blocked' and l.created_at >= v_since and l.actor_id is not null
              group by l.actor_id
              order by n desc, last_at desc
              limit 10) x
        join cs.agents a on a.user_id = x.actor_id), '[]')));
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
  v_flags text[] := case coalesce(p_kind, 'all')
                      when 'all' then '{complaint,fraud}'::text[]
                      when 'complaint' then '{complaint}'::text[]
                      when 'fraud' then '{fraud}'::text[]
                    end;
  v_state text := coalesce(p_state, 'all');
  v_like  text := cs.like_pattern(p_query);
  v_total integer;
  v_rows  jsonb;
begin
  if v_flags is null then
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
    where t.flags && v_flags
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

create or replace function cs_api.compliance_case(p_ticket_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{compliance}');
  t      cs.tickets := cs.read_case(p_ticket_id);
  v_days integer := cs.setting_int('complaint.extension_days');
begin
  perform cs.audit('compliance.case_view', t.id, t.customer_id);
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

create or replace function cs_api.compliance_review(p_ticket_id uuid, p_verdict text, p_note text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{compliance}');
  v_note text := btrim(coalesce(p_note, ''));
  t      cs.tickets;
  r      cs.compliance_reviews;
begin
  if p_verdict is null or p_verdict not in ('compliant', 'needs_action', 'violation') then
    perform private.api_error(400, 'invalid_verdict', 'Pilih putusan: sesuai, perlu tindak lanjut, atau pelanggaran');
  end if;
  if char_length(v_note) not between 5 and 1000 then
    perform private.api_error(400, 'invalid_note', 'Catatan tinjauan 5–1000 karakter');
  end if;
  t := cs.read_case(p_ticket_id);
  insert into cs.compliance_reviews (ticket_id, reviewer_id, verdict, note)
  values (t.id, v_me, p_verdict, v_note)
  returning * into r;
  perform cs.audit('compliance.review', t.id, t.customer_id, jsonb_build_object('verdict', p_verdict));
  return jsonb_build_object('id', r.id, 'verdict', r.verdict, 'note', r.note, 'created_at', r.created_at,
                            'reviewer', cs.agent_name(v_me));
end;
$$;

create or replace function cs_api.compliance_extend_deadline(p_ticket_id uuid, p_reason text, p_version integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := cs.require_agent('{compliance}');
  v_reason text := btrim(coalesce(p_reason, ''));
  v_days   integer := cs.setting_int('complaint.extension_days');
  v_from   timestamptz;
  t        cs.tickets;
begin
  if char_length(v_reason) not between 10 and 500 then
    perform private.api_error(400, 'invalid_reason', 'Alasan perpanjangan 10–500 karakter');
  end if;
  t := cs.lock_ticket(p_ticket_id, p_version);
  if not cs.is_case(t) then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if not ('complaint' = any (t.flags)) then
    perform private.api_error(409, 'not_complaint', 'Hanya pengaduan yang punya tenggat');
  end if;
  if t.status not in ('open', 'claimed', 'waiting_customer') then
    perform private.api_error(409, 'ticket_not_active', 'Pengaduan sudah selesai');
  end if;
  if t.complaint_extended_at is not null then
    perform private.api_error(409, 'already_extended', 'Tenggat pengaduan ini sudah pernah diperpanjang');
  end if;
  if coalesce(v_days, 0) <= 0 then
    perform private.api_error(409, 'extension_disabled', 'Perpanjangan tenggat sedang dimatikan di Kebijakan');
  end if;
  if now() > t.complaint_due_at then
    perform private.api_error(409, 'deadline_passed', 'Tenggat sudah lewat. Perpanjangan harus diberitahukan sebelum tenggat');
  end if;
  v_from := t.complaint_due_at;
  update cs.tickets
     set complaint_due_at = cs.regulatory_deadline(t.complaint_due_at, v_days),
         complaint_extended_at = now(),
         complaint_extension_reason = v_reason,
         version = version + 1,
         updated_at = now()
   where id = t.id
  returning * into t;
  perform cs.log_event(t.id, 'complaint_extended',
                       jsonb_build_object('from', v_from, 'to', t.complaint_due_at, 'days', v_days, 'reason', v_reason));
  perform cs.system_message(t, 'complaint_extended',
                            jsonb_build_object('due_at', cs.format_time(t.complaint_due_at, t.language)));
  perform cs.broadcast_ticket(t, 'ticket_updated');
  perform cs.audit('compliance.deadline_extended', t.id, t.customer_id,
                   jsonb_build_object('from', v_from, 'to', t.complaint_due_at, 'days', v_days));
  return cs.compliance_case_row(t);
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
  t := cs.read_case(p_ticket_id);
  perform cs.audit('compliance.transcript_export', t.id, t.customer_id,
                   jsonb_build_object('sha256', p_sha256, 'messages', greatest(coalesce(p_messages, 0), 0)));
  return jsonb_build_object('ticket_id', t.id, 'sha256', p_sha256, 'exported_at', now());
end;
$$;

create or replace function cs_api.compliance_audit(
  p_from      date,
  p_to        date,
  p_action    text default null,
  p_query     text default null,
  p_before_at timestamptz default null,
  p_before_id bigint default null,
  p_limit     integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{compliance}');
  v_limit integer := least(greatest(coalesce(p_limit, 100), 1), 200);
  v_like  text := cs.like_pattern(p_query);
  v_from  timestamptz;
  v_to    timestamptz;
  v_rows  jsonb;
  v_count integer;
  v_last  jsonb;
begin
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 365 then
    perform private.api_error(400, 'invalid_range', 'Periode jejak audit 1–366 hari');
  end if;
  if (p_before_at is null) <> (p_before_id is null) then
    perform private.api_error(400, 'invalid_cursor', 'Penanda halaman tidak lengkap');
  end if;
  v_from := p_from::timestamp at time zone 'Asia/Jakarta';
  v_to := (p_to + 1)::timestamp at time zone 'Asia/Jakarta';
  select coalesce(jsonb_agg(x.entry order by x.created_at desc, x.id desc), '[]'), count(*)
    into v_rows, v_count
  from (
    select l.id, l.created_at, jsonb_build_object(
             'id', l.id,
             'created_at', l.created_at,
             'action', l.action,
             'actor_type', l.actor_type,
             'actor_roles', to_jsonb(l.actor_roles),
             'actor', case
                        when a.user_id is not null then
                          jsonb_build_object('id', a.user_id, 'display_name', a.display_name, 'agent_code', a.agent_code)
                        when pa.id is not null then
                          jsonb_build_object('id', pa.id, 'display_name', pa.display_name, 'username', pa.username)
                      end,
             'ticket', case when t.id is not null then
                         jsonb_build_object('id', t.id, 'ticket_number', t.ticket_number, 'case', cs.is_case(t)) end,
             'customer', case when p.id is not null then
                           jsonb_build_object('id', p.id, 'display_name', p.display_name, 'username', p.username) end,
             'details', l.details) as entry
    from cs.cs_audit_log l
    left join cs.agents a on a.user_id = l.actor_id
    left join public.profiles pa on pa.id = l.actor_id and l.actor_type = 'customer'
    left join cs.tickets t on t.id = l.session_id
    left join public.profiles p on p.id = coalesce(l.customer_id, t.customer_id)
    where l.created_at >= v_from and l.created_at < v_to
      and (p_action is null or l.action = p_action)
      and (p_before_at is null or (l.created_at, l.id) < (p_before_at, p_before_id))
      and (v_like is null
           or l.action ilike v_like or a.display_name ilike v_like or a.agent_code ilike v_like
           or pa.display_name ilike v_like or pa.username::text ilike v_like
           or t.ticket_number ilike v_like or p.display_name ilike v_like or p.username::text ilike v_like)
    order by l.created_at desc, l.id desc
    limit v_limit + 1) x;
  if v_count > v_limit then
    v_rows := v_rows - v_limit;
    v_last := v_rows -> (v_limit - 1);
  end if;
  return jsonb_build_object(
    'rows', v_rows,
    'next', case when v_last is not null
                 then jsonb_build_object('before_at', v_last -> 'created_at', 'before_id', v_last -> 'id') end,
    'actions', case when p_before_at is null then coalesce((
                 select jsonb_agg(jsonb_build_object('action', s.action, 'count', s.n) order by s.n desc, s.action)
                 from (select l.action, count(*) as n from cs.cs_audit_log l
                       where l.created_at >= v_from and l.created_at < v_to
                       group by l.action) s), '[]') end);
end;
$$;

create or replace function cs_api.compliance_policies()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{compliance}');
begin
  return jsonb_build_object(
    'policies', (select jsonb_agg(cs.compliance_policy_view(r.key) order by r.sort_order) from cs.policy_rules() r),
    'history', coalesce((
      select jsonb_agg(jsonb_build_object('key', h.key, 'version', h.version, 'old_value', h.old_value,
                                          'new_value', h.new_value, 'changed_at', h.changed_at,
                                          'changed_by', cs.agent_name(h.changed_by))
                       order by h.changed_at desc, h.id desc)
      from (select h.* from cs.cs_settings_history h
            where h.key in (select r.key from cs.policy_rules() r)
            order by h.changed_at desc, h.id desc
            limit 30) h), '[]'));
end;
$$;

create or replace function cs_api.compliance_confirm_policy(p_key text, p_value jsonb, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{compliance}');
  v_note    text := nullif(btrim(coalesce(p_note, '')), '');
  v_rule    record;
  v_old     jsonb;
  v_version integer;
begin
  select * into v_rule from cs.policy_rules() r where r.key = p_key;
  if not found then
    perform private.api_error(403, 'policy_locked', 'Kepatuhan hanya mengatur tenggat pengaduan, perpanjangan tenggat, dan retensi chat');
  end if;
  if p_value is null or jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
     or (p_value #>> '{}')::integer not between v_rule.min_value and v_rule.max_value then
    perform private.api_error(400, 'invalid_policy',
      format('Nilai harus %s–%s %s', v_rule.min_value, v_rule.max_value,
             case v_rule.unit when 'years' then 'tahun' else 'hari kerja' end));
  end if;
  if char_length(v_note) > 500 then
    perform private.api_error(400, 'invalid_note', 'Catatan konfirmasi maksimal 500 karakter');
  end if;
  select s.value into v_old from cs.cs_settings s where s.key = p_key for update;
  v_version := cs.set_setting(p_key, p_value, v_me);
  insert into cs.policy_confirmations (key, version, value, note, confirmed_by)
  values (p_key, v_version, p_value, v_note, v_me)
  on conflict (key, version) do nothing;
  perform cs.audit('compliance.policy_confirm', null, null,
                   jsonb_build_object('key', p_key, 'value', p_value, 'version', v_version,
                                      'changed', v_old is distinct from p_value));
  return cs.compliance_policy_view(p_key);
end;
$$;

revoke execute on function cs.policy_rules() from public;
revoke execute on function cs.is_case(cs.tickets) from public;
revoke execute on function cs.complaint_deadline(cs.tickets, timestamptz) from public;
revoke execute on function cs.compliance_case_row(cs.tickets) from public;
revoke execute on function cs.compliance_policy_view(text) from public;
revoke execute on function cs.read_case(uuid) from public;
revoke execute on function cs.like_pattern(text) from public;
revoke execute on function cs_api.compliance_overview() from public;
revoke execute on function cs_api.compliance_cases(text, text, date, date, text) from public;
revoke execute on function cs_api.compliance_case(uuid) from public;
revoke execute on function cs_api.compliance_review(uuid, text, text) from public;
revoke execute on function cs_api.compliance_extend_deadline(uuid, text, integer) from public;
revoke execute on function cs_api.compliance_transcript_exported(uuid, text, integer) from public;
revoke execute on function cs_api.compliance_audit(date, date, text, text, timestamptz, bigint, integer) from public;
revoke execute on function cs_api.compliance_policies() from public;
revoke execute on function cs_api.compliance_confirm_policy(text, jsonb, text) from public;

grant execute on function cs_api.compliance_overview() to authenticated;
grant execute on function cs_api.compliance_cases(text, text, date, date, text) to authenticated;
grant execute on function cs_api.compliance_case(uuid) to authenticated;
grant execute on function cs_api.compliance_review(uuid, text, text) to authenticated;
grant execute on function cs_api.compliance_extend_deadline(uuid, text, integer) to authenticated;
grant execute on function cs_api.compliance_transcript_exported(uuid, text, integer) to authenticated;
grant execute on function cs_api.compliance_audit(date, date, text, text, timestamptz, bigint, integer) to authenticated;
grant execute on function cs_api.compliance_policies() to authenticated;
grant execute on function cs_api.compliance_confirm_policy(text, jsonb, text) to authenticated;
