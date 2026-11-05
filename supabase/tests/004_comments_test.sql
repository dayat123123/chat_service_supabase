begin;
select plan(21);

select tests.create_user('alice') as alice \gset
select tests.create_user('bob_user') as bob \gset
select tests.create_user('carol') as carol \gset
insert into posts (id, author_id, body) values
  ('a2000000-0000-4000-8000-000000000001', :'alice', 'Post untuk diskusi'),
  ('a2000000-0000-4000-8000-000000000002', :'alice', 'Post lain');

-- 5-level chain: bob -> carol -> bob -> carol -> bob
select tests.authenticate_as(:'bob');
select id as c1 from create_comment('a2000000-0000-4000-8000-000000000001', null, 'Level 1') \gset
select tests.authenticate_as(:'carol');
select id as c2 from create_comment('a2000000-0000-4000-8000-000000000001', :'c1', 'Level 2') \gset
select tests.authenticate_as(:'bob');
select id as c3 from create_comment('a2000000-0000-4000-8000-000000000001', :'c2', 'Level 3') \gset
select tests.authenticate_as(:'carol');
select id as c4 from create_comment('a2000000-0000-4000-8000-000000000001', :'c3', 'Level 4') \gset
select tests.authenticate_as(:'bob');
select id as c5 from create_comment('a2000000-0000-4000-8000-000000000001', :'c4', 'Level 5') \gset

select results_eq(
  format('select depth from comments where id in (%L, %L, %L, %L, %L) order by path',
         :'c1', :'c2', :'c3', :'c4', :'c5'),
  $$values (0), (1), (2), (3), (4)$$,
  'Depth bertambah per level (5 level)');
select ok(
  (select path from comments where id = :'c5')
    operator(extensions.<@) (select path from comments where id = :'c1'),
  'Path level 5 berada di bawah path level 1');
select is((select reply_count from comments where id = :'c1'), 1, 'reply_count komentar induk bertambah');
select is((select comment_count from posts where id = 'a2000000-0000-4000-8000-000000000001'), 5,
  'comment_count post bertambah');

select id as c2b from create_comment('a2000000-0000-4000-8000-000000000001', :'c1', 'Level 2 saudara B') \gset
select id as c2c from create_comment('a2000000-0000-4000-8000-000000000001', :'c1', 'Level 2 saudara C') \gset
select tests.authenticate_as(:'alice');
select id as t2 from create_comment('a2000000-0000-4000-8000-000000000001', null, 'Top-level kedua') \gset
select id as t3 from create_comment('a2000000-0000-4000-8000-000000000001', null, 'Top-level ketiga') \gset

select results_eq(
  $$select id from get_comment_thread('a2000000-0000-4000-8000-000000000001', null, 3, null, 1, 2)$$,
  format('values (%L::uuid), (%L::uuid), (%L::uuid), (%L::uuid), (%L::uuid)',
         :'c1', :'c2', :'c3', :'c4', :'c2b'),
  'Thread terurut pohon, dibatasi max_depth 3 dan 2 balasan per cabang');
select results_eq(
  format($$select id from get_comment_thread('a2000000-0000-4000-8000-000000000001', %L, 0, %L, 10, 0)$$,
         :'c1', (select seq::text from comments where id = :'c2b')),
  format('values (%L::uuid)', :'c2c'),
  '"Lihat balasan lainnya" melanjutkan dari cursor balasan terakhir');
select results_eq(
  format($$select id from get_comment_thread('a2000000-0000-4000-8000-000000000001', %L, 3, null, 10, 3, true)$$,
         :'c4'),
  format('values (%L::uuid), (%L::uuid)', :'c4', :'c5'),
  '"Lanjutkan thread" mengembalikan root beserta turunannya');
select results_eq(
  format($$select id from get_comment_thread('a2000000-0000-4000-8000-000000000001', null, 0, %L, 10, 0)$$,
         (select seq::text from comments where id = :'c1')),
  format('values (%L::uuid), (%L::uuid)', :'t2', :'t3'),
  'Pagination komentar top-level memakai cursor keyset');

select throws_ok(
  format($$select create_comment('a2000000-0000-4000-8000-000000000002', %L, 'salah post')$$, :'c1'),
  'PT400', 'invalid_parent', 'Parent dari post lain ditolak');
select throws_ok(
  $$select create_comment('a2000000-0000-4000-8000-000000000001', null, '   ')$$,
  'PT400', 'empty_body', 'Komentar kosong ditolak');
select throws_ok(
  format($$select create_comment('a2000000-0000-4000-8000-000000000001', null, %L)$$, repeat('x', 1001)),
  'PT400', 'body_too_long', 'Komentar maksimal 1000 karakter');

select tests.authenticate_as(:'carol');
select lives_ok(format('select delete_comment(%L)', :'c2'), 'Penulis bisa menghapus komentarnya');
select results_eq(
  format($$select is_deleted, body is null, author_id is null
           from get_comment_thread('a2000000-0000-4000-8000-000000000001', %L, 0, null, 10, 0, true)
           where id = %L$$, :'c1', :'c2'),
  $$values (true, true, true)$$,
  'Komentar terhapus tampil sebagai [dihapus] tanpa isi & penulis');
select is(
  (select count(*)::int from get_comment_thread('a2000000-0000-4000-8000-000000000001', null, 10, null, 10, 10)
   where id = :'c3'),
  1, 'Balasan di bawah komentar terhapus tetap ada');
select is((select comment_count from posts where id = 'a2000000-0000-4000-8000-000000000001'), 8,
  'comment_count berkurang setelah komentar dihapus');
select is((select reply_count from comments where id = :'c1'), 3,
  'reply_count tidak berubah (komentar terhapus tetap tampil)');
select throws_ok(
  format($$select create_comment('a2000000-0000-4000-8000-000000000001', %L, 'balas yang dihapus')$$, :'c2'),
  'PT409', 'parent_deleted', 'Tidak bisa membalas komentar yang sudah dihapus');
select throws_ok(
  format('select delete_comment(%L)', :'c1'),
  'PT403', 'forbidden', 'Tidak bisa menghapus komentar orang lain');

reset role;
select ok(
  (select count(*) from notifications where user_id = :'bob' and type = 'reply'
     and payload ->> 'comment_id' = :'c2') = 1,
  'Penulis komentar induk mendapat notifikasi balasan');

insert into blocks (blocker_id, blocked_id) values (:'alice', :'bob');
select tests.authenticate_as(:'alice');
select is(
  (select count(*)::int from get_comment_thread('a2000000-0000-4000-8000-000000000001', null, 10, null, 10, 10)
   where id in (:'c1', :'c3', :'c5')),
  0, 'Komentar user yang diblokir tidak muncul di thread');

-- Comment rate limit lowered temporarily to keep the test fast.
reset role;
-- carol already wrote 2 comments within the last minute.
update private.rate_limits set max_count = 2 where action = 'comment';
select tests.authenticate_as(:'carol');
select throws_like(
  $$select create_comment('a2000000-0000-4000-8000-000000000002', null, 'satu menit terlalu banyak')$$,
  '%"PT429"%"rate_limited"%', 'Rate limit komentar per menit berlaku');

select * from finish();
rollback;
