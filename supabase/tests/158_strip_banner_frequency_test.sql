begin;
select plan(6);

delete from private.app_banners;
update private.rate_limits set max_count = 1000 where action = 'banner_event';

select tests.create_user('sf_budi') as budi \gset
select tests.create_agent('Pandu Strip', '{product}', '{}') as product \gset

select tests.authenticate_agent(:'product');
select cs_api.admin_save_banner(null, 'Pemeliharaan malam ini', p_frequency => 'daily') as strip \gset
select is(:'strip'::jsonb ->> 'frequency', 'daily', 'Strip menyimpan frekuensi sekali sehari');
select is(cs_api.admin_save_banner((:'strip'::jsonb ->> 'id')::uuid, 'Pemeliharaan malam ini',
                                   p_frequency => 'every_open') ->> 'frequency', 'every_open',
  'Frekuensi strip bisa diubah');
select is(cs_api.admin_save_banner(null, 'Info sekali', p_display => 'strip') ->> 'frequency', 'once',
  'Strip tanpa pilihan memakai sekali per pengguna');
reset role;

select is((select e ->> 'frequency' from jsonb_array_elements(private.client_banners('android', '2.0.0', :'budi')) e
            where e ->> 'id' = :'strip'::jsonb ->> 'id'), 'every_open', 'Aplikasi menerima frekuensi strip');

select tests.authenticate_as(:'budi');
select is(public.record_banner_event((:'strip'::jsonb ->> 'id')::uuid, 'impression'), '{"recorded": true}'::jsonb,
  'Tayangan strip tercatat');
reset role;
select is((select count(*)::int from private.app_banner_events
            where banner_id = (:'strip'::jsonb ->> 'id')::uuid and event = 'impression'), 1,
  'Statistik tayang strip bertambah');

select * from finish();
rollback;
