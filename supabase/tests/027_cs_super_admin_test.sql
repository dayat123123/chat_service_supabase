begin;
select plan(11);

select tests.create_agent('Rina', '{cs_agent}', '{"general": 2}') as rina \gset
select tests.create_agent('Dimas', '{cs_agent}', '{"general": 1}') as dimas \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset

select throws_ok($$select tests.create_agent('Lama', '{cs_supervisor}', '{}')$$, '23514', null,
  'Peran supervisor lama tidak berlaku lagi');
select throws_ok($$select tests.create_agent('Lama', '{cs_admin}', '{}')$$, '23514', null,
  'Peran admin CS lama tidak berlaku lagi');

select tests.authenticate_agent(:'sinta', 'aal1');
select lives_ok('select cs_api.supervisor_overview()', 'Super admin memantau dashboard tanpa 2FA');
select lives_ok('select cs_api.admin_agents()', 'Super admin membuka pengelolaan akun CS');
select is(cs_api.admin_reset_password(:'rina') ->> 'id', :'rina', 'Super admin mereset password akun CS yang lupa');
select throws_ok(format('select cs_api.admin_reset_password(%L)', gen_random_uuid()), 'PT404', 'agent_not_found',
  'Reset password akun yang tidak ada ditolak');
select throws_ok(format('select cs_api.claim_ticket(%L)', gen_random_uuid()), 'PT403', 'role_forbidden',
  'Super admin tetap tidak menangani tiket');

reset role;
select is((select count(*)::integer from cs.cs_audit_log
           where action = 'agent.reset_password' and actor_id = :'sinta' and details ->> 'agent' = :'rina'), 1,
  'Reset password tercatat di audit log');
update cs.agents set disabled_at = now() where user_id = :'dimas';
select tests.authenticate_agent(:'sinta', 'aal1');
select throws_ok(format('select cs_api.admin_reset_password(%L)', :'dimas'), 'PT409', 'agent_disabled',
  'Akun nonaktif harus diaktifkan dulu sebelum direset');

select tests.authenticate_agent(:'rina', 'aal1');
select throws_ok(format('select cs_api.admin_reset_password(%L)', :'sinta'), 'PT403', 'role_forbidden',
  'CS biasa tidak bisa mereset password akun lain');
select lives_ok('select cs_api.agent_me()', 'CS biasa cukup login email + password, tanpa 2FA');

select * from finish();
rollback;
