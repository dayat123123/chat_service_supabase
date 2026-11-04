begin;
select plan(24);

update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
delete from cs.holidays;

select results_eq(
  $$select permissive::text collate "default", cmd::text collate "default", roles::text collate "default" from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname = 'cs_staff_public_edge'$$,
  $$values ('RESTRICTIVE', 'ALL', '{authenticated}')$$,
  'Storage: satu policy restrictive menolak JWT staf di edge publik untuk semua bucket dan operasi');
select results_eq(
  $$select policyname::text collate "default", cmd::text collate "default" from pg_policies
    where schemaname = 'realtime' and tablename = 'messages' order by policyname$$,
  $$values ('olt_realtime_receive', 'SELECT'), ('olt_realtime_send', 'INSERT')$$,
  'Realtime: tetap satu policy per aksi');
select ok(
  (select bool_and(coalesce(qual, with_check) like '%staff_on_public_edge%') from pg_policies
   where schemaname = 'realtime' and tablename = 'messages'),
  'Kedua policy Realtime memeriksa penanda edge publik');
select ok(
  exists (select 1 from pg_trigger
          where tgrelid = 'realtime.subscription'::regclass and tgname = 'cs_staff_postgres_changes' and not tgisinternal),
  'Trigger penolak postgres_changes staf terpasang');

select tests.create_user('edge_rt_budi') as budi \gset
select tests.create_user('edge_rt_sari') as sari \gset
select tests.create_agent('Edge Rina', '{cs_agent}', '{"general": 2, "account": 2}') as rina \gset

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') as j \gset
select (:'j'::jsonb ->> 'id') as ticket, (:'j'::jsonb ->> 'room_id') as room \gset
select get_or_create_direct_room(:'sari') as dm \gset
reset role;

select tests.agent_online(:'rina');
select tests.authenticate_agent(:'rina');
select cs_api.claim_ticket(:'ticket') ->> 'id' as claimed \gset
select set_config('request.headers', '{"x-olt-edge":"public"}', true) as h \gset
select ok(private.staff_on_public_edge(), 'Agen dengan penanda edge publik terdeteksi');
select set_config('request.headers', '{"x-olt-edge":"cs"}', true) as h \gset
select ok(not private.staff_on_public_edge(), 'Nilai penanda selain public tidak memblokir agen');
select set_config('request.headers', '', true) as h \gset
select ok(not private.staff_on_public_edge(), 'Header kosong tidak memblokir agen dan tidak error');
select set_config('request.headers', '{}', true) as h \gset
select ok(not private.staff_on_public_edge(), 'Agen lewat domain CS (tanpa penanda) tidak diblokir');
reset role;

select tests.authenticate_as(:'budi');
select set_config('request.headers', '{"x-olt-edge":"public"}', true) as h \gset
select ok(not private.staff_on_public_edge(), 'Nasabah di edge publik tidak dianggap staf');
reset role;
select ok(not has_function_privilege('anon', 'private.staff_on_public_edge()', 'execute'),
  'Helper edge hanya untuk policy authenticated');

insert into realtime.messages (id, topic, extension, payload, event, private)
values ('5e0e0000-0000-4000-8000-000000000085', 'cs:queue', 'broadcast', '{}', 'ticket', true);

select tests.authenticate_agent(:'rina');
select set_config('request.headers', '{}', true) as h \gset
select is((select count(*)::integer from realtime.messages where id = '5e0e0000-0000-4000-8000-000000000085'), 1,
  'Agen lewat domain CS boleh membaca channel cs:queue');
select set_config('request.headers', '{"x-olt-edge":"public"}', true) as h \gset
select is((select count(*)::integer from realtime.messages where id = '5e0e0000-0000-4000-8000-000000000085'), 0,
  'Agen lewat edge publik tidak bisa join channel cs:queue');

select set_config('realtime.topic', 'room:' || :'room', true) as topic \gset
select set_config('request.headers', '{}', true) as h \gset
select lives_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                  values (realtime.topic(), 'presence', '{}', 'presence', true)$$,
  'Agen lewat domain CS boleh presence di room tiket yang ia tangani');
select set_config('request.headers', '{"x-olt-edge":"public"}', true) as h \gset
select throws_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                   values (realtime.topic(), 'presence', '{}', 'presence', true)$$,
  '42501', null, 'Agen lewat edge publik tidak bisa presence');

select set_config('request.headers', '{}', true) as h \gset
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('avatars', '%s/edge-probe.png', %L)$$,
                       :'rina', :'rina'),
  'Agen lewat domain CS boleh mengunggah ke Storage');
select set_config('request.headers', '{"x-olt-edge":"public"}', true) as h \gset
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('avatars', '%s/edge-public.png', %L)$$,
                        :'rina', :'rina'),
  '42501', null, 'Agen lewat edge publik tidak bisa mengunggah ke Storage');
select is((select count(*)::integer from storage.objects where bucket_id = 'avatars' and name = :'rina' || '/edge-probe.png'), 0,
  'Agen lewat edge publik tidak bisa membaca objek Storage');
select set_config('request.headers', '{}', true) as h \gset
select is((select count(*)::integer from storage.objects where bucket_id = 'avatars' and name = :'rina' || '/edge-probe.png'), 1,
  'Agen lewat domain CS tetap bisa membaca objek Storage');
reset role;

select tests.authenticate_as(:'budi');
select set_config('request.headers', '{"x-olt-edge":"public"}', true) as h \gset
select is((select count(*)::integer from storage.objects where bucket_id = 'avatars' and name = :'rina' || '/edge-probe.png'), 1,
  'Nasabah di edge publik tetap membaca avatar (policy lama tidak berubah)');
select set_config('realtime.topic', 'room:' || :'dm', true) as topic \gset
select lives_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                  values (realtime.topic(), 'presence', '{}', 'presence', true)$$,
  'Nasabah di edge publik tetap bisa presence di room-nya');
select ok(not private.can_access_topic('online'), 'Topik online tidak lagi diizinkan');
select set_config('realtime.topic', 'online', true) as topic \gset
select throws_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                   values (realtime.topic(), 'presence', '{}', 'presence', true)$$,
  '42501', null, 'Presence di topik online ditolak (tidak dipakai klien, bisa membanjiri batas presence)');
reset role;

select throws_ok(format($$insert into realtime.subscription (subscription_id, entity, filters, claims)
                          values (gen_random_uuid(), 'public.posts', '{}', %L)$$,
                        json_build_object('sub', :'rina', 'role', 'authenticated')::text),
  '42501', null, 'Staf tidak bisa berlangganan postgres_changes');
select lives_ok(format($$insert into realtime.subscription (subscription_id, entity, filters, claims)
                         values (gen_random_uuid(), 'public.posts', '{}', %L)$$,
                       json_build_object('sub', :'budi', 'role', 'authenticated')::text),
  'Nasabah tetap bisa berlangganan postgres_changes');

select * from finish();
rollback;
