begin;
select plan(16);

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Maya', '{community}', '{}') as maya \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 1}') as rina \gset
update cs.agents set community_permissions = '{community.moderate}' where user_id = :'maya';
select tests.create_user('cg_budi') as budi \gset
select tests.create_user('cg_sari') as sari \gset
update public.profiles set trust_level = 2 where id in (:'budi', :'sari');
insert into public.follows (follower_id, following_id) values (:'budi', :'sari'), (:'sari', :'budi');

select tests.authenticate_as(:'budi');
select join_stock_room('CGXT') as stock_room \gset
select (send_message(:'stock_room', 'Diskusi CGXT hari ini', 'c6300000-0000-4000-8000-000000000001')).id as stock_msg \gset
select (create_post('Postingan uji konsol', null, '[]', 'c6300000-0000-4000-8000-000000000002')).id as post \gset
select get_or_create_direct_room(:'sari') as dm \gset
select (send_message(:'dm', 'Pesan pribadi ke Sari', 'c6300000-0000-4000-8000-000000000003')).id as dm_msg \gset
reset role;

select tests.authenticate_agent(:'maya');
select is((cs_api.community_room_messages('cgxt') -> 'items' -> 0 ->> 'id'), :'stock_msg',
  'Moderator melihat pesan terbaru room saham untuk dipilih sebagai sematan');
select is((cs_api.community_room_messages('CGXT') -> 'items' -> 0 #>> '{sender,username}'), 'cg_budi',
  'Pengirim pesan room ditampilkan');
select throws_ok($$select cs_api.community_room_messages('ZZZZ')$$, 'PT404', 'room_not_found', 'Room saham yang tidak ada ditolak');
select is((cs_api.community_content('post', :'post') ->> 'body'), 'Postingan uji konsol', 'Moderator membuka postingan dari ID');
select throws_ok(format($$select cs_api.community_content('message', %L)$$, :'dm_msg'), 'PT403', 'private_message_forbidden',
  'Pesan pribadi yang tidak dilaporkan tidak bisa dibuka moderator');
reset role;

insert into public.reports (reporter_id, target_type, target_id, reason) values (:'sari', 'message', :'dm_msg', 'spam');

select tests.authenticate_agent(:'maya');
select is((cs_api.community_content('message', :'dm_msg') ->> 'body'), 'Pesan pribadi ke Sari',
  'Pesan pribadi yang dilaporkan bisa dibuka moderator');
select is((cs_api.community_content_meta(jsonb_build_array(jsonb_build_object('type', 'post', 'id', :'post'))) -> 0 ->> 'deleted'),
  'false', 'Metadata konten untuk daftar moderasi');
select throws_ok($$select cs_api.community_content('poll', gen_random_uuid())$$, 'PT400', 'invalid_target_type',
  'Jenis konten yang tidak dikenal ditolak');
reset role;

select ok(exists (select 1 from cs.cs_audit_log where action = 'community.private_message_view'
                  and details ->> 'message' = :'dm_msg'), 'Akses pesan pribadi oleh moderator tercatat di audit');

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.community_room_messages('CGXT')$$, 'PT403', null, 'Agen CS tanpa izin komunitas ditolak');
select throws_ok($$select cs_api.integration_official_accounts()$$, 'PT403', null, 'Hanya Super Admin yang melihat daftar akun resmi untuk key');
reset role;

select tests.authenticate_agent(:'sinta');
select is(jsonb_typeof(cs_api.integration_official_accounts()), 'array', 'Super Admin melihat akun resmi tanpa izin komunitas');
select is(jsonb_typeof(cs_api.integration_stats_daily(30)), 'array', 'Statistik harian per key tersedia');
select cs_api.admin_set_feature_flag('cg_uji', true, 100, '{}', '{}', null, 'Deskripsi awal');
select cs_api.admin_set_feature_flag('cg_uji', true, 100, '{}', '{}', null, null);
reset role;
select is((select description from private.feature_flags where key = 'cg_uji'), 'Deskripsi awal',
  'Deskripsi tetap bila tidak diisi');
select tests.authenticate_agent(:'sinta');
select cs_api.admin_set_feature_flag('cg_uji', true, 100, '{}', '{}', null, '');
reset role;
select is((select description from private.feature_flags where key = 'cg_uji'), null,
  'Deskripsi bisa dikosongkan dengan teks kosong');

select ok(not has_function_privilege('anon', 'cs_api.community_content(text,uuid)', 'EXECUTE'),
  'Anonim tidak bisa membuka konten lewat RPC staf');

select * from finish();
rollback;
