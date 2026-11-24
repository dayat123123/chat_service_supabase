begin;
select plan(14);

update private.rate_limits set max_count = 1000 where action in ('message', 'room_create', 'stock_room_create', 'post');
update private.settings set value = '0' where key = 'safety.new_account_days';

select tests.create_user('nc_ani') as ani \gset
select tests.create_user('nc_budi') as budi \gset
select tests.create_user('nc_cici') as cici \gset

select tests.authenticate_as(:'ani');
select public.register_push_device('android-token-nc-ani-0000001', 'android', 'id-ID', '2.4.0') is not null as device \gset
select tests.authenticate_as(:'budi');
select get_or_create_direct_room(:'ani') as dm \gset
select create_group_room('Grup Notif', array[:'ani', :'cici']::uuid[]) as grp \gset
reset role;
update private.dm_requests set status = 'accepted', responded_at = now() where room_id = :'dm';

insert into public.posts (author_id, body) values (:'ani', 'Post Ani') returning id as post \gset
insert into public.reactions (user_id, target_type, target_id) values (:'budi', 'post', :'post');
insert into public.posts (author_id, body) values (:'budi', 'Halo @nc_ani di post');
insert into public.notifications (user_id, type, payload, group_key)
values (:'ani', 'message', jsonb_build_object('room_id', gen_random_uuid(), 'room_type', 'support', 'room_name', 'CS',
                                              'snippet', 'Tiket Anda dibalas'), 'nc:support');
update public.notifications set created_at = now() - interval '1 hour' where user_id = :'ani';
update public.notifications set created_at = now() - interval '2 hours' where user_id = :'ani' and type = 'like';

select tests.authenticate_as(:'budi');
select id as dm_msg from send_message(:'dm', 'Halo Ani lewat DM') \gset
select id as grp_msg from send_message(:'grp', 'Cek ini @nc_ani') \gset
select tests.authenticate_as(:'cici');
select join_stock_room('BBCA') as stock \gset
select id as stock_msg from send_message(:'stock', 'Pendapat @nc_ani soal BBCA?') \gset
reset role;

select is((select count(*)::integer from public.notifications where user_id = :'ani' and type = 'message'), 2,
  'Notifikasi pesan chat tetap dibuat');
select is((select count(*)::integer from public.notifications
           where user_id = :'ani' and type = 'mention' and payload ->> 'room_id' = :'grp'), 1,
  'Mention di grup tetap dibuat');
select ok((select count(*)::integer from private.push_queue where user_id = :'ani' and kind in ('message', 'mention')) >= 2,
  'Push chat tetap masuk antrean');

select tests.authenticate_as(:'ani');
select is((select count(*)::integer from get_notifications(null, 100) where type = 'message'), 0,
  'Daftar notifikasi tidak memuat pesan chat, termasuk balasan CS');
select is((select count(*)::integer from get_notifications(null, 100) where payload ->> 'room_id' = :'grp'), 0,
  'Mention di room yang saya ikuti tidak muncul di daftar notifikasi');
select is((select count(*)::integer from get_notifications(null, 100)
           where type = 'mention' and payload ->> 'room_id' = :'stock'), 1,
  'Mention di room saham yang tidak saya ikuti tetap muncul');
select is((select count(*)::integer from get_notifications(null, 100) where type = 'mention' and payload ? 'post_id'), 1,
  'Mention di post tetap muncul');
select is(get_notification_unread_count(), 3, 'Jumlah belum dibaca hanya menghitung notifikasi yang tampil');

select is(array(select type from get_notifications(null, 2)), array['mention', 'mention'],
  'Halaman pertama terisi penuh walau pesan chat lebih baru');
select cursor as next_page from get_notifications(null, 2) offset 1 limit 1 \gset
select is(array(select type from get_notifications(:'next_page', 2)), array['like'],
  'Halaman berikutnya melanjutkan tanpa pesan chat');

select join_stock_room('BBCA') as joined \gset
select is((select count(*)::integer from get_notifications(null, 100) where payload ->> 'room_id' = :'stock'), 0,
  'Mention room saham pindah ke daftar chat setelah bergabung');
select is(get_notification_unread_count(), 2, 'Jumlah belum dibaca ikut menyesuaikan');

select mark_room_read(:'grp') as read_grp \gset
select mark_room_read(:'dm') as read_dm \gset
reset role;
select is((select count(*)::integer from public.notifications
           where user_id = :'ani' and read_at is null and payload ->> 'room_id' = :'grp'), 0,
  'Membaca grup menandai mention grup terbaca');
select is((select count(*)::integer from public.notifications
           where user_id = :'ani' and read_at is null and payload ->> 'room_id' = :'dm'), 0,
  'Membaca DM menandai pesan DM terbaca');

select * from finish();
rollback;
