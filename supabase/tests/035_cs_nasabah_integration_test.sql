begin;
select plan(20);

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Nadia', '{cs_agent}', '{"general": 2}') as nadia \gset
update cs.agents set nasabah_permissions = '{online_user.view}' where user_id = :'nadia';
update cs.cs_settings set value = '""' where key in ('nasabah.csadmin_url', 'nasabah.csadmin_client_id');
update cs.cs_settings set value = '{}' where key = 'nasabah.csadmin_connected';

select tests.authenticate_service();
select is(cs_api.nasabah_integration() - 'connected_at' - 'connected_by',
  '{"url": "", "client_id": "", "configured": false}'::jsonb,
  'Tanpa pengaturan, integrasi belum aktif dan tidak ada nilai bawaan');
select ok(cs_api.nasabah_is_super_admin(:'sinta'), 'Gateway mengenali Super Admin aktif');
select ok(not cs_api.nasabah_is_super_admin(:'nadia'), 'CS biasa bukan Super Admin');

select tests.authenticate_agent(:'nadia');
select is(cs_api.agent_me() -> 'nasabah_permissions', '[]'::jsonb,
  'Selama integrasi belum aktif, menu Akun Nasabah disembunyikan walau CS punya izin');
select is(cs_api.agent_me() #> '{settings,nasabah_ready}', 'false'::jsonb, 'Profil CS memberi tahu integrasi belum aktif');
select throws_ok('select cs_api.nasabah_integration()', '42501', null,
  'Akun console tidak bisa membaca RPC khusus gateway');
select throws_ok($$select cs_api.nasabah_save_integration(auth.uid(), 'http://10.0.0.5:9001/csAdmin', 'web-cs')$$, '42501', null,
  'Akun console tidak bisa menyimpan integrasi tanpa lewat gateway');

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.admin_set_setting('nasabah.csadmin_url', '"http://10.0.0.5:8080"')$$,
  'PT403', 'setting_locked', 'Alamat tidak bisa disimpan langsung tanpa tes koneksi');
select ok(not exists (select 1 from jsonb_array_elements(cs_api.admin_settings()) x where x ->> 'key' like 'nasabah.%'),
  'Pengaturan integrasi tidak tampil di daftar pengaturan umum');

select tests.authenticate_service();
select throws_ok(format($$select cs_api.nasabah_save_integration(%L, 'http://10.0.0.5:9001/csAdmin', 'web-cs')$$, :'nadia'),
  'PT403', 'role_forbidden', 'Hanya Super Admin yang bisa mengatur integrasi');
select throws_ok(format($$select cs_api.nasabah_save_integration(%L, 'http://10.0.0.5:9001/csAdmin', '')$$, :'sinta'),
  'PT400', 'invalid_csadmin_client_id', 'Client id wajib diisi, tidak ada nilai bawaan');
select throws_ok(format($$select cs_api.nasabah_save_integration(%L, '', 'web-cs')$$, :'sinta'),
  'PT400', 'invalid_csadmin_url', 'Alamat wajib diisi');
select throws_ok(format($$select cs_api.nasabah_save_integration(%L, 'http://admin:rahasia@10.0.0.5', 'web-cs')$$, :'sinta'),
  'PT400', 'invalid_csadmin_url', 'Login di dalam URL ditolak');
select is(cs_api.nasabah_save_integration(:'sinta', ' http://10.0.0.5:9001/csAdmin ', 'web-cs.prod') - 'connected_at',
  '{"url": "http://10.0.0.5:9001/csAdmin", "client_id": "web-cs.prod", "configured": true, "connected_by": "Sinta"}'::jsonb,
  'Gateway menyimpan integrasi atas nama Super Admin setelah tes koneksi berhasil');

select tests.authenticate_agent(:'nadia');
select is(cs_api.agent_me() -> 'nasabah_permissions', '["online_user.view"]'::jsonb,
  'Setelah integrasi aktif, menu Akun Nasabah tampil untuk CS yang punya izin');
select is(cs_api.agent_me() #> '{settings,nasabah_ready}', 'true'::jsonb, 'Profil CS memberi tahu integrasi aktif');

select tests.authenticate_service();
select is(cs_api.nasabah_clear_integration(:'sinta') - 'connected_at' - 'connected_by',
  '{"url": "", "client_id": "", "configured": false}'::jsonb, 'Super Admin bisa memutus integrasi');
select tests.authenticate_agent(:'nadia');
select is(cs_api.agent_me() -> 'nasabah_permissions', '[]'::jsonb, 'Integrasi diputus, menu Akun Nasabah langsung tersembunyi');

reset role;
select is((select array_agg(action order by id) from cs.cs_audit_log where actor_id = :'sinta' and action like 'setting.nasabah%'),
  '{setting.nasabah_integration,setting.nasabah_integration_cleared}'::text[],
  'Simpan dan putus integrasi tercatat di audit log atas nama Super Admin');

update cs.agents set disabled_at = now() where user_id = :'sinta';
select tests.authenticate_service();
select ok(not cs_api.nasabah_is_super_admin(:'sinta'), 'Super Admin nonaktif kehilangan akses pengaturan integrasi');

select * from finish();
rollback;
