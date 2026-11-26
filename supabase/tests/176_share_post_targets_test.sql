begin;
select plan(31);

update private.rate_limits set max_count = 1000 where action in ('post', 'message', 'room_create', 'follow');
update private.settings set value = '0' where key = 'safety.new_account_days';

select tests.create_user('sp_ani') as ani \gset
select tests.create_user('sp_budi') as budi \gset
select tests.create_user('sp_cici') as cici \gset
select tests.create_user('sp_dodi') as dodi \gset
select tests.create_user('sp_eka') as eka \gset
select tests.create_user('sp_resmi') as resmi \gset
select tests.create_user('sp_tutup') as tutup \gset
insert into cs.official_accounts (profile_id) values (:'resmi');
insert into public.blocks (blocker_id, blocked_id) values (:'eka', :'ani');
insert into private.market_instruments (code, name, room_enabled) values ('SPTUTUP', 'Indeks Uji Tutup', false);

insert into public.posts (author_id, body) values (:'budi', 'Post untuk dibagikan') returning id as post \gset

select tests.authenticate_as(:'tutup');
select public.set_dm_policy('none');
select tests.authenticate_as(:'cici');
select public.create_group_room('Grup Saham Sp', array[:'ani'::uuid]) as grp \gset
select public.update_group_settings(:'grp', true, null);
select public.create_group_room('Grup Bebas Sp', array[:'ani'::uuid]) as grp_free \gset
reset role;

select tests.authenticate_as(:'ani');
select is(public.get_share_limits() ->> 'max_targets', '10', 'Batas tujuan per kirim terbaca klien');
select is((select count(*)::integer from public.search_share_targets('')), 0, 'Kueri kosong tidak mengembalikan apa pun');
select is(array(select s.username from public.search_share_targets('sp_') s where s.kind = 'user' order by s.username),
  array['sp_budi', 'sp_cici', 'sp_dodi', 'sp_tutup'],
  'Pencarian orang tanpa diri sendiri, akun yang memblokir, dan akun resmi');
select is((select row(s.can_send, s.reason)::text from public.search_share_targets('sp_tutup') s where s.kind = 'user'),
  row(false, 'dm_not_allowed')::text, 'Orang yang menolak DM tampil dengan alasan tidak bisa dikirim');
select ok((select s.room_id is null and s.can_send from public.search_share_targets('sp_dodi') s where s.kind = 'user'),
  'Orang tanpa chat bisa dipilih dan room-nya dibuat saat dikirim');
select is(array(select s.group_name || ':' || s.can_send || ':' || coalesce(s.reason, '-')
                from public.search_share_targets('grup') s where s.kind = 'group' order by s.group_name),
  array['Grup Bebas Sp:true:-', 'Grup Saham Sp:false:group_admins_only'],
  'Grup hanya yang diikuti, dengan aturan hanya admin');
select is((select row(s.stock_code, s.room_id, s.can_send)::text from public.search_share_targets('bbca') s
           where s.kind = 'stock'), row('BBCA', null::uuid, true)::text, 'Kode saham empat huruf menjadi tujuan room saham');
select is((select row(s.can_send, s.reason)::text from public.search_share_targets('sptutup') s where s.kind = 'stock'),
  row(false, 'room_disabled')::text, 'Room saham yang ditutup tampil dengan alasannya');
select ok(not exists (select 1 from public.search_share_targets('sp_resmi')), 'Akun resmi tidak tampil untuk pengguna biasa');
reset role;

create temp table shared (target_index integer, kind text, target text, room_id uuid, status text, error_code text,
                          message_id uuid) on commit drop;
grant all on shared to authenticated;
select tests.authenticate_as(:'ani');
select public.get_or_create_direct_room(:'budi') as dm_budi \gset
select gen_random_uuid() as c1, gen_random_uuid() as c2, gen_random_uuid() as c3, gen_random_uuid() as c4,
       gen_random_uuid() as c5, gen_random_uuid() as c6, gen_random_uuid() as c7, gen_random_uuid() as c8 \gset
insert into shared
select * from public.share_post_to_targets(:'post', jsonb_build_array(
  jsonb_build_object('room_id', :'dm_budi', 'client_id', :'c1'),
  jsonb_build_object('user_id', :'dodi', 'client_id', :'c2'),
  jsonb_build_object('stock_code', 'bbca', 'client_id', :'c3'),
  jsonb_build_object('room_id', :'grp_free', 'client_id', :'c4'),
  jsonb_build_object('room_id', :'grp', 'client_id', :'c5'),
  jsonb_build_object('user_id', :'tutup', 'client_id', :'c6'),
  jsonb_build_object('user_id', :'resmi', 'client_id', :'c7'),
  jsonb_build_object('stock_code', 'SPTUTUP', 'client_id', :'c8'),
  jsonb_build_object('user_id', :'eka', 'client_id', gen_random_uuid()),
  jsonb_build_object('room_id', 'bukan-uuid', 'client_id', gen_random_uuid())), 'Coba lihat ini');
select is(array(select s.status || ':' || coalesce(s.error_code, '-') from shared s order by s.target_index),
  array['sent:-', 'sent:-', 'sent:-', 'sent:-', 'failed:group_admins_only', 'failed:dm_not_allowed',
        'failed:official_no_dm', 'failed:room_disabled', 'failed:blocked', 'failed:invalid_target'],
  'Setiap tujuan berhasil atau gagal sendiri tanpa menggagalkan yang lain');
select is((select count(*)::integer from public.messages m where m.sender_id = :'ani'
           and m.attachments @> jsonb_build_array(jsonb_build_object('type', 'post', 'post_id', :'post'))), 4,
  'Empat pesan berisi postingan terkirim');
select ok((select bool_and(s.message_id is not null and s.room_id is not null) from shared s where s.status = 'sent'),
  'Tujuan yang berhasil membawa room dan id pesan');
select ok((select s.room_id = :'dm_budi'::uuid and s.kind = 'room' from shared s where s.target_index = 0),
  'Tujuan room memakai chat yang sudah ada');
select ok(exists (select 1 from public.chat_members m join shared s on s.room_id = m.room_id
                  where s.target_index = 1 and m.user_id = :'dodi'), 'DM baru dibuat untuk orang yang belum pernah dichat');
select ok(exists (select 1 from public.chat_rooms r join shared s on s.room_id = r.id
                  where s.target_index = 2 and r.type = 'stock' and r.stock_code = 'BBCA'),
  'Kode saham huruf kecil bergabung ke room saham yang benar');
select ok(not exists (select 1 from public.chat_rooms r where r.direct_key =
                      least(:'ani', :'tutup') || ':' || greatest(:'ani', :'tutup')),
  'Tujuan yang gagal tidak meninggalkan chat kosong');
select is((select m.body from public.messages m join shared s on s.message_id = m.id where s.target_index = 0),
  'Coba lihat ini', 'Catatan ikut terkirim');
select throws_ok(format($$select * from public.send_message(%L, 'Coba lihat ini')$$, :'grp_free'),
  'PT422', 'duplicate_content', 'Pesan biasa dengan teks kembar tetap kena aturan konten berulang');

select is(array(select s.status || ':' || s.message_id::text from public.share_post_to_targets(:'post', jsonb_build_array(
  jsonb_build_object('room_id', :'dm_budi', 'client_id', :'c1'),
  jsonb_build_object('user_id', :'dodi', 'client_id', :'c2'))) s order by s.target_index),
  array(select 'sent:' || s.message_id::text from shared s where s.target_index in (0, 1) order by s.target_index),
  'Kirim ulang dengan client_id yang sama mengembalikan pesan lama tanpa dobel');
select is((select count(*)::integer from public.messages m where m.sender_id = :'ani'), 4, 'Tidak ada pesan dobel');
select is(array(select s.error_code from public.share_post_to_targets(:'post', jsonb_build_array(
  jsonb_build_object('room_id', :'dm_budi', 'client_id', gen_random_uuid()),
  jsonb_build_object('user_id', :'budi', 'client_id', gen_random_uuid()),
  jsonb_build_object('room_id', :'dm_budi', 'client_id', :'c4'))) s order by s.target_index),
  array[null, 'duplicate_target', null]::text[],
  'Chat yang sama dua kali dalam satu kiriman hanya dikirim sekali');
select is((select array_agg(s.error_code order by s.target_index) from public.share_post_to_targets(:'post', jsonb_build_array(
  jsonb_build_object('user_id', :'budi'),
  jsonb_build_object('user_id', :'budi', 'stock_code', 'BBCA', 'client_id', gen_random_uuid()),
  '"teks"'::jsonb)) s), array['invalid_target', 'invalid_target', 'invalid_target'],
  'Tujuan tanpa client_id, dengan dua jenis, atau bukan objek ditolak');
select throws_ok(format($$select * from public.share_post_to_targets(%L, %L)$$, :'post',
  (select jsonb_agg(jsonb_build_object('user_id', :'budi', 'client_id', gen_random_uuid())) from generate_series(1, 11))),
  'PT400', 'too_many_targets', 'Lebih dari 10 tujuan ditolak');
select throws_ok(format($$select * from public.share_post_to_targets(%L, '[]')$$, :'post'),
  'PT400', 'invalid_targets', 'Daftar tujuan kosong ditolak');
select is((select s.error_code from public.share_post_to_targets(gen_random_uuid(), jsonb_build_array(
  jsonb_build_object('room_id', :'dm_budi', 'client_id', gen_random_uuid()))) s), 'post_not_found',
  'Postingan yang tidak ada ditolak per tujuan');
reset role;

select tests.authenticate_as(:'dodi');
select is((select s.error_code from public.share_post_to_targets(:'post', jsonb_build_array(
  jsonb_build_object('room_id', :'grp', 'client_id', gen_random_uuid()))) s), 'not_member',
  'Grup yang tidak diikuti tidak bisa dipakai');
reset role;

update private.rate_limits set max_count = 6 where action = 'post_share';
select tests.authenticate_as(:'ani');
select is(public.get_share_limits() ->> 'per_hour', '6', 'Batas per jam ikut pengaturan rate limit');
select is(array(select s.status || ':' || coalesce(s.error_code, '-') from public.share_post_to_targets(:'post', jsonb_build_array(
  jsonb_build_object('room_id', :'grp_free', 'client_id', gen_random_uuid()),
  jsonb_build_object('room_id', :'dm_budi', 'client_id', gen_random_uuid()))) s order by s.target_index),
  array['sent:-', 'failed:rate_limited'], 'Batas per pengguna lintas kiriman berlaku per tujuan');
select is((select count(*)::integer from public.share_post_to_chat(:'dm_budi', :'post', 'cara lama', gen_random_uuid())), 1,
  'share_post_to_chat lama tetap jalan');
reset role;

select tests.authenticate_as(:'resmi');
select ok(exists (select 1 from public.search_share_targets('sp_ani') s where s.kind = 'user'),
  'Akun resmi tetap bisa mencari pengguna');
reset role;

select ok(not has_function_privilege('anon', 'public.share_post_to_targets(uuid, jsonb, text)', 'execute')
          and not has_function_privilege('anon', 'public.search_share_targets(text, integer)', 'execute'),
  'RPC berbagi hanya untuk pengguna login');

select * from finish();
rollback;
