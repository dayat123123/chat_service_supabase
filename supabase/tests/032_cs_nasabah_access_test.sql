begin;
select plan(18);

select tests.create_agent('Nadia', '{cs_agent}', '{"general": 2}') as nadia \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Bima', '{cs_agent}', '{"general": 2}') as bima \gset
select agent_code as nadia_code from cs.agents where user_id = :'nadia' \gset

select tests.authenticate_service();
select is(cs_api.nasabah_access(:'nadia'), null, 'Akun tanpa permission Nasabah tidak punya akses');

select tests.authenticate_agent(:'nadia');
select is(cs_api.agent_me() -> 'nasabah_permissions', '[]'::jsonb, 'Profil CS memuat daftar permission Nasabah');
select throws_ok(format($$select cs_api.admin_set_nasabah_permissions(%L, '{online_user.view}')$$, :'nadia'),
  'PT403', 'role_forbidden', 'CS biasa tidak bisa memberi permission Nasabah');
select throws_ok(format('select cs_api.nasabah_access(%L)', :'nadia'), '42501', null,
  'Akun console tidak bisa memanggil RPC khusus gateway');

select tests.authenticate_agent(:'sinta');
select throws_ok(format($$select cs_api.admin_set_nasabah_permissions(%L, '{online_user.delete_all}')$$, :'nadia'),
  'PT400', 'invalid_permission', 'Permission Nasabah yang tidak dikenal ditolak');
select is(cs_api.admin_set_nasabah_permissions(:'nadia', '{online_user.manage,online_user.view,online_user.view}') -> 'nasabah_permissions',
  '["online_user.manage", "online_user.view"]'::jsonb, 'Super Admin memberi permission Nasabah (urut, tanpa duplikat)');
select throws_ok(format($$select cs_api.admin_set_nasabah_permissions(%L, '{online_user.view}')$$, :'sinta'),
  'PT400', 'not_cs_agent', 'Akses Nasabah hanya untuk akun yang berperan CS');
select throws_ok(format($$select cs_api.admin_set_nasabah_permissions(%L, '{cs_user.manage}')$$, :'bima'),
  'PT400', 'invalid_permission', 'Permission kelola akun CS csAdmin sudah dicabut');
select is(cs_api.admin_set_nasabah_permissions(:'bima', '{online_user.approve_own,online_user.status}') -> 'nasabah_permissions',
  '["online_user.approve_own", "online_user.status"]'::jsonb, 'Super Admin memberi izin approve pengajuan sendiri dan ubah status');
select ok((select bool_or(a -> 'nasabah_permissions' ? 'online_user.manage') from jsonb_array_elements(cs_api.admin_agents()) a),
  'Daftar akun CS menampilkan permission Nasabah');

select tests.authenticate_service();
select is(cs_api.nasabah_access(:'nadia') -> 'permissions', '["online_user.manage", "online_user.view"]'::jsonb,
  'Gateway membaca permission Nasabah akun aktif');
select is(cs_api.nasabah_access(:'nadia') ->> 'agent_code', :'nadia_code',
  'Gateway mendapat kode CS untuk kolom pelaku');
select lives_ok(format($$select cs_api.nasabah_audit(%L, 'nasabah.approval.create', '{"subject": {"LoginId": "budi"}}')$$, :'nadia'),
  'Gateway mencatat aksi Nasabah di audit log');
select throws_ok(format($$select cs_api.nasabah_audit(%L, 'ticket.claim', '{}')$$, :'nadia'),
  'PT400', 'invalid_action', 'Gateway hanya boleh mencatat aksi nasabah.*');

reset role;
select is((select actor_id::text || '|' || actor_type || '|' || (details -> 'subject' ->> 'LoginId') || '|' || (details ->> 'via')
           from cs.cs_audit_log where action = 'nasabah.approval.create' and actor_id = :'nadia'),
  :'nadia' || '|agent|budi|nasabah-gateway', 'Audit mencatat CS yang sebenarnya, bukan akun teknis csAdmin');
select is((select count(*)::integer from cs.cs_audit_log where action = 'agent.nasabah_permissions' and details ->> 'agent' = :'nadia'), 1,
  'Perubahan permission Nasabah tercatat di audit log');

update cs.agents set roles = '{compliance}' where user_id = :'bima';
select is((select nasabah_permissions from cs.agents where user_id = :'bima'), '{}'::text[],
  'Peran CS dicabut, akses Nasabah ikut hilang');

update cs.agents set disabled_at = now() where user_id = :'nadia';
select tests.authenticate_service();
select is(cs_api.nasabah_access(:'nadia'), null, 'Akun nonaktif langsung kehilangan akses Nasabah');

select * from finish();
rollback;
