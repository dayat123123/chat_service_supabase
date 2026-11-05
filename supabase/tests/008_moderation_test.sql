begin;
select plan(14);

insert into banned_words (word, action) values ('jelek', 'mask'), ('jaminan profit', 'block')
on conflict (word) do update set action = excluded.action;

select tests.create_user('alice') as alice \gset
select tests.create_user('bob_user') as bob \gset
insert into posts (id, author_id, body) values ('a5000000-0000-4000-8000-000000000001', :'bob', 'Post bob');

select tests.authenticate_as(:'alice');
select is(
  (select body from create_comment('a5000000-0000-4000-8000-000000000001', null, 'Kinerjanya JELEK sekali')),
  'Kinerjanya ***** sekali', 'Kata terlarang (mask) disensor');
select throws_ok(
  $$insert into posts (author_id, body) values (auth.uid(), 'Join grup kami, Jaminan Profit 20% per bulan!')$$,
  'PT422', 'content_blocked', 'Frasa terlarang (block) ditolak');
select throws_ok($$select word from banned_words$$, '42501', null, 'Daftar kata terlarang tidak bisa dibaca user');

select lives_ok(
  $$insert into reports (reporter_id, target_type, target_id, reason, details)
    values (auth.uid(), 'post', 'a5000000-0000-4000-8000-000000000001', 'pump_and_dump', 'Ajakan goreng saham')$$,
  'User bisa melaporkan post');
select throws_ok(
  $$insert into reports (reporter_id, target_type, target_id, reason)
    values (auth.uid(), 'post', 'a5000000-0000-4000-8000-000000000001', 'spam')$$,
  '23505', null, 'Satu laporan per user per target');
select throws_ok(
  $$insert into reports (reporter_id, target_type, target_id, reason)
    values (auth.uid(), 'post', gen_random_uuid(), 'spam')$$,
  'PT404', 'target_not_found', 'Target laporan harus ada');
select throws_ok(
  $$insert into reports (reporter_id, target_type, target_id, reason)
    values (auth.uid(), 'user', auth.uid(), 'bukan-alasan')$$,
  '23514', null, 'Alasan laporan harus dari daftar');
select throws_ok(
  $$update reports set status = 'resolved'$$,
  '42501', null, 'Pelapor tidak bisa mengubah status laporan');
select is((select count(*)::int from reports), 1, 'Pelapor melihat laporannya sendiri');

select tests.authenticate_as(:'bob');
select is((select count(*)::int from reports), 0, 'Laporan orang lain tidak terlihat');

reset role;
select is(
  (select report_count::int from private.report_queue where target_id = 'a5000000-0000-4000-8000-000000000001'),
  1, 'Antrean moderasi memuat target yang dilaporkan');

select tests.authenticate_as(:'alice');
select is((select count(*)::int from notifications where user_id = :'bob'), 0,
  'Notifikasi user lain tidak terlihat');
select tests.authenticate_as(:'bob');
select ok(mark_notifications_read() >= 1, 'mark_notifications_read menandai notifikasi sendiri');
select is(get_notification_unread_count(), 0, 'Tidak ada notifikasi belum dibaca setelah ditandai');

select * from finish();
rollback;
