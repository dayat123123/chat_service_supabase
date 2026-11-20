insert into cs.cs_settings (key, value, description) values
  ('security.mfa_required_roles', '["cs_super_admin"]',
   'Peran staf yang wajib memasukkan kode 2FA (TOTP) saat masuk Hub; Super Admin selalu wajib'),
  ('security.login_max_failures', '5',
   'Jumlah password salah berturut-turut sebelum akun staf dikunci sementara'),
  ('security.login_lock_minutes', '15',
   'Lama akun staf dikunci setelah terlalu banyak password salah, sekaligus jendela hitungan gagal (menit)')
on conflict (key) do nothing;

create or replace function cs.admin_editable(p_key text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_key in ('assignment.mode', 'ticket.auto_release_offline_minutes', 'ticket.auto_close_days', 'service.hours',
                   'alerts.unclaimed_minutes', 'alerts.p1_unclaimed_minutes', 'community.four_eyes',
                   'accounts.max_per_customer', 'ticket.reminder_hours', 'guest.enabled',
                   'notifications.watchlist_digest_time', 'banners.notice_four_eyes',
                   'security.mfa_required_roles', 'security.login_max_failures', 'security.login_lock_minutes')
      or p_key like 'messages.%';
$$;

create or replace function cs.check_security_setting(p_key text, p_value jsonb)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_key = 'security.mfa_required_roles' then
    if jsonb_typeof(p_value) <> 'array' then
      perform private.api_error(400, 'invalid_setting', 'Peran wajib 2FA harus berupa daftar');
    end if;
    if exists (select 1 from jsonb_array_elements(p_value) e
               where jsonb_typeof(e) <> 'string'
                  or e #>> '{}' not in ('cs_agent', 'cs_super_admin', 'compliance', 'community', 'product', 'cs_content'))
       or jsonb_array_length(p_value) <> (select count(distinct e) from jsonb_array_elements_text(p_value) e)
       or not p_value ? 'cs_super_admin' then
      perform private.api_error(400, 'invalid_setting', 'Peran wajib 2FA harus berisi Super Admin dan peran staf yang dikenal');
    end if;
  elsif p_key = 'security.login_max_failures' then
    if jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
       or (p_value #>> '{}')::integer not between 3 and 20 then
      perform private.api_error(400, 'invalid_setting', 'Batas password salah 3–20 kali');
    end if;
  elsif p_key = 'security.login_lock_minutes' then
    if jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}') !~ '^[0-9]+$'
       or (p_value #>> '{}')::integer not between 1 and 1440 then
      perform private.api_error(400, 'invalid_setting', 'Lama kunci 1–1440 menit');
    end if;
  end if;
end;
$$;

create or replace function cs_api.admin_set_setting(p_key text, p_value jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me  uuid := cs.require_agent('{cs_super_admin}');
  v_old jsonb := (select s.value from cs.cs_settings s where s.key = p_key);
begin
  if v_old is null or not cs.admin_editable(p_key) then
    perform private.api_error(403, 'setting_locked', 'Pengaturan ini tidak bisa diubah dari console');
  end if;
  if p_key like 'nasabah.%' then
    perform cs.check_integration_setting(p_key, p_value);
  elsif p_key like 'security.%' then
    perform cs.check_security_setting(p_key, p_value);
  else
    perform cs.check_setting_value(p_key, p_value, v_old);
  end if;
  perform cs.set_setting(p_key, p_value, v_me);
  perform cs.audit('setting.update', null, null, jsonb_build_object('key', p_key));
  return (select jsonb_build_object('key', s.key, 'value', s.value, 'version', s.version, 'updated_at', s.updated_at)
          from cs.cs_settings s where s.key = p_key);
end;
$$;

create table private.staff_login_guard (
  user_id           uuid primary key references auth.users (id) on delete cascade,
  failures          integer not null default 0 check (failures >= 0),
  window_started_at timestamptz,
  locked_until      timestamptz,
  updated_at        timestamptz not null default now()
);
alter table private.staff_login_guard enable row level security;

create or replace function cs.mfa_required_roles()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select array_agg(r) from jsonb_array_elements_text(cs.setting('security.mfa_required_roles')) r),
                  '{cs_super_admin}');
$$;

create or replace function cs.agent_has_mfa(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from auth.mfa_factors f where f.user_id = p_user and f.status = 'verified');
$$;

create or replace function cs.agent_needs_mfa(p_user uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_roles && cs.mfa_required_roles() or cs.agent_has_mfa(p_user);
$$;

create or replace function cs.current_agent_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select a.user_id
  from cs.agents a
  where a.user_id = auth.uid()
    and a.disabled_at is null
    and coalesce(auth.role(), '') = 'authenticated'
    and cs.session_alive()
    and (coalesce(auth.jwt() ->> 'aal', '') = 'aal2' or not cs.agent_needs_mfa(a.user_id, a.roles));
$$;

create or replace function cs.mfa_pending()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from cs.agents a
    where a.user_id = auth.uid()
      and a.disabled_at is null
      and coalesce(auth.role(), '') = 'authenticated'
      and cs.session_alive()
      and coalesce(auth.jwt() ->> 'aal', '') <> 'aal2'
      and cs.agent_needs_mfa(a.user_id, a.roles));
$$;

create or replace function cs.require_agent(p_roles text[] default null)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_id uuid := cs.current_agent_id();
begin
  if v_id is null then
    if cs.session_revoked() then
      perform private.api_error(401, 'session_revoked', 'Sesi ini sudah dikeluarkan, silakan masuk lagi');
    end if;
    if cs.mfa_pending() then
      perform private.api_error(401, 'mfa_required', 'Masukkan kode 2FA untuk melanjutkan');
    end if;
    perform private.api_error(403, 'agent_required', 'Butuh akun CS aktif');
  end if;
  if p_roles is not null and not cs.has_role(p_roles) then
    perform private.api_error(403, 'role_forbidden', 'Peran Anda tidak cukup untuk aksi ini');
  end if;
  return v_id;
end;
$$;

create or replace function cs_api.agent_security_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_agent cs.agents;
begin
  if cs.session_revoked() then
    perform private.api_error(401, 'session_revoked', 'Sesi ini sudah dikeluarkan, silakan masuk lagi');
  end if;
  select * into v_agent from cs.agents a
  where a.user_id = auth.uid() and a.disabled_at is null and coalesce(auth.role(), '') = 'authenticated';
  if not found then
    perform private.api_error(403, 'agent_required', 'Butuh akun CS aktif');
  end if;
  return jsonb_build_object(
    'mfa_required', v_agent.roles && cs.mfa_required_roles(),
    'mfa_enrolled', cs.agent_has_mfa(v_agent.user_id),
    'aal', coalesce(nullif(auth.jwt() ->> 'aal', ''), 'aal1'));
end;
$$;

create or replace function private.login_locked_reply(p_until timestamptz)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'decision', 'reject',
    'message', 'account_locked:' || to_char(p_until at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'should_logout_user', false);
$$;

create or replace function private.hook_password_verification_attempt(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user   uuid := (event ->> 'user_id')::uuid;
  v_max    integer := greatest(coalesce(cs.setting_int('security.login_max_failures'), 5), 1);
  v_window interval := make_interval(mins => greatest(coalesce(cs.setting_int('security.login_lock_minutes'), 15), 1));
  v_guard  private.staff_login_guard;
begin
  select * into v_guard from private.staff_login_guard g where g.user_id = v_user for update;
  if v_guard.locked_until > now() then
    return private.login_locked_reply(v_guard.locked_until);
  end if;
  if coalesce((event ->> 'valid')::boolean, false) then
    delete from private.staff_login_guard g where g.user_id = v_user;
    return jsonb_build_object('decision', 'continue');
  end if;

  insert into private.staff_login_guard as g (user_id, failures, window_started_at, updated_at)
  values (v_user, 1, now(), now())
  on conflict (user_id) do update
    set failures = case when g.window_started_at is null or g.window_started_at <= now() - v_window then 1
                        else g.failures + 1 end,
        window_started_at = case when g.window_started_at is null or g.window_started_at <= now() - v_window then now()
                                 else g.window_started_at end,
        locked_until = null,
        updated_at = now()
  returning * into v_guard;
  if v_guard.failures < v_max then
    return jsonb_build_object('decision', 'continue');
  end if;

  update private.staff_login_guard g
     set failures = 0, window_started_at = null, locked_until = now() + v_window, updated_at = now()
   where g.user_id = v_user
  returning * into v_guard;
  perform cs.audit('security.login_locked', null, null, jsonb_build_object(
    'user_id', v_user,
    'email', (select u.email from auth.users u where u.id = v_user),
    'failures', v_max,
    'locked_until', v_guard.locked_until));
  return private.login_locked_reply(v_guard.locked_until);
end;
$$;

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
    'totp', cs.agent_has_mfa(a.user_id),
    'mfa_required', a.roles && cs.mfa_required_roles(),
    'locked_until', (select g.locked_until from private.staff_login_guard g
                     where g.user_id = a.user_id and g.locked_until > now()),
    'nasabah_permissions', to_jsonb(a.nasabah_permissions),
    'community_permissions', to_jsonb(a.community_permissions),
    'trade_permissions', to_jsonb(a.trade_permissions),
    'created_at', a.created_at)
  from cs.agents a
  left join cs.agent_status st on st.agent_id = a.user_id
  left join cs.teams tm on tm.id = a.team_id
  left join auth.users u on u.id = a.user_id
  where a.user_id = p_agent;
$$;

create or replace function cs_api.admin_unlock_agent(p_agent_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := cs.require_agent('{cs_super_admin}');
begin
  if not exists (select 1 from cs.agents a where a.user_id = p_agent_id) then
    perform private.api_error(404, 'agent_not_found', 'Akun CS tidak ditemukan');
  end if;
  delete from private.staff_login_guard g where g.user_id = p_agent_id;
  perform cs.audit('security.login_unlocked', null, null, jsonb_build_object('agent', p_agent_id));
  return cs.agent_admin_view(p_agent_id);
end;
$$;

create or replace function cs_api.admin_reset_agent_mfa(p_agent_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := cs.require_agent('{cs_super_admin}');
  v_factors  integer;
  v_sessions integer;
begin
  if p_agent_id = v_me then
    perform private.api_error(400, 'cannot_reset_self', 'Reset 2FA milik sendiri harus dilakukan Super Admin lain');
  end if;
  if not exists (select 1 from cs.agents a where a.user_id = p_agent_id) then
    perform private.api_error(404, 'agent_not_found', 'Akun CS tidak ditemukan');
  end if;
  delete from auth.mfa_factors f where f.user_id = p_agent_id;
  get diagnostics v_factors = row_count;
  delete from auth.sessions s where s.user_id = p_agent_id;
  get diagnostics v_sessions = row_count;
  perform cs.audit('security.mfa_reset', null, null,
                   jsonb_build_object('agent', p_agent_id, 'factors', v_factors, 'sessions', v_sessions));
  return cs.agent_admin_view(p_agent_id);
end;
$$;

drop function cs_api.nasabah_access(uuid);

create or replace function cs_api.nasabah_access(p_user_id uuid, p_aal text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('agent_id', a.user_id, 'agent_code', a.agent_code, 'display_name', a.display_name,
                            'permissions', to_jsonb(a.nasabah_permissions))
  from cs.agents a
  where a.user_id = p_user_id and a.disabled_at is null and 'cs_agent' = any (a.roles)
    and cardinality(a.nasabah_permissions) > 0
    and (coalesce(p_aal, '') = 'aal2' or not cs.agent_needs_mfa(a.user_id, a.roles));
$$;

create or replace function cs_api.nasabah_is_super_admin(p_user_id uuid, p_aal text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from cs.agents a
                 where a.user_id = p_user_id
                   and a.disabled_at is null
                   and 'cs_super_admin' = any (a.roles)
                   and (coalesce(p_aal, '') = 'aal2' or not cs.agent_needs_mfa(a.user_id, a.roles)));
$$;

create or replace function private.staff_security_recover(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id       uuid;
  v_factors  integer;
  v_sessions integer;
begin
  select a.user_id into v_id
  from cs.agents a
  join auth.users u on u.id = a.user_id
  where lower(u.email) = lower(btrim(p_email));
  if v_id is null then
    raise exception 'No staff account uses the email %', p_email;
  end if;
  delete from auth.mfa_factors f where f.user_id = v_id;
  get diagnostics v_factors = row_count;
  delete from auth.sessions s where s.user_id = v_id;
  get diagnostics v_sessions = row_count;
  delete from private.staff_login_guard g where g.user_id = v_id;
  perform cs.audit('security.mfa_recovered', null, null,
                   jsonb_build_object('agent', v_id, 'factors', v_factors, 'sessions', v_sessions));
  return jsonb_build_object('agent_id', v_id, 'factors_removed', v_factors, 'sessions_removed', v_sessions);
end;
$$;

revoke execute on function cs.check_security_setting(text, jsonb) from public;
revoke execute on function cs.mfa_required_roles() from public;
revoke execute on function cs.agent_has_mfa(uuid) from public;
revoke execute on function cs.agent_needs_mfa(uuid, text[]) from public;
revoke execute on function cs.mfa_pending() from public;
revoke execute on function cs_api.agent_security_status() from public;
revoke execute on function private.login_locked_reply(timestamptz) from public;
revoke execute on function private.hook_password_verification_attempt(jsonb) from public;
revoke execute on function cs_api.admin_unlock_agent(uuid) from public;
revoke execute on function cs_api.admin_reset_agent_mfa(uuid) from public;
revoke execute on function cs_api.nasabah_access(uuid, text) from public;
revoke execute on function cs_api.nasabah_is_super_admin(uuid, text) from public;
revoke execute on function private.staff_security_recover(text) from public;

grant usage on schema private to supabase_auth_admin;
grant execute on function private.hook_password_verification_attempt(jsonb) to supabase_auth_admin;
grant execute on function cs.mfa_pending() to authenticated;
grant execute on function cs_api.agent_security_status() to authenticated;
grant execute on function cs_api.admin_unlock_agent(uuid) to authenticated;
grant execute on function cs_api.admin_reset_agent_mfa(uuid) to authenticated;
grant execute on function cs_api.nasabah_access(uuid, text) to service_role;
grant execute on function cs_api.nasabah_is_super_admin(uuid, text) to service_role;
