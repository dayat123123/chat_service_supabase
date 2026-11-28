begin;
select plan(8);

update private.rate_limits set max_count = 1000 where action = 'notification_prefs';
update cs.cs_settings set value = 'false' where key = 'trade_share.enabled';
select tests.create_user('thp_budi') as budi \gset

select ok(not (private.notification_pref_types() && array['trade_activity', 'trade_share']),
  'Jenis notifikasi Berbagi Trade disembunyikan saat fitur mati');

select tests.authenticate_as(:'budi');
select is((select count(*) from jsonb_array_elements(public.get_notification_prefs() -> 'types') e
           where e ->> 'type' in ('trade_activity', 'trade_share')), 0::bigint,
  'Pengaturan notifikasi nasabah tidak menampilkan Berbagi Trade saat fitur mati');
select is(jsonb_array_length(public.get_notification_prefs() -> 'types'), 16,
  'Pengaturan notifikasi memuat enam belas jenis saat fitur mati');
select ok(not (public.get_client_config() #> '{config,notification_types}') ?| array['trade_activity', 'trade_share'],
  'Konfigurasi klien tidak mengumumkan jenis Berbagi Trade saat fitur mati');
select throws_ok($$select public.set_notification_prefs('{"types": [{"type": "trade_activity", "push": false}]}')$$,
  'PT400', 'invalid_notification_type', 'Preferensi Berbagi Trade tidak bisa diubah saat fitur mati');

reset role;
update cs.cs_settings set value = 'true' where key = 'trade_share.enabled';
select tests.authenticate_as(:'budi');
select is((select array_agg(e ->> 'type' order by e ->> 'type') from jsonb_array_elements(public.get_notification_prefs() -> 'types') e
           where e ->> 'type' in ('trade_activity', 'trade_share')), array['trade_activity', 'trade_share'],
  'Jenis Berbagi Trade muncul lagi saat fitur dinyalakan');
select lives_ok($$select public.set_notification_prefs('{"types": [{"type": "trade_activity", "push": false}]}')$$,
  'Preferensi Berbagi Trade bisa diubah saat fitur menyala');
select ok((public.get_client_config() #> '{config,notification_types}') ?& array['trade_activity', 'trade_share'],
  'Konfigurasi klien mengumumkan jenis Berbagi Trade saat fitur menyala');

reset role;
select * from finish();
rollback;
