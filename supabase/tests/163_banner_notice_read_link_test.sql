begin;
select plan(11);

update private.rate_limits set max_count = 1000 where action in ('banner_event', 'notification_event');
update cs.cs_settings set value = '100000' where key = 'integration.broadcast_batch_size';

select tests.create_user('rl_budi') as budi \gset
select tests.create_user('rl_sari') as sari \gset
select tests.create_agent('Pandu Baca', '{product}', '{}') as pandu \gset

select tests.authenticate_agent(:'pandu');
select cs_api.admin_save_banner(null, 'Promo popup', 'Isi popup', p_display => 'popup', p_notify => true) ->> 'id' as popup \gset
select cs_api.admin_save_banner(null, 'Info strip', 'Isi strip', p_notify => true) ->> 'id' as strip \gset
select cs_api.admin_save_banner(null, 'Dari notifikasi', 'Isi', p_display => 'popup', p_notify => true) ->> 'id' as from_note \gset
reset role;
select private.app_notice_tick();

create temp table rl_unread as
select user_id, payload ->> 'banner_id' as banner_id, id from public.notifications where payload ? 'banner_id';
grant all on rl_unread to authenticated;

select ok(exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications')
          and (select pubupdate from pg_publication where pubname = 'supabase_realtime'),
  'Perubahan read_at notifikasi dikirim lewat realtime');

select tests.authenticate_as(:'budi');
select public.record_banner_event(:'strip'::uuid, 'impression') as r1 \gset
reset role;
select ok((select read_at is null from public.notifications where user_id = :'budi' and payload ->> 'banner_id' = :'strip'),
  'Strip yang sekadar tayang tidak membuat notifikasinya terbaca');

select tests.authenticate_as(:'budi');
select public.record_banner_event(:'popup'::uuid, 'impression') as r2 \gset
reset role;
select ok((select read_at is not null from public.notifications where user_id = :'budi' and payload ->> 'banner_id' = :'popup'),
  'Popup yang tampil membuat notifikasi banner yang sama terbaca');
select ok((select read_at is null from public.notifications where user_id = :'sari' and payload ->> 'banner_id' = :'popup'),
  'Notifikasi nasabah lain tidak ikut terbaca');
select ok((select read_at is null from public.notifications where user_id = :'budi' and payload ->> 'banner_id' = :'from_note'),
  'Notifikasi banner lain tetap belum terbaca');

select tests.authenticate_as(:'budi');
select public.record_banner_event(:'strip'::uuid, 'click') as r3 \gset
reset role;
select ok((select read_at is not null from public.notifications where user_id = :'budi' and payload ->> 'banner_id' = :'strip'),
  'Klik tombol strip membuat notifikasinya terbaca');

select ok(not ((select e from jsonb_array_elements(private.client_banners('android', null, :'budi')) e
                where e ->> 'id' = :'from_note') ? 'seen_at'),
  'Popup belum dianggap tayang sebelum notifikasinya dibuka');
select (select id from rl_unread where user_id = :'budi' and banner_id = :'from_note') as note \gset
select tests.authenticate_as(:'budi');
select public.report_notification_event('opened', :'note') as r4 \gset
reset role;
select ok(((select e from jsonb_array_elements(private.client_banners('android', null, :'budi')) e
            where e ->> 'id' = :'from_note') ->> 'seen_at')::timestamptz > now() - interval '1 minute',
  'Membuka notifikasinya dihitung sebagai sudah melihat popup');
select ok(((select e from jsonb_array_elements(private.client_banners('android', null, :'budi')) e
            where e ->> 'id' = :'popup') ->> 'seen_at') is not null,
  'Tayangan popup tetap tercatat sebagai seen_at');

update public.notifications set read_at = now() where user_id = :'sari';
select ok(not ((select e from jsonb_array_elements(private.client_banners('android', null, :'sari')) e
                where e ->> 'id' = :'from_note') ? 'seen_at'),
  'Tandai semua terbaca tidak menghentikan popup yang belum pernah dilihat');
select ok(not ((select e from jsonb_array_elements(private.client_banners('android', null, :'sari')) e
                where e ->> 'id' = :'popup') ? 'seen_at'),
  'Riwayat nasabah lain tidak terpengaruh');

select * from finish();
rollback;
