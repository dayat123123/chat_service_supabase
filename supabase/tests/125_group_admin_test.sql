begin;
select plan(50);

update private.rate_limits set max_count = 1000 where action in ('message', 'room_create');
create function pg_temp.event_count(p_room uuid) returns integer language sql security definer
  as $$ select count(*)::integer from public.messages m where m.room_id = p_room and m.kind = 'group_event' $$;
create function pg_temp.latest(p_room uuid) returns jsonb language sql security definer
  as $$ select m.payload || jsonb_build_object('body', m.body, 'sender_id', m.sender_id)
        from public.messages m where m.room_id = p_room and m.kind = 'group_event'
        order by m.created_at desc, m.id desc limit 1 $$;
create function pg_temp.role_of(p_room uuid, p_user uuid) returns text language sql security definer
  as $$ select role from public.chat_members where room_id = p_room and user_id = p_user $$;
create function pg_temp.message_notifications(p_room uuid) returns integer language sql security definer
  as $$ select count(*)::integer from public.notifications n
        where n.type = 'message' and n.payload ->> 'room_id' = p_room::text $$;

select tests.create_user('ga_owner') as owner \gset
select tests.create_user('ga_admin') as admin \gset
select tests.create_user('ga_ani') as ani \gset
select tests.create_user('ga_budi') as budi \gset
select tests.create_user('ga_cici') as cici \gset
select tests.create_user('ga_luar') as luar \gset
update public.profiles set display_name = 'Owen' where id = :'owner';
update public.profiles set display_name = 'Ada' where id = :'admin';
update public.profiles set display_name = 'Ani' where id = :'ani';
update public.profiles set display_name = 'Budi' where id = :'budi';
update public.profiles set display_name = 'Cici' where id = :'cici';

select tests.authenticate_as(:'owner');
select create_group_room('Investor', array[:'admin', :'ani', :'budi']::uuid[]) as grp \gset

select lives_ok(format($$select set_room_member_role(%L, %L, 'admin')$$, :'grp', :'admin'),
  'Owner menjadikan anggota admin');
select is(pg_temp.role_of(:'grp', :'admin'), 'admin', 'Peran berubah menjadi admin');
select is(pg_temp.latest(:'grp') ->> 'event', 'promoted', 'Pesan sistem promoted tercatat');
select is(pg_temp.latest(:'grp') ->> 'body', 'Owen menjadikan Ada admin', 'Isi pesan sistem promoted');
select is(pg_temp.latest(:'grp') ->> 'actor_id', :'owner', 'Pesan sistem mencatat pelaku');
select is(pg_temp.latest(:'grp') ->> 'target_id', :'admin', 'Pesan sistem mencatat sasaran');
select ok((pg_temp.latest(:'grp') -> 'sender_id') = 'null'::jsonb, 'Pesan sistem tidak punya pengirim');
select is(pg_temp.message_notifications(:'grp'), 0, 'Pesan sistem grup tidak memicu notifikasi pesan');
select is((select count(*)::integer from public.get_messages(:'grp') where kind = 'group_event'), 1,
  'get_messages mengembalikan pesan sistem grup');
select lives_ok(format($$select set_room_member_role(%L, %L, 'admin')$$, :'grp', :'admin'),
  'Menjadikan admin yang sudah admin tidak error');
select is(pg_temp.event_count(:'grp'), 1, 'Tanpa perubahan tidak ada pesan sistem baru');

select tests.authenticate_as(:'admin');
select throws_ok(format('select remove_room_member(%L, %L)', :'grp', :'owner'), 'PT403', 'forbidden',
  'Admin tidak bisa mengeluarkan owner');
select throws_ok(format($$select set_room_member_role(%L, %L, 'member')$$, :'grp', :'admin'), 'PT403', 'forbidden',
  'Admin tidak bisa mencabut status admin');
select lives_ok(format($$select set_room_member_role(%L, %L, 'admin')$$, :'grp', :'budi'),
  'Admin bisa menjadikan anggota lain admin');
select throws_ok(format('select remove_room_member(%L, %L)', :'grp', :'budi'), 'PT403', 'forbidden',
  'Admin tidak bisa mengeluarkan admin lain');
select lives_ok(format('select remove_room_member(%L, %L)', :'grp', :'ani'), 'Admin mengeluarkan anggota biasa');
select is(pg_temp.role_of(:'grp', :'ani'), null, 'Anggota yang dikeluarkan tidak lagi jadi anggota');
select is(pg_temp.latest(:'grp') ->> 'body', 'Ada mengeluarkan Ani', 'Isi pesan sistem removed');
select throws_ok(format('select transfer_room_ownership(%L, %L)', :'grp', :'budi'), 'PT403', 'forbidden',
  'Hanya owner yang bisa memindahkan kepemilikan');
select throws_ok(format('select remove_room_member(%L, %L)', :'grp', :'admin'), 'PT400', 'use_leave_room',
  'Mengeluarkan diri sendiri harus lewat keluar grup');

select tests.authenticate_as(:'ani');
select throws_ok(format('select * from get_messages(%L)', :'grp'), 'PT403', 'not_member',
  'Anggota yang dikeluarkan tidak bisa membaca grup');
select throws_ok(format($$select send_message(%L, 'Halo')$$, :'grp'), 'PT403', null,
  'Anggota yang dikeluarkan tidak bisa mengirim pesan');
select throws_ok(format('select remove_room_member(%L, %L)', :'grp', :'budi'), 'PT403', 'not_member',
  'Bukan anggota tidak bisa mengelola grup');

select tests.authenticate_as(:'owner');
select lives_ok(format($$select set_room_member_role(%L, %L, 'member')$$, :'grp', :'budi'),
  'Owner mencabut status admin');
select is(pg_temp.latest(:'grp') ->> 'body', 'Owen mencabut status admin Budi', 'Isi pesan sistem demoted');
select throws_ok(format($$select set_room_member_role(%L, %L, 'owner')$$, :'grp', :'budi'), 'PT400', 'invalid_role',
  'Peran owner tidak bisa diberikan lewat ubah peran');
select is(add_room_members(:'grp', array[:'cici', :'ani']::uuid[]), 2, 'Owner menambah dua anggota');
select is(pg_temp.latest(:'grp') ->> 'event', 'added', 'Pesan sistem added tercatat');
select is((pg_temp.latest(:'grp') ->> 'count')::integer, 2, 'Pesan sistem added mencatat jumlah anggota baru');
select ok(pg_temp.latest(:'grp') ->> 'body' in ('Owen menambahkan Cici, Ani', 'Owen menambahkan Ani, Cici'),
  'Isi pesan sistem added menyebut nama anggota baru');

select lives_ok(format($$select update_group_info(%L, p_name => 'Investor Pro', p_description => 'Diskusi saham')$$, :'grp'),
  'Owner mengubah nama dan deskripsi grup');
select is((select name from get_my_room(:'grp')), 'Investor Pro', 'Nama grup berubah');
select is((select description from get_my_room(:'grp')), 'Diskusi saham', 'Deskripsi grup tampil di ringkasan room');
select is(pg_temp.event_count(:'grp'), 7, 'Ganti nama dan deskripsi menghasilkan dua pesan sistem');
select lives_ok(format($$select update_group_info(%L, p_avatar_url => 'https://cdn.test/avatars/g.png')$$, :'grp'),
  'Owner mengganti foto grup');
select is((select avatar_url from get_my_room(:'grp')), 'https://cdn.test/avatars/g.png', 'Foto grup tampil di ringkasan room');
select throws_ok(format($$select update_group_info(%L, p_avatar_url => 'javascript:alert(1)')$$, :'grp'), 'PT400',
  'invalid_avatar', 'Alamat foto grup harus http(s)');

select tests.authenticate_as(:'cici');
select throws_ok(format($$select update_group_info(%L, p_name => 'Grup Cici')$$, :'grp'), 'PT403',
  'group_admins_only_edit', 'Anggota biasa tidak bisa mengubah info grup secara bawaan');
select throws_ok(format('select update_group_settings(%L, true)', :'grp'), 'PT403', 'forbidden',
  'Anggota biasa tidak bisa mengubah pengaturan grup');
select throws_ok(format($$update public.chat_rooms set name = 'Lewat tabel' where id = %L$$, :'grp'), '42501', null,
  'Nama grup tidak bisa diubah langsung lewat tabel');

select tests.authenticate_as(:'owner');
select lives_ok(format('select update_group_settings(%L, p_only_admins_send => true, p_only_admins_edit => false)', :'grp'),
  'Owner mengatur hanya admin yang bisa mengirim pesan');
select is((select only_admins_send from get_my_room(:'grp')), true, 'Pengaturan kirim tampil di ringkasan room');

select tests.authenticate_as(:'cici');
select throws_ok(format($$select send_message(%L, 'Boleh tanya?')$$, :'grp'), 'PT403', 'group_admins_only',
  'Anggota biasa tidak bisa mengirim saat hanya admin');
select lives_ok(format($$select update_group_info(%L, p_description => '')$$, :'grp'),
  'Anggota biasa bisa mengubah info grup bila diizinkan');

select tests.authenticate_as(:'admin');
select lives_ok(format($$select send_message(%L, 'Info dari admin')$$, :'grp'), 'Admin tetap bisa mengirim pesan');

select tests.authenticate_as(:'owner');
select lives_ok(format('select transfer_room_ownership(%L, %L)', :'grp', :'cici'), 'Owner memindahkan kepemilikan');
select ok(pg_temp.role_of(:'grp', :'cici') = 'owner' and pg_temp.role_of(:'grp', :'owner') = 'admin',
  'Pemilik baru jadi owner dan pemilik lama jadi admin');

select tests.authenticate_as(:'cici');
select lives_ok(format('select leave_room(%L)', :'grp'), 'Owner keluar grup');
select is(pg_temp.latest(:'grp') ->> 'body',
  'Cici keluar. ' || (pg_temp.latest(:'grp') ->> 'new_owner_name') || ' sekarang pemilik grup',
  'Pesan sistem left menyebut pemilik baru');
select is(pg_temp.role_of(:'grp', (pg_temp.latest(:'grp') ->> 'new_owner_id')::uuid), 'owner',
  'Kepemilikan pindah ke admin yang tersisa');

select * from finish();
rollback;
