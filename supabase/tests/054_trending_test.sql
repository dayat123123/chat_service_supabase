begin;
select plan(22);

update private.rate_limits set max_count = 1000 where action = 'post';

select tests.create_user('tr_ani') as ani \gset
select tests.create_user('tr_budi') as budi \gset
select tests.create_user('tr_cici') as cici \gset
select tests.create_user('tr_baru') as baru \gset
update public.profiles set created_at = now() - interval '60 days' where id in (:'ani', :'budi', :'cici');

insert into public.posts (id, author_id, body, sentiment, created_at) values
  ('00000000-0000-4000-8000-00000000f401', :'ani', 'Akumulasi $QZXA lanjut', 'bullish', now() - interval '2 hours'),
  ('00000000-0000-4000-8000-00000000f402', :'budi', '$QZXA tembus resisten', 'bullish', now() - interval '3 hours'),
  ('00000000-0000-4000-8000-00000000f403', :'cici', '$QZXA rawan koreksi', 'bearish', now() - interval '20 minutes'),
  ('00000000-0000-4000-8000-00000000f404', :'cici', 'Cuma pantau $QZXA', null, now() - interval '10 minutes'),
  ('00000000-0000-4000-8000-00000000f405', :'baru', '$QZXB to the moon', 'bullish', now() - interval '10 minutes'),
  ('00000000-0000-4000-8000-00000000f406', :'baru', '$QZXB pasti naik', 'bullish', now() - interval '10 minutes'),
  ('00000000-0000-4000-8000-00000000f407', :'ani', '$QZXA kemarin sepi', 'neutral', now() - interval '30 hours'),
  ('00000000-0000-4000-8000-00000000f408', :'budi', '$QZXC ramai', null, now() - interval '1 hour');
insert into public.posts (author_id, body, created_at)
select (array[:'ani', :'budi', :'cici']::uuid[])[1 + g % 3], '$QZXC diskusi ke-' || g, now() - make_interval(mins => 20 + g)
from generate_series(1, 6) g;
update public.posts set like_count = 9 where id = '00000000-0000-4000-8000-00000000f402';

select ok(private.trending_rebuild() ? 'computed_at', 'Agregat dan snapshot trending dihitung ulang');
select is((select sum(posts)::integer from private.stock_mention_buckets
           where stock_code = 'QZXA' and bucket > now() - interval '24 hours'), 4,
  'Agregat 5 menit menghitung post per saham');
select is((select sum(authors)::integer from private.stock_mention_buckets
           where stock_code = 'QZXB' and bucket > now() - interval '24 hours'), 1,
  'Satu penulis dihitung sekali per jendela 5 menit');

select tests.authenticate_anon();
select throws_ok($$select public.get_trending()$$, '42501', null, 'Trending hanya untuk pengguna masuk');
reset role;

select tests.authenticate_as(:'ani');
select public.get_stock_sentiment('$qzxa') as sent \gset
select is(:'sent'::jsonb -> '24h' ->> 'posts', '4', 'Sentimen 24 jam menghitung post');
select is(:'sent'::jsonb -> '24h' ->> 'bullish', '2', 'Jumlah post bullish 24 jam');
select is(:'sent'::jsonb -> '24h' ->> 'unlabeled', '1', 'Post tanpa label sentimen dipisahkan');
select is(:'sent'::jsonb -> '24h' ->> 'bullish_pct', '67', 'Persentase sentimen dihitung dari post berlabel');
select is(:'sent'::jsonb -> '7d' ->> 'posts', '5', 'Sentimen 7 hari mencakup post lebih lama');
select is(:'sent'::jsonb -> '7d' ->> 'neutral', '1', 'Post netral dihitung');
select throws_ok($$select public.get_stock_sentiment('12')$$, 'PT400', 'invalid_stock_code', 'Kode saham divalidasi');
select is(public.get_stock_sentiment('QZXZ') -> '24h' ->> 'posts', '0', 'Saham tanpa diskusi bernilai nol');

select public.get_trending('24h') as tr \gset
select is((select jsonb_agg(e ->> 'code') from jsonb_array_elements(:'tr'::jsonb -> 'stocks') e
           where e ->> 'code' like 'QZX%'), '["QZXC", "QZXA", "QZXB"]'::jsonb,
  'Saham trending diurutkan dari skor penulis berbobot');
select is((select e ->> 'posts' from jsonb_array_elements(:'tr'::jsonb -> 'stocks') e where e ->> 'code' = 'QZXB'), '2',
  'Akun baru tetap dihitung jumlah postnya');
select ok((select (e ->> 'score')::numeric from jsonb_array_elements(:'tr'::jsonb -> 'stocks') e where e ->> 'code' = 'QZXB')
          < (select (e ->> 'score')::numeric from jsonb_array_elements(:'tr'::jsonb -> 'stocks') e where e ->> 'code' = 'QZXA'),
  'Akun baru berbobot rendah sehingga tidak bisa mendongkrak trending sendirian');
select ok(:'tr'::jsonb -> 'rising' @> '[{"code": "QZXC"}]', 'Saham dengan diskusi naik tampil di rising');
select is(:'tr'::jsonb -> 'posts' -> 0 ->> 'id', '00000000-0000-4000-8000-00000000f402',
  'Post populer memakai skor peluruhan waktu');
select ok(:'tr'::jsonb ? 'hashtags', 'Trending memuat hashtag populer');
select throws_ok($$select public.get_trending('30d')$$, 'PT400', 'invalid_window', 'Jendela trending divalidasi');
reset role;

insert into public.blocks (blocker_id, blocked_id) values (:'cici', :'budi');
select tests.authenticate_as(:'cici');
select ok(not (public.get_trending('24h') -> 'posts' @> '[{"id": "00000000-0000-4000-8000-00000000f402"}]'),
  'Post populer dari user yang diblokir tidak tampil');
reset role;

select is(private.manipulation_alert_codes() is not null, true, 'Daftar alert manipulasi aman dibaca walau belum ada');
create or replace function private.manipulation_alert_codes()
returns text[] language sql stable set search_path = '' as $$ select array['QZXC'] $$;
select private.trending_compute() as recomputed \gset
select tests.authenticate_as(:'ani');
select ok((select jsonb_agg(e ->> 'code') from jsonb_array_elements(public.get_trending('24h') -> 'stocks') e
           where e ->> 'code' like 'QZX%') -> 0 = '"QZXA"',
  'Saham dengan alert manipulasi terbuka diturunkan bobotnya');
reset role;

select * from finish();
rollback;
