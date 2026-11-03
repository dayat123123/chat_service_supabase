begin;
select plan(37);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
update private.rate_limits set max_count = 1000 where action in ('post', 'comment', 'message');

select tests.create_user('cc_ani') as ani \gset
select tests.create_user('cc_budi') as budi \gset
select tests.create_agent('Super CC', '{cs_super_admin}', '{}') as sa \gset
select tests.create_agent('Agen CC', '{cs_agent}', '{"general": 1}') as agen \gset
insert into public.posts (id, author_id, body) values ('00000000-0000-4000-8000-00000000f701', :'budi', 'Post budi');

select tests.authenticate_anon();
select public.get_client_config('android', '2.4.1') as anon_cfg \gset
select is(:'anon_cfg'::jsonb ->> 'social_enabled', 'true', 'Pengguna anonim bisa membaca konfigurasi klien');
select ok(:'anon_cfg'::jsonb ?& array['flags', 'min_version', 'update_required', 'config'],
  'Konfigurasi memuat flag, versi minimum, dan pengaturan');
select is(:'anon_cfg'::jsonb -> 'flags' ->> 'search', 'true', 'Flag fitur bawaan aktif');
select is(:'anon_cfg'::jsonb -> 'config' ->> 'edit_minutes', '15', 'Batas waktu edit dikirim ke klien');
select throws_ok($$select public.get_client_config('symbian')$$, 'PT400', 'invalid_platform', 'Platform tidak dikenal ditolak');
select throws_ok($$select public.get_client_config('ios', 'versi-baru')$$, 'PT400', 'invalid_version',
  'Format versi aplikasi divalidasi');
reset role;

select tests.authenticate_agent(:'agen');
select throws_ok($$select cs_api.admin_feature_flags()$$, 'PT403', 'role_forbidden', 'Feature flag khusus Super Admin');
select throws_ok($$select cs_api.admin_set_kill_switch(false, 'Gangguan besar pada server')$$, 'PT403', 'role_forbidden',
  'Kill switch khusus Super Admin');
reset role;

select tests.authenticate_agent(:'sa');
select is(cs_api.admin_set_min_version('android', '2.10.0') -> 'min_versions' -> 0 ->> 'min_version', '2.10.0',
  'Super Admin mengatur versi minimum per platform');
select throws_ok($$select cs_api.admin_set_min_version('android', '2.x')$$, 'PT400', 'invalid_version',
  'Versi minimum divalidasi');
reset role;

select tests.authenticate_as(:'ani');
select is(public.get_client_config('android', '2.9.9') ->> 'update_required', 'true',
  'Versi di bawah minimum wajib update (perbandingan angka, bukan teks)');
select is(public.get_client_config('android', '2.10.0+57') ->> 'update_required', 'false', 'Versi sama tidak wajib update');
select is(public.get_client_config('android', '10.0') ->> 'update_required', 'false', 'Versi lebih baru tidak wajib update');
select is(public.get_client_config('ios', '1.0.0') ->> 'update_required', 'false', 'Platform tanpa batas tidak wajib update');
reset role;

select tests.authenticate_agent(:'sa');
select throws_ok($$select cs_api.admin_set_feature_flag('social.enabled', false)$$, 'PT400', 'use_kill_switch',
  'Kill switch tidak bisa diubah lewat flag biasa');
select throws_ok($$select cs_api.admin_set_feature_flag('Beta Fitur', true)$$, 'PT400', 'invalid_flag_key',
  'Format kunci flag divalidasi');
select throws_ok($$select cs_api.admin_set_feature_flag('beta.x', true, 150)$$, 'PT400', 'invalid_percentage',
  'Persentase divalidasi');
select ok(cs_api.admin_set_feature_flag('beta.half', true, 50) -> 'flags' @> '[{"key": "beta.half", "percentage": 50}]',
  'Super Admin membuat flag bertahap');
select ok(cs_api.admin_set_feature_flag('beta.vip', true, 0, array[:'ani']::uuid[]) is not null, 'Flag khusus pengguna tertentu');
select ok(cs_api.admin_set_feature_flag('beta.ios', true, 100, '{}', array['ios'], '3.0.0', 'Hanya iOS 3.0+') is not null,
  'Flag per platform dan versi');
reset role;

select is((select count(*)::integer from cs.cs_audit_log where action = 'feature_flag.set' and details ->> 'key' like 'beta.%'), 3,
  'Perubahan flag tercatat di audit');
select is((select count(*)::integer from generate_series(1, 400) g
           where private.rollout_bucket('beta.half', gen_random_uuid()) < 50) between 140 and 260, true,
  'Rollout persentase membagi pengguna kira-kira sesuai persentase');
select is(private.rollout_bucket('beta.half', :'ani'), private.rollout_bucket('beta.half', :'ani'),
  'Rollout deterministik per pengguna');
select (private.rollout_bucket('beta.half', :'ani') < 50)::text as ani_half \gset

select tests.authenticate_as(:'ani');
select is(public.get_client_config() -> 'flags' ->> 'beta.half', :'ani_half', 'Flag bertahap memakai hash pengguna');
select is(public.get_client_config() -> 'flags' ->> 'beta.vip', 'true', 'Pengguna dalam daftar flag mendapat fitur');
select is(public.get_client_config('ios', '3.1.0') -> 'flags' ->> 'beta.ios', 'true', 'Flag aktif untuk platform dan versi yang cocok');
select is(public.get_client_config('android', '3.1.0') -> 'flags' ->> 'beta.ios', 'false', 'Flag mati di platform lain');
select is(public.get_client_config('ios', '2.9.0') -> 'flags' ->> 'beta.ios', 'false', 'Flag mati di versi lama');
reset role;
select tests.authenticate_as(:'budi');
select is(public.get_client_config() -> 'flags' ->> 'beta.vip', 'false', 'Pengguna lain tidak mendapat flag khusus');
select cs_api.open_ticket('account') ->> 'id' as ticket \gset
select get_or_create_direct_room(:'ani') as dm \gset
reset role;
select room_id as support_room from cs.tickets where id = :'ticket' \gset

select tests.authenticate_agent(:'sa');
select throws_ok($$select cs_api.admin_set_kill_switch(false, 'mati')$$, 'PT400', 'reason_required',
  'Kill switch wajib disertai alasan');
select is(cs_api.admin_set_kill_switch(false, 'Lonjakan spam terkoordinasi, matikan sementara') -> 'kill_switch' ->> 'social_enabled',
  'false', 'Super Admin mematikan fitur komunitas');
reset role;

select tests.authenticate_as(:'budi');
select is(public.get_client_config() ->> 'social_enabled', 'false', 'Klien diberi tahu fitur komunitas mati');
select throws_ok($$insert into public.posts (author_id, body) values (auth.uid(), 'Post saat mati')$$,
  'PT503', 'social_disabled', 'Post baru ditolak saat kill switch aktif');
select throws_ok($$select * from public.create_comment('00000000-0000-4000-8000-00000000f701', null, 'Komentar')$$,
  'PT503', 'social_disabled', 'Komentar baru ditolak saat kill switch aktif');
select throws_ok(format($$select public.send_message(%L, 'Halo')$$, :'dm'),
  'PT503', 'social_disabled', 'Chat non-CS ditolak saat kill switch aktif');
select lives_ok(format($$select public.send_message(%L, 'Tolong bantu akun saya')$$, :'support_room'),
  'Chat CS tetap berjalan saat kill switch aktif');
reset role;

select is((select details ->> 'reason' from cs.cs_audit_log where action = 'kill_switch.set' order by id desc limit 1),
  'Lonjakan spam terkoordinasi, matikan sementara', 'Kill switch tercatat di audit beserta alasannya');

select * from finish();
rollback;
