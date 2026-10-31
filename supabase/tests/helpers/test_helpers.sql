-- Helper untuk tes pgTAP. Dimuat oleh scripts/test-db.sh sebelum pg_prove dan
-- dihapus setelahnya (schema `tests` tidak pernah ada di produksi).
--
-- Pola di file tes:
--   select tests.create_user('alice') as alice \gset
--   select tests.authenticate_as(:'alice');   -- role authenticated + JWT sub
--   ...
--   reset role;                                -- kembali ke postgres

create schema if not exists tests;
grant usage on schema tests to anon, authenticated;

create or replace function tests.create_user(p_username text)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into public.profiles (id, olt_user_id, username, display_name)
  values (v_id, 'test:' || v_id, p_username, initcap(replace(p_username, '_', ' ')));
  return v_id;
end;
$$;

create or replace function tests.authenticate_as(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user_id, 'role', 'authenticated', 'aud', 'authenticated')::text, true);
end;
$$;

-- Harus dipanggil saat role masih postgres (jalankan `reset role;` dulu).
create or replace function tests.authenticate_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end;
$$;

-- Seperti authenticate_as, dengan klaim JWT tambahan (mis. {"aal":"aal2"} atau {"iat": ...}).
create or replace function tests.authenticate_with(p_user_id uuid, p_extra jsonb)
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user_id, 'role', 'authenticated', 'aud', 'authenticated') || p_extra)::text, true);
end;
$$;

-- Admin uji: akun GoTrue terpisah (bukan profil sosial) dengan peran tertentu.
-- Harus dipanggil saat role masih postgres. Login: tests.authenticate_admin(id).
create or replace function tests.create_admin(p_role text)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into private.admin_users (user_id, role, display_name) values (v_id, p_role, p_role);
  return v_id;
end;
$$;

create or replace function tests.authenticate_admin(p_admin_id uuid, p_aal text default 'aal2')
returns void
language plpgsql
as $$
begin
  perform tests.authenticate_with(p_admin_id, jsonb_build_object('aal', p_aal));
end;
$$;

create or replace function tests.create_agent(
  p_name   text,
  p_roles  text[] default '{cs_agent}',
  p_skills jsonb default '{"general": 1}',
  p_team   text default 'general',
  p_max    integer default 3
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  perform cs.create_agent(v_id, p_name, p_roles, p_team, p_skills, '{id,en}', p_max);
  return v_id;
end;
$$;

create or replace function tests.authenticate_agent(p_agent_id uuid, p_aal text default 'aal2')
returns void
language plpgsql
as $$
begin
  perform tests.authenticate_with(p_agent_id, jsonb_build_object('aal', p_aal));
end;
$$;

create or replace function tests.agent_online(p_agent_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update cs.agent_status set status = 'online', last_heartbeat_at = now() where agent_id = p_agent_id;
$$;

create or replace function tests.error_detail(p_sql text)
returns text
language plpgsql
as $$
declare
  v_detail text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_detail = pg_exception_detail;
  return v_detail;
end;
$$;

create or replace function tests.authenticate_service()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'service_role', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
end;
$$;

grant execute on all functions in schema tests to anon, authenticated;
grant usage on schema tests to service_role;
grant execute on all functions in schema tests to service_role;
