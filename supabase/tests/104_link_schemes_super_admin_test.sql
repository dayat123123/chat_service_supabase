begin;
select plan(4);

select tests.create_agent('Sinta Skema', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Putri Skema', '{product}', '{}') as putri \gset

select tests.authenticate_agent(:'putri');
select lives_ok($$select cs_api.admin_banner_settings()$$,
  'Peran Fitur & Kampanye tetap bisa membaca skema deep link untuk validasi tautan banner');
select throws_ok($$select cs_api.admin_set_banner_link_schemes('{olt,mitra}')$$, 'PT403', 'role_forbidden',
  'Peran Fitur & Kampanye tidak bisa mengubah skema deep link');
reset role;

select tests.authenticate_agent(:'sinta');
select lives_ok($$select cs_api.admin_set_banner_link_schemes('{olt,mitra}')$$,
  'Super Admin mengubah skema deep link dari Pengaturan');
reset role;
select is((select actor_id from cs.cs_audit_log where action = 'banner.link_schemes' order by id desc limit 1), :'sinta'::uuid,
  'Perubahan skema tercatat atas nama Super Admin');

select * from finish();
rollback;
