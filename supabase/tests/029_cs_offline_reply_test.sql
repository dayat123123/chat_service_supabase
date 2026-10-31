begin;
select plan(5);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
select cs.set_setting('assignment.mode', '"claim"', null) as claim_mode \gset
delete from cs.holidays;

select tests.create_user('or_budi') as budi \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2, "account": 2}') as rina \gset

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') as j \gset
select (:'j'::jsonb ->> 'id') as t1, (:'j'::jsonb ->> 'room_id') as room1 \gset
select tests.authenticate_agent(:'rina');
select cs_api.agent_set_status('online') as online1 \gset
select cs_api.claim_ticket(:'t1') ->> 'status' as claimed \gset

select lives_ok(format($$select cs_api.agent_send_message(%L, 'Halo, saya bantu')$$, :'t1'),
  'CS Online membalas nasabah');

select cs_api.agent_set_status('offline') as offline1 \gset
select throws_ok(format($$select cs_api.agent_send_message(%L, 'Masih di sini')$$, :'t1'), 'PT409', 'agent_offline',
  'CS Offline tidak bisa membalas nasabah');
select is(tests.error_detail(format($$select cs_api.agent_send_message(%L, 'Masih di sini')$$, :'t1')),
  'Anda sedang Offline. Ubah ke Online dulu untuk membalas nasabah', 'Pesan error menyuruh CS Online dulu');

select tests.authenticate_as(:'budi');
select lives_ok(format($$select cs_api.send_message(%L, 'Halo CS?', gen_random_uuid())$$, :'room1'),
  'Nasabah tetap bisa mengirim pesan walau CS Offline');

select tests.authenticate_agent(:'rina');
select cs_api.agent_set_status('busy') as busy1 \gset
select lives_ok(format($$select cs_api.agent_send_message(%L, 'Sudah kembali')$$, :'t1'),
  'CS Sibuk tetap membalas tiket miliknya');

select * from finish();
rollback;
