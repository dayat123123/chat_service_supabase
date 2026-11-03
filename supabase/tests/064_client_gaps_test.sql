begin;
select plan(13);

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_user('cl_budi') as budi \gset
select tests.create_user('cl_sari') as sari \gset
update public.profiles set trust_level = 2 where id in (:'budi', :'sari');

select tests.authenticate_anon();
select is((get_client_config('windows', '1.0.0') ? 'social_enabled'), true, 'Aplikasi Windows bisa membaca konfigurasi klien');
select throws_ok($$select get_client_config('symbian', '1.0.0')$$, 'PT400', 'invalid_platform', 'Platform yang tidak dikenal ditolak');
reset role;

select tests.authenticate_agent(:'sinta');
select lives_ok($$select cs_api.admin_set_min_version('windows', '1.3.0')$$, 'Super Admin mengatur versi minimum Windows');
select lives_ok($$select cs_api.admin_set_feature_flag('trending', true, 100, '{}', '{windows,macos}', null, null)$$,
  'Feature flag bisa ditargetkan ke desktop');
reset role;

select tests.authenticate_anon();
select is((get_client_config('windows', '1.2.0') ->> 'update_required')::boolean, true,
  'Versi Windows di bawah minimum diminta update');
reset role;

select tests.authenticate_as(:'budi');
select is((track_events('[{"event":"feed_open"}]'::jsonb, 'windows', '1.3.0') ->> 'accepted')::integer, 1,
  'Analitik menerima event dari Windows');
select get_or_create_direct_room(:'sari') as dm \gset
select send_message(:'dm', 'Halo Sari, salam kenal', 'c6400000-0000-4000-8000-000000000001');
select is(get_dm_request_state(:'dm') ->> 'role', 'sender', 'Pengirim tahu pesannya masih permintaan');
select is((get_dm_request_state(:'dm') ->> 'sent')::integer, 1, 'Jumlah pesan yang sudah terkirim ditampilkan');
select is((get_dm_request_state(:'dm') ->> 'max_messages')::integer, 3, 'Batas pesan permintaan ditampilkan');
reset role;

select tests.authenticate_as(:'sari');
select is(get_dm_request_state(:'dm') ->> 'role', 'recipient', 'Penerima melihat permintaan yang masuk');
select respond_message_request(:'dm', 'accept');
select is(get_dm_request_state(:'dm') ->> 'is_request', 'false', 'Setelah diterima, room menjadi chat biasa');
reset role;

select tests.authenticate_as(:'budi');
select (create_post('Postingan yang nanti disembunyikan', null, '[]', 'c6400000-0000-4000-8000-000000000002')).id as post \gset
reset role;
update public.posts set moderation_status = 'hidden', moderated_at = now() where id = :'post';

select tests.authenticate_as(:'budi');
select is((get_my_moderated_content() -> 0 ->> 'id'), :'post', 'Nasabah melihat kontennya yang disembunyikan moderator');
reset role;

select tests.authenticate_as(:'sari');
select is(jsonb_array_length(get_my_moderated_content()), 0, 'Konten orang lain tidak ikut tampil');
reset role;

select * from finish();
rollback;
