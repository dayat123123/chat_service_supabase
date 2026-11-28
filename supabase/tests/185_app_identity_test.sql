begin;
select plan(19);

update private.rate_limits set max_count = 1000 where action in ('post', 'post_share_link');
update cs.cs_settings set value = private.app_identity_defaults() where key = 'app.identity';
select private.app_identity_defaults() as identity_defaults \gset
update cs.cs_settings set value = '["olt"]' where key = 'banners.deep_link_schemes';
update cs.cs_settings set value = '{"enabled": true, "base_url": "http://192.168.0.235:8000", "preview": true}' where key = 'share.links';

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Nadia', '{cs_agent}', '{"general": 2}') as nadia \gset
select tests.create_user('ai_ani') as ani \gset
insert into public.posts (author_id, body) values (:'ani', 'Post identitas') returning id as post \gset

select tests.authenticate_agent(:'nadia');
select throws_ok($$select cs_api.app_identity()$$, 'PT403', 'role_forbidden', 'Agen biasa tidak bisa membaca identitas aplikasi');
select throws_ok($$select cs_api.admin_save_app_identity('{}')$$, 'PT403', 'role_forbidden', 'Agen biasa tidak bisa mengubah identitas aplikasi');
reset role;

select tests.authenticate_agent(:'sinta');
select is(cs_api.app_identity() -> 'identity', :'identity_defaults'::jsonb, 'Identitas bawaan: OLT tanpa aplikasi terdaftar');
select is(cs_api.app_identity() ->> 'app_scheme', 'olt', 'Skema utama diambil dari daftar skema aplikasi');
select throws_ok($$select cs_api.admin_save_app_identity('{"app_name": "<b>"}')$$,
  'PT400', 'invalid_share_app_name', 'Nama aplikasi berisi tag ditolak');
select throws_ok($$select cs_api.admin_save_app_identity('{"app_name": "OLT", "android": [{"package": "olt", "sha256": ["AA"]}]}')$$,
  'PT400', 'invalid_share_android_package', 'Package name tanpa titik ditolak');
select throws_ok($$select cs_api.admin_save_app_identity('{"app_name": "OLT", "android": [{"package": "co.olt.app", "sha256": ["AA:BB"]}]}')$$,
  'PT400', 'invalid_share_android_fingerprint', 'Fingerprint SHA-256 pendek ditolak');
select throws_ok($$select cs_api.admin_save_app_identity('{"app_name": "OLT", "ios_app_ids": ["co.olt.app"]}')$$,
  'PT400', 'invalid_share_ios_app_id', 'App ID tanpa Team ID ditolak');
select throws_ok($$select cs_api.admin_save_app_identity('{"app_name": "OLT", "macos_download_url": "http://unduh.olt.test/OLT.dmg"}')$$,
  'PT400', 'invalid_share_store_url', 'Tautan unduh Mac tanpa https ditolak');

select is(cs_api.admin_save_app_identity(jsonb_build_object(
    'app_name', ' OLT ',
    'android', jsonb_build_array(jsonb_build_object('package', 'co.olt.app',
      'sha256', jsonb_build_array(lower(repeat('ab:', 31) || 'ab'), repeat('AB:', 31) || 'AB'))),
    'ios_app_ids', jsonb_build_array('ABCDE12345.co.olt.app', 'ABCDE12345.co.olt.mac'),
    'android_store_url', 'https://play.google.com/store/apps/details?id=co.olt.app',
    'macos_download_url', ' https://unduh.olt.test/OLT.dmg ')) -> 'identity',
  jsonb_build_object(
    'app_name', 'OLT',
    'android', jsonb_build_array(jsonb_build_object('package', 'co.olt.app', 'sha256', jsonb_build_array(repeat('AB:', 31) || 'AB'))),
    'ios_app_ids', jsonb_build_array('ABCDE12345.co.olt.app', 'ABCDE12345.co.olt.mac'),
    'android_store_url', 'https://play.google.com/store/apps/details?id=co.olt.app',
    'ios_store_url', '', 'windows_download_url', '', 'macos_download_url', 'https://unduh.olt.test/OLT.dmg'),
  'Identitas dinormalisasi: spasi, fingerprint duplikat, App ID iOS dan Mac, unduhan Mac');
select lives_ok($$select cs_api.admin_save_app_identity(cs_api.app_identity() -> 'identity')$$, 'Menyimpan tanpa perubahan tetap berhasil');
reset role;

select is((select count(*)::integer from cs.cs_audit_log where actor_id = :'sinta' and action = 'setting.app_identity'), 1,
  'Perubahan identitas tercatat sekali di audit log');

select tests.authenticate_service();
select is(public.share_link_config() -> 'android' -> 0 ->> 'package', 'co.olt.app', 'Layanan share-link membaca Android dari identitas aplikasi');
select is(public.share_link_config() ->> 'macos_download_url', 'https://unduh.olt.test/OLT.dmg', 'Layanan share-link membaca unduhan Mac');
reset role;

select tests.authenticate_agent(:'sinta');
select is(cs_api.admin_set_banner_link_schemes('{oltpro,olt}') -> 'deep_link_schemes', '["oltpro", "olt"]'::jsonb,
  'Urutan skema mengikuti yang diketik');
select is(cs_api.app_identity() ->> 'app_scheme', 'oltpro', 'Skema pertama menjadi skema utama');
reset role;

select tests.authenticate_as(:'ani');
select matches(public.post_share_link(:'post') ->> 'app_url', '^oltpro://p/[A-Za-z0-9]{10}$', 'Tautan aplikasi memakai skema utama');
reset role;

update cs.cs_settings set value = '[]' where key = 'banners.deep_link_schemes';
select tests.authenticate_as(:'ani');
select is(public.post_share_link(:'post') ->> 'app_url', null, 'Tanpa skema, tautan tetap dibuat tanpa tautan aplikasi');
reset role;

select tests.authenticate_service();
select is(public.share_link_config() ->> 'app_scheme', '', 'Halaman tanpa skema tidak menampilkan tombol buka aplikasi');
reset role;

select * from finish();
rollback;
