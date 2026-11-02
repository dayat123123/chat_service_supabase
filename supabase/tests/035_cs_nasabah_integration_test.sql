begin;
select plan(17);

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Nadia', '{cs_agent}', '{"general": 2}') as nadia \gset

select tests.authenticate_service();
select is(cs_api.nasabah_integration(), '{"url": "", "client_id": ""}'::jsonb,
  'Tanpa pengaturan web, gateway memakai nilai docker/.env');
select ok(cs_api.nasabah_is_super_admin(:'sinta'), 'Gateway mengenali Super Admin aktif');
select ok(not cs_api.nasabah_is_super_admin(:'nadia'), 'CS biasa bukan Super Admin');

select tests.authenticate_agent(:'nadia');
select throws_ok('select cs_api.nasabah_integration()', '42501', null,
  'Akun console tidak bisa membaca RPC khusus gateway');
select throws_ok($$select cs_api.admin_set_setting('nasabah.csadmin_url', '"http://10.0.0.5:8080"')$$,
  'PT403', 'role_forbidden', 'CS biasa tidak bisa mengubah alamat csAdmin');

select tests.authenticate_agent(:'sinta');
select ok((select count(*) = 2 from jsonb_array_elements(cs_api.admin_settings()) x
           where x ->> 'key' in ('nasabah.csadmin_url', 'nasabah.csadmin_client_id')),
  'Super Admin melihat pengaturan integrasi csAdmin');
select throws_ok($$select cs_api.admin_set_setting('nasabah.csadmin_url', '"ftp://10.0.0.5"')$$,
  'PT400', 'invalid_csadmin_url', 'Hanya http atau https');
select throws_ok($$select cs_api.admin_set_setting('nasabah.csadmin_url', '"http://admin:rahasia@10.0.0.5:8080"')$$,
  'PT400', 'invalid_csadmin_url', 'Login di dalam URL ditolak');
select throws_ok($$select cs_api.admin_set_setting('nasabah.csadmin_url', '"http://10.0.0.5:8080/csAdmin?next=x"')$$,
  'PT400', 'invalid_csadmin_url', 'Query di URL ditolak');
select throws_ok($$select cs_api.admin_set_setting('nasabah.csadmin_url', '8080')$$,
  'PT400', 'invalid_setting', 'Alamat harus berupa teks');
select is(cs_api.admin_set_setting('nasabah.csadmin_url', '"http://10.0.0.5:9001/csAdmin"') ->> 'value',
  'http://10.0.0.5:9001/csAdmin', 'Super Admin menyimpan alamat csAdmin beserta prefix path');
select throws_ok($$select cs_api.admin_set_setting('nasabah.csadmin_client_id', '"web cs"')$$,
  'PT400', 'invalid_csadmin_client_id', 'Client id tanpa spasi');
select lives_ok($$select cs_api.admin_set_setting('nasabah.csadmin_client_id', '"web-cs.prod"')$$,
  'Super Admin menyimpan client id');

select tests.authenticate_service();
select is(cs_api.nasabah_integration(), '{"url": "http://10.0.0.5:9001/csAdmin", "client_id": "web-cs.prod"}'::jsonb,
  'Gateway membaca pengaturan dari web');

select tests.authenticate_agent(:'sinta');
select lives_ok($$select cs_api.admin_set_setting('nasabah.csadmin_url', '""')$$,
  'Alamat dikosongkan untuk kembali memakai docker/.env');

reset role;
select is((select count(*)::integer from cs.cs_audit_log
           where action = 'setting.update' and details ->> 'key' = 'nasabah.csadmin_url' and actor_id = :'sinta'), 2,
  'Setiap perubahan alamat csAdmin tercatat di audit log');

update cs.agents set disabled_at = now() where user_id = :'sinta';
select tests.authenticate_service();
select ok(not cs_api.nasabah_is_super_admin(:'sinta'), 'Super Admin nonaktif kehilangan akses pengaturan integrasi');

select * from finish();
rollback;
