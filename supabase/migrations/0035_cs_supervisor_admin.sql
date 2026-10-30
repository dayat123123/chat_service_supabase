create or replace function cs.agent_admin_view(p_agent uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', a.user_id,
    'agent_code', a.agent_code,
    'display_name', a.display_name,
    'email', u.email,
    'roles', to_jsonb(a.roles),
    'team', tm.code,
    'max_active_tickets', a.max_active_tickets,
    'disabled_at', a.disabled_at,
    'status', coalesce(st.status, 'offline'),
    'active_tickets', cs.active_ticket_count(a.user_id),
    'totp', exists (select 1 from auth.mfa_factors f where f.user_id = a.user_id and f.status = 'verified'),
    'created_at', a.created_at)
  from cs.agents a
  left join cs.agent_status st on st.agent_id = a.user_id
  left join cs.teams tm on tm.id = a.team_id
  left join auth.users u on u.id = a.user_id
  where a.user_id = p_agent;
$$;

create or replace function cs.check_agent_input(p_display_name text, p_roles text[], p_team text, p_max integer)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if char_length(btrim(coalesce(p_display_name, ''))) not between 2 and 40 then
    perform private.api_error(400, 'invalid_name', 'Nama CS 2–40 karakter');
  end if;
  if coalesce(cardinality(p_roles), 0) = 0 or not (p_roles <@ '{cs_agent,cs_supervisor,cs_admin,compliance}'::text[]) then
    perform private.api_error(400, 'invalid_roles', 'Peran harus cs_agent, cs_supervisor, cs_admin, atau compliance');
  end if;
  if p_team is not null and not exists (select 1 from cs.teams t where t.code = p_team and t.active) then
    perform private.api_error(400, 'invalid_team', 'Tim tidak dikenal');
  end if;
  if coalesce(p_max, 0) not between 1 and 20 then
    perform private.api_error(400, 'invalid_limit', 'Batas tiket aktif 1–20');
  end if;
end;
$$;

create or replace function cs.placeholders(p_text text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(distinct m[1]), '{}')
  from regexp_matches(coalesce(p_text, ''), '(\{[a-z_]+\})', 'g') m;
$$;

create or replace function cs.admin_editable(p_key text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_key in ('assignment.mode', 'ticket.auto_release_offline_minutes', 'service.hours',
                   'alerts.unclaimed_minutes', 'alerts.p1_unclaimed_minutes')
      or p_key like 'messages.%';
$$;

create or replace function cs.check_setting_value(p_key text, p_value jsonb, p_old jsonb)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_day   text;
  v_hours jsonb;
  v_lang  text;
  v_min   integer := 1;
  v_max   integer := 240;
  v_error text := 'Batas alert 1–240 menit';
begin
  case
    when p_key = 'assignment.mode' then
      if jsonb_typeof(p_value) <> 'string' or p_value #>> '{}' not in ('claim', 'auto_assign') then
        perform private.api_error(400, 'invalid_setting', 'Mode penugasan harus claim atau auto_assign');
      end if;
    when p_key in ('ticket.auto_release_offline_minutes', 'alerts.unclaimed_minutes', 'alerts.p1_unclaimed_minutes') then
      if p_key = 'ticket.auto_release_offline_minutes' then
        v_min := 0;
        v_max := 1440;
        v_error := 'Lepas otomatis 0–1440 menit (0 = mati)';
      end if;
      if jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
         or (p_value #>> '{}')::integer not between v_min and v_max then
        perform private.api_error(400, 'invalid_setting', v_error);
      end if;
    when p_key = 'service.hours' then
      if jsonb_typeof(p_value) <> 'object'
         or (select array_agg(k order by k) from jsonb_object_keys(p_value) k) <> '{1,2,3,4,5,6,7}'::text[] then
        perform private.api_error(400, 'invalid_setting', 'Jam layanan harus berisi hari 1–7');
      end if;
      for v_day, v_hours in select * from jsonb_each(p_value) loop
        if jsonb_typeof(v_hours) = 'null' then
          continue;
        end if;
        if jsonb_typeof(v_hours) <> 'array' or jsonb_array_length(v_hours) <> 2
           or (v_hours ->> 0) !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
           or (v_hours ->> 1) !~ '^(([01][0-9]|2[0-3]):[0-5][0-9]|24:00)$'
           or (v_hours ->> 0) >= (v_hours ->> 1) then
          perform private.api_error(400, 'invalid_setting', 'Jam layanan hari ' || v_day || ' harus HH:MM–HH:MM dan jam buka sebelum jam tutup');
        end if;
      end loop;
    when p_key like 'messages.%' then
      if jsonb_typeof(p_value) <> 'object'
         or (select array_agg(k order by k) from jsonb_object_keys(p_value) k) <> '{en,id}'::text[] then
        perform private.api_error(400, 'invalid_setting', 'Pesan otomatis harus punya teks id dan en');
      end if;
      foreach v_lang in array array['id', 'en'] loop
        if jsonb_typeof(p_value -> v_lang) <> 'string' or char_length(btrim(p_value ->> v_lang)) not between 2 and 500 then
          perform private.api_error(400, 'invalid_setting', 'Teks pesan 2–500 karakter');
        end if;
        if not (cs.placeholders(p_value ->> v_lang) <@ cs.placeholders(p_old ->> v_lang)) then
          perform private.api_error(400, 'invalid_setting',
            'Variabel yang boleh dipakai: ' || coalesce(nullif(array_to_string(cs.placeholders(p_old ->> v_lang), ', '), ''), '-'));
        end if;
      end loop;
    else
      perform private.api_error(403, 'setting_locked', 'Pengaturan ini tidak bisa diubah dari console');
  end case;
end;
$$;

create or replace function cs_api.supervisor_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me    uuid := cs.require_agent('{cs_supervisor}');
  v_late  integer := cs.setting_int('alerts.unclaimed_minutes');
  v_p1    integer := cs.setting_int('alerts.p1_unclaimed_minutes');
  v_stale interval := make_interval(secs => cs.setting_int('agent.heartbeat_fresh_seconds') * 4);
  v_today timestamptz := cs.local_date(now())::timestamp at time zone 'Asia/Jakarta';
begin
  return jsonb_build_object(
    'generated_at', now(),
    'thresholds', jsonb_build_object('unclaimed_minutes', v_late, 'p1_unclaimed_minutes', v_p1),
    'open_count', (select count(*) from cs.tickets t where t.status = 'open'),
    'oldest_open_at', (select min(t.queued_at) from cs.tickets t where t.status = 'open'),
    'active_count', (select count(*) from cs.tickets t where t.status in ('claimed', 'waiting_customer')),
    'resolved_today', (select count(*) from cs.tickets t where t.resolved_at >= v_today),
    'overdue', coalesce((
      select jsonb_agg(cs.ticket_card(t, v_me) order by t.priority, t.queued_at)
      from cs.tickets t
      where t.status = 'open'
        and (t.queued_at < now() - make_interval(mins => v_late)
             or (t.priority = 'P1' and t.queued_at < now() - make_interval(mins => v_p1)))), '[]'),
    'flagged_open', coalesce((
      select jsonb_agg(cs.ticket_card(t, v_me) order by t.priority, t.queued_at)
      from cs.tickets t
      where t.status = 'open' and t.flags && '{fraud,complaint}'::text[]), '[]'),
    'offline_owned', coalesce((
      select jsonb_agg(cs.ticket_card(t, v_me) order by t.priority, t.claimed_at)
      from cs.tickets t
      join cs.agent_status st on st.agent_id = t.owner_agent_id
      where t.status in ('claimed', 'waiting_customer')
        and (st.status = 'offline' or st.last_heartbeat_at < now() - v_stale)), '[]'),
    'agents', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', a.user_id, 'display_name', a.display_name, 'agent_code', a.agent_code,
               'roles', to_jsonb(a.roles), 'status', st.status,
               'connected', st.status <> 'offline' and st.last_heartbeat_at > now() - v_stale,
               'active_tickets', cs.active_ticket_count(a.user_id), 'max_active_tickets', a.max_active_tickets,
               'resolved_today', (select count(*) from cs.tickets t where t.resolved_by = a.user_id and t.resolved_at >= v_today),
               'status_changed_at', st.status_changed_at)
             order by (st.status = 'online') desc, (st.status = 'offline'), a.display_name)
      from cs.agents a
      join cs.agent_status st on st.agent_id = a.user_id
      where a.disabled_at is null and a.roles && '{cs_agent,cs_supervisor}'::text[]), '[]'));
end;
$$;

create or replace function cs.report_stats(p_from timestamptz, p_to timestamptz)
returns table (
  created                    bigint,
  resolved                   bigint,
  avg_claim_minutes          numeric,
  avg_first_response_minutes numeric,
  avg_resolution_minutes     numeric,
  avg_rating                 numeric,
  ratings                    bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select count(*),
         count(*) filter (where t.resolved_at is not null),
         round((avg(extract(epoch from t.first_claimed_at - t.created_at)) / 60)::numeric, 1),
         round((avg(extract(epoch from t.first_response_at - t.created_at)) / 60)::numeric, 1),
         round((avg(extract(epoch from t.resolved_at - t.created_at)) / 60)::numeric, 1),
         round(avg(t.rating)::numeric, 2),
         count(t.rating)
  from cs.tickets t
  where t.created_at >= p_from and t.created_at < p_to;
$$;

create or replace function cs_api.report_summary(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me   uuid := cs.require_agent('{cs_supervisor,cs_admin}');
  v_from timestamptz;
  v_to   timestamptz;
begin
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 92 then
    perform private.api_error(400, 'invalid_range', 'Rentang laporan 1–93 hari');
  end if;
  v_from := p_from::timestamp at time zone 'Asia/Jakarta';
  v_to := (p_to + 1)::timestamp at time zone 'Asia/Jakarta';
  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'totals', (select to_jsonb(s) from cs.report_stats(v_from, v_to) s),
    'daily', (
      select jsonb_agg(to_jsonb(s) || jsonb_build_object('day', p_from + d.i) order by d.i)
      from generate_series(0, p_to - p_from) d(i)
      cross join lateral cs.report_stats((p_from + d.i)::timestamp at time zone 'Asia/Jakarta',
                                         (p_from + d.i + 1)::timestamp at time zone 'Asia/Jakarta') s),
    'agents', coalesce((
      select jsonb_agg(x order by (x ->> 'resolved')::integer desc, x ->> 'display_name')
      from (
        select jsonb_build_object(
                 'id', a.user_id, 'display_name', a.display_name, 'agent_code', a.agent_code,
                 'handled', count(*),
                 'resolved', count(*) filter (where t.resolved_by = a.user_id),
                 'avg_first_response_minutes',
                   round((avg(extract(epoch from t.first_response_at - t.first_claimed_at)) / 60)::numeric, 1),
                 'avg_rating', round(avg(t.rating)::numeric, 2),
                 'ratings', count(t.rating)) x
        from cs.tickets t
        join cs.agents a on a.user_id = t.last_owner_id
        where t.created_at >= v_from and t.created_at < v_to
        group by a.user_id, a.display_name, a.agent_code) r), '[]'),
    'topics', coalesce((
      select jsonb_agg(x order by (x ->> 'count')::integer desc, x ->> 'topic')
      from (
        select jsonb_build_object('topic', t.topic, 'name', coalesce(tp.name_id, t.topic), 'count', count(*)) x
        from cs.tickets t
        left join cs.support_topics tp on tp.code = t.topic
        where t.created_at >= v_from and t.created_at < v_to
        group by t.topic, tp.name_id) r), '[]'));
end;
$$;

create or replace function cs_api.admin_agents()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_admin}');
begin
  return coalesce((
    select jsonb_agg(cs.agent_admin_view(a.user_id) order by a.disabled_at nulls first, a.display_name)
    from cs.agents a), '[]');
end;
$$;

create or replace function cs_api.admin_options()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_admin}');
begin
  return jsonb_build_object(
    'teams', coalesce((select jsonb_agg(jsonb_build_object('code', t.code, 'name', t.name_id) order by t.name_id)
                       from cs.teams t where t.active), '[]'),
    'skills', coalesce((select jsonb_agg(jsonb_build_object('code', s.code, 'name', s.name_id) order by s.name_id)
                        from cs.skills s), '[]'));
end;
$$;

create or replace function cs.retire_agent_work(p_agent uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
begin
  for r in
    update cs.ticket_transfers
       set result = 'cancelled', responded_at = now(), reason = p_reason
     where to_agent_id = p_agent and result is null
    returning id, ticket_id, from_agent_id
  loop
    perform cs.log_event(r.ticket_id, 'transfer_cancelled', jsonb_build_object('to', p_agent, 'reason', p_reason));
    perform realtime.send(jsonb_build_object('event', 'transfer_cancelled', 'transfer_id', r.id, 'ticket_id', r.ticket_id,
                                             'ticket_number', (select t.ticket_number from cs.tickets t where t.id = r.ticket_id),
                                             'by_name', cs.agent_name(p_agent), 'reason', p_reason),
                          'transfer', 'cs:agent:' || r.from_agent_id::text, true);
  end loop;
  perform cs.release_owner_tickets(p_agent, p_reason);
end;
$$;

create or replace function cs_api.admin_update_agent(
  p_agent_id           uuid,
  p_display_name       text,
  p_roles              text[],
  p_team               text,
  p_max_active_tickets integer,
  p_disabled           boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := cs.require_agent('{cs_admin}');
  v_disable boolean := coalesce(p_disabled, false);
  a         cs.agents;
begin
  perform cs.check_agent_input(p_display_name, p_roles, p_team, p_max_active_tickets);
  if p_agent_id = v_me and (v_disable or not ('cs_admin' = any (p_roles))) then
    perform private.api_error(400, 'cannot_change_self', 'Tidak bisa menonaktifkan atau melepas peran admin akun sendiri');
  end if;
  select * into a from cs.agents where user_id = p_agent_id for update;
  if not found then
    perform private.api_error(404, 'agent_not_found', 'Akun CS tidak ditemukan');
  end if;
  perform 1 from cs.agent_status where agent_id = p_agent_id for update;

  update cs.agents
     set display_name = btrim(p_display_name),
         roles = p_roles,
         team_id = coalesce((select t.id from cs.teams t where t.code = p_team), team_id),
         max_active_tickets = p_max_active_tickets,
         disabled_at = case when v_disable then coalesce(disabled_at, now()) end
   where user_id = p_agent_id;
  update public.profiles set display_name = btrim(p_display_name)
   where id = p_agent_id and display_name is distinct from btrim(p_display_name);

  if v_disable and a.disabled_at is null then
    update cs.agent_status set status = 'offline', reason = null, status_changed_at = now()
     where agent_id = p_agent_id and status <> 'offline';
    perform cs.retire_agent_work(p_agent_id, 'Akun CS dinonaktifkan');
    perform realtime.send(jsonb_build_object('event', 'agent_status', 'agent_id', p_agent_id, 'status', 'offline'),
                          'agent', 'cs:queue', true);
  elsif not (p_roles && '{cs_agent,cs_supervisor}'::text[]) and a.roles && '{cs_agent,cs_supervisor}'::text[] then
    perform cs.retire_agent_work(p_agent_id, 'Peran CS diubah');
  end if;

  perform cs.audit('agent.update', null, null, jsonb_build_object(
    'agent', p_agent_id, 'roles', p_roles, 'team', p_team, 'max_active_tickets', p_max_active_tickets,
    'disabled', v_disable));
  return cs.agent_admin_view(p_agent_id);
end;
$$;

create or replace function cs_api.service_create_agent(
  p_user_id            uuid,
  p_display_name       text,
  p_roles              text[],
  p_team               text,
  p_max_active_tickets integer,
  p_created_by         uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    perform private.api_error(403, 'service_only', 'Hanya layanan admin yang bisa membuat akun CS');
  end if;
  if not exists (select 1 from cs.agents a where a.user_id = p_created_by and a.disabled_at is null and 'cs_admin' = any (a.roles)) then
    perform private.api_error(403, 'admin_required', 'Pembuat akun harus admin CS aktif');
  end if;
  perform cs.check_agent_input(p_display_name, p_roles, coalesce(p_team, 'general'), p_max_active_tickets);
  perform cs.create_agent(p_user_id, p_display_name, p_roles, coalesce(p_team, 'general'), '{"general": 1}', '{id,en}',
                          p_max_active_tickets, p_created_by);
  insert into cs.cs_audit_log (actor_id, actor_type, actor_roles, action, details)
  values (p_created_by, 'agent', (select a.roles from cs.agents a where a.user_id = p_created_by), 'agent.create',
          jsonb_build_object('agent', p_user_id, 'roles', p_roles, 'team', coalesce(p_team, 'general'),
                             'max_active_tickets', p_max_active_tickets));
  return cs.agent_admin_view(p_user_id);
end;
$$;

create or replace function cs_api.admin_topics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_admin}');
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'code', t.code, 'name_id', t.name_id, 'name_en', t.name_en, 'skill', t.skill,
             'default_priority', t.default_priority, 'help_url', t.help_url, 'sort_order', t.sort_order,
             'active', t.active)
           order by t.sort_order, t.code)
    from cs.support_topics t), '[]');
end;
$$;

create or replace function cs_api.admin_save_topic(
  p_code             text,
  p_name_id          text,
  p_name_en          text,
  p_skill            text,
  p_default_priority text,
  p_help_url         text,
  p_sort_order       integer,
  p_active           boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_admin}');
  v_url text := nullif(btrim(coalesce(p_help_url, '')), '');
begin
  if coalesce(p_code, '') !~ '^[a-z][a-z0-9_]{1,31}$' then
    perform private.api_error(400, 'invalid_code', 'Kode topik 2–32 huruf kecil, angka, atau garis bawah');
  end if;
  if char_length(btrim(coalesce(p_name_id, ''))) not between 2 and 40
     or char_length(btrim(coalesce(p_name_en, ''))) not between 2 and 40 then
    perform private.api_error(400, 'invalid_name', 'Nama topik (ID dan EN) 2–40 karakter');
  end if;
  if not exists (select 1 from cs.skills s where s.code = p_skill) then
    perform private.api_error(400, 'invalid_skill', 'Skill tidak dikenal');
  end if;
  if coalesce(p_default_priority, '') not in ('P1', 'P2', 'P3', 'P4') then
    perform private.api_error(400, 'invalid_priority', 'Prioritas harus P1–P4');
  end if;
  if coalesce(p_sort_order, -1) not between 0 and 999 then
    perform private.api_error(400, 'invalid_sort', 'Urutan 0–999');
  end if;
  if v_url is not null and (v_url !~ '^https://[A-Za-z0-9.-]+(/\S*)?$'
     or not (cs.setting('help.allowed_hosts') ? lower(substring(v_url from '^https://([A-Za-z0-9.-]+)')))) then
    perform private.api_error(400, 'invalid_help_link', 'Tautan bantuan harus https ke situs bantuan resmi');
  end if;
  if not coalesce(p_active, true) and p_code = cs.setting('ticket.default_topic') #>> '{}' then
    perform private.api_error(400, 'default_topic', 'Topik bawaan tidak bisa dinonaktifkan');
  end if;
  insert into cs.support_topics (code, name_id, name_en, skill, default_priority, help_url, sort_order, active)
  values (p_code, btrim(p_name_id), btrim(p_name_en), p_skill, p_default_priority, v_url, p_sort_order,
          coalesce(p_active, true))
  on conflict (code) do update
    set name_id = excluded.name_id, name_en = excluded.name_en, skill = excluded.skill,
        default_priority = excluded.default_priority, help_url = excluded.help_url,
        sort_order = excluded.sort_order, active = excluded.active;
  perform cs.audit('topic.save', null, null, jsonb_build_object('code', p_code, 'active', coalesce(p_active, true)));
  return cs_api.admin_topics();
end;
$$;

create or replace function cs_api.admin_quick_replies()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_admin}');
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', q.id, 'shortcut', q.shortcut, 'title', q.title, 'body', q.body,
             'language', q.language, 'active', q.active, 'updated_at', q.updated_at)
           order by q.language, q.shortcut)
    from cs.quick_replies q
    where q.scope = 'global'), '[]');
end;
$$;

create or replace function cs_api.admin_save_quick_reply(
  p_id       uuid,
  p_shortcut text,
  p_title    text,
  p_body     text,
  p_language text,
  p_active   boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_agent('{cs_admin}');
  v_language text := coalesce(p_language, 'id');
begin
  if coalesce(p_shortcut, '') !~ '^[a-z0-9_-]{2,32}$' then
    perform private.api_error(400, 'invalid_shortcut', 'Pintasan 2–32 huruf kecil, angka, - atau _');
  end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 1 and 80 then
    perform private.api_error(400, 'invalid_title', 'Judul 1–80 karakter');
  end if;
  if char_length(btrim(coalesce(p_body, ''))) not between 1 and 2000 then
    perform private.api_error(400, 'invalid_body', 'Isi balasan 1–2000 karakter');
  end if;
  if v_language not in ('id', 'en') then
    perform private.api_error(400, 'invalid_language', 'Bahasa harus id atau en');
  end if;
  if cs.requests_secret(p_body) then
    perform private.api_error(400, 'secret_request_blocked', 'Balasan cepat tidak boleh meminta OTP, PIN, atau password');
  end if;
  if exists (select 1 from cs.quick_replies q
             where q.scope = 'global' and q.shortcut = p_shortcut and q.language = v_language
               and q.id is distinct from p_id) then
    perform private.api_error(409, 'duplicate_shortcut', 'Pintasan sudah dipakai balasan lain');
  end if;
  if p_id is null then
    insert into cs.quick_replies (scope, shortcut, title, body, language, active, created_by)
    values ('global', p_shortcut, btrim(p_title), btrim(p_body), v_language, coalesce(p_active, true), v_me);
  else
    update cs.quick_replies
       set shortcut = p_shortcut, title = btrim(p_title), body = btrim(p_body),
           language = v_language, active = coalesce(p_active, true), updated_at = now()
     where id = p_id and scope = 'global';
    if not found then
      perform private.api_error(404, 'quick_reply_not_found', 'Balasan cepat tidak ditemukan');
    end if;
  end if;
  perform cs.audit('quick_reply.save', null, null, jsonb_build_object('shortcut', p_shortcut, 'active', coalesce(p_active, true)));
  return cs_api.admin_quick_replies();
end;
$$;

create or replace function cs_api.admin_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_admin}');
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'key', s.key, 'value', s.value, 'description', s.description, 'version', s.version,
             'updated_at', s.updated_at, 'updated_by', a.display_name)
           order by s.key)
    from cs.cs_settings s
    left join cs.agents a on a.user_id = s.updated_by
    where cs.admin_editable(s.key)), '[]');
end;
$$;

create or replace function cs_api.admin_set_setting(p_key text, p_value jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_admin}');
  v_old jsonb := (select s.value from cs.cs_settings s where s.key = p_key);
begin
  if v_old is null or not cs.admin_editable(p_key) then
    perform private.api_error(403, 'setting_locked', 'Pengaturan ini tidak bisa diubah dari console');
  end if;
  perform cs.check_setting_value(p_key, p_value, v_old);
  perform cs.set_setting(p_key, p_value, v_me);
  perform cs.audit('setting.update', null, null, jsonb_build_object('key', p_key));
  return (select jsonb_build_object('key', s.key, 'value', s.value, 'version', s.version, 'updated_at', s.updated_at)
          from cs.cs_settings s where s.key = p_key);
end;
$$;

create or replace function cs_api.admin_holidays(p_year integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_admin}');
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('day', h.day, 'name', h.name, 'kind', h.kind) order by h.day)
    from cs.holidays h
    where h.day >= make_date(p_year, 1, 1) and h.day < make_date(p_year + 1, 1, 1)), '[]');
end;
$$;

create or replace function cs_api.admin_save_holiday(p_day date, p_name text, p_kind text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_admin}');
begin
  if p_day is null then
    perform private.api_error(400, 'invalid_day', 'Tanggal wajib diisi');
  end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 2 and 120 then
    perform private.api_error(400, 'invalid_name', 'Nama hari libur 2–120 karakter');
  end if;
  if coalesce(p_kind, '') not in ('national', 'collective_leave', 'exchange') then
    perform private.api_error(400, 'invalid_kind', 'Jenis harus libur nasional, cuti bersama, atau libur bursa');
  end if;
  insert into cs.holidays (day, name, kind, verified, updated_at, updated_by)
  values (p_day, btrim(p_name), p_kind, true, now(), v_me)
  on conflict (day) do update
    set name = excluded.name, kind = excluded.kind, verified = true, updated_at = now(), updated_by = v_me;
  perform cs.audit('holiday.save', null, null, jsonb_build_object('day', p_day, 'kind', p_kind));
  return cs_api.admin_holidays(extract(year from p_day)::integer);
end;
$$;

create or replace function cs_api.admin_delete_holiday(p_day date)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_admin}');
begin
  delete from cs.holidays where day = p_day;
  if not found then
    perform private.api_error(404, 'holiday_not_found', 'Hari libur tidak ditemukan');
  end if;
  perform cs.audit('holiday.delete', null, null, jsonb_build_object('day', p_day));
  return cs_api.admin_holidays(extract(year from p_day)::integer);
end;
$$;

revoke execute on function cs.agent_admin_view(uuid) from public;
revoke execute on function cs.check_agent_input(text, text[], text, integer) from public;
revoke execute on function cs.placeholders(text) from public;
revoke execute on function cs.admin_editable(text) from public;
revoke execute on function cs.check_setting_value(text, jsonb, jsonb) from public;
revoke execute on function cs.report_stats(timestamptz, timestamptz) from public;
revoke execute on function cs.retire_agent_work(uuid, text) from public;
revoke execute on function cs_api.supervisor_overview() from public;
revoke execute on function cs_api.report_summary(date, date) from public;
revoke execute on function cs_api.admin_agents() from public;
revoke execute on function cs_api.admin_options() from public;
revoke execute on function cs_api.admin_update_agent(uuid, text, text[], text, integer, boolean) from public;
revoke execute on function cs_api.service_create_agent(uuid, text, text[], text, integer, uuid) from public;
revoke execute on function cs_api.admin_topics() from public;
revoke execute on function cs_api.admin_save_topic(text, text, text, text, text, text, integer, boolean) from public;
revoke execute on function cs_api.admin_quick_replies() from public;
revoke execute on function cs_api.admin_save_quick_reply(uuid, text, text, text, text, boolean) from public;
revoke execute on function cs_api.admin_settings() from public;
revoke execute on function cs_api.admin_set_setting(text, jsonb) from public;
revoke execute on function cs_api.admin_holidays(integer) from public;
revoke execute on function cs_api.admin_save_holiday(date, text, text) from public;
revoke execute on function cs_api.admin_delete_holiday(date) from public;

grant execute on function cs_api.supervisor_overview() to authenticated;
grant execute on function cs_api.report_summary(date, date) to authenticated;
grant execute on function cs_api.admin_agents() to authenticated;
grant execute on function cs_api.admin_options() to authenticated;
grant execute on function cs_api.admin_update_agent(uuid, text, text[], text, integer, boolean) to authenticated;
grant execute on function cs_api.service_create_agent(uuid, text, text[], text, integer, uuid) to service_role;
grant execute on function cs_api.admin_topics() to authenticated;
grant execute on function cs_api.admin_save_topic(text, text, text, text, text, text, integer, boolean) to authenticated;
grant execute on function cs_api.admin_quick_replies() to authenticated;
grant execute on function cs_api.admin_save_quick_reply(uuid, text, text, text, text, boolean) to authenticated;
grant execute on function cs_api.admin_settings() to authenticated;
grant execute on function cs_api.admin_set_setting(text, jsonb) to authenticated;
grant execute on function cs_api.admin_holidays(integer) to authenticated;
grant execute on function cs_api.admin_save_holiday(date, text, text) to authenticated;
grant execute on function cs_api.admin_delete_holiday(date) to authenticated;
