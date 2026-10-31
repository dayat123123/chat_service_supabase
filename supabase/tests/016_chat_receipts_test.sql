begin;
select plan(21);

select tests.create_user('rc_alice') as alice \gset
select tests.create_user('rc_bob') as bob \gset
select tests.create_user('rc_carol') as carol \gset

select tests.authenticate_as(:'alice');
select get_or_create_direct_room(:'bob') as dm \gset
select create_group_room('Grup Uji', array[:'bob', :'carol']::uuid[]) as grp \gset
select join_stock_room('BBCA') as stock_room \gset
select tests.authenticate_as(:'bob');
select join_stock_room('BBCA') as stock_room_bob \gset

reset role;
update chat_members
   set last_read_at = now() - interval '1 minute',
       last_delivered_at = now() - interval '1 minute'
 where room_id in (:'dm', :'grp', :'stock_room');

select tests.authenticate_as(:'alice');
select id as m_dm from send_message(:'dm', 'Halo Bob', 'e1000000-0000-4000-8000-000000000001') \gset
select is(
  (select last_message_status from get_my_rooms() where id = :'dm'), 'sent',
  'Belum diterima perangkat lawan: centang satu');
select is(mark_rooms_delivered(), 0, 'Pesan sendiri tidak perlu ditandai terkirim');

select tests.authenticate_as(:'bob');
select is(
  (select last_message_status from get_my_rooms() where id = :'dm'), null,
  'Status centang hanya untuk pesan sendiri');
select is(mark_rooms_delivered(array[:'dm']::uuid[]), 1, 'Penerima yang online menandai pesan terkirim');
select is(mark_rooms_delivered(), 0, 'Tanda terkirim tidak diulang tanpa pesan baru');

reset role;
select is(
  (select count(*)::int from realtime.messages
    where topic = 'room:' || :'dm' and event = 'receipt' and payload ->> 'user_id' = :'bob'),
  1, 'Tanda terkirim disiarkan server ke channel room');

select tests.authenticate_as(:'alice');
select is(
  (select last_message_status from get_my_rooms() where id = :'dm'), 'delivered',
  'Diterima tapi belum dibuka: centang dua abu-abu');

select tests.authenticate_as(:'bob');
select lives_ok(format('select mark_room_read(%L)', :'dm'), 'Penerima membuka room');
select ok(
  (select last_delivered_at >= last_read_at from get_room_members(:'dm') where user_id = :'bob'),
  'Membaca juga berarti sudah diterima');
select throws_ok(
  format('update chat_members set last_read_at = now() where room_id = %L', :'dm'),
  '42501', null, 'last_read_at hanya bisa diubah lewat RPC');

select tests.authenticate_as(:'alice');
select is(
  (select last_message_status from get_my_rooms() where id = :'dm'), 'read',
  'Sudah dibaca: centang dua biru');

select id as m_grp from send_message(:'grp', 'Halo grup', 'e1000000-0000-4000-8000-000000000002') \gset
select tests.authenticate_as(:'bob');
select is(mark_rooms_delivered(), 1, 'Anggota grup pertama menerima');
select tests.authenticate_as(:'alice');
select is(
  (select last_message_status from get_my_rooms() where id = :'grp'), 'sent',
  'Grup: centang dua menunggu semua anggota menerima');
select tests.authenticate_as(:'carol');
select is(mark_rooms_delivered(), 1, 'Anggota grup kedua menerima');
select tests.authenticate_as(:'alice');
select is(
  (select last_message_status from get_my_rooms() where id = :'grp'), 'delivered',
  'Grup: semua menerima, centang dua abu-abu');
select tests.authenticate_as(:'bob');
select lives_ok(format('select mark_room_read(%L)', :'grp'), 'Anggota grup pertama membaca');
select tests.authenticate_as(:'alice');
select is(
  (select last_message_status from get_my_rooms() where id = :'grp'), 'delivered',
  'Grup: biru menunggu semua anggota membaca');
select tests.authenticate_as(:'carol');
select lives_ok(format('select mark_room_read(%L)', :'grp'), 'Anggota grup kedua membaca');
select tests.authenticate_as(:'alice');
select is(
  (select last_message_status from get_my_rooms() where id = :'grp'), 'read',
  'Grup: semua membaca, centang dua biru');

select id as m_stock from send_message(:'stock_room', 'Pantau BBCA', 'e1000000-0000-4000-8000-000000000003') \gset
select tests.authenticate_as(:'bob');
select is(mark_rooms_delivered(array[:'stock_room']::uuid[]), 0, 'Room saham tidak dilacak tanda terimanya');

select tests.authenticate_as(:'carol');
select throws_ok(
  format('select mark_room_read(%L)', :'dm'),
  'PT404', 'not_member', 'Non-anggota tidak bisa menandai room dibaca');

select * from finish();
rollback;
