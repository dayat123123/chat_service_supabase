-- Privasi & UU PDP (0015): mute di feed, hapus akun, ekspor data, profil yang
-- dibuat ulang, retensi otomatis, promosi akun baru.
begin;
select plan(26);

update private.rate_limits set max_count = 100 where action = 'post' and window_seconds = 60;
select tests.create_user('pv_ani') as ani \gset
select tests.create_user('pv_budi') as budi \gset
select tests.create_user('pv_cici') as cici \gset
select 'GOTO' as goto \gset
insert into private.user_private (user_id, email) values (:'cici', 'cici@example.com');

select tests.authenticate_as(:'budi');
insert into posts (author_id, body) values (auth.uid(), 'Post dari budi yang di-mute');
reset role;
select tests.authenticate_as(:'cici');
insert into posts (author_id, body) values (auth.uid(), '$GOTO lagi ramai hari ini') returning id as goto_post \gset
insert into posts (author_id, body) values (auth.uid(), 'Ini kata RAHASIA yang di-mute') returning id as kw_post \gset
reset role;
select tests.authenticate_as(:'ani');
insert into follows (follower_id, following_id) values (auth.uid(), :'cici');
insert into mutes (muter_id, muted_id) values (auth.uid(), :'budi');
insert into muted_stocks (user_id, stock_code) values (auth.uid(), 'GOTO');
insert into muted_keywords (user_id, keyword) values (auth.uid(), 'rahasia');

-- Mute disaring di server ------------------------------------------------------
select is((select count(*)::int from get_feed('global', null, null, 50) f where f.author_id = :'budi'), 0,
  'Feed global tanpa post user yang di-mute');
select ok((select count(*) from get_feed('user', null, null, 50, :'budi')) >= 1,
  'Profil user yang di-mute tetap bisa dibuka');
select is((select count(*)::int from get_feed('global', null, null, 50) f where f.id = :'goto_post'), 0,
  'Feed global tanpa saham yang di-mute');
select is((select count(*)::int from get_feed('stock', 'GOTO', null, 50) f where f.id = :'goto_post'), 1,
  'Halaman saham yang di-mute tetap menampilkan post-nya');
select is((select count(*)::int from get_feed('global', null, null, 50) f where f.id = :'kw_post'), 0,
  'Feed global tanpa kata yang di-mute (tidak peka huruf besar)');
reset role;
update private.settings set value = '1' where key = 'mute.max_keywords';
select tests.authenticate_as(:'ani');
select throws_ok($$insert into muted_keywords (user_id, keyword) values (auth.uid(), 'lainnya')$$,
  'PT422', 'too_many_muted_keywords', 'Batas kata yang di-mute berlaku');
select is((select count(*)::int from mutes where muted_id = :'budi'), 1, 'Mute hanya terlihat oleh pemiliknya');
reset role;
select tests.authenticate_as(:'budi');
select is((select count(*)::int from mutes where muted_id = :'budi'), 0, 'User yang di-mute tidak tahu dirinya di-mute');
reset role;

-- Ekspor data -------------------------------------------------------------------
select tests.authenticate_as(:'cici');
select ok((select export_my_data() ?& array['profile', 'posts', 'comments', 'messages', 'consents']),
  'Ekspor data memuat semua bagian');
select is(jsonb_array_length(export_my_data() -> 'posts'), 2, 'Ekspor memuat post milik sendiri');
select ok(not ((export_my_data() -> 'profile') ? 'olt_user_id'), 'Ekspor tidak memuat olt_user_id');
select throws_like($$select export_my_data()$$, '%"rate_limited"%data_export%', 'Ekspor dibatasi 3x per hari');
reset role;
select is((select count(*)::int from private.personal_data_access_log where subject_id = :'cici' and purpose = 'self_export'),
  3, 'Setiap ekspor dicatat');

-- Hapus akun ------------------------------------------------------------------------
select tests.authenticate_as(:'cici');
select lives_ok($$select delete_my_account()$$, 'User menghapus akunnya');
reset role;
select is((select count(*)::int from posts where author_id = :'cici' and deleted_at is null), 0,
  'Semua post user terhapus dari tampilan');
select is((select count(*)::int from private.content_archive where author_id = :'cici' and reason = 'account_delete'), 2,
  'Konten diarsipkan untuk regulator');
select ok((select username::text like 'deleted\_%' and deleted_at is not null and display_name is null
           from profiles where id = :'cici'), 'Profil dianonimkan');
select is((select count(*)::int from follows where following_id = :'cici'), 0, 'Relasi follow dihapus');
select is((select count(*)::int from private.user_private where user_id = :'cici'), 0, 'Email dihapus');
select is((select count(*)::int from private.storage_cleanup_queue where prefix like '%' || :'cici' || '%'), 2,
  'File storage masuk antrean pembersihan');

-- Login lagi lewat OLT setelah akun dihapus: dibuat ulang sebagai akun baru --------
select upsert_olt_profile(:'cici', 'test:' || :'cici', 'cici_kembali', 'Cici') as relogin \gset
select ok((select deleted_at is null and trust_level = 0 and username::text = 'cici_kembali'
           from profiles where id = :'cici'), 'Akun yang dihapus dibuat ulang bersih (trust_level 0)');
insert into private.user_sanctions (user_id, kind, reason) values (:'ani', 'ban', 'uji');
select is((upsert_olt_profile(:'ani', 'test:' || :'ani', 'pv_ani') ->> 'banned')::boolean, true,
  'upsert_olt_profile mengembalikan status ban');

-- Retensi & promosi akun baru ----------------------------------------------------
insert into notifications (user_id, actor_id, type, created_at) values
  (:'ani', :'budi', 'follow', now() - interval '100 days'),
  (:'ani', :'budi', 'like', now());
insert into private.content_archive (target_type, target_id, author_id, body, retain_until, legal_hold) values
  ('post', gen_random_uuid(), :'budi', 'kedaluwarsa', now() - interval '1 day', false),
  ('post', gen_random_uuid(), :'budi', 'ditahan legal', now() - interval '1 day', true);
update profiles set trust_level = 0, created_at = now() - interval '2 days' where id = :'budi';
select private.run_retention() as retention \gset
select is((select count(*)::int from notifications where user_id = :'ani'), 1, 'Notifikasi lama dihapus, yang baru tetap');
select is((select count(*)::int from private.content_archive where author_id = :'budi'), 1,
  'Arsip kedaluwarsa dihapus, kecuali yang legal hold');
select is(private.promote_new_accounts() >= 1, true, 'Akun baru yang sudah 24 jam dipromosikan');
select is((select trust_level from profiles where id = :'budi'), 1::smallint, 'trust_level naik ke 1');

select * from finish();
rollback;
