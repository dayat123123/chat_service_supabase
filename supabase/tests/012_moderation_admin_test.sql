begin;
select plan(39);

select tests.create_user('ma_penulis') as author \gset
select tests.create_user('ma_lain') as other \gset
select tests.create_user('ma_pelapor') as reporter \gset
select tests.create_admin('super_admin') as super \gset
select tests.create_admin('compliance_admin') as compliance \gset
select tests.create_admin('moderator') as moderator \gset
select tests.create_admin('room_moderator') as room_mod \gset
select tests.create_admin('viewer') as viewer \gset
insert into private.user_private (user_id, email) values (:'author', 'penulis@example.com');

select tests.authenticate_as(:'author');
insert into posts (author_id, body) values (auth.uid(), 'Post yang akan dilaporkan') returning id as post \gset
select create_group_room('Grup R', array[:'other']::uuid[]) as room_r \gset
select create_group_room('Grup R2', array[:'other']::uuid[]) as room_r2 \gset
reset role;
select tests.authenticate_as(:'other');
select (send_message(:'room_r', 'pesan di room R')).id as msg_r \gset
select (send_message(:'room_r2', 'pesan di room R2')).id as msg_r2 \gset
reset role;
select tests.authenticate_as(:'reporter');
insert into reports (reporter_id, target_type, target_id, reason) values (auth.uid(), 'post', :'post', 'spam');
reset role;

select tests.authenticate_as(:'other');
select throws_ok($$select admin_api.whoami()$$, 'PT403', 'admin_required', 'User biasa bukan admin');
reset role;
select tests.authenticate_admin(:'moderator', 'aal1');
select throws_ok($$select admin_api.whoami()$$, 'PT403', 'admin_required', 'Admin tanpa 2FA (aal1) ditolak');
reset role;
select tests.authenticate_admin(:'moderator');
select is(admin_api.whoami() ->> 'role', 'moderator', 'Admin dengan 2FA (aal2) dikenali');
select is((select report_count from admin_api.report_queue() where target_id = :'post'), 1,
  'Laporan muncul di antrean');
reset role;
select tests.authenticate_admin(:'viewer');
select throws_ok(format($$select admin_api.resolve_target('post', %L, 'hide', 'uji')$$, :'post'),
  'PT403', 'admin_forbidden', 'viewer tidak bisa menindak laporan');
reset role;

select tests.authenticate_admin(:'moderator');
select lives_ok(format($$select admin_api.resolve_target('post', %L, 'hide', 'spam')$$, :'post'),
  'Moderator menyembunyikan post');
reset role;
select tests.authenticate_as(:'other');
select is((select count(*)::int from posts where id = :'post'), 0, 'Post tersembunyi tidak terlihat user lain');
reset role;
select tests.authenticate_as(:'author');
select is((select count(*)::int from posts where id = :'post'), 1, 'Penulis tetap melihat post-nya');
reset role;
select is((select status from reports where target_id = :'post'), 'resolved', 'Laporan ditandai selesai');
select tests.authenticate_admin(:'moderator');
select lives_ok(format($$select admin_api.resolve_target('post', %L, 'restore', 'salah tindak')$$, :'post'),
  'Moderator memulihkan post');
reset role;
select tests.authenticate_as(:'other');
select is((select count(*)::int from posts where id = :'post'), 1, 'Post terlihat lagi setelah dipulihkan');
reset role;
select tests.authenticate_admin(:'moderator');
select lives_ok(format($$select admin_api.resolve_target('post', %L, 'remove', 'penipuan')$$, :'post'),
  'Moderator menghapus post');
reset role;
select is((select count(*)::int from private.content_archive
           where target_id = :'post' and reason = 'moderator_remove'), 1, 'Post terhapus diarsipkan');
select isnt((select deleted_at from posts where id = :'post'), null, 'Post ditandai terhapus');

select tests.authenticate_admin(:'compliance');
select lives_ok(format($$select admin_api.set_room_scope(%L, %L, true)$$, :'room_mod', :'room_r'),
  'compliance_admin menugaskan room_moderator ke room R');
reset role;
select tests.authenticate_admin(:'room_mod');
select lives_ok(format($$select admin_api.resolve_target('message', %L, 'hide', 'kasar')$$, :'msg_r'),
  'room_moderator menyembunyikan pesan di room-nya');
select throws_ok(format($$select admin_api.resolve_target('message', %L, 'hide', 'kasar')$$, :'msg_r2'),
  'PT403', 'admin_forbidden', 'room_moderator tidak bisa menindak room lain');
reset role;
select tests.authenticate_as(:'author');
select is((select count(*)::int from messages where id = :'msg_r'), 0, 'Pesan tersembunyi tidak terlihat anggota lain');
reset role;
select tests.authenticate_as(:'other');
select is((select count(*)::int from messages where id = :'msg_r'), 1, 'Pengirim tetap melihat pesannya');
reset role;

select tests.authenticate_admin(:'moderator');
select is(admin_api.sanction_user(:'other', 'spam berulang') ->> 'kind', 'warning', 'Pelanggaran 1: peringatan');
select is(admin_api.sanction_user(:'other', 'spam berulang') ->> 'kind', 'mute', 'Pelanggaran 2: mute');
reset role;
select ok(private.is_muted(:'other'), 'User sedang di-mute');
select tests.authenticate_as(:'other');
select is((select count(*)::int from get_my_sanctions()), 2, 'User bisa melihat sanksinya sendiri');
reset role;
select tests.authenticate_admin(:'moderator');
select is(admin_api.sanction_user(:'other', 'spam berulang', 'spam', 'ban', 168) ->> 'kind', 'ban', 'Ban 7 hari');
reset role;
select tests.authenticate_with(:'other', jsonb_build_object('iat', extract(epoch from now())::bigint + 1));
select throws_ok($$select private.check_request()$$, 'PT403', 'user_banned', 'User yang di-ban ditolak di setiap request');
reset role;

select tests.authenticate_admin(:'moderator');
select lives_ok(format($$select admin_api.revoke_user_sessions(%L, 'perangkat hilang')$$, :'author'),
  'Moderator mencabut semua sesi user');
reset role;
select tests.authenticate_with(:'author', jsonb_build_object('iat', extract(epoch from now())::bigint - 60));
select throws_ok($$select private.check_request()$$, 'PT401', 'session_revoked', 'JWT lama ditolak setelah sesi dicabut');
reset role;
select tests.authenticate_with(:'author', jsonb_build_object('iat', extract(epoch from now())::bigint + 1));
select lives_ok($$select private.check_request()$$, 'JWT baru (setelah pencabutan) diterima');
reset role;

select is((select count(*)::int from private.admin_audit_log
           where actor_id = :'moderator' and action = 'resolve_hide'), 1, 'Aksi admin tercatat di audit log');
select throws_ok($$update private.admin_audit_log set action = 'diubah'$$, '42501', null, 'Audit log tidak bisa diubah');
select throws_ok($$delete from private.admin_audit_log$$, '42501', null, 'Audit log tidak bisa dihapus');

select tests.authenticate_admin(:'compliance');
select throws_ok(format($$select admin_api.set_admin(%L, 'compliance_admin')$$, :'viewer'),
  'PT403', 'admin_forbidden', 'compliance_admin tidak bisa membuat compliance_admin');
select lives_ok(format($$select admin_api.set_trust_level(%L, 2, 'analis terverifikasi')$$, :'author'),
  'compliance_admin mengubah trust_level');
select is(admin_api.user_detail(:'author') -> 'profile' ->> 'email', 'penulis@example.com',
  'compliance_admin melihat email (data pribadi)');
reset role;
select is((select count(*)::int from private.personal_data_access_log
           where subject_id = :'author' and purpose = 'admin_user_detail'), 1, 'Akses data pribadi dicatat');
select tests.authenticate_admin(:'viewer');
select is(admin_api.user_detail(:'author') -> 'profile' ->> 'email', null, 'viewer tidak melihat email');
reset role;
select tests.authenticate_admin(:'moderator');
select throws_ok($$select admin_api.upsert_banned_word('judol', 'block')$$,
  'PT403', 'admin_forbidden', 'moderator tidak bisa mengubah kebijakan kata');
reset role;
select tests.authenticate_admin(:'super');
select lives_ok(format($$select admin_api.set_admin(%L, 'compliance_admin')$$, :'viewer'),
  'super_admin bisa menunjuk compliance_admin');
select lives_ok($$select count(*) from admin_api.archive()$$, 'super_admin bisa membaca arsip regulator');
reset role;

select * from finish();
rollback;
