begin;
select plan(48);

update private.rate_limits set max_count = 1000 where action in ('message', 'cs_message');
update private.settings set value = '0' where key = 'rooms.busy_slow_mode';
update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
delete from cs.holidays;

select tests.create_user('rb_alice') as alice \gset
select tests.create_user('rb_bob') as bob \gset
select tests.create_user('rb_carol') as carol \gset
select tests.create_user('rb_dina') as dina \gset
select tests.create_user('rb_eko') as eko \gset
select tests.create_agent('Rani', '{cs_agent}', '{"general": 2, "account": 2}') as rani \gset

select results_eq(
  $$select tablename::text collate "default" from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' order by 1$$,
  $$values ('comments'), ('notifications'), ('posts'), ('reactions')$$,
  'Pesan tidak lagi lewat postgres_changes: tabel messages keluar dari publikasi realtime');
select ok(exists (select 1 from pg_trigger where tgname = 'messages_60_broadcast' and tgrelid = 'public.messages'::regclass),
  'Trigger siaran pesan terpasang');

select tests.authenticate_as(:'alice');
select get_or_create_direct_room(:'bob') as dm \gset
select create_group_room('Grup Siaran', array[:'bob', :'carol']::uuid[]) as grp \gset
select join_stock_room('RBST') as stock \gset
select tests.authenticate_as(:'bob');
select join_stock_room('RBST') is not null as joined \gset

select tests.authenticate_as(:'alice');
select ok(private.can_access_topic('user:' || :'alice'), 'User boleh join topik user miliknya');
select ok(not private.can_access_topic('user:' || :'bob'), 'User tidak boleh join topik user orang lain');
select ok(private.can_access_topic('room:' || :'dm'), 'Anggota boleh menerima topik room');

select set_config('realtime.topic', 'room:' || :'dm', true) as topic \gset
select throws_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                   values (realtime.topic(), 'broadcast', '{"message_id": "x"}', 'message_hidden', true)$$,
  '42501', null, 'Anggota tidak bisa mengirim broadcast apa pun ke topik room');
select throws_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                   values (realtime.topic(), 'broadcast', '{"user_id": "x", "typing": true}', 'typing', true)$$,
  '42501', null, 'Typing atas nama orang lain lewat broadcast klien ditolak');
select lives_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                  values (realtime.topic(), 'presence', '{}', 'presence', true)$$,
  'Anggota tetap boleh memakai presence di topik room');
select set_config('realtime.topic', 'user:' || :'alice', true) as topic \gset
select throws_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                   values (realtime.topic(), 'broadcast', '{}', 'room_activity', true)$$,
  '42501', null, 'Klien tidak bisa menulis ke topik user, bahkan miliknya sendiri');
select set_config('realtime.topic', 'online', true) as topic \gset
select throws_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                   values (realtime.topic(), 'broadcast', '{}', 'x', true)$$,
  '42501', null, 'Broadcast klien di topik online ditolak');
select throws_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                   values (realtime.topic(), 'presence', '{}', 'presence', true)$$,
  '42501', null, 'Presence di topik online ditolak (topik ditutup, 0105)');
select tests.authenticate_as(:'eko');
select set_config('realtime.topic', 'room:' || :'dm', true) as topic \gset
select throws_ok($$insert into realtime.messages (topic, extension, payload, event, private)
                   values (realtime.topic(), 'presence', '{}', 'presence', true)$$,
  '42501', null, 'Bukan anggota tidak bisa memakai presence room orang lain');

select tests.authenticate_as(:'alice');
select id as m_dm from send_message(:'dm', 'Halo Bob lewat siaran', 'e7800000-0000-4000-8000-000000000001') \gset
reset role;
select is((select count(*)::integer from realtime.messages
           where topic = 'room:' || :'dm' and event = 'message' and payload ->> 'id' = :'m_dm'),
  1, 'Pesan DM baru disiarkan sekali ke topik room');
select is((select payload ->> 'body' from realtime.messages
           where topic = 'room:' || :'dm' and event = 'message' and payload ->> 'id' = :'m_dm'),
  'Halo Bob lewat siaran', 'Siaran membawa isi pesan untuk dirender langsung');
select is((select payload ->> 'sender_username' from realtime.messages
           where topic = 'room:' || :'dm' and event = 'message' and payload ->> 'id' = :'m_dm'),
  'rb_alice', 'Siaran membawa profil pengirim');
select ok((select payload ? 'cursor' and payload ? 'client_id' and payload ? 'created_at' from realtime.messages
           where topic = 'room:' || :'dm' and event = 'message' and payload ->> 'id' = :'m_dm'),
  'Siaran membawa cursor dan client_id untuk dedupe dan isi celah');
select ok((select not (payload ?| array['moderation_status', 'reactions', 'shared_post', 'moderated_at']) from realtime.messages
           where topic = 'room:' || :'dm' and event = 'message' and payload ->> 'id' = :'m_dm'),
  'Siaran tanpa data per penonton (status moderasi, reaksi, pratinjau postingan)');
select is((select count(*)::integer from realtime.messages
           where event = 'room_activity' and payload ->> 'message_id' = :'m_dm'
             and topic in ('user:' || :'alice', 'user:' || :'bob')),
  2, 'Aktivitas DM dikirim ke topik user kedua anggota');
select is((select count(*)::integer from realtime.messages
           where event = 'room_activity' and payload ->> 'message_id' = :'m_dm'
             and topic not in ('user:' || :'alice', 'user:' || :'bob')),
  0, 'Aktivitas DM tidak dikirim ke user lain');

select tests.authenticate_as(:'alice');
select id as m_stock from send_message(:'stock', 'Pantau antrean pagi', 'e7800000-0000-4000-8000-000000000002') \gset
reset role;
select is((select count(*)::integer from realtime.messages
           where topic = 'room:' || :'stock' and event = 'message' and payload ->> 'id' = :'m_stock'),
  1, 'Pesan room saham disiarkan sekali, berapa pun jumlah anggotanya');
select is((select count(*)::integer from realtime.messages
           where event = 'room_activity' and payload ->> 'message_id' = :'m_stock'),
  0, 'Room saham tidak mengirim aktivitas per anggota');

insert into public.blocks (blocker_id, blocked_id) values (:'carol', :'alice');
select tests.authenticate_as(:'alice');
select id as m_grp from send_message(:'grp', 'Rahasia untuk yang tidak memblokir', 'e7800000-0000-4000-8000-000000000003') \gset
reset role;
select is((select payload ->> 'ref' from realtime.messages
           where topic = 'room:' || :'grp' and event = 'message' and payload ->> 'id' = :'m_grp'),
  'true', 'Pesan dari pengirim yang terlibat blokir di room hanya disiarkan sebagai referensi');
select ok((select not (payload ? 'body') and not (payload ? 'attachments') from realtime.messages
           where topic = 'room:' || :'grp' and event = 'message' and payload ->> 'id' = :'m_grp'),
  'Referensi pesan tidak memuat isi; klien mengambilnya lewat get_messages (RLS)');
select is((select count(*)::integer from realtime.messages
           where event = 'room_activity' and payload ->> 'message_id' = :'m_grp' and topic = 'user:' || :'carol'),
  0, 'Aktivitas tidak dikirim ke anggota yang memblokir pengirim');
select is((select count(*)::integer from realtime.messages
           where event = 'room_activity' and payload ->> 'message_id' = :'m_grp' and topic = 'user:' || :'bob'),
  1, 'Aktivitas tetap dikirim ke anggota lain');
select tests.authenticate_as(:'carol');
select is((select count(*)::integer from get_messages(:'grp') where id = :'m_grp'), 0,
  'Pengambilan referensi oleh yang memblokir tetap kosong');
select tests.authenticate_as(:'bob');
select is((select body from get_messages(:'grp') where id = :'m_grp'), 'Rahasia untuk yang tidak memblokir',
  'Anggota lain mengambil isi pesan referensi');

reset role;
update public.messages set body = 'Halo Bob, sudah diubah' where id = :'m_dm';
select is((select count(*)::integer from realtime.messages
           where topic = 'room:' || :'dm' and event = 'message' and payload ->> 'id' = :'m_dm'
             and payload ->> 'body' = 'Halo Bob, sudah diubah' and payload ? 'edited_at'),
  1, 'Pesan yang diubah disiarkan ulang dengan isi baru');
update public.messages set moderated_at = now() where id = :'m_dm';
select is((select count(*)::integer from realtime.messages
           where topic = 'room:' || :'dm' and event = 'message' and payload ->> 'id' = :'m_dm'),
  2, 'Perubahan kolom yang tidak tampil tidak disiarkan');

select tests.authenticate_as(:'alice');
select id as m_del from send_message(:'dm', 'Akan dihapus', 'e7800000-0000-4000-8000-000000000004') \gset
select delete_message(:'m_del') as deleted \gset
reset role;
select ok((select bool_and(payload ->> 'is_deleted' = 'true' and not (payload ? 'body')) from realtime.messages
           where topic = 'room:' || :'dm' and event = 'message' and payload ->> 'id' = :'m_del'
             and payload ->> 'is_deleted' = 'true'),
  'Pesan terhapus disiarkan tanpa isi');

select tests.authenticate_as(:'alice');
select id as m_hide from send_message(:'stock', 'Akan disembunyikan', 'e7800000-0000-4000-8000-000000000005') \gset
reset role;
update public.messages set moderation_status = 'hidden', moderated_at = now() where id = :'m_hide';
select is((select count(*)::integer from realtime.messages
           where topic = 'room:' || :'stock' and event = 'message_hidden' and payload ->> 'message_id' = :'m_hide'),
  1, 'Pesan yang disembunyikan memicu sinyal message_hidden dari server');
update public.messages set body = 'Isi tersembunyi diubah' where id = :'m_hide';
select is((select count(*)::integer from realtime.messages
           where topic = 'room:' || :'stock' and event = 'message' and payload ->> 'body' = 'Isi tersembunyi diubah'),
  0, 'Pesan tersembunyi tidak pernah disiarkan isinya');

insert into public.messages (room_id, sender_id, body, moderation_status)
values (:'stock', :'alice', 'Ditahan moderasi', 'held');
select is((select count(*)::integer from realtime.messages
           where topic = 'room:' || :'stock' and payload ->> 'body' = 'Ditahan moderasi'),
  0, 'Pesan yang ditahan moderasi tidak disiarkan');

select tests.authenticate_as(:'dina');
select cs_api.open_ticket('account') as j \gset
select (:'j'::jsonb ->> 'id') as ticket, (:'j'::jsonb ->> 'room_id') as support \gset
select id as m_cs from cs_api.send_message(:'support', 'Saldo saya belum masuk') \gset
reset role;
select is((select count(*)::integer from realtime.messages
           where topic = 'room:' || :'support' and event = 'message' and payload ->> 'id' = :'m_cs'),
  1, 'Pesan chat CS disiarkan ke topik room nasabah');
select ok((select not (payload ? 'sender_username') from realtime.messages
           where topic = 'room:' || :'support' and event = 'message' and payload ->> 'id' = :'m_cs'),
  'Siaran chat CS tidak memuat profil; pengirim dibaca dari anggota room');
select is((select payload ->> 'ticket_id' from realtime.messages
           where topic = 'cs:room:' || :'support' and event = 'message' and payload ->> 'id' = :'m_cs'),
  :'ticket', 'Staf menerima sinyal pesan baru di topik cs:room');
select ok((select not (payload ? 'body') from realtime.messages
           where topic = 'cs:room:' || :'support' and event = 'message' and payload ->> 'id' = :'m_cs'),
  'Sinyal staf hanya berisi id; isi diambil lewat cs_api.get_messages');
select is((select array_agg(topic) from realtime.messages
           where event = 'room_activity' and payload ->> 'message_id' = :'m_cs'),
  array['user:' || :'dina'], 'Aktivitas chat CS hanya ke nasabah');

select tests.authenticate_as(:'alice');
select ok(send_typing(:'dm'), 'Typing dikirim server');
select is((select payload ->> 'user_id' from realtime.messages
           where topic = 'room:' || :'dm' and event = 'typing' order by inserted_at desc limit 1),
  :'alice', 'Identitas typing diambil dari JWT, bukan dari klien');
select ok(not send_typing(:'dm'), 'Typing berulang dalam 3 detik tidak disiarkan ulang');
select ok(send_typing(:'dm', false), 'Berhenti mengetik tetap disiarkan');
select is((select count(*)::integer from realtime.messages where topic = 'room:' || :'dm' and event = 'typing'),
  2, 'Hanya dua sinyal typing yang benar-benar dikirim');
select tests.authenticate_as(:'eko');
select throws_ok(format($$select send_typing(%L)$$, :'dm'), 'PT404', 'not_member',
  'Bukan anggota tidak bisa mengirim typing');
select throws_ok(format($$select cs_api.agent_typing(%L)$$, :'support'), 'PT403', 'agent_required',
  'Nasabah tidak bisa memakai typing CS');
reset role;
select tests.authenticate_anon();
select throws_ok(format($$select send_typing(%L)$$, :'dm'), '42501', null, 'Anon tidak bisa mengirim typing');
reset role;

select tests.agent_online(:'rani');
select tests.authenticate_agent(:'rani');
select cs_api.claim_ticket(:'ticket') ->> 'id' as claimed \gset
select ok(cs_api.agent_typing(:'support'), 'CS pemilik tiket mengirim typing ke nasabah');
reset role;
select is((select payload ->> 'display_name' from realtime.messages
           where topic = 'room:' || :'support' and event = 'typing' order by inserted_at desc limit 1),
  'Rani', 'Typing CS memakai nama tampilan agen');

select * from finish();
rollback;
