begin;
select plan(37);

update private.rate_limits set max_count = 1000 where action in ('post', 'search');

select tests.create_user('sr_ani') as ani \gset
select tests.create_user('sr_budi') as budi \gset
select tests.create_user('sr_cici') as cici \gset
select tests.create_user('sr_dodi') as dodi \gset
select tests.create_user('zorvex_trader') as zorvex \gset
select tests.create_user('zorvex_banned') as banned \gset
update public.profiles set created_at = now() - interval '30 days' where id in (:'ani', :'budi', :'cici');

insert into private.user_sanctions (user_id, kind, reason) values (:'banned', 'ban', 'spam');

insert into public.posts (id, author_id, body, sentiment) values
  ('00000000-0000-4000-8000-00000000f301', :'budi', 'Saham zorvexbank sedang menguat #ZorvexNaik #ihsg $ZRVX', 'bullish'),
  ('00000000-0000-4000-8000-00000000f302', :'cici', 'Penguatan zorvexbank berlanjut, cek https://x.co/a#frag #zorvexnaik', null),
  ('00000000-0000-4000-8000-00000000f303', :'dodi', 'Analisa zorvexbank versi akun baru #zorvexnaik', 'bearish'),
  ('00000000-0000-4000-8000-00000000f304', :'cici', 'Perbankan zorvexindo masih lesu #soloaja', null);
update public.posts set created_at = created_at - interval '1 minute' where id = '00000000-0000-4000-8000-00000000f301';
update public.posts set moderation_status = 'held' where id = '00000000-0000-4000-8000-00000000f303';

select results_eq(
  $$select tag::text from public.post_hashtags where post_id = '00000000-0000-4000-8000-00000000f301' order by tag$$,
  $$values ('ihsg'), ('zorvexnaik')$$,
  'Hashtag diekstrak ke huruf kecil');
select results_eq(
  $$select tag::text from public.post_hashtags where post_id = '00000000-0000-4000-8000-00000000f302'$$,
  $$values ('zorvexnaik')$$,
  'Fragmen URL tidak dianggap hashtag');
select ok((select count(*) from private.post_search where post_id = '00000000-0000-4000-8000-00000000f301') = 1,
  'Vektor pencarian dibuat saat post ditulis');
select ok(exists (select 1 from private.stock_codes where code = 'ZRVX'), 'Kode saham baru masuk direktori pencarian');

select tests.authenticate_as(:'cici');
update public.posts set body = 'Perbankan zorvexindo masih lesu #gantitag' where id = '00000000-0000-4000-8000-00000000f304';
reset role;
select results_eq(
  $$select tag::text from public.post_hashtags where post_id = '00000000-0000-4000-8000-00000000f304'$$,
  $$values ('gantitag')$$,
  'Hashtag disinkronkan ulang setelah edit');

select tests.authenticate_anon();
select throws_ok($$select public.search('zorvex')$$, '42501', null, 'Pengguna anonim tidak bisa mencari');
reset role;

select tests.authenticate_as(:'ani');
select throws_ok($$select public.search('z')$$, 'PT400', 'query_too_short', 'Kata kunci terlalu pendek ditolak');
select throws_ok($$select public.search('zorvex', 'groups')$$, 'PT400', 'invalid_type', 'Jenis pencarian tidak dikenal ditolak');
select throws_ok($$select public.search('zorvex', 'all', 'o:5')$$, 'PT400', 'invalid_cursor',
  'Cursor tidak dipakai untuk pencarian gabungan');
select throws_ok($$select public.search('zorvex', 'users', 'xx')$$, 'PT400', 'invalid_cursor', 'Cursor rusak ditolak');

select is(
  (select jsonb_agg(e ->> 'id' order by e ->> 'id') from jsonb_array_elements(public.search('zorvexbank', 'posts') -> 'posts') e),
  '["00000000-0000-4000-8000-00000000f301", "00000000-0000-4000-8000-00000000f302"]'::jsonb,
  'Pencarian post menemukan kata yang sama dan tidak menampilkan post yang ditahan');
select ok(
  public.search('menguat', 'posts') -> 'posts' @> '[{"id": "00000000-0000-4000-8000-00000000f301"}]'
  and public.search('penguatan zorvexbank', 'posts') -> 'posts' @> '[{"id": "00000000-0000-4000-8000-00000000f302"}]',
  'Pencarian memakai stemming bahasa Indonesia');
select ok(public.search('zorvexba', 'posts') -> 'posts' @> '[{"id": "00000000-0000-4000-8000-00000000f301"}]',
  'Kata terakhir dicocokkan sebagai awalan');
select ok(public.search('zorvexbnak', 'posts') -> 'posts' @> '[{"id": "00000000-0000-4000-8000-00000000f301"}]',
  'Salah ketik tetap ditemukan lewat trigram');
select ok(public.search('#zorvexnaik', 'posts') -> 'posts' @> '[{"id": "00000000-0000-4000-8000-00000000f302"}]',
  'Kata kunci hashtag menemukan post');
select ok(public.search('$zrvx', 'posts') -> 'posts' @> '[{"id": "00000000-0000-4000-8000-00000000f301"}]',
  'Kata kunci cashtag menemukan post');

select public.search('zorvexbank', 'posts', null, 1) as page1 \gset
select is(jsonb_array_length(:'page1'::jsonb -> 'posts'), 1, 'Halaman pertama dibatasi limit');
select is(:'page1'::jsonb -> 'posts' -> 0 ->> 'id', '00000000-0000-4000-8000-00000000f302', 'Hasil diurutkan terbaru dulu');
select is(
  public.search('zorvexbank', 'posts', :'page1'::jsonb ->> 'next_cursor', 1) -> 'posts' -> 0 ->> 'id',
  '00000000-0000-4000-8000-00000000f301', 'Cursor membuka halaman berikutnya');
reset role;

select tests.authenticate_as(:'dodi');
select ok(public.search('zorvexbank', 'posts') -> 'posts' @> '[{"id": "00000000-0000-4000-8000-00000000f303"}]',
  'Penulis tetap menemukan post miliknya yang ditahan');
reset role;

insert into public.mutes (muter_id, muted_id) values (:'ani', :'cici');
insert into public.blocks (blocker_id, blocked_id) values (:'budi', :'ani');
select tests.authenticate_as(:'ani');
select is(jsonb_array_length(public.search('zorvexbank', 'posts') -> 'posts'), 0,
  'Post dari user yang diblokir atau dibisukan tidak muncul');

select is(
  (select jsonb_agg(e ->> 'username' order by e ->> 'username') from jsonb_array_elements(public.search('sr_', 'users') -> 'users') e),
  '["sr_ani", "sr_cici", "sr_dodi"]'::jsonb,
  'Pencarian pengguna tidak menampilkan pemblokir');
select is(public.search('zorvex', 'users') -> 'users' -> 0 ->> 'username', 'zorvex_trader',
  'Akun yang di-ban tidak muncul di pencarian pengguna');
select is(public.search('zorvex_tradr', 'users') -> 'users' -> 0 ->> 'username', 'zorvex_trader',
  'Salah ketik username tetap ditemukan');
select is((public.search('sr_', 'users', null, 2) ->> 'next_cursor'), 'o:2', 'Pencarian pengguna memakai cursor offset');

select is(public.search('$zr', 'stocks') -> 'stocks' -> 0 ->> 'code', 'ZRVX', 'Pencarian saham memakai awalan kode');
select is(public.search('zrvx', 'stocks') -> 'stocks' -> 0 ->> 'posts_7d', '1', 'Hasil saham memuat jumlah post 7 hari');
select is(public.search('#zorvex', 'hashtags') -> 'hashtags' -> 0 ->> 'tag', 'zorvexnaik',
  'Pencarian hashtag memakai awalan');

select ok(public.search('zorvex') ?& array['posts', 'users', 'stocks', 'hashtags'],
  'Pencarian gabungan mengembalikan semua jenis');

select is((select count(*)::integer from public.get_hashtag_feed('#ZorvexNaik')), 0,
  'Feed hashtag menghormati blokir, bisu, dan status moderasi');
reset role;
delete from public.mutes where muter_id = :'ani';
select tests.authenticate_as(:'ani');
select results_eq($$select id from public.get_hashtag_feed('zorvexnaik')$$,
  $$values ('00000000-0000-4000-8000-00000000f302'::uuid)$$,
  'Feed hashtag menampilkan post bertag yang terlihat');
select throws_ok($$select * from public.get_hashtag_feed('#a')$$, 'PT400', 'invalid_hashtag', 'Hashtag tidak valid ditolak');
reset role;

update public.posts set moderation_status = 'visible' where id = '00000000-0000-4000-8000-00000000f303';
select private.trending_compute() as trending \gset
select tests.authenticate_as(:'ani');
select is((select author_count from public.get_trending_hashtags('24h') where tag = 'zorvexnaik'), 3,
  'Trending hashtag menghitung penulis berbeda');
select is((select score from public.get_trending_hashtags('24h') where tag = 'zorvexnaik'), 2.20::numeric,
  'Akun baru berbobot rendah di trending hashtag');
select ok(not exists (select 1 from public.get_trending_hashtags('7d') where tag = 'gantitag'),
  'Hashtag dari satu penulis saja tidak trending');
select throws_ok($$select * from public.get_trending_hashtags('1y')$$, 'PT400', 'invalid_window', 'Jendela trending divalidasi');
reset role;

update private.rate_limits set max_count = 2 where action = 'search' and window_seconds = 60;
select tests.authenticate_as(:'cici');
select public.search('zorvex', 'users') as s1 \gset
select public.search('zorvex', 'users') as s2 \gset
select throws_like($$select public.search('zorvex', 'users')$$, '%"PT429"%rate_limited%', 'Pencarian dibatasi rate limit');
reset role;

select * from finish();
rollback;
