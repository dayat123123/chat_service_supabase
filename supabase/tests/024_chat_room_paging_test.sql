begin;
select plan(11);

select tests.create_stock('BBCA');
select tests.create_user('alice') as alice \gset
select tests.create_user('bob_user') as bob \gset
select tests.create_user('carol') as carol \gset
select tests.create_user('dina') as dina \gset

select tests.authenticate_as(:'alice');
select get_or_create_direct_room(:'bob') as dm_bob \gset
select get_or_create_direct_room(:'carol') as dm_carol \gset
select join_stock_room('BBCA') as stock \gset

reset role;
select cs.ensure_room(:'alice') as support \gset
update chat_rooms set last_message_at = now() - interval '1 hour' where id = :'dm_bob';
update chat_rooms set last_message_at = now() - interval '2 hours' where id = :'dm_carol';
update chat_rooms set last_message_at = now() - interval '3 hours' where id = :'stock';
update chat_rooms set last_message_at = now() - interval '9 hours' where id = :'support';

select tests.authenticate_as(:'alice');
select is(
  array(select id from get_my_rooms(null, 2)),
  array[:'support', :'dm_bob']::uuid[],
  'Halaman pertama: room CS tersemat di atas, lalu aktivitas terbaru sesuai limit');
select ok(
  (select bool_and(cursor is not null) from get_my_rooms(null, 2)),
  'Setiap room membawa cursor');

select cursor as page_two from get_my_rooms(null, 2) where id = :'dm_bob' \gset
select is(
  array(select id from get_my_rooms(:'page_two', 2)),
  array[:'dm_carol', :'stock']::uuid[],
  'Halaman berikutnya melanjutkan dari cursor tanpa duplikat');

select cursor as page_three from get_my_rooms(:'page_two', 2) where id = :'stock' \gset
select is((select count(*)::int from get_my_rooms(:'page_three', 2)), 0, 'Setelah halaman terakhir tidak ada room lagi');

select is((select count(*)::int from get_my_rooms()), 4, 'Tanpa argumen memuat halaman pertama dengan limit bawaan');
select is((select count(*)::int from get_my_rooms(null, 0)), 1, 'Limit di bawah 1 dinaikkan menjadi 1');
select throws_ok(
  $$select * from get_my_rooms('bukan-cursor', 2)$$,
  'PT400', 'invalid_cursor', 'Cursor rusak ditolak');

reset role;
update chat_rooms set last_message_at = now() where id = :'stock';
select tests.authenticate_as(:'alice');
select is(
  array(select id from get_my_rooms(null, 2)),
  array[:'support', :'stock']::uuid[],
  'Room dengan aktivitas baru naik ke halaman pertama');

select is(
  (select other_username from get_my_room(:'dm_bob')), 'bob_user',
  'get_my_room memuat detail satu room milik anggota');

select tests.authenticate_as(:'dina');
select is((select count(*)::int from get_my_room(:'dm_bob')), 0, 'Non-anggota tidak mendapat detail room');
select is((select count(*)::int from get_my_rooms()), 0, 'Non-anggota tidak melihat room orang lain');

select * from finish();
rollback;
