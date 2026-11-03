begin;
select plan(54);

update private.rate_limits set max_count = 1000 where action in ('message', 'stock_room_create', 'report', 'appeal');
update cs.agents set community_permissions = '{}';
select tests.create_agent('Dodi', '{community}', '{}') as dodi \gset
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Nadia', '{cs_agent}', '{"general": 1}') as nadia \gset
update cs.agents set community_permissions = '{community.moderate}' where user_id = :'dodi';
select tests.create_user('rm_mod') as moderator \gset
select tests.create_user('rm_mod2') as moderator2 \gset
select tests.create_user('rm_mod3') as moderator3 \gset
select tests.create_user('rm_low') as low \gset
select tests.create_user('rm_sanksi') as sanctioned \gset
select tests.create_user('rm_budi') as budi \gset
select tests.create_user('rm_resmi') as resmi \gset
update public.profiles set trust_level = 2 where id in (:'moderator', :'moderator2', :'moderator3', :'sanctioned', :'resmi');
update public.profiles set trust_level = 1 where id in (:'low', :'budi');
insert into cs.official_accounts (profile_id) values (:'resmi');
select private.apply_sanction(:'sanctioned', 'Spam berulang', null, 'warning', null, null) is not null as sanctioned_ok \gset

select tests.authenticate_as(:'budi');
select join_stock_room('RMXT') as room \gset
select (send_message(:'room', 'Pesan pertama Budi', 'c7300000-0000-4000-8000-000000000001')).id as msg1 \gset
select (send_message(:'room', 'Pesan kedua Budi', 'c7300000-0000-4000-8000-000000000002')).id as msg2 \gset
select (send_message(:'room', 'Pesan ketiga Budi', 'c7300000-0000-4000-8000-000000000003')).id as msg3 \gset
reset role;
select tests.authenticate_as(:'resmi');
select join_stock_room('RMXT') is not null as joined \gset
select (send_message(:'room', 'Pengumuman resmi', 'c7300000-0000-4000-8000-000000000004')).id as official_msg \gset
reset role;

select tests.authenticate_agent(:'dodi');
select is((select x ->> 'eligible' from jsonb_array_elements(cs_api.community_room_moderator_candidates('RMXT', 'rm_low')) x
           where x ->> 'id' = :'low'), 'false', 'Trust level rendah tidak memenuhi syarat');
select is((select x -> 'problems' ->> 0 from jsonb_array_elements(cs_api.community_room_moderator_candidates('RMXT', 'rm_low')) x
           where x ->> 'id' = :'low'), 'trust_level', 'Alasan tidak memenuhi syarat ditampilkan');
select throws_ok(format($$select cs_api.community_appoint_room_moderator('RMXT', %L, null)$$, :'low'),
  'PT400', 'not_eligible', 'Nasabah dengan trust level rendah tidak bisa ditunjuk');
select throws_ok(format($$select cs_api.community_appoint_room_moderator('RMXT', %L, null)$$, :'sanctioned'),
  'PT400', 'not_eligible', 'Nasabah dengan sanksi baru tidak bisa ditunjuk');
select is(tests.error_detail(format($$select cs_api.community_appoint_room_moderator('RMXT', %L, null)$$, :'resmi')),
  'protected_account', 'Akun resmi tidak bisa ditunjuk');
select is(jsonb_array_length(cs_api.community_appoint_room_moderator('RMXT', :'moderator', 'Aktif dan sopan') -> 'moderators'), 1,
  'Staf menunjuk moderator room');
select throws_ok(format($$select cs_api.community_appoint_room_moderator('RMXT', %L, null)$$, :'moderator'),
  'PT409', 'already_moderator', 'Moderator yang sama tidak ditunjuk dua kali');
select cs_api.community_appoint_room_moderator('RMXT', :'moderator2', null) is not null as appointed2 \gset
reset role;

select ok(exists (select 1 from cs.cs_audit_log where action = 'community.room_moderator_appoint' and customer_id = :'moderator'),
  'Penunjukan tercatat di audit');
select ok(exists (select 1 from public.chat_members where room_id = :'room' and user_id = :'moderator'),
  'Moderator otomatis menjadi anggota room');

select tests.authenticate_agent(:'nadia');
select throws_ok($$select cs_api.community_room_moderators('RMXT')$$, 'PT403', null, 'Agen tanpa izin komunitas ditolak');
reset role;

select tests.authenticate_as(:'budi');
select ok((get_stock_room_state('RMXT') -> 'moderators') ? :'moderator', 'Anggota room melihat daftar moderator untuk lencana');
select is((get_stock_room_state('RMXT') ->> 'is_moderator')::boolean, false, 'Anggota biasa bukan moderator');
select throws_ok(format($$select room_mod_hide_message(%L, 'spam')$$, :'msg1'), 'PT403', 'not_room_moderator',
  'Anggota biasa tidak bisa menyembunyikan pesan');
reset role;

select tests.authenticate_as(:'moderator2');
select (send_message(:'room', 'Pesan moderator dua', 'c7300000-0000-4000-8000-000000000005')).id as mod2_msg \gset
reset role;

select tests.authenticate_as(:'moderator');
select is((get_stock_room_state('RMXT') ->> 'is_moderator')::boolean, true, 'Moderator mengetahui perannya di room');
select (send_message(:'room', 'Pesan moderator', 'c7300000-0000-4000-8000-000000000006')).id as mod_msg \gset
select throws_ok(format($$select room_mod_hide_message(%L, 'jualan')$$, :'msg1'), 'PT400', 'invalid_mod_reason',
  'Alasan harus dari daftar');
select is(room_mod_hide_message(:'msg1', 'spam', 'Promosi grup') ->> 'action', 'hide', 'Moderator menyembunyikan pesan');
select throws_ok(format($$select room_mod_hide_message(%L, 'spam')$$, :'msg1'), 'PT409', 'already_moderated',
  'Pesan yang sudah disembunyikan tidak diproses lagi');
select throws_ok(format($$select room_mod_hide_message(%L, 'spam')$$, :'official_msg'), 'PT403', 'protected_account',
  'Pesan akun resmi tidak bisa disembunyikan moderator');
select throws_ok(format($$select room_mod_hide_message(%L, 'spam')$$, :'mod2_msg'), 'PT403', 'moderator_target',
  'Pesan moderator lain tidak bisa disembunyikan');
select throws_ok(format($$select room_mod_hide_message(%L, 'spam')$$, :'mod_msg'), 'PT403', 'self_target',
  'Moderator tidak memoderasi pesannya sendiri');
select throws_ok(format($$select room_mod_mute_user(%L, %L, 2000, 'abuse')$$, :'room', :'budi'), 'PT400', 'invalid_duration',
  'Lama bisu dibatasi maksimal 24 jam');
select throws_ok(format($$select room_mod_mute_user(%L, %L, 60, 'abuse')$$, :'room', :'resmi'), 'PT403', 'protected_account',
  'Akun resmi tidak bisa dibisukan moderator');
select is(room_mod_mute_user(:'room', :'budi', 60, 'abuse', null, :'msg2') ->> 'action', 'mute', 'Moderator membisukan anggota');
select throws_ok(format($$select room_mod_mute_user(%L, %L, 30, 'abuse')$$, :'room', :'budi'), 'PT409', 'already_muted',
  'Bisu yang lebih pendek dari bisu aktif ditolak');
select ok(room_mod_escalate(:'msg3', 'scam', 'Ajakan transfer dana') ? 'report_id', 'Moderator mengeskalasi pesan ke staf');
select throws_ok(format($$select room_mod_escalate(%L, 'scam')$$, :'msg3'), 'PT409', 'already_escalated',
  'Pesan yang sama tidak dieskalasi dua kali');
reset role;

select is((select moderation_status from public.messages where id = :'msg1'), 'hidden', 'Pesan tersembunyi');
select is((select actor_id from private.moderation_events where target_id = :'msg1' order by id desc limit 1), :'moderator'::uuid,
  'Pelaku moderasi tercatat sebagai moderator room');
select ok(exists (select 1 from public.reports where reporter_id = :'moderator' and target_id = :'msg3'
                  and status = 'open' and details like '[Moderator room $RMXT]%'), 'Eskalasi masuk antrean laporan staf');

select tests.authenticate_as(:'budi');
select isnt(get_stock_room_state('RMXT') ->> 'muted_until', null, 'Anggota yang dibisukan melihat batas waktu bisunya');
select throws_ok(format($$select send_message(%L, 'Coba kirim', 'c7300000-0000-4000-8000-000000000007')$$, :'room'),
  'PT403', 'room_muted', 'Anggota yang dibisukan tidak bisa mengirim pesan di room');
select ok(exists (select 1 from jsonb_array_elements(get_my_moderated_content()) x where x ->> 'id' = :'msg1'),
  'Pesan yang disembunyikan moderator muncul di konten termoderasi');
select is(create_appeal('message', :'msg1', 'Ini bukan promosi, hanya berbagi info') ->> 'status', 'pending',
  'Pengirim bisa mengajukan banding');
reset role;

update private.rate_limits set max_count = 1 where action = 'room_mod_action' and window_seconds = 3600;
select tests.authenticate_as(:'moderator');
select throws_like(format($$select room_mod_hide_message(%L, 'spam')$$, :'msg2'), '%"PT429"%"rate_limited"%',
  'Aksi moderator dibatasi rate limit');
reset role;

select tests.authenticate_agent(:'dodi');
select is(jsonb_array_length(cs_api.community_room_moderator_actions('RMXT') -> 'items'), 3, 'Staf melihat log aksi moderator');
select ok(jsonb_array_length(cs_api.community_room_moderator_actions(null) -> 'items') >= 3, 'Log semua room tersedia');
select is((select (x ->> 'can_undo')::boolean from jsonb_array_elements(cs_api.community_room_moderator_actions('RMXT') -> 'items') x
           where x ->> 'action' = 'hide'), true, 'Penyembunyian bisa dibatalkan staf');
select (select x ->> 'id' from jsonb_array_elements(cs_api.community_room_moderator_actions('RMXT') -> 'items') x
        where x ->> 'action' = 'hide') as hide_action \gset
select (select x ->> 'id' from jsonb_array_elements(cs_api.community_room_moderator_actions('RMXT') -> 'items') x
        where x ->> 'action' = 'mute') as mute_action \gset
select (select x ->> 'id' from jsonb_array_elements(cs_api.community_room_moderator_actions('RMXT') -> 'items') x
        where x ->> 'action' = 'escalate') as escalate_action \gset
select throws_ok(format($$select cs_api.community_undo_room_moderator_action(%L, 'ok')$$, :'hide_action'),
  'PT400', 'note_required', 'Pembatalan wajib dengan catatan');
select isnt(cs_api.community_undo_room_moderator_action(:'hide_action', 'Bukan promosi') ->> 'undone_at', null,
  'Staf membatalkan penyembunyian');
select throws_ok(format($$select cs_api.community_undo_room_moderator_action(%L, 'Ulangi batal')$$, :'hide_action'),
  'PT409', 'action_undone', 'Aksi yang sudah dibatalkan tidak dibatalkan lagi');
select throws_ok(format($$select cs_api.community_undo_room_moderator_action(%L, 'Batal eskalasi')$$, :'escalate_action'),
  'PT400', 'undo_not_supported', 'Eskalasi diselesaikan dari antrean laporan');
select cs_api.community_undo_room_moderator_action(:'mute_action', 'Bisu terlalu keras') is not null as unmuted \gset
reset role;

select is((select moderation_status from public.messages where id = :'msg1'), 'visible', 'Pesan tampil kembali');
select is((select status from public.appeals where target_id = :'msg1'), 'accepted', 'Banding yang tertunda ikut diterima');
select ok(exists (select 1 from cs.cs_audit_log where action = 'community.room_moderator_undo' and customer_id = :'budi'),
  'Pembatalan tercatat di audit');

select tests.authenticate_as(:'budi');
select is((send_message(:'room', 'Sudah bisa kirim', 'c7300000-0000-4000-8000-000000000008')).body, 'Sudah bisa kirim',
  'Setelah bisu dibatalkan anggota bisa mengirim lagi');
reset role;

select private.apply_sanction(:'moderator2', 'Melanggar pedoman', null, 'mute', 1, null) is not null as mod2_sanctioned \gset
select isnt((select removed_at from private.room_moderators where user_id = :'moderator2' order by appointed_at desc limit 1), null,
  'Moderator yang dikenai sanksi otomatis dicopot');

select tests.authenticate_agent(:'dodi');
select throws_ok(format($$select cs_api.community_remove_room_moderator('RMXT', %L, 'x')$$, :'moderator'),
  'PT400', 'reason_required', 'Pencopotan wajib dengan alasan');
select is(jsonb_array_length(cs_api.community_remove_room_moderator('RMXT', :'moderator', 'Rotasi moderator') -> 'moderators'), 0,
  'Staf mencopot moderator');
select cs_api.community_appoint_room_moderator('RMXT', :'moderator3', null) is not null as appointed3 \gset
reset role;
update private.settings set value = '1' where key = 'room_mods.max_rooms_per_user';
select tests.authenticate_agent(:'dodi');
select throws_ok(format($$select cs_api.community_appoint_room_moderator('RMXY', %L, null)$$, :'moderator3'),
  'PT409', 'user_moderator_limit', 'Jumlah room per moderator dibatasi');
select throws_ok($$select cs_api.community_set_room_moderator_settings('{"room_mods.min_trust_level": 3}')$$,
  'PT403', 'role_forbidden', 'Hanya Kepatuhan atau Super Admin yang mengubah syarat moderator');
reset role;

select tests.authenticate_as(:'moderator');
select throws_ok(format($$select room_mod_hide_message(%L, 'spam')$$, :'msg2'), 'PT403', 'not_room_moderator',
  'Moderator yang dicopot kehilangan hak');
reset role;

select tests.authenticate_agent(:'kirana');
select is(cs_api.community_set_room_moderator_settings('{"room_mods.min_trust_level": 3}') ->> 'room_mods.min_trust_level', '3',
  'Kepatuhan mengubah trust level minimal');
select throws_ok($$select cs_api.community_set_room_moderator_settings('{"room_mods.max_mute_hours": 48}')$$,
  'PT400', 'invalid_setting', 'Lama bisu maksimal tidak boleh melewati 24 jam');
reset role;

select ok(not has_function_privilege('anon', 'public.room_mod_hide_message(uuid,text,text)', 'EXECUTE'),
  'Anonim tidak bisa memakai aksi moderator');

select * from finish();
rollback;
