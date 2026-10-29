-- Post: insert/RLS, parsing $KODE & @mention, edit, rate limit, blokir, soft delete.
begin;
select plan(20);

select tests.create_stock('BBCA');
select tests.create_stock('GOTO');
select tests.create_user('alice') as alice \gset
select tests.create_user('bob_user') as bob \gset
select tests.create_user('carol') as carol \gset

select tests.authenticate_as(:'alice');

select lives_ok(
  $$insert into posts (id, author_id, body, sentiment)
    values ('a1000000-0000-4000-8000-000000000001', auth.uid(),
            '  Akumulasi $BBCA dan $goto, bukan $ZZZZ atau $100. cc @bob_user  ', 'bullish')$$,
  'User bisa membuat post');
select is(
  (select body from posts where id = 'a1000000-0000-4000-8000-000000000001'),
  'Akumulasi $BBCA dan $goto, bukan $ZZZZ atau $100. cc @bob_user',
  'Spasi di awal/akhir body dipangkas');
select results_eq(
  $$select stock_code from post_stocks where post_id = 'a1000000-0000-4000-8000-000000000001' order by 1$$,
  $$values ('BBCA'::text), ('GOTO'::text)$$,
  '$KODE diparsing dan hanya kode di tabel stocks yang disimpan');
select results_eq(
  $$select user_id from post_mentions where post_id = 'a1000000-0000-4000-8000-000000000001'$$,
  format('values (%L::uuid)', :'bob'),
  '@mention diparsing ke post_mentions');

select throws_ok(
  format('insert into posts (author_id, body) values (%L, %L)', :'bob', 'palsu'),
  '42501', null, 'Tidak bisa membuat post atas nama orang lain');
select throws_ok(
  format('insert into posts (author_id, body) values (auth.uid(), %L)', repeat('x', 2001)),
  '23514', null, 'Body maksimal 2000 karakter');
select throws_ok(
  $$insert into posts (author_id, body, sentiment) values (auth.uid(), 'x', 'moon')$$,
  '23514', null, 'Sentimen selain bullish/bearish/neutral ditolak');
select throws_ok(
  $$insert into posts (author_id, body, attachments)
    values (auth.uid(), 'x', '[{"path":"posts/orang-lain/a.jpg"}]')$$,
  'PT400', 'invalid_attachments', 'Lampiran harus berada di folder milik sendiri');

select lives_ok(
  $$update posts set body = 'Ganti ke $GOTO saja' where id = 'a1000000-0000-4000-8000-000000000001'$$,
  'Pemilik bisa mengedit post');
select results_eq(
  $$select stock_code from post_stocks where post_id = 'a1000000-0000-4000-8000-000000000001'$$,
  $$values ('GOTO'::text)$$,
  'Tag saham disinkronkan ulang setelah edit');
select isnt(
  (select edited_at from posts where id = 'a1000000-0000-4000-8000-000000000001'),
  null, 'edited_at terisi setelah edit');

-- Rate limit: 1 post sudah ada, tambah 4 = 5; post ke-6 ditolak.
select lives_ok(
  $$insert into posts (author_id, body) select auth.uid(), 'post ' || g from generate_series(1, 4) g$$,
  'Hingga 5 post per menit diizinkan');
select throws_ok(
  $$insert into posts (author_id, body) values (auth.uid(), 'post ke-6')$$,
  'PT429', 'rate_limited', 'Post ke-6 dalam satu menit ditolak');

-- Blokir menyembunyikan post dua arah.
reset role;
insert into posts (id, author_id, body) values ('b1000000-0000-4000-8000-000000000001', :'bob', 'Post milik bob');
insert into posts (id, author_id, body) values ('b1000000-0000-4000-8000-000000000002', :'carol', 'Post milik carol');

select tests.authenticate_as(:'bob');
insert into blocks (blocker_id, blocked_id) values (auth.uid(), :'alice');
select is((select count(*)::int from posts where author_id = :'alice'), 0,
  'Pemblokir tidak melihat post user yang diblokir');

select tests.authenticate_as(:'alice');
select is((select count(*)::int from posts where id = 'b1000000-0000-4000-8000-000000000001'), 0,
  'User yang diblokir tidak melihat post pemblokir');

-- Soft delete.
select throws_ok(
  $$select delete_post('b1000000-0000-4000-8000-000000000002')$$,
  'PT403', 'forbidden', 'Tidak bisa menghapus post orang lain');
select lives_ok(
  $$select delete_post('a1000000-0000-4000-8000-000000000001')$$,
  'Pemilik bisa menghapus post');
select is((select count(*)::int from posts where id = 'a1000000-0000-4000-8000-000000000001'), 0,
  'Post terhapus tidak lagi terlihat');

reset role;
select is(
  (select body from private.content_archive where target_id = 'a1000000-0000-4000-8000-000000000001'),
  'Ganti ke $GOTO saja', 'Isi post yang dihapus diarsipkan untuk moderasi');

select tests.authenticate_anon();
select throws_ok($$select id from posts$$, '42501', null, 'anon tidak bisa membaca post');

select * from finish();
rollback;
