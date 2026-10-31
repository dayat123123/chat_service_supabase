begin;
select plan(17);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
delete from cs.holidays;

select tests.create_user('mo_budi') as budi \gset
select tests.create_user('mo_sari') as sari \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2, "account": 2, "funds": 2}') as rina \gset
select tests.create_agent('Dimas', '{cs_agent}', '{"general": 2, "account": 2, "funds": 2}') as dimas \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{"general": 3, "account": 3, "funds": 3}') as sinta \gset

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') as j1 \gset
select (:'j1'::jsonb ->> 'id') as t1, (:'j1'::jsonb ->> 'room_id') as room1 \gset
select tests.authenticate_as(:'sari');
select cs_api.open_ticket('funds') ->> 'id' as t2 \gset

select tests.agent_online(:'rina');
select tests.agent_online(:'dimas');
select tests.agent_online(:'sinta');
select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'t1') ->> 'id' as claimed \gset

select hasnt_function('cs_api', 'join_ticket', 'Supervisor tidak lagi bergabung ke tiket');

select tests.authenticate_agent(:'sinta');
select throws_ok(format($$select cs_api.claim_ticket(%L)$$, :'t2'), 'PT403', 'role_forbidden',
  'Supervisor yang Online tetap tidak bisa mengambil tiket');
select throws_ok(format($$select cs_api.agent_send_message(%L, 'Halo, saya bantu')$$, :'t1'), 'PT403', 'role_forbidden',
  'Supervisor tidak membalas nasabah');
select throws_ok(format($$select cs_api.resolve_ticket(%L, 'answered', 'Ditutup supervisor')$$, :'t1'), 'PT403', 'role_forbidden',
  'Supervisor tidak menyelesaikan tiket CS lain');
select throws_ok(format($$select cs_api.wait_customer(%L)$$, :'t1'), 'PT403', 'role_forbidden',
  'Supervisor tidak mengubah tiket menjadi menunggu nasabah');
select throws_ok(format($$select cs_api.request_transfer(%L, %L, 'Tolong lanjutkan')$$, :'t1', :'dimas'), 'PT403', 'role_forbidden',
  'Supervisor tidak mentransfer tiket');

select ok((cs_api.ticket_lists() -> 'all_active') @> jsonb_build_array(jsonb_build_object('id', :'t1')),
  'Supervisor memantau tiket yang sedang ditangani');
select ok((select count(*) > 0 from cs_api.get_messages(:'room1'::uuid)), 'Supervisor membaca percakapan tiket');
select ok(not exists (select 1 from jsonb_array_elements(cs_api.online_agents()) x where x ->> 'id' = :'sinta'),
  'Daftar CS tujuan tidak memuat supervisor');
select ok(not exists (select 1 from jsonb_array_elements(cs_api.supervisor_overview() -> 'agents') x where x ->> 'id' = :'sinta'),
  'Dashboard hanya menghitung CS, bukan supervisor');
select is(cs_api.set_ticket_priority(:'t1', 'P1') ->> 'priority', 'P1', 'Supervisor tetap bisa menaikkan prioritas');
select throws_ok(format($$select cs_api.reassign_ticket(%L, %L, 'Supervisor ambil alih')$$, :'t1', :'sinta'), 'PT404', 'agent_not_found',
  'Tiket tidak bisa dipindahkan ke supervisor');
select is(cs_api.reassign_ticket(:'t1', :'dimas', 'Rina sedang rapat') -> 'owner' ->> 'display_name', 'Dimas',
  'Supervisor memindahkan tiket ke CS lain');

select tests.authenticate_agent(:'dimas');
select throws_ok(format($$select cs_api.request_transfer(%L, %L, 'Tolong pantau')$$, :'t1', :'sinta'), 'PT409', 'agent_unavailable',
  'Supervisor tidak bisa menjadi tujuan transfer');

reset role;
select ok(not cs.can_take_tickets(:'sinta'), 'Supervisor yang Online tidak menerima tiket');
select cs.set_setting('assignment.mode', '"auto_assign"', null) as mode \gset
update cs.agent_status set status = 'offline' where agent_id in (:'rina', :'dimas');
select cs.auto_assign_open() as assigned \gset
select is((select owner_agent_id from cs.tickets where id = :'t2'), null, 'Pembagian otomatis tidak memberi tiket ke supervisor');
select throws_ok(
  format($$insert into public.messages (room_id, sender_id, body, sender_role, session_id)
           values (%L, %L, 'Pesan supervisor', 'supervisor', %L)$$, :'room1', :'sinta', :'t1'),
  'PT403', 'use_cs_api', 'Pesan baru bertanda supervisor ditolak');

select * from finish();
rollback;
