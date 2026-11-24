begin;
select plan(22);

update private.settings set value = '0' where key = 'safety.new_account_days';

select tests.create_user('ng_ani') as ani \gset
select tests.create_user('ng_budi') as budi \gset
select tests.create_user('ng_cici') as cici \gset
select tests.create_user('ng_dodi') as dodi \gset
select tests.create_user('ng_eka') as eka \gset

select tests.authenticate_as(:'ani');
select public.register_push_device('android-token-ng-ani-0000001', 'android', 'id-ID', '2.4.0') is not null as device \gset
select tests.authenticate_as(:'budi');
select public.register_push_device('android-token-ng-budi-000001', 'android', 'id-ID', '2.4.0') is not null as device \gset
reset role;

insert into public.posts (author_id, body, attachments)
values (:'ani', 'Post bergambar Ani',
        jsonb_build_array(jsonb_build_object('path', 'posts/' || :'ani' || '/klip.mp4', 'mime', 'video/mp4'),
                          jsonb_build_object('path', 'posts/' || :'ani' || '/foto.jpg', 'mime', 'image/jpeg',
                                             'width', 800, 'height', 600)))
returning id as post \gset
insert into public.posts (author_id, body, attachments)
values (:'ani', 'Post kedua Ani',
        jsonb_build_array(jsonb_build_object('path', 'posts/' || :'ani' || '/kedua.jpg', 'mime', 'image/jpeg')))
returning id as post2 \gset

insert into public.reactions (user_id, target_type, target_id) values (:'budi', 'post', :'post');
insert into public.reactions (user_id, target_type, target_id) values (:'cici', 'post', :'post');
select is((select count(*)::integer from private.push_queue where user_id = :'ani' and kind = 'like'), 1,
  'Like yang digabung ke notifikasi belum dibaca tidak mengirim push lagi');

update public.notifications set read_at = now() where user_id = :'ani' and type = 'like';
delete from private.push_queue where user_id = :'ani';
insert into public.reactions (user_id, target_type, target_id) values (:'dodi', 'post', :'post');
select is((select count(*)::integer || '/' || (count(*) filter (where read_at is null))::integer
           from public.notifications where user_id = :'ani' and type = 'like'),
  '1/1', 'Like setelah notifikasi dibaca menghidupkan lagi notifikasi yang sama');
select is((select title from private.push_queue where user_id = :'ani' and kind = 'like'),
  'Ng Dodi dan 2 lainnya menyukai konten Anda',
  'Like yang menghidupkan lagi notifikasi mengirim push dengan jumlah pelaku, bukan jumlah kejadian');

update private.notification_actors set created_at = now() - interval '2 days'
 where notification_id = (select id from public.notifications where user_id = :'ani' and type = 'like');
update public.notifications set created_at = now() - interval '2 days' where user_id = :'ani' and type = 'like';
insert into public.reactions (user_id, target_type, target_id) values (:'eka', 'post', :'post');
select is((select count(*)::integer from public.notifications where user_id = :'ani' and type = 'like'), 1,
  'Like berhari-hari kemudian tetap digabung ke notifikasi yang sama');
select ok((select created_at > now() - interval '1 minute' from public.notifications
           where user_id = :'ani' and type = 'like'),
  'Like baru menaikkan notifikasi ke atas');

select tests.authenticate_as(:'ani');
select is((select actor_count || '|' || actor_username || '|' || jsonb_array_length(actors) || '|' || (actors -> 0 ->> 'username')
           from public.get_notifications() where type = 'like'),
  '4|ng_eka|3|ng_eka', 'Notifikasi like menghitung semua pelaku dan memuat tiga pelaku terbaru');
select is((select payload -> 'post_attachment' from public.get_notifications() where type = 'like'),
  jsonb_build_object('path', 'posts/' || :'ani' || '/foto.jpg', 'mime', 'image/jpeg', 'width', 800, 'height', 600),
  'Notifikasi like membawa gambar pertama post, bukan video');
reset role;

select is((select count(*)::integer from public.notifications where user_id = :'ani' and type = 'like'
           and payload ? 'post_attachment'), 0, 'Gambar post tidak disimpan di tabel notifikasi');

delete from public.reactions where user_id = :'eka' and target_id = :'post';
select tests.authenticate_as(:'ani');
select is((select actor_count || '|' || actor_username from public.get_notifications() where type = 'like'),
  '3|ng_dodi', 'Unlike menghapus pelaku dan pelaku terbaru berikutnya tampil');
reset role;
delete from public.reactions where target_id = :'post' and user_id in (:'budi', :'cici');
select tests.authenticate_as(:'ani');
select is((select actor_count || '|' || actor_username from public.get_notifications() where type = 'like'),
  '1|ng_dodi', 'Unlike pelaku lain tidak mengganti pelaku terbaru');
reset role;
delete from public.reactions where target_id = :'post' and user_id = :'dodi';
select is((select count(*)::integer from public.notifications where user_id = :'ani' and type = 'like'), 0,
  'Notifikasi like hilang saat semua pelaku unlike');

insert into public.reactions (user_id, target_type, target_id) values (:'budi', 'post', :'post2');
delete from private.notification_actors
 where notification_id = (select id from public.notifications where user_id = :'ani' and group_key = 'like:post:' || :'post2');
insert into public.reactions (user_id, target_type, target_id) values (:'cici', 'post', :'post2');
delete from public.reactions where target_id = :'post2' and user_id = :'budi';
select is((select count(*)::integer from public.notifications where user_id = :'ani' and group_key = 'like:post:' || :'post2'), 1,
  'Unlike dari pelaku lama tanpa catatan pelaku tidak menghapus notifikasi');

update public.posts set moderation_status = 'hidden' where id = :'post2';
select tests.authenticate_as(:'ani');
select ok((select not payload ? 'post_attachment' from public.get_notifications() where type = 'like'),
  'Post yang disembunyikan moderator tidak menampilkan gambar');
reset role;
update public.posts set moderation_status = 'visible' where id = :'post2';

select tests.authenticate_as(:'budi');
select id as c1 from public.create_comment(:'post', null, 'Komentar Budi') \gset
select tests.authenticate_as(:'cici');
select id as c2 from public.create_comment(:'post', :'c1', 'Balasan Cici') \gset
select tests.authenticate_as(:'dodi');
select id as c3 from public.create_comment(:'post', :'c1', 'Balasan Dodi') \gset
select tests.authenticate_as(:'cici');
select id as c4 from public.create_comment(:'post', :'c1', 'Balasan Cici lagi @ng_eka') \gset

select tests.authenticate_as(:'ani');
select is((select count(*)::integer || '|' || max(actor_count) || '|' || max(event_count) || '|' || max(payload ->> 'scope')
           from public.get_notifications() where type = 'reply'),
  '1|3|4|post', 'Komentar di post digabung per post dengan semua pelakunya');
select is((select payload -> 'post_attachment' ->> 'path' from public.get_notifications() where type = 'reply'),
  'posts/' || :'ani' || '/foto.jpg', 'Notifikasi komentar membawa gambar post');
select tests.authenticate_as(:'budi');
select is((select count(*)::integer || '|' || max(actor_count) || '|' || max(actor_username) || '|' || max(payload ->> 'scope')
           from public.get_notifications() where type = 'reply'),
  '1|2|ng_cici|comment', 'Balasan ke komentar digabung per komentar');
reset role;
select is((select title from private.push_queue where user_id = :'budi' and kind = 'reply'
           order by created_at desc, id desc limit 1),
  'Ng Cici dan 1 lainnya membalas komentar Anda', 'Push balasan komentar menyebut komentar, bukan postingan');

select tests.authenticate_as(:'cici');
select id as c5 from public.create_comment(:'post', null, 'Halo @ng_eka') \gset
reset role;
select is((select count(*)::integer from public.notifications where user_id = :'eka' and type = 'mention'), 2,
  'Mention tetap satu notifikasi per kejadian');

update public.notifications set read_at = now() where user_id = :'budi' and type = 'reply';
select tests.authenticate_as(:'dodi');
select id as c6 from public.create_comment(:'post', :'c1', 'Balasan setelah dibaca') \gset
reset role;
select is((select count(*)::integer || '/' || (count(*) filter (where read_at is null))::integer
           from public.notifications where user_id = :'budi' and type = 'reply'),
  '2/1', 'Balasan setelah notifikasi dibaca membuat notifikasi baru');

insert into public.follows (follower_id, following_id) values (:'cici', :'ani');
update public.notifications set created_at = now() - interval '2 days' where user_id = :'ani' and type = 'follow';
update private.notification_actors set created_at = now() - interval '2 days'
 where notification_id in (select id from public.notifications where user_id = :'ani' and type = 'follow');
insert into public.follows (follower_id, following_id) values (:'dodi', :'ani');
select tests.authenticate_as(:'ani');
select is((select count(*)::integer || '|' || max(actor_count) || '|' || max(actor_username)
           from public.get_notifications() where type = 'follow'),
  '1|2|ng_dodi', 'Follow yang belum dibaca digabung tanpa batas waktu');
reset role;

insert into public.notifications (user_id, actor_id, type, payload, group_key)
values (:'ani', :'budi', 'followed_post', jsonb_build_object('post_id', :'post', 'author_id', :'budi'),
        'followed_post:' || :'budi' || ':2026010100');
insert into public.notifications (user_id, actor_id, type, payload, group_key)
values (:'ani', :'budi', 'followed_post', jsonb_build_object('post_id', :'post2', 'author_id', :'budi'),
        'followed_post:' || :'budi' || ':2026010101')
on conflict (user_id, group_key) where read_at is null and group_key is not null
do update set event_count = public.notifications.event_count + 1;
select is((select count(*)::integer || '|' || max(event_count) || '|' || max(group_key)
           from public.notifications where user_id = :'ani' and type = 'followed_post'),
  '1|2|followed_post:' || :'budi' || ':' || to_char(now() at time zone 'Asia/Jakarta', 'YYYYMMDD'),
  'Postingan akun yang diikuti digabung per penulis per hari');

select is((select description from private.settings where key = 'notifications.aggregate_minutes') like 'Tidak dipakai lagi%',
  true, 'Pengaturan jendela gabung lama ditandai tidak dipakai');

select * from finish();
rollback;
