begin;
select plan(17);

update private.rate_limits set max_count = 1000 where action in ('post', 'post_share_link');
update private.settings set value = '0' where key = 'safety.new_account_days';
update cs.cs_settings set value = private.share_links_defaults() || '{"enabled": true, "base_url": "https://share.olt.test"}'
 where key = 'share.links';

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Nadia', '{cs_agent}', '{"general": 2}') as nadia \gset
select tests.create_user('ss_ani') as ani \gset
select tests.create_user('ss_budi') as budi \gset

insert into public.posts (author_id, body) values (:'ani', E'Cek   $BBCA\nhari ini') returning id as post \gset
insert into public.posts (author_id, body) values (:'budi', 'Post kedua') returning id as second \gset

select tests.authenticate_as(:'budi');
select public.post_share_link(:'post') ->> 'code' as code \gset
select public.post_share_link(:'second') ->> 'code' as second_code \gset
reset role;

select tests.authenticate_as(:'ani');
select throws_ok($$select public.share_link_record_stats('[]')$$, '42501', null,
  'Pengguna biasa tidak bisa mencatat statistik tautan');
select is(public.resolve_post_share(:'code'), :'post'::uuid, 'Membuka kode di aplikasi tetap mengarah ke post');
select is(public.resolve_post_share(:'code'), :'post'::uuid, 'Membuka kedua kali tetap berhasil');
select is(public.resolve_post_share('ZZZZZZZZZZ'), null, 'Kode tidak dikenal tidak dicatat');
reset role;

select is((select app_opens from private.post_share_daily where post_id = :'post'), 2,
  'Setiap pembukaan lewat aplikasi dihitung');

select tests.authenticate_service();
select is(public.share_link_record_stats(jsonb_build_array(
    jsonb_build_object('code', :'code', 'views', 5, 'previews', 2, 'opens', 3, 'android', 1, 'windows', 2),
    jsonb_build_object('code', :'code', 'views', 1),
    jsonb_build_object('code', 'ZZZZZZZZZZ', 'views', 9),
    jsonb_build_object('code', :'second_code', 'views', -4, 'mac', 1))), 2,
  'Baris dengan kode dikenal digabung per post; kode tak dikenal diabaikan');
select is(public.share_link_record_stats(jsonb_build_array(jsonb_build_object('code', :'code', 'views', 4, 'ios', 1))), 1,
  'Kiriman berikutnya menambah hitungan hari yang sama');
select throws_ok($$select public.share_link_record_stats('{"code": "x"}')$$, 'PT400', 'invalid_share_stats',
  'Isi selain array ditolak');
select throws_ok($$select public.share_link_record_stats('[1]')$$, 'PT400', 'invalid_share_stats',
  'Baris selain objek ditolak');
reset role;

select is((select row(views, previews, opens, app_opens, android, ios, windows, mac)::text
           from private.post_share_daily where post_id = :'post'),
  '(10,2,3,2,1,1,2,0)', 'Hitungan harian post pertama sesuai');
select is((select row(views, mac)::text from private.post_share_daily where post_id = :'second'),
  '(0,1)', 'Nilai negatif dianggap nol');

insert into private.post_share_daily (post_id, day, views) values (:'second', private.share_stats_day() - 40, 50);

select tests.authenticate_agent(:'nadia');
select throws_ok($$select cs_api.share_link_stats(30)$$, 'PT403', 'role_forbidden', 'Agen biasa tidak bisa membaca statistik');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.share_link_stats(14)$$, 'PT400', 'invalid_share_stats_days', 'Rentang selain 7/30/90 ditolak');
select cs_api.share_link_stats(30) as stats \gset
select is(:'stats'::jsonb -> 'totals',
  '{"views": 10, "previews": 2, "opens": 3, "app_opens": 2, "android": 1, "ios": 1, "windows": 2, "mac": 1, "posts": 2}'::jsonb,
  'Total 30 hari tidak memasukkan data 40 hari lalu');
select is(jsonb_array_length(:'stats'::jsonb -> 'daily'), 30, 'Deret harian berisi 30 hari termasuk hari kosong');
select is(:'stats'::jsonb -> 'top' -> 0 ->> 'code', :'code', 'Post paling banyak dilihat ada di urutan pertama');
select is(:'stats'::jsonb -> 'top' -> 0 ->> 'body', 'Cek $BBCA hari ini', 'Cuplikan isi diringkas');
reset role;

select * from finish();
rollback;
