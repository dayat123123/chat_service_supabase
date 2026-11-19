begin;
select plan(14);

delete from private.app_banners;
update private.rate_limits set max_count = 1000 where action = 'banner_event';

select tests.create_user('bh_budi') as budi \gset
select tests.create_user('bh_sari') as sari \gset
select tests.create_agent('Pandu Riwayat', '{product}', '{}') as product \gset

select tests.authenticate_agent(:'product');
select cs_api.admin_save_banner(null, 'Sekali saja', p_frequency => 'once') ->> 'id' as once_id \gset
select cs_api.admin_save_banner(null, 'Boleh ditutup', p_frequency => 'every_open') ->> 'id' as strip_id \gset
reset role;

create temp table bh_banners (who text, item jsonb);
grant all on bh_banners to authenticated, anon;

select tests.authenticate_as(:'budi');
select public.record_banner_event(:'once_id'::uuid, 'impression') as r1 \gset
select public.record_banner_event(:'strip_id'::uuid, 'impression') as r2 \gset
select public.record_banner_event(:'strip_id'::uuid, 'dismiss') as r3 \gset
select public.record_banner_event(:'strip_id'::uuid, 'click') as r4 \gset
insert into bh_banners select 'budi', e from jsonb_array_elements(public.get_client_config('android') -> 'banners') e;
select is(public.get_client_config('android') -> 'config' ->> 'viewer_id', :'budi'::text,
  'Config menyebut pengguna yang memintanya');
reset role;

select tests.authenticate_as(:'sari');
insert into bh_banners select 'sari', e from jsonb_array_elements(public.get_client_config('android') -> 'banners') e;
reset role;

select tests.authenticate_anon();
insert into bh_banners select 'anon', e from jsonb_array_elements(public.get_client_config('android') -> 'banners') e;
select ok((public.get_client_config('android') -> 'config') ? 'viewer_id'
          and public.get_client_config('android') -> 'config' -> 'viewer_id' = 'null'::jsonb,
  'Config tamu menyebut viewer_id kosong');
reset role;

select ok((select (item ->> 'seen_at')::timestamptz > now() - interval '1 minute' from bh_banners
            where who = 'budi' and item ->> 'id' = :'once_id'),
  'Banner yang pernah tayang membawa seen_at milik pengguna itu');
select ok(not (select item ? 'dismissed_at' from bh_banners where who = 'budi' and item ->> 'id' = :'once_id'),
  'Banner yang belum ditutup tidak membawa dismissed_at');
select ok((select item ? 'dismissed_at' and item ? 'seen_at' from bh_banners
            where who = 'budi' and item ->> 'id' = :'strip_id'),
  'Strip yang ditutup membawa dismissed_at dan seen_at');
select is((select count(*)::int from bh_banners where who = 'sari' and (item ? 'seen_at' or item ? 'dismissed_at')), 0,
  'Riwayat satu pengguna tidak bocor ke pengguna lain');
select is((select count(*)::int from bh_banners where who = 'anon' and (item ? 'seen_at' or item ? 'dismissed_at')), 0,
  'Tamu tidak menerima riwayat');
select is((select count(*)::int from bh_banners where who = 'sari'), 2, 'Pengguna lain tetap menerima kedua banner');

update private.app_banner_events
   set created_at = now() - interval '400 days', day = (now() - interval '400 days')::date
 where banner_id = :'once_id'::uuid and user_id = :'budi'::uuid;
insert into private.app_banner_events (banner_id, user_id, event, day, created_at) values
  (:'once_id'::uuid, :'budi'::uuid, 'impression', (now() - interval '500 days')::date, now() - interval '500 days'),
  (:'once_id'::uuid, :'budi'::uuid, 'click', (now() - interval '450 days')::date, now() - interval '450 days'),
  (:'once_id'::uuid, null, 'impression', (now() - interval '450 days')::date, now() - interval '450 days');

select is(private.app_banner_maintenance(), 3,
  'Retensi menghapus tayang lama, klik lama, dan tayang tanpa pengguna');
select is((select count(*)::int from private.app_banner_events
            where banner_id = :'once_id'::uuid and user_id = :'budi'::uuid and event = 'impression'), 1,
  'Tayang terakhir pengguna pada banner aktif disimpan');
select ok((select (e ->> 'seen_at')::timestamptz < now() - interval '399 days'
            from jsonb_array_elements(private.client_banners('android', null, :'budi')) e
            where e ->> 'id' = :'once_id'),
  'Banner sekali per pengguna tetap tahu sudah tayang setelah masa retensi');

update private.app_banners set ends_at = now() - interval '1 minute', starts_at = now() - interval '2 days'
 where id = :'once_id'::uuid;
select is(private.app_banner_maintenance(), 1, 'Riwayat banner yang sudah selesai ikut dihapus setelah masa retensi');

update private.app_banner_events set created_at = now() - interval '400 days', day = (now() - interval '400 days')::date
 where banner_id = :'strip_id'::uuid and event = 'dismiss';
select is(private.app_banner_maintenance(), 0, 'Tutup terakhir pengguna pada banner aktif disimpan');
select ok((select e ? 'dismissed_at' from jsonb_array_elements(private.client_banners('android', null, :'budi')) e
            where e ->> 'id' = :'strip_id'),
  'Strip yang ditutup tetap tersembunyi setelah masa retensi');

select * from finish();
rollback;
