begin;
select plan(28);

select tests.create_user('alice') as alice \gset
select tests.create_user('bob_user') as bob \gset
select tests.create_user('carol') as carol \gset
insert into follows (follower_id, following_id) values (:'bob', :'alice');

select tests.authenticate_as(:'alice');
select get_or_create_direct_room(:'bob') as dm \gset
select is(get_or_create_direct_room(:'bob'), :'dm'::uuid, 'DM dengan user yang sama memakai room yang sama');
select tests.authenticate_as(:'bob');
select is(get_or_create_direct_room(:'alice'), :'dm'::uuid, 'DM dari sisi lawan juga memakai room yang sama');
select throws_ok(
  format('select get_or_create_direct_room(%L)', :'bob'),
  'PT400', 'invalid_user', 'Tidak bisa DM diri sendiri');

-- now() is constant within a transaction; move last_read_at back so messages sent in this test
-- count as unread.
reset role;
update chat_members set last_read_at = now() - interval '1 minute' where room_id = :'dm';

select tests.authenticate_as(:'alice');
select lives_ok(
  format($$select send_message(%L, 'Halo Bob', 'f0000000-0000-4000-8000-000000000001')$$, :'dm'),
  'Anggota bisa mengirim pesan');
select lives_ok(
  format($$select send_message(%L, 'Halo Bob', 'f0000000-0000-4000-8000-000000000001')$$, :'dm'),
  'Kirim ulang dengan client_id sama tidak error');
select is(
  (select count(*)::int from messages where room_id = :'dm'), 1,
  'Kirim ulang dengan client_id sama tidak menduplikasi pesan');
select id as m2 from send_message(:'dm', 'Sudah lihat BBCA?', 'f0000000-0000-4000-8000-000000000002') \gset
select is(
  (select reply_to_body from send_message(:'dm', 'Balasan', null, :'m2')),
  'Sudah lihat BBCA?', 'Balasan menyertakan cuplikan pesan yang dibalas');

select tests.authenticate_as(:'carol');
select is((select count(*)::int from messages where room_id = :'dm'), 0, 'Non-anggota tidak bisa membaca pesan');
select throws_ok(
  format($$insert into messages (room_id, sender_id, body) values (%L, auth.uid(), 'nyusup')$$, :'dm'),
  '42501', null, 'Non-anggota tidak bisa insert pesan');
select throws_ok(
  format($$select get_messages(%L)$$, :'dm'),
  'PT403', 'not_member', 'Non-anggota tidak bisa memanggil get_messages');

select tests.authenticate_as(:'bob');
select is(
  (select unread_count from get_unread_counts() where room_id = :'dm'), 3,
  'Penerima punya 3 pesan belum dibaca');
select is(
  (select other_username from get_my_rooms() where id = :'dm'), 'alice',
  'get_my_rooms menampilkan lawan bicara DM');
select is(
  (select count(*)::int from get_messages(:'dm', null, 2)), 2,
  'get_messages menghormati limit');
select lives_ok(format('select mark_room_read(%L)', :'dm'), 'Penerima bisa menandai room dibaca');
select is(
  (select unread_count from get_unread_counts() where room_id = :'dm'), 0,
  'Unread menjadi 0 setelah dibaca');

reset role;
select is(
  (select count(*)::int from notifications where user_id = :'bob' and type = 'message'), 1,
  'Notifikasi pesan digabung per room');

insert into blocks (blocker_id, blocked_id) values (:'bob', :'alice');
select tests.authenticate_as(:'alice');
select throws_ok(
  format($$select send_message(%L, 'masih bisa?')$$, :'dm'),
  'PT403', 'cannot_send', 'Tidak bisa mengirim pesan ke user yang memblokir');
select throws_ok(
  format('select get_or_create_direct_room(%L)', :'bob'),
  'PT403', 'blocked', 'Tidak bisa membuat DM dengan user yang memblokir');

select create_group_room('Diskusi Bank', array[:'carol']::uuid[]) as grp \gset
reset role;
select results_eq(
  format('select user_id, role from chat_members where room_id = %L order by role desc', :'grp'),
  format('values (%L::uuid, %L::text), (%L::uuid, %L::text)', :'alice', 'owner', :'carol', 'member'),
  'Pembuat grup menjadi owner, anggota ditambahkan');
select tests.authenticate_as(:'alice');
select lives_ok(format('select leave_room(%L)', :'grp'), 'Owner bisa keluar dari grup');
reset role;
select is(
  (select role from chat_members where room_id = :'grp' and user_id = :'carol'), 'owner',
  'Kepemilikan grup diwariskan ke anggota tersisa');

select tests.authenticate_as(:'carol');
select join_stock_room('bbca') as stock_room \gset
select tests.authenticate_as(:'bob');
select is(join_stock_room('BBCA'), :'stock_room'::uuid, 'Satu room per kode saham');
select join_stock_room('nope') as new_room \gset
select is((select name from chat_rooms where id = :'new_room'), 'NOPE',
  'Kode saham apa pun dari klien membuka room tanpa daftar saham di server');
select throws_ok($$select join_stock_room('1X')$$, 'PT400', 'invalid_stock_code', 'Kode saham berformat salah ditolak');
reset role;
update private.rate_limits set max_count = 1 where action = 'stock_room_create';
select tests.authenticate_as(:'bob');
select throws_like($$select join_stock_room('XYZW')$$, '%"PT429"%"rate_limited"%',
  'Pembuatan room saham baru dibatasi rate limit');
select is(join_stock_room('BBCA'), :'stock_room'::uuid, 'Bergabung ke room saham yang sudah ada tidak terkena rate limit');

reset role;
update private.rate_limits set max_count = 1 where action = 'message';
select tests.authenticate_as(:'carol');
select lives_ok(format($$select send_message(%L, 'Pesan pertama')$$, :'stock_room'), 'Pesan pertama terkirim');
select throws_like(
  format($$select send_message(%L, 'Pesan kedua')$$, :'stock_room'),
  '%"PT429"%"rate_limited"%', 'Rate limit pesan berlaku');

select * from finish();
rollback;
