begin;
select plan(43);

update private.rate_limits set max_count = 1000 where action in ('message', 'cs_message');
update private.settings set value = '0' where key = 'rooms.busy_slow_mode';
update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
delete from cs.holidays;

select is(private.setting_num('rooms.typing_aggregate_members', 0), 50::numeric, 'Ambang ringkasan typing bawaan 50 anggota');
select is(private.setting_num('rooms.typing_summary_seconds', 0), 3::numeric, 'Ringkasan typing paling sering tiap 3 detik');
select is(private.setting_num('rooms.typing_off_members', 0), 2000::numeric, 'Typing mati mulai 2000 anggota');
select is(private.setting_num('rooms.presence_max_members', 0), 50::numeric, 'Presence ditolak mulai 50 anggota');
select is(private.setting_num('rooms.presence_stock_members', -1), 0::numeric, 'Presence room saham selalu ditolak secara bawaan');
select is((select relpersistence::text from pg_class where oid = 'private.typing_rooms'::regclass), 'u',
  'Status ringkasan typing per room di tabel unlogged');
select ok((select relrowsecurity from pg_class where oid = 'private.typing_rooms'::regclass), 'RLS aktif di typing_rooms');
select ok(exists (select 1 from pg_indexes where schemaname = 'private' and indexname = 'typing_throttle_room_idx'),
  'Index typing_throttle per room untuk menghitung yang sedang mengetik');

update private.settings set value = '3' where key = 'rooms.typing_aggregate_members';
update private.settings set value = '3' where key = 'rooms.presence_max_members';

select tests.create_user('tp_alice') as alice \gset
select tests.create_user('tp_bob') as bob \gset
select tests.create_user('tp_carol') as carol \gset
select tests.create_user('tp_dina') as dina \gset
select tests.create_user('tp_eko') as eko \gset
select tests.create_agent('Rani', '{cs_agent}', '{"general": 2, "account": 2}') as rani \gset

select tests.authenticate_as(:'alice');
select get_or_create_direct_room(:'bob') as dm \gset
select create_group_room('Grup Kecil', array[:'bob']::uuid[]) as small \gset
select create_group_room('Grup Besar', array[:'bob', :'carol', :'dina']::uuid[]) as big \gset
select join_stock_room('TPAG') as stock \gset
select tests.authenticate_as(:'bob');
select join_stock_room('TPAG') is not null as joined \gset
select tests.authenticate_as(:'carol');
select join_stock_room('TPAG') is not null as joined \gset
reset role;

select ok(private.room_has_members(:'stock', 3), 'Room saham berisi 3 anggota mencapai ambang 3');
select ok(not private.room_has_members(:'stock', 4), 'Room saham berisi 3 anggota belum mencapai ambang 4');

select tests.authenticate_as(:'alice');
select ok(send_typing(:'dm'), 'DM tetap menyiarkan typing per orang');
select is((select payload ->> 'user_id' from realtime.messages
           where topic = 'room:' || :'dm' and event = 'typing' order by inserted_at desc limit 1),
  :'alice', 'Typing DM membawa identitas pengirim');
select ok(send_typing(:'small'), 'Grup kecil tetap menyiarkan typing per orang');
select is((select count(*)::integer from realtime.messages where topic = 'room:' || :'small' and event = 'typing_summary'),
  0, 'Grup kecil tidak memakai ringkasan typing');

select ok(send_typing(:'stock'), 'Typing pertama di room besar memicu ringkasan');
select is((select count(*)::integer from realtime.messages where topic = 'room:' || :'stock' and event = 'typing'),
  0, 'Room besar tidak menyiarkan typing per orang');
select is((select count(*)::integer from realtime.messages where topic = 'room:' || :'stock' and event = 'typing_summary'),
  1, 'Satu ringkasan typing disiarkan');
select is((select payload - 'id' from realtime.messages
           where topic = 'room:' || :'stock' and event = 'typing_summary' order by inserted_at desc limit 1),
  jsonb_build_object('room_id', :'stock'::uuid, 'count', 1, 'ttl_ms', 6000),
  'Ringkasan hanya berisi room, jumlah, dan masa berlaku, tanpa identitas');

select tests.authenticate_as(:'bob');
select ok(not send_typing(:'stock'), 'Typing lain dalam interval tidak menyiarkan ringkasan baru');
select is((select count(*)::integer from realtime.messages where topic = 'room:' || :'stock' and event = 'typing_summary'),
  1, 'Masih satu ringkasan dalam interval');
reset role;
update private.typing_rooms set sent_at = now() - interval '10 seconds' where room_id = :'stock';
update private.typing_throttle set sent_at = now() - interval '2 seconds' where user_id = :'bob';
select tests.authenticate_as(:'bob');
select ok(send_typing(:'stock'), 'Setelah interval lewat ringkasan berikutnya disiarkan');
select is((select max((payload ->> 'count')::integer) from realtime.messages
           where topic = 'room:' || :'stock' and event = 'typing_summary'),
  2, 'Ringkasan menghitung dua orang yang sedang mengetik');
reset role;
update private.typing_rooms set sent_at = now() - interval '10 seconds' where room_id = :'stock';
select tests.authenticate_as(:'bob');
select ok(not send_typing(:'stock', false), 'Berhenti mengetik di room besar tidak disiarkan');
select is((select count(*)::integer from realtime.messages where topic = 'room:' || :'stock' and event = 'typing_summary'),
  2, 'Berhenti mengetik tidak menambah ringkasan');

reset role;
insert into private.room_mod_actions (room_id, moderator_id, action, target_user_id, reason, mute_until)
values (:'stock', :'alice', 'mute', :'carol', 'spam', now() + interval '1 hour');
select tests.authenticate_as(:'carol');
select ok(not send_typing(:'stock'), 'User yang dibisukan di room tidak memicu ringkasan typing');
select is((select count(*)::integer from realtime.messages where topic = 'room:' || :'stock' and event = 'typing_summary'),
  2, 'Typing user yang dibisukan tidak disiarkan');

select tests.authenticate_as(:'dina');
select ok(send_typing(:'big'), 'Grup besar memakai ringkasan typing');
select is((select count(*)::integer from realtime.messages where topic = 'room:' || :'big' and event = 'typing'),
  0, 'Grup besar tidak menyiarkan typing per orang');

reset role;
update private.settings set value = '3' where key = 'rooms.typing_off_members';
update private.typing_rooms set sent_at = now() - interval '10 seconds';
select tests.authenticate_as(:'alice');
select ok(not send_typing(:'stock'), 'Room di atas ambang typing mati tidak menyiarkan apa pun');
select is((select count(*)::integer from realtime.messages where topic = 'room:' || :'stock' and event in ('typing', 'typing_summary')),
  2, 'Tidak ada siaran typing baru di room di atas ambang mati');

select tests.authenticate_as(:'eko');
select throws_ok(format($$select send_typing(%L)$$, :'stock'), 'PT404', 'not_member',
  'Bukan anggota tetap tidak bisa mengirim typing');

reset role;
update private.settings set value = '1' where key = 'rooms.typing_aggregate_members';
select tests.authenticate_as(:'eko');
select cs_api.open_ticket('account') as j \gset
select (:'j'::jsonb ->> 'id') as ticket, (:'j'::jsonb ->> 'room_id') as support \gset
reset role;
select tests.agent_online(:'rani');
select tests.authenticate_agent(:'rani');
select cs_api.claim_ticket(:'ticket') ->> 'id' as claimed \gset
select ok(cs_api.agent_typing(:'support'), 'Typing CS tidak terpengaruh ambang');
reset role;
select is((select payload ->> 'display_name' from realtime.messages
           where topic = 'room:' || :'support' and event = 'typing' order by inserted_at desc limit 1),
  'Rani', 'Chat CS tetap menyiarkan typing bernama');

select tests.authenticate_as(:'alice');
select ok(private.can_access_topic('room:' || :'stock'), 'Anggota tetap boleh join topik room saham');
select set_config('realtime.topic', 'room:' || :'stock', true) as topic \gset
select throws_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                   values (realtime.topic(), 'presence', '{}', 'presence', true)$$,
  '42501', null, 'Presence di room saham ditolak');
reset role;
update private.settings set value = '1000000' where key = 'rooms.presence_stock_members';
select tests.authenticate_as(:'alice');
select set_config('realtime.topic', 'room:' || :'stock', true) as topic \gset
select lives_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                  values (realtime.topic(), 'presence', '{}', 'presence', true)$$,
  'Ambang presence room saham bisa dinaikkan untuk uji A/B');
select set_config('realtime.topic', 'room:' || :'dm', true) as topic \gset
select lives_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                  values (realtime.topic(), 'presence', '{}', 'presence', true)$$,
  'Presence di DM tetap berjalan');
select set_config('realtime.topic', 'room:' || :'small', true) as topic \gset
select lives_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                  values (realtime.topic(), 'presence', '{}', 'presence', true)$$,
  'Presence di grup kecil tetap berjalan');
select set_config('realtime.topic', 'room:' || :'big', true) as topic \gset
select throws_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                   values (realtime.topic(), 'presence', '{}', 'presence', true)$$,
  '42501', null, 'Presence di grup besar ditolak');
select tests.authenticate_as(:'eko');
select set_config('realtime.topic', 'room:' || :'support', true) as topic \gset
select lives_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                  values (realtime.topic(), 'presence', '{}', 'presence', true)$$,
  'Presence nasabah di chat CS tetap berjalan');
reset role;

select ok(not has_function_privilege('anon', 'private.can_track_presence(text)', 'execute'),
  'Anon tidak bisa memanggil can_track_presence');
select ok(not has_function_privilege('authenticated', 'private.room_typing_summary(uuid, uuid, boolean)', 'execute'),
  'Ringkasan typing hanya lewat send_typing');
select ok((select bool_and(p.prosecdef and p.proconfig @> array['search_path=""'])
           from pg_proc p
           where p.oid in ('private.room_has_members(uuid, integer)'::regprocedure,
                           'private.room_typing_summary(uuid, uuid, boolean)'::regprocedure,
                           'private.can_track_presence(text)'::regprocedure)),
  'Fungsi baru security definer dengan search_path kosong');

select * from finish();
rollback;
