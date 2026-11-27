begin;
select plan(12);

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Nadia', '{cs_agent}', '{"general": 2}') as nadia \gset
update cs.cs_settings set value = '""' where key in ('nasabah.csadmin_url', 'nasabah.csadmin_client_id');
update cs.cs_settings set value = '"csAdmin"' where key = 'nasabah.csadmin_audience';
update cs.cs_settings set value = '{}' where key = 'nasabah.csadmin_connected';

select tests.authenticate_service();
select is(cs_api.nasabah_integration() ->> 'audience', 'csAdmin',
  'Audience bawaan csAdmin, tanpa kode broker');
select is(cs_api.nasabah_save_integration(:'sinta', 'http://10.0.0.5:9001/csAdmin', 'web-cs', ' csAdminOD ') ->> 'audience',
  'csAdminOD', 'Super Admin bisa menyimpan audience layanan lain, spasi dibuang');
select is(cs_api.nasabah_integration() ->> 'audience', 'csAdminOD', 'Gateway membaca audience yang tersimpan');
select is(cs_api.nasabah_integration() ->> 'configured', 'true', 'Integrasi dengan audience lain tetap aktif');
select is(cs_api.nasabah_save_integration(:'sinta', 'http://10.0.0.5:9001/csAdmin', 'web-cs', '') ->> 'audience',
  'csAdmin', 'Audience kosong kembali ke csAdmin');
select is(cs_api.nasabah_save_integration(:'sinta', 'http://10.0.0.5:9001/csAdmin', 'web-cs') ->> 'audience',
  'csAdmin', 'Pemanggilan lama tanpa audience tetap jalan dengan csAdmin');
select throws_ok(format($$select cs_api.nasabah_save_integration(%L, 'http://10.0.0.5:9001/csAdmin', 'web-cs', 'cs admin')$$, :'sinta'),
  'PT400', 'invalid_csadmin_audience', 'Audience berisi spasi ditolak');
select throws_ok(format($$select cs_api.nasabah_save_integration(%L, 'http://10.0.0.5:9001/csAdmin', 'web-cs', %L)$$, :'sinta', repeat('a', 51)),
  'PT400', 'invalid_csadmin_audience', 'Audience lebih dari 50 karakter ditolak');
select is(cs_api.nasabah_save_integration(:'sinta', 'http://10.0.0.5:9001/csAdmin', 'web-cs', 'csAdminOD') ->> 'audience',
  'csAdminOD', 'Audience bisa diganti lagi');
select is(cs_api.nasabah_clear_integration(:'sinta') ->> 'audience', 'csAdmin',
  'Memutus integrasi mengembalikan audience ke csAdmin');

reset role;
select is((select details ->> 'audience' from cs.cs_audit_log
           where actor_id = :'sinta' and action = 'setting.nasabah_integration' order by id limit 1),
  'csAdminOD', 'Audience tercatat di audit log setiap kali integrasi disimpan');

select tests.authenticate_agent(:'nadia');
select throws_ok($$select cs_api.nasabah_save_integration(auth.uid(), 'http://10.0.0.5:9001/csAdmin', 'web-cs', 'csAdminOD')$$,
  '42501', null, 'Akun console tidak bisa mengubah audience tanpa lewat gateway');

select * from finish();
rollback;
