begin;
select plan(19);

delete from private.app_banners;

select tests.create_agent('Sinta Produk', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Putri Produk', '{product}', '{}') as putri \gset
select tests.create_agent('Rina Produk', '{cs_agent}', '{"general": 1}') as rina \gset
select gen_random_uuid() || '.png' as img \gset

select ok((select roles = '{product}' from cs.agents where user_id = :'putri'),
  'Peran Fitur & Kampanye (product) bisa dipasang tanpa peran lain');
select throws_ok($$select cs.check_agent_input('Uji', '{marketing}', null, 3)$$, 'PT400', 'invalid_roles',
  'Peran di luar daftar tetap ditolak');

select tests.authenticate_agent(:'sinta');
select lives_ok(format($$select cs_api.admin_update_agent(%L, 'Rina Produk', '{cs_agent,product}', 'general', 3, false)$$,
                       :'rina'),
  'Super Admin menambahkan peran Fitur & Kampanye ke agen CS');
select lives_ok(format($$select cs_api.admin_update_agent(%L, 'Rina Produk', '{cs_agent}', 'general', 3, false)$$,
                       :'rina'),
  'Super Admin mencabut peran Fitur & Kampanye');
reset role;

select tests.authenticate_agent(:'putri');
select is(jsonb_array_length(cs_api.admin_feature_flags() -> 'flags'), 8,
  'Peran Fitur & Kampanye melihat daftar fitur');
select is(cs_api.admin_toggle_feature_flag('bookmarks', false) -> 'flags' -> 2 ->> 'enabled', 'false',
  'Peran Fitur & Kampanye mematikan fitur');
select is(cs_api.admin_set_min_version('android', '3.1.0') -> 'min_versions' -> 0 ->> 'min_version', '3.1.0',
  'Peran Fitur & Kampanye mengatur versi minimum aplikasi');
select is(cs_api.admin_set_kill_switch(false, 'Uji pemadaman sementara oleh tim produk') -> 'kill_switch' ->> 'social_enabled',
  'false', 'Peran Fitur & Kampanye memakai saklar darurat');
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('app-banners', %L, %L)$$,
                       :'img', :'putri'),
  'Peran Fitur & Kampanye mengunggah gambar banner');
select lives_ok($$select cs_api.admin_save_banner(null, 'Promo akhir tahun', p_link_url => 'olt://promo/akhir-tahun')$$,
  'Peran Fitur & Kampanye membuat banner');
select is(jsonb_array_length(cs_api.admin_banners()), 1, 'Peran Fitur & Kampanye melihat banner');
select lives_ok($$select cs_api.admin_banner_settings()$$, 'Peran Fitur & Kampanye membaca pengaturan banner');

select throws_ok(format($$select cs_api.admin_update_agent(%L, 'Rina', '{cs_agent}', 'general', 3, false)$$, :'rina'),
  'PT403', 'role_forbidden', 'Peran Fitur & Kampanye tidak bisa mengelola akun staf');
select throws_ok(format($$select cs_api.admin_set_community_permissions(%L, '{community.post}')$$, :'rina'),
  'PT403', 'role_forbidden', 'Peran Fitur & Kampanye tidak bisa memberi izin komunitas');
select throws_ok($$select cs_api.admin_settings()$$, 'PT403', 'role_forbidden',
  'Peran Fitur & Kampanye tidak membuka pengaturan Super Admin');
reset role;

select is((select actor_id from cs.cs_audit_log where action = 'kill_switch.set' order by id desc limit 1), :'putri'::uuid,
  'Perubahan oleh peran Fitur & Kampanye tercatat atas namanya');

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.admin_feature_flags()$$, 'PT403', 'role_forbidden',
  'Agen CS tetap tidak bisa mengelola fitur');
select throws_ok($$select cs_api.admin_banners()$$, 'PT403', 'role_forbidden',
  'Agen CS tetap tidak bisa mengelola banner');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('app-banners', %L, %L)$$,
                        gen_random_uuid() || '.png', :'rina'),
  '42501', null, 'Agen CS tetap tidak bisa mengunggah gambar banner');
reset role;

select * from finish();
rollback;
