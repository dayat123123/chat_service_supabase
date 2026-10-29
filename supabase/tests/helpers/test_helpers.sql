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

create or replace function tests.create_stock(p_code text, p_name text default null)
returns text
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  insert into public.stocks (code, name) values (p_code, coalesce(p_name, p_code || ' Tbk'))
  on conflict (code) do nothing;
  return p_code;
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

grant execute on all functions in schema tests to anon, authenticated;
