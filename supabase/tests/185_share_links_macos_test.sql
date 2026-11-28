begin;
select plan(6);

update cs.cs_settings set value = private.share_links_defaults() where key = 'share.links';
select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset

select is(private.share_links_defaults() ->> 'macos_download_url', '', 'Bawaan tautan unduh Mac kosong');

select tests.authenticate_agent(:'sinta');
select is(cs_api.share_links() -> 'config' ->> 'macos_download_url', '', 'Hub membaca kolom unduhan Mac');
select is(cs_api.admin_save_share_links(jsonb_build_object(
    'enabled', true, 'preview', true, 'base_url', 'http://192.168.0.235:8000', 'app_name', 'OLT', 'app_scheme', 'olt',
    'macos_download_url', ' https://unduh.olt.test/OLT.dmg ')) -> 'config' ->> 'macos_download_url',
  'https://unduh.olt.test/OLT.dmg', 'Tautan unduh Mac disimpan tanpa spasi');
select throws_ok($$select cs_api.admin_save_share_links('{"enabled": false, "preview": true, "base_url": "", "app_name": "OLT", "app_scheme": "olt", "macos_download_url": "http://unduh.olt.test/OLT.dmg"}')$$,
  'PT400', 'invalid_share_store_url', 'Tautan unduh Mac tanpa https ditolak');
select is(cs_api.admin_save_share_links('{"enabled": false, "preview": true, "base_url": "", "app_name": "OLT", "app_scheme": "olt"}')
  -> 'config' ->> 'macos_download_url', '', 'Pengaturan lama tanpa kolom Mac tetap bisa disimpan');
reset role;

select tests.authenticate_service();
select is(public.share_link_config() ->> 'macos_download_url', '', 'Layanan share-link menerima kolom unduhan Mac');
reset role;

select * from finish();
rollback;
