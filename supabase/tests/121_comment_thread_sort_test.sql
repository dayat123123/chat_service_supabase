begin;
select plan(9);

select tests.create_user('sort_alice') as alice \gset
select tests.create_user('sort_bob') as bob \gset
insert into posts (id, author_id, body) values ('a2100000-0000-4000-8000-000000000001', :'alice', 'Post urutan komentar');

select tests.authenticate_as(:'bob');
select id as c1 from create_comment('a2100000-0000-4000-8000-000000000001', null, 'Pertama') \gset
select id as c2 from create_comment('a2100000-0000-4000-8000-000000000001', null, 'Kedua') \gset
select id as c3 from create_comment('a2100000-0000-4000-8000-000000000001', null, 'Ketiga') \gset
select id as r1 from create_comment('a2100000-0000-4000-8000-000000000001', :'c1', 'Balasan untuk pertama') \gset
reset role;
update comments set like_count = 5 where id = :'c2';

select tests.authenticate_as(:'bob');
select results_eq(
  $$select id from get_comment_thread('a2100000-0000-4000-8000-000000000001', null, 1, null, 10, 3)$$,
  format('values (%L::uuid), (%L::uuid), (%L::uuid), (%L::uuid)', :'c1', :'r1', :'c2', :'c3'),
  'Tanpa p_sort urutannya tetap dari yang terlama, seperti klien lama');
select results_eq(
  $$select id from get_comment_thread('a2100000-0000-4000-8000-000000000001', null, 1, null, 10, 3, false, 'latest')$$,
  format('values (%L::uuid), (%L::uuid), (%L::uuid), (%L::uuid)', :'c3', :'c2', :'c1', :'r1'),
  'latest: komentar teratas dari yang terbaru, balasan tetap di bawah induknya');
select results_eq(
  format($$select id from get_comment_thread('a2100000-0000-4000-8000-000000000001', null, 0, %L, 10, 0, false, 'latest')$$,
         (select seq::text from comments where id = :'c2')),
  format('values (%L::uuid)', :'c1'),
  'latest: cursor melanjutkan ke komentar yang lebih lama');
select results_eq(
  $$select id from get_comment_thread('a2100000-0000-4000-8000-000000000001', null, 1, null, 10, 3, false, 'top')$$,
  format('values (%L::uuid), (%L::uuid), (%L::uuid), (%L::uuid)', :'c2', :'c1', :'r1', :'c3'),
  'top: suka + balasan terbanyak lebih dulu, seri diurutkan dari yang terlama');
select results_eq(
  $$select id from get_comment_thread('a2100000-0000-4000-8000-000000000001', null, 0, null, 1, 0, false, 'top')$$,
  format('values (%L::uuid)', :'c2'),
  'top: halaman pertama dibatasi limit');
select results_eq(
  $$select id from get_comment_thread('a2100000-0000-4000-8000-000000000001', null, 0, '1', 2, 0, false, 'top')$$,
  format('values (%L::uuid), (%L::uuid)', :'c1', :'c3'),
  'top: cursor adalah offset komentar teratas');
select results_eq(
  format($$select id from get_comment_thread('a2100000-0000-4000-8000-000000000001', %L, 0, null, 10, 0, true, 'latest')$$, :'c1'),
  format('values (%L::uuid), (%L::uuid)', :'c1', :'r1'),
  'Root tetap tampil pertama saat melanjutkan utas');
select throws_ok(
  $$select * from get_comment_thread('a2100000-0000-4000-8000-000000000001', null, 1, null, 10, 3, false, 'random')$$,
  'PT400', 'invalid_sort', 'Urutan di luar daftar ditolak');
reset role;

select tests.authenticate_anon();
select throws_ok(
  $$select * from get_comment_thread('a2100000-0000-4000-8000-000000000001')$$,
  '42501', null, 'Anon tidak bisa membaca thread');
reset role;

select * from finish();
rollback;
