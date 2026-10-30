begin;
select plan(7);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';

select tests.create_user('rm_budi') as budi \gset
select tests.create_user('rm_sari') as sari \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2, "account": 2}') as rina \gset
select tests.create_agent('Dimas', '{cs_agent}', '{"general": 1}') as dimas \gset

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') as j \gset
select (:'j'::jsonb ->> 'id') as t1, (:'j'::jsonb ->> 'room_id') as room \gset

select tests.agent_online(:'rina');
select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t1') as claimed \gset

select tests.authenticate_as(:'budi');
select is((select count(*)::integer from jsonb_array_elements(cs_api.room_members(:'room'))), 2,
  'Nasabah melihat anggota room CS miliknya untuk tanda dibaca');
select is((select x ->> 'display_name' from jsonb_array_elements(cs_api.room_members(:'room')) x
           where (x ->> 'is_staff')::boolean), 'Rina', 'Anggota staf ditandai is_staff');

select tests.authenticate_as(:'sari');
select throws_ok(format('select cs_api.room_members(%L)', :'room'), 'PT403', null,
  'Nasabah lain tidak bisa melihat anggota room CS orang lain');

select tests.authenticate_agent(:'dimas');
select throws_ok(format('select cs_api.room_members(%L)', :'room'), 'PT404', 'room_not_found',
  'CS yang tidak menangani tiket tidak bisa melihat anggota room');

reset role;
select tests.authenticate_as(:'sari');
select cs_api.open_ticket('funds') as j2 \gset
select (:'j2'::jsonb ->> 'room_id') as room2 \gset
select tests.authenticate_agent(:'dimas');
select is((select count(*)::integer from jsonb_array_elements(cs_api.room_members(:'room2'))), 1,
  'Semua CS boleh pratinjau anggota tiket open');

reset role;
select tests.authenticate_agent(:'rina');
select is((select count(*)::integer from jsonb_array_elements(cs_api.room_members(:'room'))), 2,
  'Pemilik tiket melihat anggota room');
reset role;
select tests.authenticate_anon();
select throws_ok(format('select cs_api.room_members(%L)', :'room'), '42501', null,
  'Anon tidak bisa memanggil fungsi');

select * from finish();
rollback;
