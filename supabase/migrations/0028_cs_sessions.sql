alter table public.chat_rooms add column if not exists customer_id uuid references public.profiles (id) on delete restrict;
alter table public.chat_rooms drop constraint if exists chat_rooms_type;
alter table public.chat_rooms add constraint chat_rooms_type check (type in ('direct', 'group', 'stock', 'support'));
alter table public.chat_rooms add constraint chat_rooms_support check ((type = 'support') = (customer_id is not null));
create unique index if not exists chat_rooms_support_customer_idx on public.chat_rooms (customer_id) where type = 'support';

create table cs.support_sessions (
  id                       uuid primary key default gen_random_uuid(),
  room_id                  uuid not null references public.chat_rooms (id) on delete restrict,
  customer_id              uuid not null references public.profiles (id) on delete restrict,
  topic                    text not null references cs.support_topics (code) on update cascade,
  language                 text not null default 'id' check (language in ('id', 'en')),
  priority                 text not null check (priority in ('P1', 'P2', 'P3', 'P4')),
  flags                    text[] not null default '{}' check (flags <@ array['complaint', 'fraud', 'vip']),
  status                   text not null default 'queued' check (
    status in ('queued', 'offered', 'active', 'transferring', 'reopened', 'closed')
  ),
  required_skill           text not null references cs.skills (code) on update cascade,
  current_agent_id         uuid references cs.agents (user_id),
  last_agent_id            uuid references cs.agents (user_id),
  target_team_id           uuid references cs.teams (id),
  target_agent_id          uuid references cs.agents (user_id),
  context                  jsonb not null default '{}' check (jsonb_typeof(context) = 'object'),
  queued_at                timestamptz not null default now(),
  offered_at               timestamptz,
  accepted_at              timestamptz,
  first_response_at        timestamptz,
  closed_at                timestamptz,
  last_customer_message_at timestamptz,
  last_agent_message_at    timestamptz,
  transfer_count           integer not null default 0,
  reopen_count             integer not null default 0,
  close_outcome            text,
  tags                     text[] not null default '{}',
  closed_by                uuid,
  rating                   smallint check (rating between 1 and 5),
  rating_comment           text check (char_length(rating_comment) <= 500),
  rated_at                 timestamptz,
  complaint_received_at    timestamptz,
  complaint_due_at         timestamptz,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  check ((status = 'closed') = (closed_at is not null)),
  check (status not in ('offered', 'active') or current_agent_id is not null),
  check (('complaint' = any (flags)) = (complaint_received_at is not null))
);
create unique index support_sessions_open_room_idx on cs.support_sessions (room_id) where status <> 'closed';
create index support_sessions_waiting_idx on cs.support_sessions (priority, queued_at)
  where status in ('queued', 'transferring', 'reopened');
create index support_sessions_agent_idx on cs.support_sessions (current_agent_id) where status in ('offered', 'active');
create index support_sessions_last_agent_idx on cs.support_sessions (last_agent_id, closed_at desc);
create index support_sessions_customer_idx on cs.support_sessions (customer_id, created_at desc);
create index support_sessions_room_idx on cs.support_sessions (room_id, created_at desc);

alter table public.messages
  add column if not exists kind text not null default 'text',
  add column if not exists session_id uuid references cs.support_sessions (id) on delete restrict,
  add column if not exists sender_role text,
  add column if not exists payload jsonb not null default '{}';
alter table public.messages add constraint messages_kind
  check (kind in ('text', 'system', 'card', 'quick_reply', 'help_link', 'identity_request', 'csat'));
alter table public.messages add constraint messages_sender_role
  check (sender_role in ('customer', 'agent', 'supervisor', 'system'));
alter table public.messages add constraint messages_support
  check ((session_id is null) = (sender_role is null) and (session_id is not null or kind = 'text'));
alter table public.messages add constraint messages_payload
  check (jsonb_typeof(payload) = 'object' and pg_column_size(payload) <= 4096);
create index if not exists messages_session_idx on public.messages (session_id, created_at) where session_id is not null;

create table cs.session_events (
  id         bigint generated always as identity,
  session_id uuid not null references cs.support_sessions (id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  type       text not null,
  actor_type text not null check (actor_type in ('customer', 'agent', 'service', 'system')),
  actor_id   uuid,
  data       jsonb not null default '{}',
  primary key (id, created_at)
) partition by range (created_at);
create index session_events_session_idx on cs.session_events (session_id, created_at);
create table cs.session_events_default partition of cs.session_events default;

create table cs.cs_audit_log (
  id          bigint generated always as identity,
  created_at  timestamptz not null default clock_timestamp(),
  actor_id    uuid,
  actor_type  text not null check (actor_type in ('customer', 'agent', 'service', 'system')),
  actor_roles text[] not null default '{}',
  action      text not null,
  session_id  uuid,
  customer_id uuid,
  details     jsonb not null default '{}',
  primary key (id, created_at)
) partition by range (created_at);
create index cs_audit_log_actor_idx on cs.cs_audit_log (actor_id, action, created_at desc);
create index cs_audit_log_customer_idx on cs.cs_audit_log (customer_id, created_at desc);
create table cs.cs_audit_log_default partition of cs.cs_audit_log default;

create table cs.match_offers (
  id           uuid primary key default gen_random_uuid(),
  session_id   uuid not null references cs.support_sessions (id) on delete restrict,
  agent_id     uuid not null references cs.agents (user_id),
  mode         text not null default 'offer' check (mode in ('offer', 'auto')),
  offered_at   timestamptz not null default now(),
  expires_at   timestamptz not null,
  result       text check (result in ('accepted', 'rejected', 'expired', 'cancelled')),
  responded_at timestamptz,
  reason       text check (char_length(reason) <= 200),
  check ((result is null) = (responded_at is null))
);
create unique index match_offers_open_session_idx on cs.match_offers (session_id) where result is null;
create index match_offers_open_agent_idx on cs.match_offers (agent_id) where result is null;
create index match_offers_expiry_idx on cs.match_offers (expires_at) where result is null;
create index match_offers_agent_idx on cs.match_offers (agent_id, offered_at desc);

create table cs.agent_notes (
  id          uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles (id) on delete restrict,
  session_id  uuid references cs.support_sessions (id) on delete restrict,
  author_id   uuid references cs.agents (user_id),
  kind        text not null default 'note' check (kind in ('note', 'handover', 'system')),
  body        text not null check (char_length(btrim(body)) between 1 and 4000),
  created_at  timestamptz not null default clock_timestamp(),
  check ((kind = 'system') = (author_id is null))
);
create index agent_notes_customer_idx on cs.agent_notes (customer_id, created_at desc);
create index agent_notes_session_idx on cs.agent_notes (session_id, created_at) where session_id is not null;

create table cs.quick_replies (
  id         uuid primary key default gen_random_uuid(),
  scope      text not null check (scope in ('personal', 'team', 'global')),
  owner_id   uuid references cs.agents (user_id) on delete cascade,
  team_id    uuid references cs.teams (id) on delete cascade,
  shortcut   text not null check (shortcut ~ '^[a-z0-9_-]{2,32}$'),
  title      text not null check (char_length(btrim(title)) between 1 and 80),
  body       text not null check (char_length(btrim(body)) between 1 and 2000),
  language   text not null default 'id' check (language in ('id', 'en')),
  active     boolean not null default true,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((scope = 'personal') = (owner_id is not null)),
  check ((scope = 'team') = (team_id is not null))
);
create unique index quick_replies_shortcut_idx on cs.quick_replies
  (scope, coalesce(owner_id, team_id, '00000000-0000-0000-0000-000000000000'::uuid), language, shortcut);

alter table cs.support_sessions enable row level security;
alter table cs.session_events enable row level security;
alter table cs.session_events_default enable row level security;
alter table cs.cs_audit_log enable row level security;
alter table cs.cs_audit_log_default enable row level security;
alter table cs.match_offers enable row level security;
alter table cs.agent_notes enable row level security;
alter table cs.quick_replies enable row level security;

create trigger session_events_append_only
  before update or delete on cs.session_events
  for each row execute function cs.reject_change();
create trigger session_events_no_truncate
  before truncate on cs.session_events
  for each statement execute function cs.reject_change();
create trigger cs_audit_log_append_only
  before update or delete on cs.cs_audit_log
  for each row execute function cs.reject_change();
create trigger cs_audit_log_no_truncate
  before truncate on cs.cs_audit_log
  for each statement execute function cs.reject_change();
create trigger agent_notes_append_only
  before update or delete on cs.agent_notes
  for each row execute function cs.reject_change();

create or replace function cs.ensure_partitions(p_months_ahead integer default 3)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_table   text;
  v_start   timestamp;
  v_name    text;
  v_created integer := 0;
begin
  foreach v_table in array array['session_events', 'cs_audit_log'] loop
    for i in 0 .. greatest(coalesce(p_months_ahead, 3), 0) loop
      v_start := date_trunc('month', now() at time zone 'UTC') + make_interval(months => i);
      v_name := format('%s_p%s', v_table, to_char(v_start, 'YYYYMM'));
      continue when to_regclass('cs.' || v_name) is not null;
      begin
        execute format('create table cs.%I partition of cs.%I for values from (%L) to (%L)',
                       v_name, v_table, v_start at time zone 'UTC',
                       (v_start + interval '1 month') at time zone 'UTC');
        execute format('alter table cs.%I enable row level security', v_name);
        v_created := v_created + 1;
      exception when check_violation then
        raise warning 'cs.ensure_partitions: partisi % dilewati, partisi default sudah berisi data bulan itu', v_name;
      end;
    end loop;
  end loop;
  return v_created;
end;
$$;

select cs.ensure_partitions(3);
select cron.schedule('cs-partitions', '10 2 * * *', 'select cs.ensure_partitions(3)');

create or replace function cs.agent_can_read_room(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from cs.support_sessions s
    where s.room_id = p_room_id
      and ((s.status = 'active' and s.current_agent_id = cs.current_agent_id())
           or (s.last_agent_id = cs.current_agent_id()
               and s.closed_at > now() - make_interval(hours => cs.setting_int('agent.history_hours'))))
  );
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
    when cs.has_role('{cs_supervisor}') then
      exists (select 1 from public.chat_rooms r where r.id = p_room_id and r.type = 'support')
    else (cs.has_role('{cs_agent}') and cs.agent_can_read_room(p_room_id))
      or (cs.has_role('{compliance}')
          and exists (select 1 from cs.support_sessions s
                      where s.room_id = p_room_id and s.flags && '{complaint,fraud}'))
  end;
$$;

create or replace function cs.can_read_session(p_room_id uuid, p_flags text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when cs.current_agent_id() is null then false
    when cs.has_role('{cs_supervisor}') then true
    else (cs.has_role('{cs_agent}') and cs.agent_can_read_room(p_room_id))
      or (cs.has_role('{compliance}') and p_flags && '{complaint,fraud}')
  end;
$$;

create or replace function cs.can_read_session_id(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select cs.can_read_session(s.room_id, s.flags) from cs.support_sessions s where s.id = p_session_id), false);
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
    when cs.has_role('{cs_supervisor}') then true
    else (cs.has_role('{cs_agent}')
          and cs.agent_can_read_room((select r.id from public.chat_rooms r
                                      where r.type = 'support' and r.customer_id = p_customer_id)))
      or (cs.has_role('{compliance}') and p_session_id is not null
          and exists (select 1 from cs.support_sessions s where s.id = p_session_id and s.flags && '{complaint,fraud}'))
  end;
$$;

create or replace function cs.can_read_room_text(p_room text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_room ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     and cs.can_read_room(p_room::uuid);
$$;

create or replace function cs.is_support_owner_text(p_room text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_room ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     and exists (select 1 from public.chat_rooms r
                 where r.id = p_room::uuid and r.type = 'support' and r.customer_id = auth.uid());
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
    return cs.has_role('{cs_supervisor}');
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

grant select on cs.teams, cs.skills, cs.support_topics, cs.holidays, cs.agents, cs.agent_skills, cs.agent_status,
  cs.vip_customers, cs.cs_settings, cs.cs_settings_history, cs.support_sessions, cs.session_events, cs.match_offers,
  cs.agent_notes, cs.quick_replies, cs.cs_audit_log to authenticated;

create policy teams_select on cs.teams for select to authenticated using (true);
create policy skills_select on cs.skills for select to authenticated using (true);
create policy holidays_select on cs.holidays for select to authenticated using (true);
create policy support_topics_select on cs.support_topics for select to authenticated
  using (active or (select cs.current_agent_id()) is not null);
create policy agents_select on cs.agents for select to authenticated
  using ((select cs.current_agent_id()) is not null);
create policy agent_skills_select on cs.agent_skills for select to authenticated
  using ((select cs.current_agent_id()) is not null);
create policy agent_status_select on cs.agent_status for select to authenticated
  using ((select cs.current_agent_id()) is not null);
create policy vip_customers_select on cs.vip_customers for select to authenticated
  using ((select cs.current_agent_id()) is not null);
create policy cs_settings_select on cs.cs_settings for select to authenticated
  using ((select cs.current_agent_id()) is not null);
create policy cs_settings_history_select on cs.cs_settings_history for select to authenticated
  using ((select cs.has_role('{cs_admin,cs_supervisor,compliance}')));
create policy support_sessions_select on cs.support_sessions for select to authenticated
  using ((select cs.current_agent_id()) is not null and cs.can_read_session(room_id, flags));
create policy session_events_select on cs.session_events for select to authenticated
  using ((select cs.current_agent_id()) is not null and cs.can_read_session_id(session_id));
create policy match_offers_select on cs.match_offers for select to authenticated
  using (agent_id = (select cs.current_agent_id()) or (select cs.has_role('{cs_supervisor}')));
create policy agent_notes_select on cs.agent_notes for select to authenticated
  using ((select cs.current_agent_id()) is not null and cs.can_read_notes(customer_id, session_id));
create policy quick_replies_select on cs.quick_replies for select to authenticated
  using (
    (select cs.current_agent_id()) is not null
    and (scope = 'global'
         or (scope = 'personal' and owner_id = (select cs.current_agent_id()))
         or (scope = 'team' and ((select cs.has_role('{cs_supervisor}'))
                                 or team_id = (select a.team_id from cs.agents a where a.user_id = (select cs.current_agent_id())))))
  );
create policy cs_audit_log_select on cs.cs_audit_log for select to authenticated
  using ((select cs.has_role('{cs_admin,compliance}')));

create policy chat_rooms_select_cs on public.chat_rooms for select to authenticated
  using (type = 'support' and (select cs.current_agent_id()) is not null and cs.can_read_room(id));
create policy chat_members_select_cs on public.chat_members for select to authenticated
  using ((select cs.current_agent_id()) is not null and cs.can_read_room(room_id));
create policy messages_select_cs on public.messages for select to authenticated
  using (
    session_id is not null
    and moderation_status = 'visible'
    and (select cs.current_agent_id()) is not null
    and cs.can_read_session_id(session_id)
  );

create policy olt_cs_attachments_read on storage.objects for select to authenticated
  using (bucket_id = 'attachments' and (storage.foldername(name))[1] = 'rooms'
         and cs.can_read_room_text((storage.foldername(name))[2]));
create policy olt_cs_attachments_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'attachments' and (storage.foldername(name))[1] = 'rooms'
              and (storage.foldername(name))[3] = (select auth.uid())::text
              and cs.is_support_owner_text((storage.foldername(name))[2]));

create or replace function cs.actor_type()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when cs.current_agent_id() is not null then 'agent'
    when coalesce(auth.role(), '') = 'service_role' then 'service'
    when cs.current_customer_id() is not null then 'customer'
    else 'system'
  end;
$$;

create or replace function cs.log_event(p_session_id uuid, p_type text, p_data jsonb default '{}')
returns void
language sql
security definer
set search_path = ''
as $$
  insert into cs.session_events (session_id, type, actor_type, actor_id, data)
  select p_session_id, p_type, a.t, case when a.t in ('agent', 'customer') then auth.uid() end, coalesce(p_data, '{}')
  from (select cs.actor_type() as t) a;
$$;

create or replace function cs.audit(p_action text, p_session_id uuid default null, p_customer_id uuid default null,
                                    p_details jsonb default '{}')
returns void
language sql
security definer
set search_path = ''
as $$
  insert into cs.cs_audit_log (actor_id, actor_type, actor_roles, action, session_id, customer_id, details)
  select case when a.t in ('agent', 'customer') then auth.uid() end, a.t, cs.current_roles(),
         p_action, p_session_id, p_customer_id, coalesce(p_details, '{}')
  from (select cs.actor_type() as t) a;
$$;

create or replace function cs.format_time(p_at timestamptz, p_language text)
returns text
language sql
stable
set search_path = ''
as $$
  select case when p_language = 'en'
    then to_char(x.l, 'FMDay, FMDD FMMonth YYYY, HH24:MI') || ' WIB'
    else (array['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'])[extract(isodow from x.l)::integer]
         || ', ' || extract(day from x.l)::integer || ' '
         || (array['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September',
                   'Oktober', 'November', 'Desember'])[extract(month from x.l)::integer]
         || ' ' || extract(year from x.l)::integer || ' pukul ' || to_char(x.l, 'HH24.MI') || ' WIB'
  end
  from (select p_at at time zone 'Asia/Jakarta' as l) x;
$$;

create or replace function cs.transition_allowed(p_from text, p_to text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select (p_from, p_to) in (
    ('queued', 'offered'), ('queued', 'active'), ('queued', 'closed'),
    ('transferring', 'offered'), ('transferring', 'active'), ('transferring', 'queued'), ('transferring', 'closed'),
    ('reopened', 'offered'), ('reopened', 'active'), ('reopened', 'queued'), ('reopened', 'closed'),
    ('offered', 'active'), ('offered', 'queued'), ('offered', 'closed'),
    ('active', 'closed'), ('active', 'transferring'), ('active', 'queued'),
    ('closed', 'reopened')
  );
$$;

create or replace function cs.set_status(p_session_id uuid, p_to text, p_event text, p_data jsonb default '{}',
                                         p_agent uuid default null)
returns cs.support_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  s cs.support_sessions;
begin
  select * into s from cs.support_sessions where id = p_session_id for update;
  if not found then
    perform private.api_error(404, 'session_not_found', 'Sesi tidak ditemukan');
  end if;
  if not cs.transition_allowed(s.status, p_to) then
    perform private.api_error(409, 'invalid_transition',
      format('Sesi berstatus %s tidak bisa menjadi %s', s.status, p_to));
  end if;
  update cs.support_sessions
     set status = p_to,
         current_agent_id = case when p_to in ('offered', 'active') then coalesce(p_agent, current_agent_id) end,
         offered_at = case when p_to = 'offered' then now() else offered_at end,
         accepted_at = case when p_to = 'active' then coalesce(accepted_at, now()) else accepted_at end,
         closed_at = case when p_to = 'closed' then now() end,
         updated_at = now()
   where id = p_session_id
  returning * into s;
  perform cs.log_event(p_session_id, p_event, coalesce(p_data, '{}') || jsonb_build_object('status', p_to));
  return s;
end;
$$;

create or replace function cs.broadcast_session(s cs.support_sessions, p_event text, p_agent uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_agent uuid;
begin
  perform realtime.send(jsonb_build_object('session_id', s.id, 'status', s.status, 'event', p_event),
                        'session', 'cs:room:' || s.room_id::text, true);
  perform realtime.send(jsonb_build_object('session_id', s.id, 'room_id', s.room_id, 'status', s.status,
                                           'priority', s.priority, 'flags', s.flags, 'topic', s.topic, 'event', p_event),
                        'session', 'cs:queue', true);
  foreach v_agent in array array_remove(array[s.current_agent_id, nullif(p_agent, s.current_agent_id)], null) loop
    perform realtime.send(jsonb_build_object('session_id', s.id, 'room_id', s.room_id, 'status', s.status, 'event', p_event),
                          'session', 'cs:agent:' || v_agent::text, true);
  end loop;
end;
$$;

create or replace function cs.refresh_agent_load(p_agent uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update cs.agent_status st
     set active_sessions = (select count(*) from cs.support_sessions s
                            where s.current_agent_id = p_agent and s.status in ('offered', 'active'))
   where st.agent_id = p_agent;
$$;

create or replace function cs.agent_available(p_agent uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from cs.agents a
    join cs.agent_status st on st.agent_id = a.user_id
    where a.user_id = p_agent
      and a.disabled_at is null
      and a.roles && '{cs_agent,cs_supervisor}'
      and st.status = 'online'
      and st.last_heartbeat_at > now() - make_interval(secs => cs.setting_int('agent.heartbeat_fresh_seconds'))
      and st.active_sessions < a.max_concurrent
  );
$$;

create or replace function cs.check_rate(p_action text, p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r        record;
  v_count  integer;
  v_oldest timestamptz;
begin
  for r in
    select l.max_count, l.window_seconds from private.rate_limits l
    where l.action = p_action order by l.window_seconds
  loop
    if p_action = 'cs_session' then
      select count(*), min(s.created_at) into v_count, v_oldest
      from cs.support_sessions s
      where s.customer_id = p_user and s.created_at > now() - make_interval(secs => r.window_seconds);
    else
      select count(*), min(m.created_at) into v_count, v_oldest
      from public.messages m
      where m.sender_id = p_user and m.session_id is not null
        and m.created_at > now() - make_interval(secs => r.window_seconds);
    end if;
    if v_count >= r.max_count then
      perform private.raise_rate_limited(p_action, r.max_count, r.window_seconds,
        ceil(r.window_seconds - extract(epoch from (now() - v_oldest)))::integer);
    end if;
  end loop;
end;
$$;

create or replace function cs.initial_priority(p_topic text, p_flags text[], p_text text, p_at timestamptz,
                                               out priority text, out flags text[])
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t cs.support_topics;
  r jsonb;
begin
  select * into t from cs.support_topics where code = p_topic;
  priority := t.default_priority;
  flags := array(select distinct f from unnest(coalesce(p_flags, '{}') || t.flags) f order by f);
  if coalesce(btrim(p_text), '') <> '' then
    for r in select value from jsonb_array_elements(coalesce(cs.setting('priority.rules'), '[]')) loop
      continue when coalesce((r ->> 'market_hours_only')::boolean, false) and not cs.is_market_hours(p_at);
      if exists (select 1 from jsonb_array_elements_text(r -> 'words') w (word)
                 where position(lower(w.word) in lower(p_text)) > 0) then
        priority := least(priority, r ->> 'priority');
        if r ? 'flag' then
          flags := array(select distinct f from unnest(flags || (r ->> 'flag')) f order by f);
        end if;
      end if;
    end loop;
  end if;
  if 'fraud' = any (flags) then
    priority := 'P1';
  elsif 'complaint' = any (flags) then
    priority := least(priority, 'P2');
  end if;
end;
$$;

create or replace function cs.system_message(s cs.support_sessions, p_code text, p_vars jsonb default '{}',
                                             p_kind text default 'system', p_payload jsonb default '{}')
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_template jsonb := cs.setting('messages.' || p_code);
  v_id       uuid;
begin
  insert into public.messages (room_id, sender_id, body, kind, session_id, sender_role, payload)
  values (s.room_id, null,
          cs.render_text(coalesce(v_template ->> s.language, v_template ->> 'id', p_code), p_vars),
          p_kind, s.id, 'system', coalesce(p_payload, '{}') || jsonb_build_object('code', p_code))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function cs.ensure_room(p_customer uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room uuid;
begin
  select r.id into v_room from public.chat_rooms r where r.type = 'support' and r.customer_id = p_customer;
  if v_room is null then
    insert into public.chat_rooms (type, customer_id)
    values ('support', p_customer)
    on conflict (customer_id) where type = 'support' do nothing
    returning id into v_room;
    if v_room is null then
      select r.id into v_room from public.chat_rooms r where r.type = 'support' and r.customer_id = p_customer;
    end if;
  end if;
  insert into public.chat_members (room_id, user_id, role) values (v_room, p_customer, 'owner')
  on conflict do nothing;
  return v_room;
end;
$$;

create or replace function cs.complaint_note(s cs.support_sessions)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object('received_at', cs.format_time(s.complaint_received_at, s.language),
                            'due_at', cs.format_time(s.complaint_due_at, s.language));
$$;

create or replace function cs.open_session(p_customer uuid, p_topic text, p_language text, p_flags text[],
                                           p_context jsonb, p_first_text text)
returns cs.support_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  t      cs.support_topics;
  v_room uuid;
  v_prio record;
  s      cs.support_sessions;
begin
  select * into t from cs.support_topics where code = p_topic and active;
  if not found then
    perform private.api_error(400, 'invalid_topic', 'Topik bantuan tidak dikenal');
  end if;
  v_room := cs.ensure_room(p_customer);
  select * into s from cs.support_sessions where room_id = v_room and status <> 'closed' for update;
  if found then
    return s;
  end if;
  perform cs.check_rate('cs_session', p_customer);

  select * into v_prio from cs.initial_priority(
    p_topic,
    coalesce(p_flags, '{}') || case when exists (select 1 from cs.vip_customers v where v.customer_id = p_customer)
                                    then array['vip'] else array[]::text[] end,
    p_first_text, now());

  insert into cs.support_sessions (room_id, customer_id, topic, language, priority, flags, required_skill,
                                   target_team_id, context, complaint_received_at, complaint_due_at)
  values (v_room, p_customer, t.code, coalesce(p_language, 'id'), v_prio.priority, v_prio.flags,
          case when 'fraud' = any (v_prio.flags) then 'fraud'
               when 'complaint' = any (v_prio.flags) then 'complaint'
               else t.skill end,
          t.team_id, coalesce(p_context, '{}'),
          case when 'complaint' = any (v_prio.flags) then now() end,
          case when 'complaint' = any (v_prio.flags)
               then cs.regulatory_deadline(now(), cs.setting_int('complaint.days')) end)
  returning * into s;

  perform cs.log_event(s.id, 'queued', jsonb_build_object('topic', s.topic, 'priority', s.priority, 'flags', s.flags));
  perform cs.system_message(s, 'greeting',
    jsonb_build_object('name', coalesce((select p.display_name from public.profiles p where p.id = p_customer), '')));
  perform cs.system_message(s, 'security_reminder');
  if t.help_url is not null then
    perform cs.system_message(s, 'help',
      jsonb_build_object('topic', case when s.language = 'en' then t.name_en else t.name_id end),
      'help_link', jsonb_build_object('url', t.help_url));
  end if;
  if cs.is_open(now()) then
    perform cs.system_message(s, 'queued');
  else
    perform cs.system_message(s, 'out_of_hours',
      jsonb_build_object('next_open', cs.format_time(cs.next_open_at(now()), s.language)));
  end if;
  if 'complaint' = any (s.flags) then
    perform cs.system_message(s, 'complaint', cs.complaint_note(s));
  end if;
  perform cs.broadcast_session(s, 'queued');
  return s;
end;
$$;

create or replace function cs.assign(p_session_id uuid, p_agent uuid, p_event text)
returns cs.support_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  s cs.support_sessions;
begin
  perform 1 from cs.agent_status where agent_id = p_agent for update;
  perform cs.set_status(p_session_id, 'active', p_event, jsonb_build_object('agent_id', p_agent), p_agent);
  update cs.support_sessions
     set last_agent_id = p_agent, target_agent_id = null
   where id = p_session_id
  returning * into s;
  update cs.agent_status set last_assigned_at = now(), consecutive_timeouts = 0 where agent_id = p_agent;
  insert into public.chat_members (room_id, user_id, role) values (s.room_id, p_agent, 'member')
  on conflict do nothing;
  perform cs.refresh_agent_load(p_agent);
  perform cs.system_message(s, 'connected',
    jsonb_build_object('agent', (select a.display_name from cs.agents a where a.user_id = p_agent)));
  perform cs.broadcast_session(s, p_event);
  return s;
end;
$$;

create or replace function cs.offer(p_session_id uuid, p_agent uuid)
returns cs.match_offers
language plpgsql
security definer
set search_path = ''
as $$
declare
  s      cs.support_sessions;
  o      cs.match_offers;
  v_mode text;
begin
  perform 1 from cs.agent_status where agent_id = p_agent for update;
  if not cs.agent_available(p_agent) then
    perform private.api_error(409, 'agent_unavailable', 'Agen tidak tersedia atau kapasitasnya penuh');
  end if;
  select * into s from cs.support_sessions where id = p_session_id for update;
  if not found or s.status not in ('queued', 'transferring', 'reopened') then
    perform private.api_error(409, 'session_not_waiting', 'Sesi tidak sedang menunggu agen');
  end if;
  select coalesce(t.assignment_mode, 'offer') into v_mode
  from cs.agents a left join cs.teams t on t.id = a.team_id
  where a.user_id = p_agent;

  if v_mode = 'auto' then
    insert into cs.match_offers (session_id, agent_id, mode, expires_at, result, responded_at)
    values (p_session_id, p_agent, 'auto', now(), 'accepted', now())
    returning * into o;
    perform cs.assign(p_session_id, p_agent, 'assigned');
    return o;
  end if;

  s := cs.set_status(p_session_id, 'offered', 'offered', jsonb_build_object('agent_id', p_agent), p_agent);
  insert into cs.match_offers (session_id, agent_id, expires_at)
  values (p_session_id, p_agent, now() + make_interval(secs => cs.setting_int('offer.timeout_seconds')))
  returning * into o;
  perform cs.refresh_agent_load(p_agent);
  perform cs.broadcast_session(s, 'offered');
  perform realtime.send(jsonb_build_object('offer_id', o.id, 'session_id', s.id, 'expires_at', o.expires_at),
                        'offer', 'cs:agent:' || p_agent::text, true);
  return o;
end;
$$;

create or replace function cs.close_offer(p_offer_id uuid, p_result text, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  o          cs.match_offers;
  s          cs.support_sessions;
  v_timeouts integer;
begin
  update cs.match_offers
     set result = p_result, responded_at = now(), reason = left(p_reason, 200)
   where id = p_offer_id and result is null
  returning * into o;
  if not found then
    return;
  end if;
  select * into s from cs.support_sessions where id = o.session_id for update;
  if s.status = 'offered' and s.current_agent_id = o.agent_id then
    perform cs.set_status(s.id, 'queued', 'offer_' || p_result, jsonb_build_object('agent_id', o.agent_id));
    update cs.support_sessions
       set target_agent_id = case when target_agent_id = o.agent_id then null else target_agent_id end
     where id = s.id
    returning * into s;
    perform cs.broadcast_session(s, 'offer_' || p_result, o.agent_id);
  end if;
  if p_result = 'expired' then
    update cs.agent_status set consecutive_timeouts = consecutive_timeouts + 1
     where agent_id = o.agent_id
    returning consecutive_timeouts into v_timeouts;
    if v_timeouts >= cs.setting_int('offer.max_consecutive_timeouts') then
      update cs.agent_status
         set status = 'break', reason = 'Tidak merespons penawaran', status_changed_at = now()
       where agent_id = o.agent_id and status = 'online';
      if found then
        perform cs.audit('agent.auto_break', null, null,
          jsonb_build_object('agent_id', o.agent_id, 'consecutive_timeouts', v_timeouts));
        perform realtime.send(jsonb_build_object('status', 'break', 'reason', 'offer_timeouts'),
                              'status', 'cs:agent:' || o.agent_id::text, true);
      end if;
    end if;
  elsif p_result = 'rejected' then
    update cs.agent_status set consecutive_timeouts = 0 where agent_id = o.agent_id;
  end if;
  perform cs.refresh_agent_load(o.agent_id);
end;
$$;

create or replace function cs.expire_offers()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id    uuid;
  v_count integer := 0;
begin
  for v_id in
    select o.id from cs.match_offers o
    where o.result is null and o.expires_at <= now()
    order by o.expires_at
    for update skip locked
  loop
    perform cs.close_offer(v_id, 'expired');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function cs.close_session(p_session_id uuid, p_outcome text, p_tags text[], p_by uuid)
returns cs.support_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  s       cs.support_sessions;
  v_agent uuid;
begin
  select * into s from cs.support_sessions where id = p_session_id for update;
  if not found then
    perform private.api_error(404, 'session_not_found', 'Sesi tidak ditemukan');
  end if;
  if s.status = 'closed' then
    return s;
  end if;
  if cs.setting('close.outcomes') -> p_outcome is null then
    perform private.api_error(400, 'invalid_outcome', 'Hasil penutupan tidak ada dalam daftar');
  end if;
  v_agent := s.current_agent_id;
  update cs.match_offers set result = 'cancelled', responded_at = now()
   where session_id = s.id and result is null;
  s := cs.set_status(s.id, 'closed', 'closed', jsonb_build_object('outcome', p_outcome, 'tags', coalesce(p_tags, '{}')));
  update cs.support_sessions
     set target_agent_id = null, close_outcome = p_outcome,
         tags = coalesce(p_tags, '{}'), closed_by = p_by
   where id = s.id
  returning * into s;
  if v_agent is not null then
    delete from public.chat_members where room_id = s.room_id and user_id = v_agent;
    perform cs.refresh_agent_load(v_agent);
  end if;
  perform cs.system_message(s, 'closed');
  if s.accepted_at is not null then
    perform cs.system_message(s, 'csat', '{}', 'csat', jsonb_build_object('session_id', s.id));
  end if;
  perform cs.broadcast_session(s, 'closed', v_agent);
  return s;
end;
$$;

create or replace function cs.transfer_session(p_session_id uuid, p_team text, p_topic text, p_agent uuid,
                                               p_note text, p_by uuid)
returns cs.support_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  s       cs.support_sessions;
  t       cs.support_topics;
  v_team  cs.teams;
  v_prev  uuid;
  v_label text;
begin
  select * into s from cs.support_sessions where id = p_session_id for update;
  if not found then
    perform private.api_error(404, 'session_not_found', 'Sesi tidak ditemukan');
  end if;
  if s.status <> 'active' then
    perform private.api_error(409, 'session_not_active', 'Hanya sesi aktif yang bisa ditransfer');
  end if;
  if p_team is null and p_topic is null and p_agent is null then
    perform private.api_error(400, 'transfer_target_required', 'Pilih tim, topik, atau agen tujuan');
  end if;
  if coalesce(btrim(p_note), '') = '' then
    perform private.api_error(400, 'handover_note_required', 'Tulis catatan serah terima');
  end if;
  if p_topic is not null then
    select * into t from cs.support_topics where code = p_topic and active;
    if not found then
      perform private.api_error(400, 'invalid_topic', 'Topik bantuan tidak dikenal');
    end if;
  end if;
  if p_team is not null then
    select * into v_team from cs.teams where code = p_team and active;
    if not found then
      perform private.api_error(400, 'invalid_team', 'Tim tujuan tidak dikenal');
    end if;
  elsif t.team_id is not null then
    select * into v_team from cs.teams where id = t.team_id;
  end if;
  if p_agent is not null then
    if p_agent = s.current_agent_id then
      perform private.api_error(400, 'same_agent', 'Sesi sudah ditangani agen ini');
    end if;
    if not cs.agent_available(p_agent) then
      perform private.api_error(409, 'agent_unavailable', 'Agen tujuan tidak tersedia atau kapasitasnya penuh');
    end if;
    if v_team.id is null then
      select tm.* into v_team from cs.agents a join cs.teams tm on tm.id = a.team_id where a.user_id = p_agent;
    end if;
  end if;

  v_prev := s.current_agent_id;
  perform cs.set_status(s.id, 'transferring', 'transferred', jsonb_build_object(
    'from_agent', v_prev, 'team', v_team.code, 'topic', p_topic, 'agent_id', p_agent));
  update cs.support_sessions
     set target_team_id = coalesce(v_team.id, target_team_id),
         target_agent_id = p_agent,
         topic = coalesce(t.code, topic),
         required_skill = case when flags && '{fraud,complaint}' then required_skill else coalesce(t.skill, required_skill) end,
         transfer_count = transfer_count + 1,
         queued_at = now()
   where id = s.id
  returning * into s;
  insert into cs.agent_notes (customer_id, session_id, author_id, kind, body)
  values (s.customer_id, s.id, p_by, case when p_by is null then 'system' else 'handover' end,
          (cs.mask_sensitive(btrim(p_note))).masked);
  if v_prev is not null then
    delete from public.chat_members where room_id = s.room_id and user_id = v_prev;
    perform cs.refresh_agent_load(v_prev);
  end if;
  v_label := coalesce(case when s.language = 'en' then v_team.name_en else v_team.name_id end, 'CS');
  perform cs.system_message(s, 'transferred', jsonb_build_object('team', v_label));
  perform cs.broadcast_session(s, 'transferred', v_prev);
  if p_agent is not null then
    perform cs.offer(s.id, p_agent);
    select * into s from cs.support_sessions where id = s.id;
  end if;
  return s;
end;
$$;

create or replace function cs.requeue_session(p_session_id uuid, p_reason text)
returns cs.support_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  s       cs.support_sessions;
  v_agent uuid;
begin
  select * into s from cs.support_sessions where id = p_session_id for update;
  if not found or s.status <> 'active' then
    return s;
  end if;
  v_agent := s.current_agent_id;
  perform cs.set_status(s.id, 'queued', 'requeued', jsonb_build_object('agent_id', v_agent, 'reason', p_reason));
  update cs.support_sessions
     set target_agent_id = null, priority = least(priority, 'P2')
   where id = s.id
  returning * into s;
  delete from public.chat_members where room_id = s.room_id and user_id = v_agent;
  perform cs.refresh_agent_load(v_agent);
  perform cs.system_message(s, 'reconnecting');
  perform cs.broadcast_session(s, 'requeued', v_agent);
  return s;
end;
$$;

create or replace function cs.release_agent(p_agent uuid, p_status text, p_reason text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id    uuid;
  v_count integer := 0;
begin
  perform 1 from cs.agent_status where agent_id = p_agent for update;
  for v_id in select o.id from cs.match_offers o where o.agent_id = p_agent and o.result is null loop
    perform cs.close_offer(v_id, 'cancelled', p_reason);
  end loop;
  for v_id in
    select s.id from cs.support_sessions s
    where s.current_agent_id = p_agent and s.status = 'active'
    order by s.accepted_at
  loop
    perform cs.requeue_session(v_id, p_reason);
    v_count := v_count + 1;
  end loop;
  update cs.agent_status
     set status = p_status, reason = left(p_reason, 120), status_changed_at = now()
   where agent_id = p_agent;
  return v_count;
end;
$$;

create or replace function cs.reopen(p_session_id uuid)
returns cs.support_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  s cs.support_sessions;
begin
  perform cs.set_status(p_session_id, 'reopened', 'reopened');
  update cs.support_sessions
     set closed_by = null, close_outcome = null, reopen_count = reopen_count + 1,
         target_agent_id = last_agent_id, queued_at = now()
   where id = p_session_id
  returning * into s;
  perform cs.system_message(s, 'reopened');
  if s.last_agent_id is not null and cs.agent_available(s.last_agent_id) then
    return cs.assign(s.id, s.last_agent_id, 'reassigned');
  end if;
  perform cs.broadcast_session(s, 'reopened');
  return s;
end;
$$;

create or replace function cs.flag_session(p_session_id uuid, p_flag text)
returns cs.support_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  s cs.support_sessions;
begin
  if p_flag not in ('complaint', 'fraud') then
    perform private.api_error(400, 'invalid_flag', 'Tanda sesi tidak dikenal');
  end if;
  select * into s from cs.support_sessions where id = p_session_id for update;
  if not found then
    perform private.api_error(404, 'session_not_found', 'Sesi tidak ditemukan');
  end if;
  if s.status = 'closed' then
    perform private.api_error(409, 'session_closed', 'Sesi sudah selesai');
  end if;
  if p_flag = any (s.flags) then
    return s;
  end if;
  update cs.support_sessions
     set flags = array(select distinct f from unnest(flags || p_flag) f order by f),
         priority = case when p_flag = 'fraud' then 'P1' else least(priority, 'P2') end,
         required_skill = case when p_flag = 'fraud' or not ('fraud' = any (flags)) then p_flag else required_skill end,
         complaint_received_at = case when p_flag = 'complaint' then now() else complaint_received_at end,
         complaint_due_at = case when p_flag = 'complaint'
                                 then cs.regulatory_deadline(now(), cs.setting_int('complaint.days'))
                                 else complaint_due_at end,
         updated_at = now()
   where id = p_session_id
  returning * into s;
  perform cs.log_event(s.id, 'flagged', jsonb_build_object('flag', p_flag, 'priority', s.priority));
  if p_flag = 'complaint' then
    perform cs.system_message(s, 'complaint', cs.complaint_note(s));
  end if;
  if s.status = 'active' and not exists (
    select 1 from cs.agent_skills k where k.agent_id = s.current_agent_id and k.skill = s.required_skill
  ) then
    return cs.transfer_session(s.id, case p_flag when 'fraud' then 'security' else 'complaints' end, null, null,
      'Dialihkan otomatis karena sesi ditandai ' || p_flag, null);
  end if;
  perform cs.broadcast_session(s, 'flagged');
  return s;
end;
$$;

create or replace function cs.message_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room   public.chat_rooms;
  s        cs.support_sessions;
  v_last   cs.support_sessions;
  v_prio   record;
  v_masked record;
begin
  if tg_op = 'UPDATE' then
    if old.session_id is null
       or (new.body, new.attachments, new.deleted_at, new.kind, new.payload, new.session_id, new.sender_role)
          is not distinct from
          (old.body, old.attachments, old.deleted_at, old.kind, old.payload, old.session_id, old.sender_role)
       or not private.is_end_user()
       or private.admin_role() is not null then
      return new;
    end if;
    if new.deleted_at is not null and old.deleted_at is null then
      return null;
    end if;
    perform private.api_error(409, 'support_message_locked', 'Pesan di chat CS tidak bisa diubah');
  end if;

  select * into v_room from public.chat_rooms where id = new.room_id;
  if v_room.type is distinct from 'support' then
    if new.session_id is not null or new.sender_role is not null then
      perform private.api_error(400, 'invalid_message', 'Pesan ini hanya untuk chat CS');
    end if;
    return new;
  end if;

  if new.sender_id is null then
    new.sender_role := 'system';
  elsif new.sender_id = v_room.customer_id then
    new.sender_role := 'customer';
    if new.kind not in ('text', 'card') then
      perform private.api_error(400, 'invalid_kind', 'Jenis pesan tidak diizinkan');
    end if;
  elsif new.sender_role is null or new.sender_role not in ('agent', 'supervisor') or not cs.is_staff(new.sender_id) then
    perform private.api_error(403, 'use_cs_api', 'Pesan CS hanya bisa dikirim lewat panel CS');
  end if;

  if new.sender_role = 'customer' and new.session_id is null then
    if new.client_id is not null then
      select m.session_id into new.session_id
      from public.messages m where m.sender_id = new.sender_id and m.client_id = new.client_id;
      if new.session_id is not null then
        return new;
      end if;
    end if;
    perform cs.check_rate('cs_message', new.sender_id);
    select * into s from cs.support_sessions where room_id = new.room_id and status <> 'closed' for update;
    if not found then
      select * into v_last from cs.support_sessions where room_id = new.room_id order by created_at desc limit 1;
      if v_last.id is not null
         and v_last.closed_at > now() - make_interval(mins => cs.setting_int('session.reopen_minutes')) then
        s := cs.reopen(v_last.id);
      else
        s := cs.open_session(new.sender_id, cs.setting('session.default_topic') #>> '{}',
                             coalesce(v_last.language, 'id'), '{}', '{}', new.body);
      end if;
    elsif s.last_customer_message_at is null then
      select * into v_prio from cs.initial_priority(s.topic, s.flags, new.body, now());
      if v_prio.priority < s.priority or not (v_prio.flags <@ s.flags) then
        update cs.support_sessions
           set priority = least(priority, v_prio.priority),
               flags = array(select distinct f from unnest(flags || v_prio.flags) f order by f),
               required_skill = case when 'fraud' = any (v_prio.flags) then 'fraud' else required_skill end,
               updated_at = now()
         where id = s.id
        returning * into s;
        perform cs.log_event(s.id, 'priority_changed', jsonb_build_object('priority', s.priority, 'flags', s.flags));
        perform cs.broadcast_session(s, 'priority_changed');
      end if;
    end if;
    new.session_id := s.id;
  end if;

  select * into s from cs.support_sessions where id = new.session_id;
  if s.room_id is distinct from new.room_id then
    perform private.api_error(400, 'invalid_session', 'Sesi tidak sesuai dengan room');
  end if;

  if new.sender_role = 'customer' then
    update cs.support_sessions set last_customer_message_at = clock_timestamp() where id = s.id;
  elsif new.sender_role in ('agent', 'supervisor') then
    update cs.support_sessions
       set last_agent_message_at = clock_timestamp(),
           first_response_at = coalesce(first_response_at, clock_timestamp())
     where id = s.id;
  end if;

  if new.sender_role <> 'system' and new.body <> '' then
    select * into v_masked from cs.mask_sensitive(new.body);
    if cardinality(v_masked.kinds) > 0 then
      new.body := v_masked.masked;
      new.payload := new.payload || jsonb_build_object('masked', to_jsonb(v_masked.kinds));
    end if;
  end if;
  new.created_at := clock_timestamp();
  return new;
end;
$$;

create or replace function cs.message_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  s cs.support_sessions;
begin
  select * into s from cs.support_sessions where id = new.session_id;
  if new.sender_role = 'customer' then
    if s.current_agent_id is not null then
      perform realtime.send(jsonb_build_object('session_id', s.id, 'room_id', s.room_id, 'message_id', new.id),
                            'message', 'cs:agent:' || s.current_agent_id::text, true);
    end if;
  elsif new.sender_role in ('agent', 'supervisor') or new.kind = 'csat' then
    perform private.notify(
      s.customer_id, new.sender_id, 'message',
      jsonb_build_object(
        'room_id', new.room_id,
        'room_type', 'support',
        'room_name', null,
        'message_id', new.id,
        'snippet', case when new.body = '' then '[lampiran]' else private.snippet(new.body, 120) end
      ),
      'message:room:' || new.room_id
    );
  end if;
  return null;
end;
$$;

create or replace trigger messages_05_support
  before insert or update on public.messages
  for each row execute function cs.message_before_write();
create or replace trigger messages_10_rate_limit
  before insert on public.messages
  for each row when (new.session_id is null)
  execute function private.enforce_rate_limit('message', 'sender_id');
create or replace trigger messages_25_integrity
  before insert or update of body on public.messages
  for each row when (new.session_id is null)
  execute function private.enforce_content_integrity('message', 'sender_id');
create or replace trigger messages_support_after_insert
  after insert on public.messages
  for each row when (new.session_id is not null)
  execute function cs.message_after_insert();

create or replace function cs.chat_members_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.chat_rooms;
begin
  select * into v_room from public.chat_rooms where id = new.room_id;
  if v_room.type = 'support' then
    if new.user_id <> v_room.customer_id and not cs.is_staff(new.user_id) then
      perform private.api_error(403, 'support_room_private', 'Chat CS hanya untuk nasabah dan CS');
    end if;
  elsif cs.is_staff(new.user_id) then
    perform private.api_error(403, 'cs_staff_room', 'Akun CS hanya bisa berada di chat CS');
  end if;
  return new;
end;
$$;

create trigger chat_members_cs_guard
  before insert on public.chat_members
  for each row execute function cs.chat_members_guard();

create or replace function public.leave_room(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_room   public.chat_rooms;
  v_role   text;
  v_heir   uuid;
begin
  select * into v_room from public.chat_rooms where id = p_room_id;
  v_role := private.room_role(p_room_id);
  if not found or v_role is null then
    perform private.api_error(404, 'not_member', 'Anda bukan anggota room ini');
  end if;
  if v_room.type = 'direct' then
    perform private.api_error(400, 'cannot_leave_direct', 'Room DM tidak bisa ditinggalkan');
  end if;
  if v_room.type = 'support' then
    perform private.api_error(400, 'cannot_leave_support', 'Chat CS tidak bisa ditinggalkan');
  end if;

  delete from public.chat_members where room_id = p_room_id and user_id = auth.uid();

  if v_room.type = 'group' and v_role = 'owner' then
    select user_id into v_heir from public.chat_members
    where room_id = p_room_id
    order by (role = 'admin') desc, joined_at
    limit 1;
    if v_heir is null then
      delete from public.chat_rooms where id = p_room_id;
    else
      update public.chat_members set role = 'owner' where room_id = p_room_id and user_id = v_heir;
    end if;
  end if;
end;
$$;

alter type public.chat_message
  add attribute kind text,
  add attribute payload jsonb,
  add attribute session_id uuid,
  add attribute sender_role text;

create or replace function private.chat_messages(p_ids uuid[])
returns setof public.chat_message
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select m.id, m.room_id, m.sender_id,
         s.username::text, s.display_name, s.avatar_url,
         case when m.deleted_at is null then m.body end,
         m.deleted_at is not null,
         m.reply_to_id,
         case when rt.deleted_at is null then private.snippet(rt.body, 200) end,
         rs.username::text,
         case when m.deleted_at is null then m.attachments else '[]'::jsonb end,
         m.client_id, m.edited_at, m.created_at,
         private.make_cursor(m.created_at, m.id),
         m.kind,
         case when m.deleted_at is null then m.payload else '{}'::jsonb end,
         m.session_id,
         m.sender_role
  from public.messages m
  left join public.profiles s on s.id = m.sender_id
  left join public.messages rt on rt.id = m.reply_to_id
  left join public.profiles rs on rs.id = rt.sender_id
  where m.id = any(p_ids)
  order by m.created_at desc, m.id desc;
$$;

create or replace function public.get_my_rooms()
returns table (
  id                     uuid,
  type                   text,
  name                   text,
  stock_code             text,
  created_by             uuid,
  last_message_at        timestamptz,
  last_message_preview   text,
  last_message_sender_id uuid,
  last_message_status    text,
  created_at             timestamptz,
  my_role                text,
  muted                  boolean,
  last_read_at           timestamptz,
  unread_count           integer,
  member_count           integer,
  other_user_id          uuid,
  other_username         text,
  other_display_name     text,
  other_avatar_url       text,
  other_is_verified      boolean
)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  select r.id, r.type, r.name, r.stock_code, r.created_by,
         r.last_message_at, r.last_message_preview, r.last_message_sender_id,
         case
           when r.last_message_at is null or r.last_message_sender_id is distinct from m.user_id then null
           when r.type = 'stock' or rc.others = 0 then 'sent'
           when rc.unread = 0 then 'read'
           when rc.undelivered = 0 then 'delivered'
           else 'sent'
         end,
         r.created_at,
         m.role, m.muted, m.last_read_at,
         (select count(*)::integer from (
            select 1 from public.messages msg
            where msg.room_id = r.id
              and msg.created_at > m.last_read_at
              and msg.sender_id is distinct from m.user_id
              and msg.deleted_at is null
            limit 100
          ) s),
         rc.members,
         o.id, o.username::text, o.display_name, o.avatar_url, o.is_verified
  from public.chat_members m
  join public.chat_rooms r on r.id = m.room_id
  cross join lateral (
    select count(*)::integer as members,
           count(*) filter (where om.user_id <> m.user_id)::integer as others,
           count(*) filter (where om.user_id <> m.user_id and om.last_read_at < r.last_message_at)::integer as unread,
           count(*) filter (where om.user_id <> m.user_id and om.last_delivered_at < r.last_message_at)::integer as undelivered
    from public.chat_members om
    where om.room_id = r.id
  ) rc
  left join lateral (
    select p.id, p.username, p.display_name, p.avatar_url, p.is_verified
    from public.chat_members om
    join public.profiles p on p.id = om.user_id
    where r.type = 'direct' and om.room_id = r.id and om.user_id <> m.user_id
    limit 1
  ) o on true
  where m.user_id = auth.uid()
    and r.type <> 'support'
  order by coalesce(r.last_message_at, r.created_at) desc;
$$;

create or replace function public.search_profiles(p_query text, p_limit integer default 10)
returns table (id uuid, username text, display_name text, avatar_url text, is_verified boolean)
language sql
stable
set search_path = public, extensions, pg_temp
as $$
  with q as (
    select replace(replace(replace(btrim(coalesce(p_query, '')), '\', '\\'), '%', '\%'), '_', '\_') as term
  )
  select p.id, p.username::text, p.display_name, p.avatar_url, p.is_verified
  from public.profiles p, q
  where q.term <> ''
    and (p.username::text ilike q.term || '%' or p.display_name ilike '%' || q.term || '%')
    and p.id not in (select private.blocked_user_ids())
    and not cs.is_staff(p.id)
  order by (lower(p.username::text) = lower(btrim(p_query))) desc,
           p.follower_count desc,
           p.username
  limit least(greatest(coalesce(p_limit, 10), 1), 25);
$$;

create or replace function private.can_access_topic(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_room uuid;
begin
  if auth.uid() is null or p_topic is null then
    return false;
  end if;
  if p_topic like 'cs:%' then
    return cs.can_access_topic(p_topic);
  end if;
  if p_topic ~* '^room:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_room := substring(p_topic from 6)::uuid;
    if not exists (select 1 from public.chat_members where room_id = v_room and user_id = auth.uid()) then
      return false;
    end if;
    return not private.is_banned(auth.uid())
        or exists (select 1 from public.chat_rooms where id = v_room and type = 'support');
  end if;
  return p_topic = 'online' and not private.is_banned(auth.uid());
end;
$$;

drop policy if exists olt_realtime_send on realtime.messages;
create policy olt_realtime_send on realtime.messages
  for insert to authenticated
  with check (private.can_access_topic((select realtime.topic())) and (select realtime.topic()) not like 'cs:%');

create or replace function private.check_request()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid;
  v_revoked timestamptz;
  v_iat     numeric;
  v_headers jsonb;
  v_profile text;
begin
  if coalesce(auth.role(), '') <> 'authenticated' then
    return;
  end if;
  v_uid := auth.uid();
  if v_uid is null then
    return;
  end if;
  v_headers := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb;
  v_profile := coalesce(case when current_setting('request.method', true) in ('GET', 'HEAD')
                             then v_headers ->> 'accept-profile'
                             else v_headers ->> 'content-profile' end, 'public');
  if v_profile <> 'cs_api' and private.is_banned(v_uid) then
    perform private.api_error(403, 'user_banned', 'Akun Anda diblokir dari fitur sosial');
  end if;
  if v_profile = 'public' and cs.is_staff(v_uid) then
    perform private.api_error(403, 'cs_staff_social_forbidden', 'Akun CS tidak bisa memakai fitur sosial');
  end if;
  select s.revoked_before into v_revoked from private.user_sessions s where s.user_id = v_uid;
  if v_revoked is not null then
    v_iat := nullif(auth.jwt() ->> 'iat', '')::numeric;
    if v_iat is null or to_timestamp(v_iat) < v_revoked then
      perform private.api_error(401, 'session_revoked', 'Sesi sudah dicabut, silakan masuk ulang');
    end if;
  end if;
end;
$$;

revoke execute on all functions in schema cs from public;
grant execute on function
  cs.current_agent_id(), cs.current_roles(), cs.has_role(text[]), cs.is_staff(uuid),
  cs.can_read_room(uuid), cs.can_read_session(uuid, text[]), cs.can_read_session_id(uuid),
  cs.can_read_notes(uuid, uuid), cs.can_read_room_text(text), cs.is_support_owner_text(text),
  cs.agent_can_read_room(uuid)
to authenticated;
