begin;
select plan(12);

update private.rate_limits set max_count = 1000 where action = 'post';

select tests.create_user('ts_ani') as ani \gset
select tests.create_user('ts_budi') as budi \gset
select tests.create_user('ts_baru') as baru \gset
update public.profiles set created_at = now() - interval '60 days' where id in (:'ani', :'budi');

insert into public.posts (author_id, body, created_at) values
  (:'ani', 'Bahas #qtagsatu hari ini', now() - interval '1 hour'),
  (:'budi', 'Setuju #qtagsatu', now() - interval '2 hours'),
  (:'baru', 'Ikut #qtagsatu dan #qtagdua', now() - interval '3 hours'),
  (:'ani', 'Lama #qtagtiga', now() - interval '3 days'),
  (:'budi', 'Lama juga #qtagtiga', now() - interval '4 days'),
  (:'baru', 'Sendirian #qtagdua', now() - interval '10 minutes');

select tests.authenticate_as(:'ani');
select is((select count(*)::integer from public.get_trending_hashtags('24h') where tag like 'qtag%'), 0,
  'Hashtag trending dibaca dari snapshot, belum ada sebelum job berjalan');
reset role;

select ok(private.trending_tick() ? 'computed_at', 'Job 5 menit menghitung snapshot');
select is((select count(*)::integer from private.trending_snapshot where kind = 'hashtag' and item_key like 'qtag%'), 3,
  'Snapshot memuat hashtag 24 jam dan 7 hari');

select tests.authenticate_as(:'ani');
select results_eq($$select tag, post_count, author_count, score from public.get_trending_hashtags('24h') where tag like 'qtag%'$$,
  $$values ('qtagsatu'::text, 3, 3, 2.20::numeric)$$,
  'Bentuk hasil tetap dan akun baru berbobot rendah');
select is((select author_count from public.get_trending_hashtags('7d') where tag = 'qtagtiga'), 2,
  'Snapshot 7 hari mencakup postingan lama');
select ok(not exists (select 1 from public.get_trending_hashtags('7d') where tag = 'qtagdua'),
  'Hashtag satu penulis tidak masuk snapshot');
select is((select count(*)::integer from public.get_trending_hashtags('7d', 1)), 1, 'Batas jumlah hasil dihormati');
select ok(public.get_trending('7d') -> 'hashtags' @> '[{"tag": "qtagsatu"}]', 'get_trending memuat hashtag dari snapshot');
select throws_ok($$select * from public.get_trending_hashtags('1y')$$, 'PT400', 'invalid_window', 'Jendela tetap divalidasi');
reset role;

insert into private.content_edits (target_type, target_id, body, edited_at, retain_until, legal_hold) values
  ('post', gen_random_uuid(), 'kedaluwarsa', now() - interval '1900 days', now() - interval '1 day', false),
  ('post', gen_random_uuid(), 'ditahan legal', now() - interval '1900 days', now() - interval '1 day', true),
  ('post', gen_random_uuid(), 'masih berlaku', now() - interval '10 days', now() + interval '1800 days', false);
select ok(private.content_edits_purge() >= 1, 'Riwayat edit kedaluwarsa dibersihkan');
select results_eq($$select body from private.content_edits where body in ('kedaluwarsa', 'ditahan legal', 'masih berlaku') order by body$$,
  $$values ('ditahan legal'::text), ('masih berlaku'::text)$$,
  'Riwayat dengan legal hold atau masih dalam retensi tetap disimpan');
select is((select schedule from cron.job where jobname = 'social-content-edits-retention'), '35 3 * * *',
  'Job retensi riwayat edit terjadwal');

select * from finish();
rollback;
