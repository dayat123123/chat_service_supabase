begin;
select plan(24);

update private.rate_limits set max_count = 1000 where action in ('message', 'room_create', 'follow', 'report');
create function pg_temp.requests_to(p_user uuid) returns integer language sql security definer
  as $$ select count(*)::integer from private.dm_requests q where q.recipient_id = p_user $$;
select tests.create_user('od_ani') as ani \gset
select tests.create_user('od_budi') as budi \gset
select tests.create_user('od_verif') as verif \gset
select tests.create_user('od_resmi') as resmi \gset
select tests.create_user('od_riset') as riset \gset
select tests.create_user('od_lama') as lama \gset
select tests.create_agent('Sari', '{cs_agent}', '{"general": 1}') as sari \gset
insert into cs.official_accounts (profile_id) values (:'resmi'), (:'riset'), (:'lama');
update cs.official_accounts set disabled_at = now() where profile_id = :'lama';
update public.profiles set is_verified = true where id = :'verif';

select tests.authenticate_as(:'resmi');
select get_or_create_direct_room(:'ani') as dm_old \gset
select lives_ok(format($$select send_message(%L, 'Pengumuman dari akun resmi')$$, :'dm_old'),
  'Akun resmi boleh memulai DM dan mengirim pesan');
reset role;
insert into public.messages (room_id, sender_id, body, client_id)
values (:'dm_old', :'ani', 'Pesan lama sebelum aturan', 'e1440000-0000-4000-8000-000000000001');
insert into public.posts (id, author_id, body) values ('e1440000-0000-4000-8000-0000000000a1', :'budi', 'Analisis $BBCA');

select tests.authenticate_as(:'ani');
select throws_ok(format('select get_or_create_direct_room(%L)', :'riset'), 'PT403', 'official_no_dm',
  'User biasa tidak bisa membuat DM baru ke akun resmi');
select is(pg_temp.requests_to(:'riset'), 0,
  'Tidak ada permintaan pesan ke akun resmi');
select is(get_or_create_direct_room(:'resmi'), :'dm_old'::uuid,
  'DM lama dengan akun resmi tetap bisa dibuka');
select throws_ok(format($$select send_message(%L, 'Halo admin')$$, :'dm_old'), 'PT403', 'official_no_dm',
  'User biasa tidak bisa mengirim pesan ke DM lama dengan akun resmi');
select throws_ok(
  format($$select share_post_to_chat(%L, %L)$$, :'dm_old', 'e1440000-0000-4000-8000-0000000000a1'),
  'PT403', 'official_no_dm', 'Bagikan postingan ke DM akun resmi juga tidak bisa');
select lives_ok(
  format($$select send_message(%L, 'Pesan lama sebelum aturan', 'e1440000-0000-4000-8000-000000000001')$$, :'dm_old'),
  'Kirim ulang pesan lama dengan client_id yang sama tetap idempoten');
select ok((select count(*) from public.get_messages(:'dm_old')) >= 2, 'Riwayat DM lama tetap bisa dibaca');

select ok(get_or_create_direct_room(:'verif') is not null, 'Akun terverifikasi tetap bisa di-DM');
select get_or_create_direct_room(:'verif') as dm_verif \gset
select lives_ok(format($$select send_message(%L, 'Halo kontributor')$$, :'dm_verif'),
  'Pesan ke akun terverifikasi terkirim');
select ok(get_or_create_direct_room(:'lama') is not null, 'Akun resmi yang dinonaktifkan kembali bisa di-DM');

select throws_ok(format($$select create_group_room('Diskusi', array[%L, %L]::uuid[])$$, :'budi', :'riset'),
  'PT403', 'official_no_dm', 'User biasa tidak bisa memasukkan akun resmi ke grup baru');
select create_group_room('Diskusi', array[:'budi', :'verif']::uuid[]) as grp \gset
select ok(:'grp' is not null, 'Grup tanpa akun resmi tetap bisa dibuat');
select throws_ok(format($$select add_room_members(%L, array[%L]::uuid[])$$, :'grp', :'resmi'),
  'PT403', 'official_no_dm', 'User biasa tidak bisa menambahkan akun resmi ke grup');
select is(add_room_members(:'grp', array[:'ani']::uuid[]), 0, 'Menambah anggota biasa tetap jalan');

select is((select is_official from public.get_profile(:'resmi')), true, 'get_profile menandai akun resmi');
select is((select is_official from public.get_profile(:'verif')), false, 'Akun terverifikasi bukan akun resmi');
select is((select is_official from public.get_profile(null, 'od_riset')), true, 'get_profile lewat username juga');
select is((select is_official from public.search_profiles('od_resmi') where id = :'resmi'), true,
  'search_profiles menandai akun resmi');
select is((select is_official from public.search_profiles('od_verif') where id = :'verif'), false,
  'search_profiles tidak menandai akun terverifikasi');

select tests.authenticate_as(:'resmi');
select lives_ok(format($$select send_message(%L, 'Balasan terakhir dari akun resmi')$$, :'dm_old'),
  'Akun resmi masih boleh mengirim ke DM lama');
select ok(create_group_room('Riset', array[:'ani', :'riset']::uuid[]) is not null,
  'Akun resmi boleh membuat grup bersama akun resmi lain');

select tests.authenticate_agent(:'sari');
select ok(private.official_dm_exempt(:'sari'), 'Staf dikecualikan dari aturan akun resmi');

select tests.authenticate_as(:'ani');
select is(private.official_dm_exempt(:'ani'), false, 'User biasa tidak dikecualikan');

select * from finish();
rollback;
