begin;
select plan(27);

update private.rate_limits set max_count = 1000 where action in ('post', 'comment');

select tests.create_user('sd_ani') as ani \gset
select tests.create_user('sd_budi') as budi \gset
select tests.create_user('sd_cici') as cici \gset
select tests.create_user('sd_dodi') as dodi \gset
select tests.create_user('sd_eko') as eko \gset
select tests.create_user('sd_resmi') as resmi \gset
update public.profiles set created_at = now() - interval '60 days'
 where id in (:'ani', :'budi', :'cici', :'dodi', :'eko', :'resmi');
insert into cs.official_accounts (profile_id) values (:'resmi');

select private.trending_refresh(now() - interval '1 hour') >= 0 as refreshed \gset
select tests.authenticate_as(:'ani');
select (public.get_market_sentiment('24h') ->> 'posts')::integer as posts0,
       (public.get_market_sentiment('24h') ->> 'bullish')::integer as bull0 \gset
select coalesce((select posts_today from public.get_stock_stats(array['UNVR']) where code = 'UNVR'), 0) as unvr0,
       coalesce((select posts_today from public.get_stock_stats(array['ADRO']) where code = 'ADRO'), 0) as adro0 \gset
reset role;

insert into public.posts (id, author_id, body, sentiment, like_count, created_at) values
  ('a2200000-0000-4000-8000-000000000001', :'budi', 'Bahas $UNVR dan $ADRO hari ini', 'bullish', 1000, now() - interval '3 minutes'),
  ('a2200000-0000-4000-8000-000000000002', :'cici', 'Pandangan $ADRO minggu ini', 'bearish', 2000, now() - interval '2 minutes'),
  ('a2200000-0000-4000-8000-000000000004', :'resmi', 'Riset resmi pekan ini', null, 0, now() - interval '4 minutes'),
  ('a2200000-0000-4000-8000-000000000005', :'ani', 'Catatan saya sendiri', null, 9000, now() - interval '5 minutes');
insert into public.posts (id, author_id, body, attachments, like_count, created_at) values
  ('a2200000-0000-4000-8000-000000000003', :'budi', 'Grafik $UNVR',
   jsonb_build_array(jsonb_build_object('path', 'posts/' || :'budi' || '/grafik.png', 'mime', 'image/png')), 1500,
   now() - interval '1 minute');
insert into public.posts (id, author_id, body, sentiment, created_at, moderation_status) values
  ('a2200000-0000-4000-8000-000000000006', :'budi', 'Ditahan moderator', 'bullish', now() - interval '1 minute', 'held');
insert into public.comments (id, post_id, author_id, body) values
  ('a2200000-0000-4000-8000-0000000000c1', 'a2200000-0000-4000-8000-000000000001', :'cici', 'Komentar pertama'),
  ('a2200000-0000-4000-8000-0000000000c2', 'a2200000-0000-4000-8000-000000000001', :'dodi', 'Komentar paling disukai');
update public.comments set like_count = 10 where id = 'a2200000-0000-4000-8000-0000000000c2';

insert into public.follows (follower_id, following_id) values
  (:'ani', :'budi'), (:'ani', :'cici'), (:'budi', :'dodi'), (:'cici', :'dodi'), (:'budi', :'eko');
insert into public.blocks (blocker_id, blocked_id) values (:'ani', :'eko');
select private.trending_refresh(now() - interval '1 hour') >= 0 as refreshed \gset

select tests.authenticate_as(:'ani');

select is((select count(*)::integer from public.get_feed('global', null, null, 3)), 3,
  'Panggilan get_feed lama tanpa parameter baru tetap jalan');
select results_eq(
  $$select id from public.get_feed('stocks', null, null, 50, null, 'latest', false, array['unvr', '$ADRO'])
    where id::text like 'a2200000-%'$$,
  $$values ('a2200000-0000-4000-8000-000000000003'::uuid), ('a2200000-0000-4000-8000-000000000002'::uuid),
           ('a2200000-0000-4000-8000-000000000001'::uuid)$$,
  'Scope stocks menggabungkan beberapa saham tanpa duplikat, terbaru dulu');
select results_eq(
  $$select id from public.get_feed('stocks', null, null, 50, null, 'top', false, array['UNVR', 'ADRO'])
    where id::text like 'a2200000-%'$$,
  $$values ('a2200000-0000-4000-8000-000000000002'::uuid), ('a2200000-0000-4000-8000-000000000003'::uuid),
           ('a2200000-0000-4000-8000-000000000001'::uuid)$$,
  'Urutan top: suka + komentar terbanyak lebih dulu');
select is((select cursor from public.get_feed('stocks', null, null, 1, null, 'top', false, array['UNVR', 'ADRO'])),
  'o:1', 'Cursor urutan top adalah offset');
select is((select cursor from public.get_feed('stocks', null, 'o:1', 1, null, 'top', false, array['UNVR', 'ADRO'])),
  'o:2', 'Cursor top melanjutkan ke halaman berikutnya');
select isnt((select id from public.get_feed('stocks', null, 'o:1', 1, null, 'top', false, array['UNVR', 'ADRO'])),
  (select id from public.get_feed('stocks', null, null, 1, null, 'top', false, array['UNVR', 'ADRO'])),
  'Halaman kedua top tidak mengulang post pertama');
select results_eq(
  $$select id from public.get_feed('stocks', null, null, 50, null, 'latest', true, array['UNVR', 'ADRO'])
    where id::text like 'a2200000-%'$$,
  $$values ('a2200000-0000-4000-8000-000000000003'::uuid)$$,
  'media_only hanya memuat post bergambar');
select ok((select bool_and(author_is_official) from public.get_feed('official', null, null, 50)),
  'Scope official hanya memuat akun resmi');
select ok(exists (select 1 from public.get_feed('official', null, null, 50) where id = 'a2200000-0000-4000-8000-000000000004'),
  'Scope official memuat post akun resmi');
select ok(exists (select 1 from public.get_feed('for_you', null, null, 50) where id = 'a2200000-0000-4000-8000-000000000002'),
  'Scope for_you memuat post populer');
select ok(not exists (select 1 from public.get_feed('for_you', null, null, 50) where author_id = :'ani'),
  'Scope for_you tidak memuat post sendiri');
select ok(not exists (select 1 from public.get_feed('for_you', null, null, 50) where id = 'a2200000-0000-4000-8000-000000000006'),
  'Post yang ditahan tidak masuk for_you');
select is((select top_comment ->> 'id' from public.get_post('a2200000-0000-4000-8000-000000000001')),
  'a2200000-0000-4000-8000-0000000000c2', 'top_comment memuat komentar teratas paling disukai');
select is((select top_comment from public.get_post('a2200000-0000-4000-8000-000000000002')), null,
  'Post tanpa komentar tidak punya top_comment');
select throws_ok($$select * from public.get_feed('global', null, null, 20, null, 'random')$$,
  'PT400', 'invalid_sort', 'Urutan feed di luar daftar ditolak');
select throws_ok($$select * from public.get_feed('global', null, 'o:3')$$,
  'PT400', 'invalid_cursor', 'Cursor offset tidak berlaku untuk urutan terbaru');
select throws_ok(
  $$select * from public.get_feed('stocks', null, null, 20, null, 'latest', false,
                                 array(select 'S' || g from generate_series(1, 51) g))$$,
  'PT400', 'too_many_stocks', 'Jumlah saham dibatasi');
select throws_ok($$select * from public.get_feed('stocks')$$,
  'PT400', 'stock_code_required', 'Scope stocks wajib kode saham');

select is((select username from public.get_suggested_users(5) limit 1), 'sd_dodi',
  'Saran akun mendahulukan yang diikuti teman');
select is((select mutual_count from public.get_suggested_users(5) where id = :'dodi'), 2,
  'Saran akun memuat jumlah teman yang mengikuti');
select ok(not exists (select 1 from public.get_suggested_users(20) where id in (:'ani', :'budi', :'cici', :'eko')),
  'Saran akun tanpa diri sendiri, yang sudah diikuti, dan yang diblokir');

select is((public.get_market_sentiment('24h') ->> 'posts')::integer, :posts0 + 5,
  'Mood pasar menghitung post yang tampil saja');
select is((public.get_market_sentiment('24h') ->> 'bullish')::integer, :bull0 + 1,
  'Mood pasar menghitung label bullish');
select throws_ok($$select public.get_market_sentiment('1y')$$, 'PT400', 'invalid_window', 'Jendela mood divalidasi');

select results_eq(
  $$select code, posts_today from public.get_stock_stats(array['adro', '$UNVR', 'bukan-kode'])$$,
  format('values (%L::text, %s::integer), (%L::text, %s::integer)', 'ADRO', :adro0 + 2, 'UNVR', :unvr0 + 2),
  'Statistik saham per hari, kode tidak valid diabaikan');
reset role;

select tests.authenticate_anon();
select throws_ok($$select * from public.get_suggested_users()$$, '42501', null, 'Anon tidak bisa membaca saran akun');
reset role;

update private.settings set value = '0' where key = 'feed.for_you_days';
select tests.authenticate_as(:'ani');
select ok((select bool_and(cursor not like 'o:%') from public.get_feed('for_you', null, null, 5)),
  'for_you kembali ke feed terbaru bila belum ada peringkat');
reset role;

select * from finish();
rollback;
