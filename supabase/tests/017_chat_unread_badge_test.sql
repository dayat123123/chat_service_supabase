begin;
select plan(12);

select tests.create_user('ub_alice') as alice \gset
select tests.create_user('ub_bob') as bob \gset
select tests.create_user('ub_carol') as carol \gset
insert into follows (follower_id, following_id) values (:'bob', :'alice'), (:'bob', :'carol');

select tests.authenticate_as(:'alice');
select get_or_create_direct_room(:'bob') as dm \gset
select create_group_room('Grup Badge', array[:'bob', :'carol']::uuid[]) as grp \gset
select join_stock_room('BBRI') as stock_room \gset
select tests.authenticate_as(:'bob');
select join_stock_room('BBRI') as stock_room_bob \gset
select tests.authenticate_as(:'carol');
select get_or_create_direct_room(:'bob') as dm2 \gset

reset role;
update chat_members
   set last_read_at = now() - interval '1 minute',
       last_delivered_at = now() - interval '1 minute'
 where room_id in (:'dm', :'grp', :'stock_room', :'dm2');

select tests.authenticate_as(:'bob');
select is(get_unread_chat_count(), 0, 'Belum ada chat yang belum dibaca');

select tests.authenticate_as(:'alice');
select id as m1 from send_message(:'dm', 'Halo Bob', 'e2000000-0000-4000-8000-000000000001') \gset
select id as m2 from send_message(:'dm', 'Masih di sana?', 'e2000000-0000-4000-8000-000000000002') \gset
select tests.authenticate_as(:'bob');
select is(get_unread_chat_count(), 1, 'Dua pesan di satu DM dihitung satu chat');

select tests.authenticate_as(:'alice');
select id as m3 from send_message(:'grp', 'Halo grup', 'e2000000-0000-4000-8000-000000000003') \gset
select id as m4 from send_message(:'stock_room', 'Pantau BBRI', 'e2000000-0000-4000-8000-000000000004') \gset
select is(get_unread_chat_count(), 0, 'Pesan sendiri tidak membuat chat belum dibaca');
select tests.authenticate_as(:'bob');
select is(get_unread_chat_count(), 2, 'DM dan grup dihitung, room saham tidak');

select lives_ok(
  format('update chat_members set muted = true where room_id = %L and user_id = %L', :'grp', :'bob'),
  'Bob membisukan grup');
select is(get_unread_chat_count(), 1, 'Room yang dibisukan tidak dihitung');

select lives_ok(format('select mark_room_read(%L)', :'dm'), 'Bob membuka DM');
select is(get_unread_chat_count(), 0, 'DM yang sudah dibuka tidak dihitung lagi');

select tests.authenticate_as(:'carol');
select id as m5 from send_message(:'dm2', 'Salah kirim', 'e2000000-0000-4000-8000-000000000005') \gset
select tests.authenticate_as(:'bob');
select is(get_unread_chat_count(), 1, 'Chat baru dari Carol dihitung');

select tests.authenticate_as(:'carol');
select lives_ok(format('select delete_message(%L)', :'m5'), 'Carol menghapus pesannya');
select tests.authenticate_as(:'bob');
select is(get_unread_chat_count(), 0, 'Pesan yang dihapus tidak dihitung');

select tests.authenticate_anon();
select throws_ok($$select get_unread_chat_count()$$, '42501', null, 'anon tidak bisa memanggil get_unread_chat_count');

select * from finish();
rollback;
