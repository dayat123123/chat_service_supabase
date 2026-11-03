begin;
select plan(34);

update private.rate_limits set max_count = 1000
 where action in ('message', 'post', 'comment', 'follow', 'room_create', 'stock_room_create', 'notification_prefs');
update private.settings set value = '0' where key = 'rooms.busy_slow_mode';
delete from private.watchlist_digest_runs;

select tests.create_user('n66_budi') as budi \gset
select tests.create_user('n66_sari') as sari \gset
select tests.create_user('n66_joko') as joko \gset
select tests.create_user('n66_dewi') as dewi \gset
select tests.create_user('n66_rudi') as rudi \gset
select count(tests.create_user('n66_u' || g)) as created from generate_series(1, 7) g \gset
select tests.create_agent('Dodi Moderasi', '{community}', '{}') as dodi \gset
update cs.agents set community_permissions = '{community.moderate,community.sanction}' where user_id = :'dodi';

select ok(private.notification_pref_types() @> array['followed_post', 'watchlist_digest', 'moderation'],
  'Jenis preferensi baru tersedia');
select ok(public.get_client_config() -> 'config' -> 'notification_types' ?& array['followed_post', 'watchlist_digest', 'moderation'],
  'Konfigurasi klien memuat jenis notifikasi baru');

select tests.authenticate_as(:'sari');
select public.register_push_device('n66-token-sari-000000000000001', 'android') as dev_sari \gset
select public.get_notification_prefs() as prefs \gset
select is((select e from jsonb_array_elements(:'prefs'::jsonb -> 'types') e where e ->> 'type' = 'followed_post'),
  '{"type": "followed_post", "in_app": true, "push": false, "in_app_locked": false}'::jsonb,
  'Postingan akun yang diikuti: in-app aktif, push mati secara bawaan');
select is((select e from jsonb_array_elements(:'prefs'::jsonb -> 'types') e where e ->> 'type' = 'watchlist_digest'),
  '{"type": "watchlist_digest", "in_app": true, "push": true, "in_app_locked": false}'::jsonb,
  'Ringkasan saham pantauan: in-app dan push aktif secara bawaan');
select is((select e from jsonb_array_elements(public.set_notification_prefs('{"types": {"moderation": {"in_app": false, "push": false}}}') -> 'types') e
           where e ->> 'type' = 'moderation'),
  '{"type": "moderation", "in_app": true, "push": false, "in_app_locked": true}'::jsonb,
  'Notifikasi moderasi in-app tidak bisa dimatikan, push bisa');
select lives_ok($$select public.set_notification_prefs('{"types": {"moderation": {"push": true}}}')$$,
  'Push moderasi bisa dihidupkan kembali');
reset role;
select ok(not private.push_allowed(:'sari', 'followed_post') and private.push_allowed(:'sari', 'watchlist_digest')
          and private.push_allowed(:'sari', 'moderation'),
  'push_allowed memakai bawaan per jenis');

select tests.authenticate_as(:'joko');
select public.register_push_device('n66-token-joko-000000000000001', 'android') as dev_joko \gset
select public.set_notification_prefs('{"types": {"followed_post": {"push": true}}}') as joko_prefs \gset
reset role;
select tests.authenticate_as(:'budi');
select public.register_push_device('n66-token-budi-000000000000001', 'ios') as dev_budi \gset
reset role;

insert into public.mutes (muter_id, muted_id) values (:'dewi', :'budi');
select tests.authenticate_as(:'budi');
select join_stock_room('NTSA') as room \gset
select id as msg1 from send_message(:'room', 'Halo @n66_sari @N66_Joko @n66_dewi @n66_budi cek $NTSA') \gset
reset role;
select is((select string_agg(p.username::text, ',' order by p.username) from public.notifications n
           join public.profiles p on p.id = n.user_id
           where n.type = 'mention' and n.payload ->> 'room_id' = :'room'), 'n66_joko,n66_sari',
  'Mention di room saham memberi notifikasi, tanpa diri sendiri dan pengguna yang membisukan pengirim');
select is((select payload - 'room_name' from public.notifications where user_id = :'sari' and type = 'mention'),
  jsonb_build_object('room_id', :'room', 'room_type', 'stock', 'stock_code', 'NTSA', 'message_id', :'msg1',
                     'snippet', 'Halo @n66_sari @N66_Joko @n66_dewi @n66_budi cek $NTSA'),
  'Payload mention room memuat room, kode saham, pesan, dan cuplikan');
select is((select title from private.push_queue where user_id = :'sari' and kind = 'mention'),
  'N66 Budi menyebut Anda di $NTSA', 'Push mention room menyebut kode saham');

select tests.authenticate_as(:'budi');
select id as msg2 from send_message(:'room', '@n66_sari setuju, target berikutnya') \gset
reset role;
select is((select count(*)::integer || '/' || max(event_count) from public.notifications where user_id = :'sari' and type = 'mention'),
  '1/2', 'Mention berulang di room yang sama digabung per pengguna');

select tests.authenticate_as(:'budi');
select id as msg3 from send_message(:'room', 'Panggil @n66_u1 @n66_u2 @n66_u3 @n66_u4 @n66_u5 @n66_u6 @n66_u7') \gset
reset role;
select is((select count(*)::integer from public.notifications n join public.profiles p on p.id = n.user_id
           where n.type = 'mention' and p.username::text like 'n66_u%'), 5,
  'Maksimal lima pengguna disebut per pesan');

insert into public.follows (follower_id, following_id) values (:'sari', :'budi'), (:'joko', :'budi'), (:'dewi', :'budi');
insert into public.posts (author_id, body) values (:'budi', 'Postingan baru Budi tentang $NTSA') returning id as post1 \gset
select ok(exists (select 1 from private.followed_post_queue where post_id = :'post1'), 'Postingan terlihat masuk antrean pengikut');
insert into public.posts (author_id, body, moderation_status) values (:'budi', 'Postingan ditahan', 'held') returning id as held_post \gset
select ok(not exists (select 1 from private.followed_post_queue where post_id = :'held_post'),
  'Postingan yang ditahan tidak memberi notifikasi pengikut');
select is(private.followed_post_tick() ->> 'notifications', '2', 'Job mengirim notifikasi ke pengikut');
select is((select string_agg(p.username::text, ',' order by p.username) from public.notifications n
           join public.profiles p on p.id = n.user_id where n.type = 'followed_post'), 'n66_joko,n66_sari',
  'Pengikut yang membisukan penulis tidak diberi notifikasi');
select is((select payload from public.notifications where user_id = :'sari' and type = 'followed_post'),
  jsonb_build_object('post_id', :'post1', 'author_id', :'budi', 'snippet', 'Postingan baru Budi tentang $NTSA'),
  'Payload postingan akun yang diikuti');
select is((select count(*)::integer || '/' || (select count(*) from private.push_queue where user_id = :'sari' and kind = 'followed_post')
           from private.push_queue where user_id = :'joko' and kind = 'followed_post'), '1/0',
  'Push postingan akun yang diikuti hanya bila pengguna mengaktifkannya');
insert into public.posts (author_id, body) values (:'budi', 'Postingan kedua Budi di jam yang sama') returning id as post2 \gset
select private.followed_post_tick() as tick2 \gset
select is((select count(*)::integer || '/' || max(event_count) || '/' || max(payload ->> 'post_id')
           from public.notifications where user_id = :'sari' and type = 'followed_post'),
  '1/2/' || :'post2', 'Postingan dalam jam yang sama digabung per penulis');
select is((select count(*)::integer from private.push_queue where user_id = :'joko' and kind = 'followed_post'), 1,
  'Push postingan akun yang diikuti tidak diulang saat digabung');
select ok(not exists (select 1 from private.followed_post_queue where author_id = :'budi'), 'Antrean pengikut kosong setelah diproses');

insert into public.stock_watchers (user_id, stock_code) values
  (:'sari', 'NTSA'), (:'sari', 'NTSB'), (:'sari', 'NTSC'), (:'sari', 'NTSD'), (:'dewi', 'NTSZ'), (:'rudi', 'NTSB');
insert into public.posts (author_id, body) values
  (:'joko', 'Diskusi $NTSA dan $NTSB hari ini'),
  (:'joko', 'Update $NTSB laporan keuangan'),
  (:'dewi', 'Pendapat $NTSC dan $NTSD'),
  (:'sari', 'Postingan sendiri $NTSA tidak dihitung');
insert into public.blocks (blocker_id, blocked_id) values (:'rudi', :'joko');
select private.watchlist_digest(now()) as digest \gset
select is((select payload - 'since' - 'until' - 'date' from public.notifications where user_id = :'sari' and type = 'watchlist_digest'),
  '{"post_count": 4, "stock_count": 4, "stocks": ["NTSA", "NTSB", "NTSC"]}'::jsonb,
  'Ringkasan memuat jumlah postingan baru, jumlah saham, dan tiga kode teratas');
select ok(not exists (select 1 from public.notifications where user_id in (:'dewi', :'rudi') and type = 'watchlist_digest'),
  'Tanpa postingan baru (atau penulis diblokir) tidak ada ringkasan');
select is((select body from private.push_queue where user_id = :'sari' and kind = 'watchlist_digest'),
  '4 postingan baru tentang $NTSA, $NTSB, $NTSC, dan 1 saham lainnya', 'Push ringkasan menyebut kode saham');
select is(private.watchlist_digest(now()) ->> 'skipped', 'true', 'Ringkasan hanya dikirim sekali per hari');

insert into public.comments (post_id, author_id, body) values (:'post1', :'budi', 'Komentar Budi sendiri') returning id as comment1 \gset
select tests.authenticate_agent(:'dodi');
select cs_api.community_resolve_report('post', :'post1', 'hide', 'Menyesatkan') as hidden \gset
select cs_api.community_resolve_report('comment', :'comment1', 'remove', 'Spam berulang') as removed \gset
reset role;
select is((select payload from public.notifications where user_id = :'budi' and type = 'moderation' and payload ->> 'state' = 'hidden'),
  jsonb_build_object('target_type', 'post', 'target_id', :'post1', 'state', 'hidden',
                     'excerpt', 'Postingan baru Budi tentang $NTSA', 'appealable', true),
  'Penulis diberi tahu saat postingan disembunyikan moderator');
select is((select payload from public.notifications where user_id = :'budi' and type = 'moderation' and payload ->> 'state' = 'removed'),
  jsonb_build_object('target_type', 'comment', 'target_id', :'comment1', 'state', 'removed',
                     'excerpt', 'Komentar Budi sendiri', 'appealable', true, 'post_id', :'post1'),
  'Penulis diberi tahu saat komentar dihapus moderator');
select is((select title || ' | ' || (data ? 'excerpt')::text || ' | ' || (data ->> 'target_id')
           from private.push_queue where user_id = :'budi' and kind = 'moderation' and data ->> 'state' = 'hidden'),
  'Postingan Anda disembunyikan moderator | false | ' || :'post1', 'Push moderasi tanpa cuplikan konten');
update public.posts set moderation_status = 'held' where id = :'post2';
select is((select count(*)::integer from public.notifications where user_id = :'budi' and type = 'moderation'), 2,
  'Penahanan otomatis (held) tidak memberi notifikasi moderasi');

select tests.authenticate_as(:'budi');
select public.set_notification_prefs('{"types": {"moderation": {"push": false}}}') as budi_prefs \gset
reset role;
insert into public.posts (author_id, body) values (:'budi', 'Postingan ketiga Budi') returning id as post3 \gset
select tests.authenticate_agent(:'dodi');
select cs_api.community_resolve_report('post', :'post3', 'remove', 'Melanggar') as removed3 \gset
reset role;
select is((select count(*)::integer || '/' || (select count(*) from private.push_queue
                                               where user_id = :'budi' and kind = 'moderation' and data ->> 'target_id' = :'post3')
           from public.notifications where user_id = :'budi' and type = 'moderation' and payload ->> 'target_id' = :'post3'),
  '1/0', 'Notifikasi moderasi selalu masuk kotak notifikasi, push mengikuti preferensi');

insert into public.posts (author_id, body) values (:'rudi', 'Konten Rudi') returning id as rudi_post \gset
select tests.authenticate_agent(:'dodi');
select cs_api.community_zero_tolerance(:'rudi', 'Materi terlarang') as zt \gset
reset role;
select ok(not exists (select 1 from public.notifications where user_id = :'rudi' and type = 'moderation'),
  'Toleransi nol tidak mengirim notifikasi moderasi');

insert into public.posts (author_id, body) values (:'dodi', 'Postingan staf') returning id as staff_post \gset
update public.posts set moderation_status = 'hidden' where id = :'staff_post';
select ok(not exists (select 1 from public.notifications where user_id = :'dodi' and type = 'moderation'),
  'Konten staf yang disembunyikan tidak memberi notifikasi moderasi');

select tests.authenticate_as(:'budi');
select join_stock_room('NTSB') as room_b \gset
select id as dm_msg from send_message(:'room_b', 'Pesan untuk dihapus') \gset
reset role;
select tests.authenticate_agent(:'dodi');
select cs_api.community_resolve_report('message', :'dm_msg', 'remove', 'Spam room') as msg_removed \gset
reset role;
select is((select payload ->> 'room_id' from public.notifications where user_id = :'budi' and type = 'moderation'
           and payload ->> 'target_id' = :'dm_msg'), :'room_b', 'Notifikasi moderasi pesan memuat room');

select is((select count(*)::integer from cron.job where jobname in ('social-followed-posts', 'social-watchlist-digest')), 2,
  'Job pengikut dan ringkasan terjadwal');

select * from finish();
rollback;
