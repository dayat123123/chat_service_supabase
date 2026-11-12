begin;
select plan(5);

update private.rate_limits set max_count = 1000 where action in ('message', 'room_create', 'stock_room_create');
select tests.create_user('lr_owner') as owner \gset
select tests.create_user('lr_ani') as ani \gset

select tests.authenticate_as(:'owner');
select create_group_room('Keluar', array[:'ani']::uuid[]) as grp \gset
select tests.authenticate_as(:'ani');
select join_stock_room('LRXT') as stock \gset
select lives_ok(format('select leave_room(%L)', :'grp'), 'Anggota keluar dari grup');
select lives_ok(format('select leave_room(%L)', :'stock'), 'Anggota keluar dari room saham');
reset role;

select is((select array_agg(payload ->> 'room_id' order by payload ->> 'room_id') from realtime.messages
           where topic = 'user:' || :'ani' and event = 'room_removed' and payload ->> 'reason' = 'left'),
  (select array_agg(x order by x) from unnest(array[:'grp', :'stock']) x),
  'Sesi lain milik pengguna menerima room_removed dengan alasan left');
select is((select count(*)::integer from realtime.messages
           where topic = 'user:' || :'owner' and event = 'room_removed'), 0,
  'Anggota lain tidak menerima event keluar milik pengguna');

select tests.authenticate_as(:'ani');
select throws_ok(format('select leave_room(%L)', :'grp'), 'PT404', 'not_member', 'Keluar dua kali ditolak tanpa event baru');

select * from finish();
rollback;
