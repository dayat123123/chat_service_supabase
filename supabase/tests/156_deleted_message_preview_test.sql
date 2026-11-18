begin;
select plan(7);

update private.rate_limits set max_count = 1000 where action in ('message', 'room_create', 'follow');

select tests.create_user('dmp_ani') as ani \gset
select tests.create_user('dmp_budi') as budi \gset
insert into public.follows (follower_id, following_id) values (:'ani', :'budi'), (:'budi', :'ani');

select tests.authenticate_as(:'ani');
select get_or_create_direct_room(:'budi') as dm \gset
select id as first from send_message(:'dm', 'halo budi') \gset
select id as last from send_message(:'dm', 'pesan rahasia') \gset
reset role;
update public.messages set created_at = created_at - interval '1 minute' where id = :'first';

create function pg_temp.preview(p_room uuid) returns text language sql security definer as $$
  select last_message_preview from public.chat_rooms where id = p_room
$$;

select is(pg_temp.preview(:'dm'), 'pesan rahasia', 'Pratinjau memuat pesan terakhir');

select tests.authenticate_as(:'ani');
select delete_message(:'first');
reset role;
select is(pg_temp.preview(:'dm'), 'pesan rahasia', 'Menghapus pesan yang bukan terakhir tidak mengubah pratinjau');

select tests.authenticate_as(:'ani');
select delete_message(:'last');
reset role;
select is(pg_temp.preview(:'dm'), '[pesan dihapus]', 'Menghapus pesan terakhir mengganti pratinjau di daftar chat');
select is((select count(*)::int from realtime.messages
           where event = 'room_activity' and payload ->> 'message_id' = :'last'
             and payload ->> 'preview' = '[pesan dihapus]'
             and topic in ('user:' || :'ani', 'user:' || :'budi')), 2,
  'Kedua anggota mendapat room_activity supaya daftar chat yang terbuka diperbarui');
select ok(not exists (select 1 from public.chat_rooms where id = :'dm' and last_message_preview like '%rahasia%'),
  'Isi pesan yang dihapus tidak tersisa di pratinjau');

select tests.authenticate_as(:'ani');
select id as next from send_message(:'dm', 'pesan baru') \gset
reset role;
select is(pg_temp.preview(:'dm'), 'pesan baru', 'Pesan baru kembali menjadi pratinjau');

update public.chat_rooms set last_message_preview = 'pesan baru' where id = :'dm';
update public.messages set deleted_at = now(), body = '' where id = :'next';
select is(pg_temp.preview(:'dm'), '[pesan dihapus]', 'Penghapusan lewat jalur lain (moderasi, hapus akun) ikut mengganti pratinjau');

select * from finish();
rollback;
