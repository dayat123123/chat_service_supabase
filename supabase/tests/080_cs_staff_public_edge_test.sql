begin;
select plan(8);

select tests.create_user('edge_customer') as customer \gset
select tests.create_agent('Edge Agen', '{cs_agent}', '{}') as agent \gset

select tests.authenticate_as(:'agent');
select set_config('request.method', 'POST', true) as m \gset
select set_config('request.path', '/rpc/ticket_messages', true) as p \gset
select set_config('request.headers', '{"content-profile":"cs_api"}', true) as h \gset
select lives_ok('select private.check_request()', 'Agen lewat domain CS (tanpa penanda edge publik) lolos');

select set_config('request.headers', '{"content-profile":"cs_api","x-olt-edge":"public"}', true) as h \gset
select throws_ok('select private.check_request()', 'PT403', 'cs_staff_public_edge',
  'Agen lewat router publik ditolak untuk RPC cs_api');

select set_config('request.method', 'GET', true) as m \gset
select set_config('request.headers', '{"accept-profile":"cs_api","x-olt-edge":"public"}', true) as h \gset
select throws_ok('select private.check_request()', 'PT403', 'cs_staff_public_edge',
  'Agen lewat router publik ditolak juga untuk GET cs_api');

select set_config('request.headers', '{"x-olt-edge":"public"}', true) as h \gset
select throws_ok('select private.check_request()', 'PT403', 'cs_staff_social_forbidden',
  'Agen di skema public tetap ditolak dengan kode lama');

select set_config('request.headers', '{"accept-profile":"cs_api","x-olt-edge":"cs"}', true) as h \gset
select lives_ok('select private.check_request()', 'Nilai penanda selain public tidak memblokir agen');
reset role;

select tests.authenticate_as(:'customer');
select set_config('request.method', 'POST', true) as m \gset
select set_config('request.headers', '{"content-profile":"cs_api","x-olt-edge":"public"}', true) as h \gset
select lives_ok('select private.check_request()', 'Nasabah lewat router publik tetap bisa memakai chat CS');

select set_config('request.headers', '{"x-olt-edge":"public"}', true) as h \gset
select lives_ok('select private.check_request()', 'Nasabah lewat router publik tetap bisa memakai skema public');
reset role;

select set_config('role', 'anon', true) as r \gset
select set_config('request.jwt.claims', '{"role":"anon"}', true) as c \gset
select lives_ok('select private.check_request()', 'Anon lewat router publik tidak terpengaruh');
reset role;

select * from finish();
rollback;
