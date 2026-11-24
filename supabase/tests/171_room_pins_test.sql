begin;
select plan(31);

update private.rate_limits set max_count = 1000 where action in ('message', 'room_create', 'stock_room_create');
update private.settings set value = '0' where key = 'safety.new_account_days';

create function pg_temp.pins(p_user uuid) returns integer language sql security definer as $$
  select count(*)::integer from public.chat_members where user_id = p_user and pinned_at is not null
$$;
create function pg_temp.pin_events(p_user uuid, p_room uuid, p_pinned boolean) returns integer language sql security definer as $$
  select count(*)::integer from realtime.messages
  where topic = 'user:' || p_user::text and event = 'room_pinned' and payload ->> 'room_id' = p_room::text
    and (payload -> 'pinned_at' <> 'null'::jsonb) = p_pinned
$$;

select tests.create_user('pn_ani') as ani \gset
select tests.create_user('pn_budi') as budi \gset
select tests.create_user('pn_cici') as cici \gset
select tests.create_user('pn_dodi') as dodi \gset
select tests.create_user('pn_eka') as eka \gset
select tests.create_user('pn_luar') as luar \gset

select tests.authenticate_as(:'ani');
select get_or_create_direct_room(:'budi') as dm_budi \gset
select get_or_create_direct_room(:'cici') as dm_cici \gset
select get_or_create_direct_room(:'dodi') as dm_dodi \gset
select get_or_create_direct_room(:'eka') as dm_eka \gset
select create_group_room('Grup Pin', array[:'budi', :'cici']::uuid[]) as grp \gset
select join_stock_room('BBCA') as stock \gset
reset role;
update private.dm_requests set status = 'accepted', responded_at = now() where sender_id = :'ani';
select cs.ensure_room(:'ani') as support \gset
update public.chat_rooms set last_message_at = now() - interval '1 hour' where id = :'dm_budi';
update public.chat_rooms set last_message_at = now() - interval '2 hours' where id = :'dm_cici';
update public.chat_rooms set last_message_at = now() - interval '3 hours' where id = :'dm_dodi';
update public.chat_rooms set last_message_at = now() - interval '4 hours' where id = :'dm_eka';
update public.chat_rooms set last_message_at = now() - interval '5 hours' where id = :'grp';
update public.chat_rooms set last_message_at = now() - interval '6 hours' where id = :'stock';
update public.chat_rooms set last_message_at = now() - interval '9 hours' where id = :'support';

select tests.authenticate_as(:'ani');
select is((select count(*)::integer from get_my_rooms(null, 100) where pinned_at is not null), 0,
  'Tanpa sematan tidak ada room yang disematkan');
select set_room_pinned(:'dm_eka', true) as eka_pin \gset
select ok(:'eka_pin' is not null and :'eka_pin' <> '', 'Menyematkan chat mengembalikan waktu sematan');
select is((select pinned_at from get_my_room(:'dm_eka')), :'eka_pin'::timestamptz, 'get_my_room membawa pinned_at');
select is(set_room_pinned(:'dm_eka', true), :'eka_pin'::timestamptz, 'Menyematkan ulang mempertahankan waktu sematan awal');
select ok(set_room_pinned(:'grp', true) is not null, 'Grup bisa disematkan');
select ok(set_room_pinned(:'dm_dodi', true) is not null, 'Sematan ketiga diterima');

select throws_ok(format('select set_room_pinned(%L, true)', :'dm_cici'), 'PT409', 'pin_limit',
  'Sematan keempat ditolak');
select throws_ok(format('select set_room_pinned(%L, true)', :'support'), 'PT400', 'cannot_pin',
  'Chat CS tidak bisa disematkan');
select throws_ok(format('select set_room_pinned(%L, false)', :'support'), 'PT400', 'cannot_pin',
  'Chat CS juga tidak bisa dilepas sematannya');
select throws_ok(format('select set_room_pinned(%L, null)', :'dm_cici'), 'PT400', 'invalid_pinned',
  'Nilai sematan wajib diisi');

select is(array(select id from get_my_rooms(null, 2)),
  array[:'support', :'dm_dodi', :'grp', :'dm_eka', :'dm_budi']::uuid[],
  'Halaman pertama: CS, semua chat tersemat dari sematan terbaru, lalu chat lain sesuai limit');
select cursor as page_two from get_my_rooms(null, 2) where id = :'dm_budi' \gset
select is(array(select id from get_my_rooms(:'page_two', 2)), array[:'dm_cici', :'stock']::uuid[],
  'Halaman berikutnya hanya memuat chat yang tidak disematkan');
select cursor as page_three from get_my_rooms(:'page_two', 2) where id = :'stock' \gset
select is((select count(*)::integer from get_my_rooms(:'page_three', 2)), 0, 'Setelah halaman terakhir tidak ada room lagi');

select is(array(select id from get_my_rooms(null, 1)),
  array[:'support', :'dm_dodi', :'grp', :'dm_eka']::uuid[],
  'Chat tersemat tidak memakan limit halaman');
select cursor as after_pinned from get_my_rooms(null, 1) where id = :'dm_eka' \gset
select is(array(select id from get_my_rooms(:'after_pinned', 2)), array[:'dm_budi', :'dm_cici']::uuid[],
  'Cursor baris tersemat terakhir melanjutkan ke chat tidak tersemat paling atas');
select is((select count(*)::integer from get_my_rooms(null, 100)), 7, 'Setiap room muncul tepat sekali');
reset role;

select is(pg_temp.pin_events(:'ani', :'dm_eka', true) + pg_temp.pin_events(:'ani', :'grp', true)
          + pg_temp.pin_events(:'ani', :'dm_dodi', true), 3,
  'Event room_pinned dikirim sekali per sematan baru, tidak untuk sematan ulang');

select tests.authenticate_as(:'budi');
select id as grp_msg from send_message(:'grp', 'Pesan grup baru') \gset
select tests.authenticate_as(:'cici');
select id as cici_msg from send_message(:'dm_cici', 'Pesan baru dari Cici') \gset
select tests.authenticate_as(:'ani');
select is(array(select id from get_my_rooms(null, 2)),
  array[:'support', :'dm_dodi', :'grp', :'dm_eka', :'dm_cici']::uuid[],
  'Pesan baru tidak mengubah urutan sematan dan menaikkan chat lain ke atas bagian tak tersemat');

select is(set_room_pinned(:'dm_eka', false), null::timestamptz, 'Melepas sematan mengembalikan null');
select is((select pinned_at from get_my_room(:'dm_eka')), null::timestamptz, 'pinned_at kosong setelah dilepas');
select is(set_room_pinned(:'dm_eka', false), null::timestamptz, 'Melepas sematan yang tidak ada tetap aman');
reset role;
select is(pg_temp.pin_events(:'ani', :'dm_eka', false), 1, 'Event room_pinned dengan pinned_at null dikirim sekali');

select tests.authenticate_as(:'budi');
select create_group_room('Grup Sementara', array[:'ani']::uuid[]) as grp2 \gset
select tests.authenticate_as(:'ani');
select set_room_pinned(:'grp2', true) as grp2_pin \gset
select tests.authenticate_as(:'budi');
select delete_group(:'grp2') as deleted \gset
reset role;
select is(pg_temp.pins(:'ani'), 2, 'Grup yang dihapus ikut melepas sematannya');

select tests.authenticate_as(:'ani');
select set_room_pinned(:'dm_cici', true) as cici_pin \gset
select hide_room(:'dm_cici') as hidden \gset
reset role;
select is((select pinned_at from public.chat_members where room_id = :'dm_cici' and user_id = :'ani'), null::timestamptz,
  'Menghapus chat untuk saya melepas sematannya');

select tests.authenticate_as(:'ani');
select leave_room(:'grp') as left_group \gset
reset role;
select is(pg_temp.pins(:'ani'), 1, 'Keluar grup ikut melepas sematannya');

select tests.authenticate_as(:'ani');
select ok(set_room_pinned(:'dm_budi', true) is not null and set_room_pinned(:'stock', true) is not null,
  'Slot sematan yang kosong bisa dipakai lagi, termasuk room saham');
select throws_ok(format('select set_room_pinned(%L, true)', :'dm_eka'), 'PT409', 'pin_limit',
  'Batas sematan tetap tiga');
select throws_ok(format('update public.chat_members set pinned_at = now() where room_id = %L', :'dm_eka'),
  '42501', null, 'pinned_at tidak bisa diubah langsung lewat tabel');

select tests.authenticate_as(:'luar');
select throws_ok(format('select set_room_pinned(%L, true)', :'dm_budi'), 'PT404', 'not_member',
  'Bukan anggota tidak bisa menyematkan');

select tests.authenticate_as(:'budi');
select is((select pinned_at from get_my_room(:'dm_budi')), null::timestamptz,
  'Sematan bersifat pribadi per anggota');
reset role;

select is((select value #>> '{}' from private.settings where key = 'rooms.pin_limit'), '3',
  'Batas sematan tersimpan di pengaturan');

select * from finish();
rollback;
