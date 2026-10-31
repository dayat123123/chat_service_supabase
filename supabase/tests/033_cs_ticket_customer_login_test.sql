begin;
select plan(8);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';

select gen_random_uuid() as budi \gset
select public.upsert_olt_profile(:'budi', 'olt-tl-77', 'budi.s', 'Budi S', 'budi@contoh.test') ->> 'username' as budi_username \gset
select tests.create_user('tl_sari') as sari \gset
select tests.create_agent('Laila', '{cs_agent}', '{"general": 2, "account": 2}') as laila \gset
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset

select is(:'budi_username'::text, 'budi_s', 'Username profil tetap disanitasi untuk aplikasi sosial');
select is((select olt_username from private.user_private where user_id = :'budi'), 'budi.s',
  'Username login OLT asli disimpan di tabel privat');

select public.upsert_olt_profile(:'budi', 'olt-tl-77', 'budi.baru', null, null) ->> 'id' as relogin \gset
select is((select olt_username from private.user_private where user_id = :'budi'), 'budi.baru',
  'Login berikutnya memperbarui username login OLT asli');

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as t1 \gset
select throws_ok(format('select cs_api.ticket_customer_login(%L)', :'t1'), 'PT403', 'agent_required',
  'Nasabah tidak bisa membaca LoginId lewat RPC CS');
reset role;
select tests.authenticate_as(:'sari');
select cs_api.open_ticket('account') ->> 'id' as t2 \gset
reset role;

select tests.authenticate_agent(:'laila');
select is(cs_api.ticket_customer_login(:'t1'), jsonb_build_object('login_id', 'budi.baru', 'source', 'olt'),
  'CS mendapat LoginId nasabah tiket dari username login OLT asli');
select is(cs_api.ticket_customer_login(:'t2'), jsonb_build_object('login_id', 'tl_sari', 'source', 'profile'),
  'Tanpa username login asli, LoginId jatuh ke username profil');
select throws_ok(format('select cs_api.ticket_customer_login(%L)', gen_random_uuid()), 'PT404', 'ticket_not_found',
  'Tiket yang tidak ada ditolak');

select tests.authenticate_agent(:'kirana');
select throws_ok(format('select cs_api.ticket_customer_login(%L)', :'t1'), 'PT404', 'ticket_not_found',
  'Akun yang tidak boleh membaca tiket tidak mendapat LoginId nasabahnya');

select * from finish();
rollback;
