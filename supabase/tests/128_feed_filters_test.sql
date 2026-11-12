begin;
select plan(24);

update private.rate_limits set max_count = 1000 where action in ('post', 'comment');

select tests.create_user('ff_ani') as ani \gset
select tests.create_user('ff_budi') as budi \gset
select tests.create_agent('ff_product', '{product}') as product \gset
select tests.create_agent('ff_agent', '{cs_agent}', '{"general": 1}') as agent \gset

insert into public.posts (id, author_id, body, like_count, created_at) values
  ('a2800000-0000-4000-8000-000000000001', :'budi', 'Teks biasa $FFAA', 50, now() - interval '5 minutes'),
  ('a2800000-0000-4000-8000-000000000002', :'budi', 'Polling $FFAA', 10, now() - interval '4 minutes'),
  ('a2800000-0000-4000-8000-000000000003', :'budi', 'Polling kedua $FFAA', 30, now() - interval '3 minutes');
insert into public.posts (id, author_id, body, attachments, like_count, created_at) values
  ('a2800000-0000-4000-8000-000000000004', :'budi', 'Grafik $FFAA',
   jsonb_build_array(jsonb_build_object('path', 'posts/' || :'budi' || '/g.png', 'mime', 'image/png')), 20,
   now() - interval '2 minutes');
insert into public.post_polls (post_id, ends_at) values
  ('a2800000-0000-4000-8000-000000000002', now() + interval '1 day'),
  ('a2800000-0000-4000-8000-000000000003', now() + interval '1 day');

select tests.authenticate_as(:'ani');

select results_eq(
  $$select key from public.get_feed_filters()$$,
  $$values ('latest'::text), ('top'), ('media'), ('polls')$$,
  'get_feed_filters memuat filter bawaan sesuai urutan');
select results_eq(
  $$select id from public.get_feed('stock', 'FFAA', null, 50, null, 'latest', false, null, 'polls')$$,
  $$values ('a2800000-0000-4000-8000-000000000003'::uuid), ('a2800000-0000-4000-8000-000000000002'::uuid)$$,
  'Filter polls hanya memuat post yang punya polling');
select results_eq(
  $$select id from public.get_feed('stock', 'FFAA', null, 50, null, 'latest', false, null, 'media')$$,
  $$select id from public.get_feed('stock', 'FFAA', null, 50, null, 'latest', true)$$,
  'Filter media sama dengan p_media_only');
select results_eq(
  $$select id from public.get_feed('stock', 'FFAA', null, 50, null, 'top', true, null, 'latest')$$,
  $$values ('a2800000-0000-4000-8000-000000000004'::uuid), ('a2800000-0000-4000-8000-000000000003'::uuid),
           ('a2800000-0000-4000-8000-000000000002'::uuid), ('a2800000-0000-4000-8000-000000000001'::uuid)$$,
  'p_filter mengalahkan p_sort dan p_media_only');
select results_eq(
  $$select id from public.get_feed('stock', 'FFAA', null, 50, null, 'latest', false, null, 'top')$$,
  $$values ('a2800000-0000-4000-8000-000000000001'::uuid), ('a2800000-0000-4000-8000-000000000003'::uuid),
           ('a2800000-0000-4000-8000-000000000004'::uuid), ('a2800000-0000-4000-8000-000000000002'::uuid)$$,
  'Filter top mengurutkan berdasarkan suka dan komentar');
select is((select cursor from public.get_feed('stock', 'FFAA', null, 1, null, 'latest', false, null, 'top')),
  'o:1', 'Filter top memakai cursor offset');
select is((select id from public.get_feed('stock', 'FFAA', 'o:1', 1, null, 'latest', false, null, 'top')),
  'a2800000-0000-4000-8000-000000000003'::uuid, 'Cursor o: melanjutkan filter top');
select throws_ok(
  $$select * from public.get_feed('stock', 'FFAA', 'o:1', 1, null, 'latest', false, null, 'polls')$$,
  'PT400', 'invalid_cursor', 'Cursor offset ditolak untuk filter urutan terbaru');
select is((select count(*)::integer from public.get_feed('stock', 'FFAA', null, 50, null, 'latest', false, null)), 4,
  'Panggilan 8 argumen lama tetap jalan');
select is((select count(*)::integer from public.get_feed('stock', 'FFAA', null, 50)), 4,
  'Panggilan 4 argumen lama tetap jalan');
select is((select count(*)::integer from public.get_feed('stock', 'FFAA', null, 50, null, 'latest', false, null, '')), 4,
  'Filter kosong diperlakukan seperti tanpa filter');
select throws_ok(
  $$select * from public.get_feed('global', null, null, 20, null, 'latest', false, null, 'tidak_ada')$$,
  'PT400', 'invalid_filter', 'Filter tidak dikenal ditolak');
reset role;

update public.feed_filters set enabled = false where key = 'polls';
select tests.authenticate_as(:'ani');
select throws_ok(
  $$select * from public.get_feed('global', null, null, 20, null, 'latest', false, null, 'polls')$$,
  'PT400', 'invalid_filter', 'Filter nonaktif ditolak');
select ok(not exists (select 1 from public.get_feed_filters() where key = 'polls'),
  'get_feed_filters menyembunyikan filter nonaktif');
select throws_ok($$select * from public.feed_filters$$, '42501', null, 'Tabel feed_filters tidak bisa dibaca langsung');
select throws_ok($$select cs_api.admin_feed_filters()$$, 'PT403', null, 'Nasabah tidak bisa mengelola filter');
reset role;

select tests.authenticate_anon();
select throws_ok($$select * from public.get_feed_filters()$$, '42501', null, 'Anon tidak bisa membaca filter feed');
reset role;

select tests.authenticate_agent(:'agent');
select throws_ok($$select cs_api.admin_feed_filters()$$, 'PT403', null, 'Agen CS biasa tidak bisa mengelola filter');
reset role;

select tests.authenticate_agent(:'product');
select is(jsonb_array_length(cs_api.admin_feed_filters()), 4, 'Product melihat semua filter termasuk yang nonaktif');
select is(cs_api.admin_save_feed_filter('watch_media', 'Watchlist media', 'Media pantauan', 'top', 'media', 'image') ->> 'position',
  '4', 'Filter baru diletakkan di akhir');
select throws_ok($$select cs_api.admin_save_feed_filter('x', 'A', 'B', 'latest')$$,
  'PT400', 'invalid_filter_key', 'Kunci filter divalidasi');
select throws_ok($$select cs_api.admin_save_feed_filter('video', 'Video', 'Video', 'latest', 'video')$$,
  'PT400', 'invalid_filter_content', 'Isi filter divalidasi');
select results_eq(
  $$select e ->> 'key' from jsonb_array_elements(
      cs_api.admin_reorder_feed_filters(array['polls', 'latest', 'top', 'media', 'watch_media'])) e$$,
  $$values ('polls'::text), ('latest'), ('top'), ('media'), ('watch_media')$$,
  'Urutan filter bisa diubah');
reset role;
select is((select count(*)::integer from cs.cs_audit_log where action like 'feed_filter.%' and actor_id = :'product'), 2,
  'Perubahan filter tercatat di audit');

select * from finish();
rollback;
