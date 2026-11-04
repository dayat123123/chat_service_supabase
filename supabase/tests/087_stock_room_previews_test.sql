begin;
select plan(14);

update private.rate_limits set max_count = 1000 where action = 'message';
update private.settings set value = '0' where key = 'rooms.busy_slow_mode';

select is(private.setting_num('rooms.preview_poll_seconds', 0), 15::numeric, 'Polling pratinjau bawaan 15 detik');

select tests.create_user('pv_alice') as alice \gset
select tests.create_user('pv_bob') as bob \gset

select tests.authenticate_as(:'alice');
select join_stock_room('PVAA') as mine \gset
select get_or_create_direct_room(:'bob') as dm \gset
select tests.authenticate_as(:'bob');
select join_stock_room('PVAA') is not null as joined \gset
select join_stock_room('PVBB') as other \gset
select id as m1 from send_message(:'mine', 'Antre di bid', 'e8700000-0000-4000-8000-000000000001') \gset
select id as m2 from send_message(:'mine', 'Offer tebal', 'e8700000-0000-4000-8000-000000000002') \gset
select id as m3 from send_message(:'dm', 'Halo', 'e8700000-0000-4000-8000-000000000003') \gset
select id as m4 from send_message(:'other', 'Room lain', 'e8700000-0000-4000-8000-000000000004') \gset
select tests.authenticate_as(:'alice');
select id as m5 from send_message(:'mine', 'Saya ikut', 'e8700000-0000-4000-8000-000000000005') \gset
reset role;
update public.chat_members set last_read_at = '-infinity' where room_id = :'mine' and user_id = :'alice';

select tests.authenticate_as(:'alice');
select get_room_previews(array[:'mine', :'dm', :'other']::uuid[]) as res \gset
select is(jsonb_array_length(:'res'::jsonb -> 'rooms'), 1, 'Hanya room saham milik pemanggil yang dikembalikan');
select is(:'res'::jsonb -> 'rooms' -> 0 ->> 'room_id', :'mine', 'Room saham yang diikuti dikembalikan');
select is((:'res'::jsonb ->> 'poll_seconds')::numeric, 15::numeric, 'Interval polling ikut dikirim server');
select is(:'res'::jsonb -> 'rooms' -> 0 ->> 'last_message_preview',
  (select last_message_preview from get_my_rooms(null, 50) where id = :'mine'), 'Pratinjau sama dengan get_my_rooms');
select is((:'res'::jsonb -> 'rooms' -> 0 ->> 'last_message_at')::timestamptz,
  (select last_message_at from get_my_rooms(null, 50) where id = :'mine'), 'Waktu pesan terakhir sama dengan get_my_rooms');
select is((:'res'::jsonb -> 'rooms' -> 0 ->> 'last_message_sender_id')::uuid, :'alice'::uuid, 'Pengirim terakhir ikut dikirim');
select is((:'res'::jsonb -> 'rooms' -> 0 ->> 'unread_count')::integer, 2, 'Pesan sendiri tidak dihitung belum dibaca');
select is((:'res'::jsonb -> 'rooms' -> 0 ->> 'unread_count')::integer,
  (select unread_count from get_my_rooms(null, 50) where id = :'mine'), 'Jumlah belum dibaca sama dengan get_my_rooms');
select is(:'res'::jsonb -> 'rooms' -> 0 ->> 'cursor',
  (select cursor from get_my_rooms(null, 50) where id = :'mine'), 'Cursor sama dengan get_my_rooms');
select is(get_room_previews('{}'::uuid[]) -> 'rooms', '[]'::jsonb, 'Tanpa id hasilnya kosong');
select throws_ok(format($$select get_room_previews(%L::uuid[])$$,
                        (select array_agg(gen_random_uuid())::text from generate_series(1, 51))),
  'PT400', 'too_many_rooms', 'Maksimal 50 room sekaligus');
reset role;

select tests.authenticate_anon();
select throws_ok(format($$select get_room_previews(array[%L]::uuid[])$$, :'mine'), '42501', null,
  'Anon tidak bisa memanggil get_room_previews');
reset role;

select is((select provolatile::text from pg_proc where oid = 'public.get_room_previews(uuid[])'::regprocedure), 's',
  'get_room_previews read-only (stable)');

select * from finish();
rollback;
