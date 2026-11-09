alter table public.profiles add column is_guest boolean not null default false;
grant select (is_guest) on public.profiles to authenticated;

create table cs.guest_sessions (
  id           uuid primary key default gen_random_uuid(),
  token_hash   text not null unique,
  profile_id   uuid not null references public.profiles (id) on delete cascade,
  ticket_id    uuid references cs.tickets (id) on delete set null,
  login_id     text check (login_id is null or login_id ~ '^[A-Z0-9._@-]{1,50}$'),
  problem      text not null check (problem in ('password', 'pin', 'locked', 'other')),
  ip_hash      text not null,
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null,
  last_seen_at timestamptz not null default now(),
  ended_at     timestamptz
);

create index guest_sessions_ip_idx on cs.guest_sessions (ip_hash, created_at);
create index guest_sessions_login_idx on cs.guest_sessions (login_id, created_at) where login_id is not null;

create table private.guest_pepper (
  id     boolean primary key default true check (id),
  pepper bytea not null
);

insert into private.guest_pepper (pepper) values (extensions.gen_random_bytes(32)) on conflict (id) do nothing;

alter table cs.guest_sessions enable row level security;
alter table private.guest_pepper enable row level security;
revoke all on cs.guest_sessions from public, anon, authenticated;
revoke all on private.guest_pepper from public, anon, authenticated;

insert into private.rate_limits (action, max_count, window_seconds) values
  ('guest_message', 20, 60)
on conflict (action, window_seconds) do nothing;

insert into cs.cs_settings (key, value, description) values
  ('guest.enabled', 'true', 'Pengaduan tamu (nasabah yang tidak bisa login) bisa dibuka dari halaman login aplikasi'),
  ('guest.topic', '"account"', 'Topik chat CS untuk pengaduan tamu'),
  ('guest.session_hours', '24', 'Lama sesi chat pengaduan tamu (jam)')
on conflict (key) do nothing;

CREATE OR REPLACE FUNCTION public.search_profiles(p_query text, p_limit integer DEFAULT 10)
 RETURNS TABLE(id uuid, username text, display_name text, avatar_url text, is_verified boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
  with q as (
    select replace(replace(replace(btrim(coalesce(p_query, '')), '\', '\\'), '%', '\%'), '_', '\_') as term
  )
  select p.id, p.username::text, p.display_name, p.avatar_url, p.is_verified
  from public.profiles p, q
  where q.term <> ''
    and (p.username::text ilike q.term || '%' or p.display_name ilike '%' || q.term || '%')
    and p.id not in (select private.blocked_user_ids())
    and not cs.is_staff(p.id)
    and not p.is_guest
  order by (lower(p.username::text) = lower(btrim(p_query))) desc,
           p.follower_count desc,
           p.username
  limit least(greatest(coalesce(p_limit, 10), 1), 25);
$function$;

CREATE OR REPLACE FUNCTION cs_api.community_find_users(p_query text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me   uuid := cs.require_community('{community.moderate,community.sanction,community.accounts}');
  v_text text := btrim(coalesce(p_query, ''));
  v_like text;
begin
  if char_length(v_text) not between 2 and 60 then
    perform private.api_error(400, 'invalid_query', 'Ketik 2–60 karakter');
  end if;
  v_like := '%' || replace(replace(replace(ltrim(v_text, '@'), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return coalesce((
    select jsonb_agg(cs.community_user_row(x) order by x.username)
    from (select p.* from public.profiles p
          where p.olt_user_id not like 'cs-staff:%'
            and not p.is_guest
            and (p.username::text ilike v_like or p.display_name ilike v_like)
          order by (p.username::text ilike ltrim(v_text, '@')) desc, p.username
          limit 20) x), '[]');
end;
$function$;

CREATE OR REPLACE FUNCTION cs_api.push_find_users(p_query text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me   uuid := cs.require_agent('{cs_super_admin}');
  v_text text := ltrim(btrim(coalesce(p_query, '')), '@');
  v_like text;
begin
  if char_length(v_text) not between 2 and 60 then
    perform private.api_error(400, 'invalid_query', 'Ketik 2–60 karakter');
  end if;
  v_like := '%' || replace(replace(replace(v_text, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', p.id, 'username', p.username, 'display_name', p.display_name, 'avatar_url', p.avatar_url,
             'devices', (select jsonb_agg(jsonb_build_object('platform', d.platform, 'app_version', d.app_version,
                                                             'last_seen_at', d.last_seen_at)
                                          order by d.last_seen_at desc)
                         from private.push_devices d where d.user_id = p.id))
           order by p.username)
    from (select x.* from public.profiles x
          where x.deleted_at is null
            and not x.is_guest
            and exists (select 1 from private.push_devices d where d.user_id = x.id)
            and (x.username::text ilike v_like or x.display_name ilike v_like)
          order by (x.username::text ilike v_text) desc, x.username
          limit 10) p), '[]');
end;
$function$;

CREATE OR REPLACE FUNCTION cs_api.community_room_moderator_candidates(p_code text, p_query text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_me   uuid := cs.require_community('{community.moderate}');
  v_room uuid := private.stock_room_id(p_code);
  v_text text := btrim(coalesce(p_query, ''));
  v_like text;
begin
  if char_length(v_text) not between 2 and 60 then
    perform private.api_error(400, 'invalid_query', 'Ketik 2–60 karakter');
  end if;
  v_like := '%' || replace(replace(replace(ltrim(v_text, '@'), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return coalesce((
    select jsonb_agg(cs.community_user_row(x) || jsonb_build_object(
             'problems', to_jsonb(private.room_moderator_problems(x.id)),
             'eligible', cardinality(private.room_moderator_problems(x.id)) = 0,
             'is_moderator', v_room is not null and private.is_room_moderator(v_room, x.id),
             'moderated_rooms', (select count(*) from private.room_moderators m
                                 where m.user_id = x.id and m.removed_at is null),
             'member', v_room is not null and exists (select 1 from public.chat_members cm
                                                     where cm.room_id = v_room and cm.user_id = x.id))
           order by x.username)
    from (select p.* from public.profiles p
          where p.olt_user_id not like 'cs-staff:%' and p.deleted_at is null and not p.is_guest
            and (p.username::text ilike v_like or p.display_name ilike v_like)
          order by (p.username::text ilike ltrim(v_text, '@')) desc, p.username
          limit 20) x), '[]');
end;
$function$;

CREATE OR REPLACE FUNCTION cs.check_setting_value(p_key text, p_value jsonb, p_old jsonb)
 RETURNS void
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
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
    when p_key in ('community.four_eyes', 'guest.enabled') then
      if jsonb_typeof(p_value) <> 'boolean' then
        perform private.api_error(400, 'invalid_setting', 'Nilai harus true atau false');
      end if;
    when p_key in ('ticket.auto_release_offline_minutes', 'ticket.auto_close_days', 'alerts.unclaimed_minutes',
                   'alerts.p1_unclaimed_minutes') then
      if p_key = 'ticket.auto_release_offline_minutes' then
        v_min := 0;
        v_max := 1440;
        v_error := 'Lepas otomatis 0–1440 menit (0 = mati)';
      elsif p_key = 'ticket.auto_close_days' then
        v_max := 30;
        v_error := 'Tutup otomatis 1–30 hari';
      end if;
      if jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
         or (p_value #>> '{}')::integer not between v_min and v_max then
        perform private.api_error(400, 'invalid_setting', v_error);
      end if;
    when p_key = 'ticket.reminder_hours' then
      if jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
         or (p_value #>> '{}')::integer not between 0 and 72 then
        perform private.api_error(400, 'invalid_setting', 'Pengingat 0–72 jam (0 = mati)');
      end if;
    when p_key = 'accounts.max_per_customer' then
      if jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
         or (p_value #>> '{}')::integer not between 1 and 200 then
        perform private.api_error(400, 'invalid_setting', 'Batas rekening per nasabah 1–200');
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
$function$;

CREATE OR REPLACE FUNCTION cs.admin_editable(p_key text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select p_key in ('assignment.mode', 'ticket.auto_release_offline_minutes', 'ticket.auto_close_days', 'service.hours',
                   'alerts.unclaimed_minutes', 'alerts.p1_unclaimed_minutes', 'community.four_eyes',
                   'accounts.max_per_customer', 'ticket.reminder_hours', 'guest.enabled')
      or p_key like 'messages.%';
$function$;

create or replace function cs.guest_ip_hash()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select encode(extensions.hmac(
    convert_to(coalesce(nullif(btrim(split_part(h ->> 'x-forwarded-for', ',', 1)), ''), nullif(btrim(h ->> 'x-real-ip'), ''), 'unknown'), 'UTF8'),
    (select g.pepper from private.guest_pepper g), 'sha256'), 'hex')
  from (select coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb as h) x;
$$;

create or replace function cs.guest_act_as(p_profile uuid)
returns void
language plpgsql
volatile
set search_path = ''
as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_profile, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_profile::text, true);
end;
$$;

create or replace function cs.guest_session(p_token text)
returns cs.guest_sessions
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g cs.guest_sessions;
begin
  if p_token is null or char_length(p_token) not between 20 and 100 then
    perform private.api_error(401, 'guest_session_expired', 'Sesi pengaduan sudah berakhir. Silakan buat pengaduan baru.');
  end if;
  update cs.guest_sessions
     set last_seen_at = now()
   where token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
     and ended_at is null and expires_at > now()
  returning * into g;
  if g.id is null then
    perform private.api_error(401, 'guest_session_expired', 'Sesi pengaduan sudah berakhir. Silakan buat pengaduan baru.');
  end if;
  return g;
end;
$$;

create or replace function cs_api.guest_config(p_language text default 'id')
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'enabled', coalesce((cs.setting('guest.enabled') #>> '{}')::boolean, false),
    'session_hours', coalesce(cs.setting_int('guest.session_hours'), 24),
    'problems', jsonb_build_array(
      jsonb_build_object('code', 'password', 'label', case when p_language = 'en' then 'Forgot password' else 'Lupa password' end),
      jsonb_build_object('code', 'pin', 'label', case when p_language = 'en' then 'Forgot PIN' else 'Lupa PIN' end),
      jsonb_build_object('code', 'locked', 'label', case when p_language = 'en' then 'Account locked or suspended' else 'Akun terkunci atau ditangguhkan' end),
      jsonb_build_object('code', 'other', 'label', case when p_language = 'en' then 'Other login problem' else 'Masalah login lainnya' end)));
$$;

create or replace function cs_api.guest_start(p_name text, p_login_id text, p_problem text, p_description text,
                                              p_language text default 'id')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name    text := btrim(coalesce(p_name, ''));
  v_login   text := nullif(upper(btrim(coalesce(p_login_id, ''))), '');
  v_text    text := btrim(coalesce(p_description, ''));
  v_ip      text := cs.guest_ip_hash();
  v_profile uuid := gen_random_uuid();
  v_topic   text;
  v_token   text;
  v_hours   integer := least(greatest(coalesce(cs.setting_int('guest.session_hours'), 24), 1), 72);
  t         cs.tickets;
begin
  if not coalesce((cs.setting('guest.enabled') #>> '{}')::boolean, false) then
    perform private.api_error(403, 'guest_disabled', 'Pengaduan tanpa login sedang tidak tersedia');
  end if;
  if coalesce(p_language, '') not in ('id', 'en') then
    perform private.api_error(400, 'invalid_language', 'Bahasa harus id atau en');
  end if;
  if char_length(v_name) not between 2 and 60 then
    perform private.api_error(400, 'invalid_name', 'Nama 2–60 karakter');
  end if;
  if v_login is not null and v_login !~ '^[A-Z0-9._@-]{1,50}$' then
    perform private.api_error(400, 'invalid_login_id', 'Login ID tidak valid');
  end if;
  if coalesce(p_problem, '') not in ('password', 'pin', 'locked', 'other') then
    perform private.api_error(400, 'invalid_problem', 'Pilih jenis masalah');
  end if;
  if char_length(v_text) not between 10 and 1000 then
    perform private.api_error(400, 'invalid_description', 'Ceritakan masalahnya (10–1.000 karakter)');
  end if;
  if (select count(*) from cs.guest_sessions g where g.ip_hash = v_ip and g.created_at > now() - interval '1 hour') >= 3
     or (select count(*) from cs.guest_sessions g where g.ip_hash = v_ip and g.created_at > now() - interval '24 hours') >= 10 then
    perform private.api_error(429, 'rate_limited', 'Terlalu banyak pengaduan dari perangkat ini. Coba lagi nanti.');
  end if;
  if v_login is not null
     and (select count(*) from cs.guest_sessions g where g.login_id = v_login and g.created_at > now() - interval '24 hours') >= 5 then
    perform private.api_error(429, 'guest_login_limit', 'Pengaduan untuk Login ID ini sudah banyak hari ini. Coba lagi besok atau hubungi kantor cabang.');
  end if;
  select t2.code into v_topic from cs.support_topics t2
   where t2.active and t2.code = coalesce(cs.setting('guest.topic') #>> '{}', 'account');
  if v_topic is null then
    select t2.code into v_topic from cs.support_topics t2 where t2.active order by t2.sort_order, t2.code limit 1;
  end if;
  if v_topic is null then
    perform private.api_error(403, 'guest_disabled', 'Pengaduan tanpa login sedang tidak tersedia');
  end if;

  insert into public.profiles (id, olt_user_id, username, display_name, is_guest)
  values (v_profile, 'guest:' || v_profile, 'tamu_' || left(replace(v_profile::text, '-', ''), 12), v_name, true);

  v_token := rtrim(translate(encode(extensions.gen_random_bytes(32), 'base64'), '+/', '-_'), '=');
  perform cs.guest_act_as(v_profile);
  t := cs.open_ticket(v_profile, v_topic, p_language, array[]::text[],
                      jsonb_build_object('screen', 'guest',
                        'guest', jsonb_strip_nulls(jsonb_build_object('login_id', v_login, 'problem', p_problem, 'verified', false))),
                      null);
  perform cs_api.send_message(t.room_id, v_text, gen_random_uuid(), null, '[]');
  insert into cs.guest_sessions (token_hash, profile_id, ticket_id, login_id, problem, ip_hash, expires_at)
  values (encode(extensions.digest(v_token, 'sha256'), 'hex'), v_profile, t.id, v_login, p_problem, v_ip,
          now() + make_interval(hours => v_hours));
  perform cs.audit('guest.start', t.id, v_profile, jsonb_strip_nulls(jsonb_build_object('login_id', v_login, 'problem', p_problem)));
  select * into t from cs.tickets x where x.id = t.id;
  return jsonb_build_object('token', v_token, 'expires_at', now() + make_interval(hours => v_hours),
                            'ticket', cs.ticket_customer_view(t));
end;
$$;

create or replace function cs_api.guest_poll(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  g cs.guest_sessions := cs.guest_session(p_token);
  t cs.tickets;
begin
  select * into t from cs.tickets x where x.id = g.ticket_id;
  if t.id is null then
    perform private.api_error(401, 'guest_session_expired', 'Sesi pengaduan sudah berakhir. Silakan buat pengaduan baru.');
  end if;
  perform cs.guest_act_as(g.profile_id);
  return jsonb_build_object(
    'expires_at', g.expires_at,
    'ticket', cs.ticket_customer_view(t),
    'messages', coalesce((select jsonb_agg(to_jsonb(m) order by m.created_at, m.id) from cs_api.ticket_messages(t.id) m), '[]'));
end;
$$;

create or replace function cs_api.guest_send(p_token text, p_body text, p_client_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  g      cs.guest_sessions := cs.guest_session(p_token);
  t      cs.tickets;
  v_body text := btrim(coalesce(p_body, ''));
begin
  select * into t from cs.tickets x where x.id = g.ticket_id;
  if t.id is null or t.status not in ('open', 'claimed', 'waiting_customer') then
    perform private.api_error(409, 'ticket_not_active', 'Pengaduan ini sudah selesai. Buat pengaduan baru bila masih perlu bantuan.');
  end if;
  if char_length(v_body) not between 1 and 2000 then
    perform private.api_error(400, 'invalid_body', 'Pesan 1–2.000 karakter');
  end if;
  perform private.consume_rate_limit(g.profile_id, 'guest_message');
  perform cs.guest_act_as(g.profile_id);
  return (select to_jsonb(m) from cs_api.send_message(t.room_id, v_body, coalesce(p_client_id, gen_random_uuid()), null, '[]') m limit 1);
end;
$$;

create or replace function cs_api.guest_end(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  g cs.guest_sessions := cs.guest_session(p_token);
begin
  update cs.guest_sessions set ended_at = now() where id = g.id;
end;
$$;

CREATE OR REPLACE FUNCTION cs.ticket_agent_view(t cs.tickets)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'id', t.id,
    'ticket_number', t.ticket_number,
    'room_id', t.room_id,
    'status', t.status,
    'version', t.version,
    'topic', t.topic,
    'priority', t.priority,
    'flags', to_jsonb(t.flags),
    'language', t.language,
    'customer', (select jsonb_build_object('id', p.id, 'display_name', p.display_name, 'username', p.username,
                                           'deleted', p.deleted_at is not null)
                 from public.profiles p where p.id = t.customer_id),
    'owner', case when t.owner_agent_id is not null then (
      select jsonb_build_object('id', a.user_id, 'display_name', a.display_name, 'agent_code', a.agent_code,
                                'status', st.status)
      from cs.agents a join cs.agent_status st on st.agent_id = a.user_id where a.user_id = t.owner_agent_id) end,
    'is_mine', t.owner_agent_id = auth.uid(),
    'context', t.context,
    'intake', coalesce(t.context -> 'intake', '[]'),
    'topic_sop', (select tp.sop from cs.support_topics tp where tp.code = t.topic),
    'guest', case when t.context ? 'guest' then (t.context -> 'guest') || jsonb_build_object(
      'recent_24h', (select count(*) from cs.guest_sessions g
                     where g.login_id = t.context -> 'guest' ->> 'login_id'
                       and g.created_at > now() - interval '24 hours')) end,
    'queued_at', t.queued_at,
    'created_at', t.created_at,
    'claimed_at', t.claimed_at,
    'first_response_at', t.first_response_at,
    'last_customer_message_at', t.last_customer_message_at,
    'last_agent_message_at', t.last_agent_message_at,
    'resolved_at', t.resolved_at,
    'closed_at', t.closed_at,
    'outcome', t.outcome,
    'resolution_summary', t.resolution_summary,
    'returned_reason', t.returned_reason,
    'complaint_received_at', t.complaint_received_at,
    'complaint_due_at', t.complaint_due_at,
    'rating', t.rating,
    'rating_comment', t.rating_comment,
    'labels', cs.ticket_label_list(t.id),
    'transfer', (select jsonb_build_object('id', x.id, 'from_id', x.from_agent_id, 'from_name', cs.agent_name(x.from_agent_id),
                                           'to_id', x.to_agent_id, 'to_name', cs.agent_name(x.to_agent_id),
                                           'note', x.note, 'expires_at', x.expires_at)
                 from cs.ticket_transfers x where x.ticket_id = t.id and x.result is null)
  );
$function$;

CREATE OR REPLACE FUNCTION cs_api.ticket_customer_login(p_ticket_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  t cs.tickets;
begin
  perform cs.require_agent();
  select * into t from cs.tickets where id = p_ticket_id;
  if not found or not cs.can_read_ticket(t.room_id, t.id, t.status, t.flags) then
    perform private.api_error(404, 'ticket_not_found', 'Tiket tidak ditemukan');
  end if;
  if t.context ? 'guest' then
    return jsonb_build_object('login_id', t.context -> 'guest' ->> 'login_id', 'source', 'guest');
  end if;
  return (
    select jsonb_build_object('login_id', coalesce(up.olt_username, p.username::text),
                              'source', case when up.olt_username is null then 'profile' else 'olt' end)
    from public.profiles p
    left join private.user_private up on up.user_id = p.id
    where p.id = t.customer_id);
end;
$function$;

revoke execute on function cs.guest_ip_hash() from public;
revoke execute on function cs.guest_act_as(uuid) from public;
revoke execute on function cs.guest_session(text) from public;
revoke execute on function cs_api.guest_config(text) from public;
revoke execute on function cs_api.guest_start(text, text, text, text, text) from public;
revoke execute on function cs_api.guest_poll(text) from public;
revoke execute on function cs_api.guest_send(text, text, uuid) from public;
revoke execute on function cs_api.guest_end(text) from public;
grant execute on function cs_api.guest_config(text) to anon, authenticated;
grant execute on function cs_api.guest_start(text, text, text, text, text) to anon, authenticated;
grant execute on function cs_api.guest_poll(text) to anon, authenticated;
grant execute on function cs_api.guest_send(text, text, uuid) to anon, authenticated;
grant execute on function cs_api.guest_end(text) to anon, authenticated;
