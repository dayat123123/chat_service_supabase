begin;
select plan(47);

update private.rate_limits set max_count = 1000 where action in ('post', 'post_share_link');
update private.settings set value = '0' where key = 'safety.new_account_days';
update cs.cs_settings set value = private.share_links_defaults() where key = 'share.links';

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Nadia', '{cs_agent}', '{"general": 2}') as nadia \gset
select tests.create_user('sl_ani') as ani \gset
select tests.create_user('sl_budi') as budi \gset
select tests.create_user('sl_cici') as cici \gset
update public.profiles
   set avatar_url = 'http://localhost:8000/storage/v1/object/public/avatars/' || id || '/avatar-1.jpg',
       display_name = 'Ani Saham'
 where id = :'ani';
update public.profiles
   set avatar_url = 'http://localhost:8000/storage/v1/object/public/avatars/../secret.jpg'
 where id = :'budi';
insert into public.blocks (blocker_id, blocked_id) values (:'cici', :'ani');

insert into public.posts (author_id, body) values (:'ani', E'Beli   $BBCA\nhari ini') returning id as post \gset
set local session_replication_role = replica;
update public.posts set attachments = jsonb_build_array(
    jsonb_build_object('mime', 'application/pdf', 'path', 'files/x.pdf'),
    jsonb_build_object('mime', 'image/png', 'path', 'posts/' || :'ani' || '/b39350f5-4a6b-4909-94cd-11aad7c50088.png',
                       'width', 1920, 'height', 1080))
 where id = :'post';
set local session_replication_role = origin;
insert into public.posts (author_id, body) values (:'budi', repeat('panjang ', 60)) returning id as long_post \gset
insert into public.posts (author_id, body, moderation_status) values (:'ani', 'Post ditahan', 'hidden')
returning id as held \gset
insert into public.posts (author_id, body) values (:'ani', 'Post akan dihapus') returning id as gone \gset

select tests.authenticate_as(:'ani');
select is(public.get_client_config() -> 'flags' ->> 'post_links', 'false', 'Flag post_links mati selama tautan belum aktif');
select throws_ok(format('select public.post_share_link(%L)', :'post'), 'PT403', 'share_links_disabled',
  'Tautan tidak bisa dibuat sebelum diaktifkan');
reset role;

select tests.authenticate_agent(:'nadia');
select throws_ok($$select cs_api.share_links()$$, 'PT403', 'role_forbidden', 'Agen biasa tidak bisa membaca pengaturan tautan');
select throws_ok($$select cs_api.admin_save_share_links('{}')$$, 'PT403', 'role_forbidden',
  'Agen biasa tidak bisa mengubah pengaturan tautan');
reset role;

select tests.authenticate_agent(:'sinta');
select is(cs_api.share_links() -> 'config' ->> 'enabled', 'false', 'Tautan berbagi mati secara bawaan');
select throws_ok($$select cs_api.admin_save_share_links('{"enabled": true, "preview": true, "base_url": "", "app_name": "OLT", "app_scheme": "olt"}')$$,
  'PT400', 'share_base_url_required', 'Mengaktifkan tanpa domain ditolak');
select throws_ok($$select cs_api.admin_save_share_links('{"enabled": false, "preview": true, "base_url": "https://share.olt.test/p", "app_name": "OLT", "app_scheme": "olt"}')$$,
  'PT400', 'invalid_share_base_url', 'Domain dengan path ditolak');
select throws_ok($$select cs_api.admin_save_share_links('{"enabled": false, "preview": true, "base_url": "ftp://share.olt.test", "app_name": "OLT", "app_scheme": "olt"}')$$,
  'PT400', 'invalid_share_base_url', 'Domain selain http/https ditolak');
select throws_ok($$select cs_api.admin_save_share_links('{"enabled": false, "preview": true, "base_url": "", "app_name": "OLT", "app_scheme": "https"}')$$,
  'PT400', 'invalid_share_app_scheme', 'Skema https tidak boleh dipakai sebagai skema aplikasi');
select throws_ok($$select cs_api.admin_save_share_links('{"enabled": false, "preview": true, "base_url": "", "app_name": "<b>", "app_scheme": "olt"}')$$,
  'PT400', 'invalid_share_app_name', 'Nama aplikasi berisi tag ditolak');
select throws_ok($$select cs_api.admin_save_share_links('{"enabled": false, "preview": "ya", "base_url": "", "app_name": "OLT", "app_scheme": "olt"}')$$,
  'PT400', 'invalid_share_links', 'Saklar pratinjau harus boolean');
select throws_ok($$select cs_api.admin_save_share_links('{"enabled": false, "preview": true, "base_url": "", "app_name": "OLT", "app_scheme": "olt", "android": [{"package": "olt", "sha256": ["AA"]}]}')$$,
  'PT400', 'invalid_share_android_package', 'Package name tanpa titik ditolak');
select throws_ok($$select cs_api.admin_save_share_links('{"enabled": false, "preview": true, "base_url": "", "app_name": "OLT", "app_scheme": "olt", "android": [{"package": "co.olt.app", "sha256": ["AA:BB"]}]}')$$,
  'PT400', 'invalid_share_android_fingerprint', 'Fingerprint SHA-256 pendek ditolak');
select throws_ok($$select cs_api.admin_save_share_links('{"enabled": false, "preview": true, "base_url": "", "app_name": "OLT", "app_scheme": "olt", "ios_app_ids": ["co.olt.app"]}')$$,
  'PT400', 'invalid_share_ios_app_id', 'App ID iOS tanpa Team ID ditolak');
select throws_ok($$select cs_api.admin_save_share_links('{"enabled": false, "preview": true, "base_url": "", "app_name": "OLT", "app_scheme": "olt", "ios_store_url": "http://apps.apple.com/x"}')$$,
  'PT400', 'invalid_share_store_url', 'Tautan unduh tanpa https ditolak');

select is(cs_api.admin_save_share_links(jsonb_build_object(
    'enabled', true, 'preview', true, 'base_url', 'https://share.olt.test/', 'app_name', ' OLT ', 'app_scheme', 'OLT',
    'android', jsonb_build_array(jsonb_build_object('package', 'co.olt.app',
      'sha256', jsonb_build_array(lower(repeat('ab:', 31) || 'ab'), repeat('AB:', 31) || 'AB'))),
    'ios_app_ids', jsonb_build_array('ABCDE12345.co.olt.app'),
    'android_store_url', 'https://play.google.com/store/apps/details?id=co.olt.app')) -> 'config',
  jsonb_build_object(
    'enabled', true, 'preview', true, 'base_url', 'https://share.olt.test', 'app_name', 'OLT', 'app_scheme', 'olt',
    'android', jsonb_build_array(jsonb_build_object('package', 'co.olt.app', 'sha256', jsonb_build_array(repeat('AB:', 31) || 'AB'))),
    'ios_app_ids', jsonb_build_array('ABCDE12345.co.olt.app'),
    'android_store_url', 'https://play.google.com/store/apps/details?id=co.olt.app',
    'ios_store_url', '', 'windows_download_url', '', 'macos_download_url', ''),
  'Pengaturan dinormalisasi: garis miring akhir, spasi, huruf skema, fingerprint duplikat');
select is(cs_api.share_links() ->> 'ready', 'true', 'Hub melihat tautan berbagi siap');
reset role;

select is((select count(*)::integer from cs.cs_audit_log where actor_id = :'sinta' and action = 'setting.share_links'), 1,
  'Perubahan pengaturan tercatat di audit log');
select is((select details -> 'before' ->> 'enabled' from cs.cs_audit_log where actor_id = :'sinta' and action = 'setting.share_links'),
  'false', 'Audit menyimpan nilai sebelum perubahan');

select tests.authenticate_agent(:'sinta');
select lives_ok($$select cs_api.admin_save_share_links(cs_api.share_links() -> 'config')$$, 'Menyimpan tanpa perubahan tetap berhasil');
reset role;
select is((select count(*)::integer from cs.cs_audit_log where actor_id = :'sinta' and action = 'setting.share_links'), 1,
  'Menyimpan tanpa perubahan tidak menambah audit');

select tests.authenticate_as(:'ani');
select is(public.get_client_config() -> 'flags' ->> 'post_links', 'true', 'Flag post_links menyala setelah diaktifkan');
select public.post_share_link(:'post') as link \gset
select matches(:'link'::jsonb ->> 'code', '^[A-Za-z0-9]{10}$', 'Kode tautan 10 karakter alfanumerik');
select is(:'link'::jsonb ->> 'url', 'https://share.olt.test/p/' || (:'link'::jsonb ->> 'code'), 'URL memakai domain tautan');
select is(:'link'::jsonb ->> 'app_url', 'olt://p/' || (:'link'::jsonb ->> 'code'), 'URL aplikasi memakai skema aplikasi');
select is(public.post_share_link(:'post') ->> 'code', :'link'::jsonb ->> 'code', 'Kode yang sama untuk post yang sama');
select throws_ok(format('select public.post_share_link(%L)', :'held'), 'PT404', 'post_not_found', 'Post ditahan moderasi tidak bisa dibagikan');
select throws_ok(format('select public.post_share_link(%L)', gen_random_uuid()), 'PT404', 'post_not_found', 'Post tidak dikenal ditolak');
select is(public.resolve_post_share(:'link'::jsonb ->> 'code'), :'post'::uuid, 'Kode tautan mengarah ke post');
select is(public.resolve_post_share('bukan-kode'), null, 'Kode berformat salah tidak mengarah ke mana pun');
select throws_ok($$select public.share_post_preview('AAAAAAAAAA')$$, '42501', null, 'Pengguna biasa tidak bisa membaca pratinjau publik');
reset role;

select tests.authenticate_as(:'budi');
select is(public.post_share_link(:'post') ->> 'code', :'link'::jsonb ->> 'code', 'Pengguna lain mendapat kode yang sama');
select public.post_share_link(:'long_post') ->> 'code' as long_code \gset
select public.post_share_link(:'gone') ->> 'code' as gone_code \gset
reset role;

select tests.authenticate_as(:'cici');
select throws_ok(format('select public.post_share_link(%L)', :'post'), 'PT404', 'post_not_found',
  'Post dari akun yang diblokir tidak bisa dibagikan oleh pemblokir');
reset role;

select tests.authenticate_anon();
select throws_ok(format('select public.resolve_post_share(%L)', :'link'::jsonb ->> 'code'), '42501', null,
  'Tamu tanpa login tidak bisa membuka kode tautan');
reset role;

select tests.authenticate_service();
select is(public.share_link_config() ->> 'ready', 'true', 'Layanan share-link membaca pengaturan yang siap');
select public.share_post_preview(:'link'::jsonb ->> 'code') as preview \gset
select is(:'preview'::jsonb ->> 'status', 'ok', 'Pratinjau post publik tersedia');
select is(:'preview'::jsonb ->> 'body', 'Beli $BBCA hari ini', 'Isi pratinjau diringkas tanpa spasi berlebih');
select is(:'preview'::jsonb -> 'author' ->> 'display_name', 'Ani Saham', 'Nama penulis ikut di pratinjau');
select is(:'preview'::jsonb -> 'author' ->> 'avatar_path', :'ani' || '/avatar-1.jpg', 'Path avatar diambil dari bucket avatars');
select is(:'preview'::jsonb -> 'image' ->> 'path', 'posts/' || :'ani' || '/b39350f5-4a6b-4909-94cd-11aad7c50088.png',
  'Gambar pertama dipakai, lampiran non-gambar dilewati');
select is(public.share_post_preview(:'long_code') -> 'author' ->> 'avatar_path', null, 'Path avatar dengan .. diabaikan');
select is(public.share_post_preview(:'long_code') ->> 'truncated', 'true', 'Isi panjang ditandai terpotong');
select is(public.share_post_preview('ZZZZZZZZZZ') ->> 'status', 'not_found', 'Kode tidak dikenal tidak ditemukan');
reset role;

update public.posts set deleted_at = now() where id = :'gone';
select tests.authenticate_service();
select is(public.share_post_preview(:'gone_code'), jsonb_build_object('status', 'unavailable', 'code', :'gone_code'),
  'Post yang dihapus tidak menampilkan isi apa pun');
reset role;
select tests.authenticate_as(:'ani');
select is(public.resolve_post_share(:'gone_code'), null, 'Kode post yang dihapus tidak dibuka di aplikasi');
reset role;

update cs.cs_settings set value = value || '{"preview": false}' where key = 'share.links';
select tests.authenticate_service();
select is(public.share_post_preview(:'link'::jsonb ->> 'code'),
  jsonb_build_object('status', 'ok', 'code', :'link'::jsonb ->> 'code', 'preview', false),
  'Saat pratinjau dimatikan, halaman tidak membawa isi post');
reset role;

update cs.cs_settings set value = value || '{"enabled": false}' where key = 'share.links';
select tests.authenticate_service();
select is(public.share_post_preview(:'link'::jsonb ->> 'code') ->> 'status', 'disabled', 'Tautan mati saat fitur dimatikan');
reset role;

select * from finish();
rollback;
