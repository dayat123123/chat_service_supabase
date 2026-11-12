begin;
select plan(59);

update private.rate_limits set max_count = 1000 where action in ('message', 'room_create', 'content_edit', 'stock_room_create');
update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';
update cs.agent_status set status = 'offline';
select cs.set_setting('service.hours',
  '{"1": ["00:00", "24:00"], "2": ["00:00", "24:00"], "3": ["00:00", "24:00"], "4": ["00:00", "24:00"], "5": ["00:00", "24:00"], "6": ["00:00", "24:00"], "7": ["00:00", "24:00"]}',
  null) as v \gset
delete from cs.holidays;

create function pg_temp.rewind(p_room uuid, p_minutes integer) returns void language sql security definer as $$
  update public.messages set created_at = created_at - make_interval(mins => p_minutes) where room_id = p_room;
  update public.chat_rooms set last_message_at = last_message_at - make_interval(mins => p_minutes) where id = p_room;
  update public.chat_members set last_read_at = last_read_at - make_interval(mins => p_minutes),
                                 last_delivered_at = last_delivered_at - make_interval(mins => p_minutes)
  where room_id = p_room;
$$;
create function pg_temp.rewind_hide(p_room uuid, p_user uuid) returns void language sql security definer as $$
  update public.chat_members set hidden_at = now() - interval '5 minutes', cleared_at = now() - interval '5 minutes'
  where room_id = p_room and user_id = p_user;
$$;
create function pg_temp.listed(p_room uuid) returns boolean language sql as $$
  select exists (select 1 from public.get_my_rooms(null, 100) r where r.id = p_room)
$$;

select tests.create_user('hd_ani') as ani \gset
select tests.create_user('hd_budi') as budi \gset
select tests.create_user('hd_owner') as owner \gset
select tests.create_user('hd_admin') as admin \gset
select tests.create_user('hd_luar') as luar \gset
select tests.create_user('hd_nasabah') as nasabah \gset

select tests.authenticate_as(:'budi');
select get_or_create_direct_room(:'ani') as dm \gset
select id as old_msg from send_message(:'dm', 'Pesan lama') \gset
reset role;
update private.dm_requests set status = 'accepted', responded_at = now() where room_id = :'dm';
select pg_temp.rewind(:'dm', 10);

select tests.authenticate_as(:'ani');
select ok(pg_temp.listed(:'dm'), 'DM tampil sebelum dihapus');
select lives_ok(format('select hide_room(%L)', :'dm'), 'Anggota bisa menghapus chat DM untuk dirinya');
reset role;
select ok((select hidden_at is not null and cleared_at is not null from public.chat_members
           where room_id = :'dm' and user_id = :'ani'), 'hidden_at dan cleared_at tercatat');
select is((select count(*)::integer from realtime.messages
           where topic = 'user:' || :'ani' and event = 'room_removed' and payload ->> 'room_id' = :'dm'), 1,
  'Event room_removed dikirim ke perangkat lain milik pengguna');
select pg_temp.rewind_hide(:'dm', :'ani');

select tests.authenticate_as(:'ani');
select ok(not pg_temp.listed(:'dm'), 'DM yang dihapus hilang dari get_my_rooms');
select is((select count(*)::integer from get_my_room(:'dm')), 0, 'get_my_room tidak mengembalikan DM yang dihapus');
select is((select count(*)::integer from get_messages(:'dm')), 0, 'Riwayat sebelum cleared_at tidak dikirim');
select is((select count(*)::integer from get_messages_by_ids(:'dm', array[:'old_msg']::uuid[])), 0,
  'Pesan lama tidak bisa diambil lewat id');
select is((select unread_count from get_unread_counts() where room_id = :'dm'), 0, 'Pesan lama tidak dihitung belum dibaca');

select tests.authenticate_as(:'budi');
select ok(pg_temp.listed(:'dm'), 'Anggota lain tetap melihat DM');
select is((select count(*)::integer from get_messages(:'dm')), 1, 'Anggota lain tetap melihat riwayat');
select id as new_msg from send_message(:'dm', 'Pesan baru', null, :'old_msg') \gset

select tests.authenticate_as(:'ani');
select ok(pg_temp.listed(:'dm'), 'DM muncul lagi setelah ada pesan baru');
select is((select last_message_preview from get_my_room(:'dm')), 'Pesan baru', 'Preview memakai pesan baru');
select is((select array_agg(body) from get_messages(:'dm')), array['Pesan baru'], 'Hanya pesan setelah cleared_at yang tampil');
select is((select reply_to_body from get_messages(:'dm')), null, 'Kutipan balasan ke pesan lama tidak dikirim');
select is((select unread_count from get_unread_counts() where room_id = :'dm'), 1, 'Belum dibaca hanya menghitung pesan baru');
select is(get_unread_chat_count(), 1, 'Jumlah chat belum dibaca memakai cleared_at');

select lives_ok(format('select hide_room(%L)', :'dm'), 'Hapus chat lagi');
reset role;
select pg_temp.rewind(:'dm', 10);
select pg_temp.rewind_hide(:'dm', :'ani');
select tests.authenticate_as(:'ani');
select ok(not pg_temp.listed(:'dm'), 'DM tersembunyi lagi');
select is(get_or_create_direct_room(:'budi'), :'dm'::uuid, 'Membuka DM dari profil memakai room yang sama');
select ok(pg_temp.listed(:'dm'), 'Membuka DM lagi memunculkan room');
select is((select count(*)::integer from get_messages(:'dm')), 0, 'Riwayat tetap kosong setelah dibuka lagi');

select join_stock_room('BBCA') as stock \gset
select lives_ok(format('select hide_room(%L)', :'stock'), 'Room saham bisa disembunyikan');
select ok(exists (select 1 from public.chat_members where room_id = :'stock' and user_id = :'ani'),
  'Menyembunyikan room saham tidak keluar dari room');
select ok(not pg_temp.listed(:'stock'), 'Room saham tersembunyi dari daftar');
select is(join_stock_room('BBCA'), :'stock'::uuid, 'Bergabung lagi ke room saham');
select ok(pg_temp.listed(:'stock'), 'Room saham muncul lagi setelah dibuka');

select tests.authenticate_as(:'luar');
select throws_ok(format('select hide_room(%L)', :'dm'), 'PT404', 'not_member', 'Bukan anggota tidak bisa menghapus chat');

select tests.authenticate_as(:'nasabah');
select cs_api.open_ticket('account') as j \gset
select (:'j'::jsonb ->> 'room_id') as support \gset
select id as cs_msg from cs_api.send_message(:'support', 'Saya butuh bantuan') \gset
select throws_ok(format('select hide_room(%L)', :'support'), 'PT400', 'cannot_hide_support', 'Chat CS tidak bisa dihapus');
select throws_ok(format('select leave_room(%L)', :'support'), 'PT400', 'cannot_leave_support', 'Chat CS tidak bisa ditinggalkan');
select throws_ok(format('select delete_group(%L)', :'support'), 'PT400', 'not_group', 'Chat CS bukan grup');
select throws_ok(format($$select * from edit_message(%L, 'ubah')$$, :'cs_msg'), 'PT409', 'support_message_locked',
  'Pesan CS tidak bisa diedit lewat RPC');
select throws_ok(format($$update public.messages set body = 'ubah' where id = %L$$, :'cs_msg'), 'PT409',
  'support_message_locked', 'Pesan CS tidak bisa diedit langsung');
select throws_ok(format('select delete_message(%L)', :'cs_msg'), 'PT409', 'support_message_locked',
  'Pesan CS tetap tidak bisa dihapus');
select throws_ok(format($$update public.chat_members set hidden_at = now() where room_id = %L$$, :'support'), '42501',
  null, 'Kolom hidden_at tidak bisa diubah langsung');

select tests.authenticate_as(:'ani');
select id as mine from send_message(:'dm', 'Halo semua') \gset
select is((select body from edit_message(:'mine', '  Halo diedit  ')), 'Halo diedit', 'Pengirim bisa mengedit pesan teks');
select ok((select edited_at is not null from get_messages(:'dm') where id = :'mine'), 'Pesan yang diedit punya edited_at');
select is((select last_message_preview from get_my_room(:'dm')), 'Halo diedit', 'Preview daftar chat ikut diperbarui');
reset role;
select is((select body from private.content_edits where target_type = 'message' and target_id = :'mine'), 'Halo semua',
  'Isi asli disimpan untuk moderasi');
select is((select count(*)::integer from realtime.messages
           where topic = 'room:' || :'dm' and event = 'message_edited' and payload ->> 'message_id' = :'mine'), 1,
  'Event message_edited dikirim saat pesan terakhir diedit');
select is((select count(*)::integer from realtime.messages
           where topic = 'room:' || :'dm' and event = 'message' and payload ->> 'id' = :'mine'
             and payload ->> 'body' = 'Halo diedit'), 1, 'Event pesan berisi isi baru');

select tests.authenticate_as(:'budi');
select throws_ok(format($$select * from edit_message(%L, 'bukan milikku')$$, :'mine'), 'PT403', 'forbidden',
  'Bukan pengirim tidak bisa mengedit');

select tests.authenticate_as(:'ani');
select throws_ok(format($$select * from edit_message(%L, '   ')$$, :'mine'), 'PT400', 'empty_body', 'Isi kosong ditolak');
select throws_ok(format($$select * from edit_message(%L, %L)$$, :'mine', repeat('a', 4001)), 'PT400', 'body_too_long',
  'Isi terlalu panjang ditolak');
reset role;
insert into public.banned_words (word, action) values ('jaminan profit', 'block') on conflict do nothing;
select tests.authenticate_as(:'ani');
select throws_ok(format($$select * from edit_message(%L, 'ada jaminan profit')$$, :'mine'), 'PT422', 'content_blocked',
  'Kata terlarang ditolak saat edit');

select id as gone from send_message(:'dm', 'Akan dihapus') \gset
select delete_message(:'gone');
select throws_ok(format($$select * from edit_message(%L, 'hidup lagi')$$, :'gone'), 'PT400', 'not_editable',
  'Pesan terhapus tidak bisa diedit');

select id as pic from send_message(:'dm', 'Lihat gambar') \gset
reset role;
update public.messages set attachments = '[{"type": "image", "path": "x.png"}]' where id = :'pic';
select tests.authenticate_as(:'ani');
select throws_ok(format($$select * from edit_message(%L, 'ganti caption')$$, :'pic'), 'PT400', 'not_editable',
  'Pesan berlampiran tidak bisa diedit');

reset role;
update public.messages set created_at = now() - interval '20 minutes' where id = :'mine';
select tests.authenticate_as(:'ani');
select throws_ok(format($$select * from edit_message(%L, 'terlambat')$$, :'mine'), 'PT409', 'edit_window_closed',
  'Edit ditolak setelah batas waktu');
select throws_ok(format($$update public.messages set body = 'terlambat' where id = %L$$, :'mine'), 'PT409',
  'edit_window_closed', 'Batas waktu juga berlaku untuk update langsung');

select tests.authenticate_as(:'owner');
select create_group_room('Investor', array[:'admin', :'ani']::uuid[]) as grp \gset
select set_room_member_role(:'grp', :'admin', 'admin');
select tests.authenticate_as(:'ani');
select id as grp_msg from send_message(:'grp', 'Halo grup') \gset
select throws_ok(format('select delete_group(%L)', :'grp'), 'PT403', 'forbidden', 'Anggota tidak bisa menghapus grup');
select tests.authenticate_as(:'admin');
select throws_ok(format('select delete_group(%L)', :'grp'), 'PT403', 'forbidden', 'Admin tidak bisa menghapus grup');
select tests.authenticate_as(:'luar');
select throws_ok(format('select delete_group(%L)', :'grp'), 'PT403', 'forbidden', 'Bukan anggota tidak bisa menghapus grup');
select tests.authenticate_as(:'owner');
select throws_ok(format('select delete_group(%L)', :'dm'), 'PT400', 'not_group', 'DM bukan grup');
select lives_ok(format('select delete_group(%L)', :'grp'), 'Owner bisa menghapus grup');
reset role;
select ok(not exists (select 1 from public.chat_rooms where id = :'grp'), 'Room grup terhapus');
select is((select body from private.content_archive where target_type = 'message' and target_id = :'grp_msg'), 'Halo grup',
  'Pesan grup diarsipkan untuk moderasi');
select is((select count(*)::integer from private.admin_audit_log
           where action = 'chat.group_delete' and target_id = :'grp' and actor_id = :'owner'), 1, 'Hapus grup tercatat di audit');
select is((select count(*)::integer from realtime.messages
           where event = 'room_removed' and payload ->> 'room_id' = :'grp' and payload ->> 'reason' = 'group_deleted'), 3,
  'Semua anggota menerima event room_removed');
select is((select count(*)::integer from realtime.messages
           where topic = 'room:' || :'grp' and event = 'room_deleted'), 1, 'Room yang terbuka menerima event room_deleted');

select * from finish();
rollback;
