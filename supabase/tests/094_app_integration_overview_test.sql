begin;
select plan(31);

delete from private.service_instances where service = 'auth-bridge';
update private.user_private set last_login_at = null;

select tests.create_agent('Hana', '{cs_super_admin}', '{}') as hana \gset
select tests.create_agent('Rudi', '{cs_agent}', '{"general": 1}') as rudi \gset
select tests.create_user('ai_budi') as budi \gset
select tests.create_user('ai_sari') as sari \gset

create function pg_temp.beat(p_instance text, p_detail jsonb, p_status text default 'ok') returns void language plpgsql as $$
begin
  perform tests.authenticate_service();
  perform public.service_heartbeat('auth-bridge', p_instance, '0.6.0', now() - interval '1 hour', p_status, null, p_detail);
  reset role;
end;
$$;

create function pg_temp.jwt(p_env text, p_kids text[]) returns jsonb language sql as $$
  select jsonb_build_object('app_env', p_env, 'olt_mode', 'jwt', 'issuer', 'olt', 'audience', 'olt-social',
                            'max_ttl_seconds', 900, 'key_count', cardinality(p_kids),
                            'keys', (select coalesce(jsonb_agg(jsonb_build_object('kid', k, 'alg', 'EdDSA')), '[]')
                                     from unnest(p_kids) k));
$$;

create function pg_temp.overview() returns jsonb language plpgsql as $$
declare
  v jsonb;
begin
  perform tests.authenticate_agent(current_setting('t.hana')::uuid);
  v := cs_api.app_integration_overview();
  reset role;
  return v;
end;
$$;

select set_config('t.hana', :'hana', false);

select has_function('cs_api', 'app_integration_overview', array[]::text[], 'RPC ringkasan integrasi aplikasi ada');
select ok(not has_function_privilege('anon', 'cs_api.app_integration_overview()', 'EXECUTE'),
  'anon tidak bisa membaca integrasi aplikasi');
select ok(not has_function_privilege('authenticated', 'private.app_integration_bridge(jsonb)', 'EXECUTE'),
  'Fungsi bantu private tidak bisa dipanggil langsung');
select ok(not has_function_privilege('authenticated', 'public.service_heartbeat(text,text,text,timestamptz,text,text,jsonb)', 'EXECUTE'),
  'Heartbeat hanya untuk service_role');

select tests.authenticate_as(:'budi');
select throws_ok('select cs_api.app_integration_overview()', 'PT403', null, 'Nasabah tidak bisa membuka integrasi aplikasi');
reset role;
select tests.authenticate_agent(:'rudi');
select throws_ok('select cs_api.app_integration_overview()', 'PT403', null, 'Agen CS biasa tidak bisa membuka integrasi aplikasi');
reset role;

select is(pg_temp.overview() ->> 'status', 'no_heartbeat', 'Tanpa heartbeat auth-bridge statusnya tidak ada heartbeat');
select is(pg_temp.overview() -> 'instances', '[]'::jsonb, 'Tanpa heartbeat tidak ada instance');
select is(pg_temp.overview() -> 'warnings', '[]'::jsonb, 'Tanpa heartbeat tidak ada peringatan kunci');
select is(pg_temp.overview() ->> 'last_seen_at', null, 'Belum pernah ada heartbeat');

select pg_temp.beat('bridge-a', pg_temp.jwt('development', '{dev-olt-1}'));
select is(pg_temp.overview() ->> 'status', 'warning', 'Kunci dev memicu peringatan');
select is(pg_temp.overview() -> 'warnings', '["dev_key"]'::jsonb, 'Peringatannya kunci dev');
select is((pg_temp.overview() #> '{instances,0}') - 'started_at' - 'last_seen_at',
  '{"instance": "bridge-a", "version": "0.6.0", "status": "ok", "error": null, "app_env": "development",
    "olt_mode": "jwt", "issuer": "olt", "audience": "olt-social", "max_ttl_seconds": 900, "key_count": 1,
    "keys": [{"kid": "dev-olt-1", "alg": "EdDSA"}]}'::jsonb,
  'Instance aktif memuat mode, kid, issuer, audience, max TTL, dan versi');

delete from private.service_instances where service = 'auth-bridge';
select pg_temp.beat('bridge-a', pg_temp.jwt('production', '{olt-2026-11,olt-2026-05}'));
select is(pg_temp.overview() ->> 'status', 'active', 'Kunci OLT asli tanpa peringatan');
select is(pg_temp.overview() #> '{instances,0,keys}',
  '[{"kid": "olt-2026-05", "alg": "EdDSA"}, {"kid": "olt-2026-11", "alg": "EdDSA"}]'::jsonb, 'Kid diurutkan');

select pg_temp.beat('bridge-b', pg_temp.jwt('production', '{olt-2026-11}'));
select is(pg_temp.overview() -> 'warnings', '["mismatch"]'::jsonb, 'Instance dengan kunci berbeda memicu peringatan');
select is(jsonb_array_length(pg_temp.overview() -> 'instances'), 2, 'Semua instance aktif ditampilkan');

update private.service_instances set last_seen_at = now() - interval '4 minutes'
 where service = 'auth-bridge' and instance = 'bridge-b';
select is(pg_temp.overview() ->> 'status', 'active', 'Instance tanpa heartbeat > 3 menit tidak dihitung');
select is(jsonb_array_length(pg_temp.overview() -> 'instances'), 1, 'Hanya instance aktif yang ditampilkan');

delete from private.service_instances where service = 'auth-bridge';
select pg_temp.beat('bridge-a', '{"app_env": "development", "olt_mode": "mock", "key_count": 0, "keys": []}');
select is(pg_temp.overview() ->> 'status', 'active', 'Mode mock di development bukan peringatan');
select pg_temp.beat('bridge-a', '{"app_env": "staging", "olt_mode": "mock", "key_count": 0, "keys": []}');
select is(pg_temp.overview() -> 'warnings', '["not_jwt"]'::jsonb, 'Mode selain jwt di luar development memicu peringatan');

select pg_temp.beat('bridge-a', '{"olt_mode": "jwt", "keys": [{"kid": 7}, "x", {"kid": "olt-1", "alg": "ES256", "x": "AAAA"}], "max_ttl_seconds": "900"}');
select is(pg_temp.overview() #> '{instances,0,keys}', '[{"kid": "olt-1", "alg": "ES256"}]'::jsonb,
  'Detail kunci tidak sah diabaikan dan isi kunci tidak pernah ikut');
select is(pg_temp.overview() #>> '{instances,0,max_ttl_seconds}', null, 'Max TTL bukan angka diabaikan');

update private.service_instances set last_seen_at = now() - interval '10 minutes' where service = 'auth-bridge';
select is(pg_temp.overview() ->> 'status', 'no_heartbeat', 'Heartbeat lama berarti tidak ada heartbeat');
select ok((pg_temp.overview() ->> 'last_seen_at')::timestamptz < now() - interval '9 minutes',
  'Waktu heartbeat terakhir tetap ditampilkan');

select is(pg_temp.overview() -> 'logins', '{"last_login_at": null, "users_24h": 0}'::jsonb, 'Belum ada login nasabah');
insert into private.user_private (user_id, last_login_at) values (:'sari', now() - interval '2 days');
select tests.authenticate_service();
select public.upsert_olt_profile(gen_random_uuid(), 'ai-1001', 'ai_baru');
reset role;
select ok((select max(last_login_at) > now() - interval '1 minute' from private.user_private),
  'Exchange auth-bridge (upsert_olt_profile) memperbarui last_login_at');
select is((pg_temp.overview() #>> '{logins,users_24h}')::int, 1, 'Hanya nasabah yang login 24 jam terakhir dihitung');
select ok((pg_temp.overview() #>> '{logins,last_login_at}')::timestamptz > now() - interval '1 minute',
  'Login terakhir nasabah ditampilkan');
select ok(pg_temp.overview()::text !~ 'ai_baru|ai_sari|ai-1001|user_id|username',
  'Tidak ada data pribadi nasabah');
select is((select array_agg(k order by k) from jsonb_object_keys(pg_temp.overview() -> 'logins') k),
  '{last_login_at,users_24h}'::text[], 'Login hanya berisi agregat');

select * from finish();
rollback;
