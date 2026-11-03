begin;
select plan(20);

update private.rate_limits set max_count = 1000 where action in ('post', 'comment', 'message');

select tests.create_user('ms_ani') as ani \gset
select tests.create_user('ms_budi') as budi \gset
insert into public.follows (follower_id, following_id) values (:'ani', :'budi'), (:'budi', :'ani');

insert into public.posts (id, author_id, body) values
  ('00000000-0000-4000-8000-00000000f901', :'ani', 'Post ani ditahan'),
  ('00000000-0000-4000-8000-00000000f902', :'ani', 'Post ani disembunyikan'),
  ('00000000-0000-4000-8000-00000000f903', :'budi', 'Post budi terlihat');
update public.posts set moderation_status = 'held' where id = '00000000-0000-4000-8000-00000000f901';
update public.posts set moderation_status = 'hidden' where id = '00000000-0000-4000-8000-00000000f902';
insert into public.comments (id, post_id, author_id, body) values
  ('00000000-0000-4000-8000-00000000c901', '00000000-0000-4000-8000-00000000f903', :'ani', 'Komentar ani ditahan'),
  ('00000000-0000-4000-8000-00000000c902', '00000000-0000-4000-8000-00000000f903', :'budi', 'Komentar budi');
update public.comments set moderation_status = 'held' where id = '00000000-0000-4000-8000-00000000c901';

select tests.authenticate_as(:'ani');
select is((select moderation_status from public.get_feed('following') where id = '00000000-0000-4000-8000-00000000f901'),
  'held', 'Penulis melihat postingan ditahan miliknya di feed beserta statusnya');
select is((select moderation_status from public.get_feed('user', null, null, 20, :'ani') where id = '00000000-0000-4000-8000-00000000f902'),
  'hidden', 'Penulis melihat status disembunyikan di profilnya');
select is((select moderation_status from public.get_post('00000000-0000-4000-8000-00000000f903')), null,
  'Status moderasi postingan orang lain tidak dibuka');
select is((select moderation_status from public.create_post('Post baru ani')), 'visible',
  'Postingan baru menampilkan status untuk penulisnya');
select is((select moderation_status from public.get_comment_thread('00000000-0000-4000-8000-00000000f903')
           where id = '00000000-0000-4000-8000-00000000c901'), 'held', 'Penulis melihat komentar ditahan miliknya');
select is((select moderation_status from public.get_comment_thread('00000000-0000-4000-8000-00000000f903')
           where id = '00000000-0000-4000-8000-00000000c902'), null, 'Status komentar orang lain tidak dibuka');
select get_or_create_direct_room(:'budi') as dm \gset
select (public.send_message(:'dm', 'Pesan ani')).id as msg \gset
reset role;
update public.messages set moderation_status = 'held' where id = :'msg';

select tests.authenticate_as(:'ani');
select is((select moderation_status from public.get_messages(:'dm') where id = :'msg'), 'held',
  'Pengirim melihat pesan ditahan miliknya');
reset role;

select tests.authenticate_as(:'budi');
select ok(not exists (select 1 from public.get_feed('following') where id in ('00000000-0000-4000-8000-00000000f901',
                                                                              '00000000-0000-4000-8000-00000000f902')),
  'Orang lain tidak melihat postingan ditahan atau disembunyikan');
select is((select moderation_status from public.get_post('00000000-0000-4000-8000-00000000f903')), 'visible',
  'Penulis melihat status visible miliknya');
select ok(not exists (select 1 from public.get_comment_thread('00000000-0000-4000-8000-00000000f903')
                      where id = '00000000-0000-4000-8000-00000000c901'), 'Orang lain tidak melihat komentar ditahan');
select ok(not exists (select 1 from public.get_messages(:'dm') where id = :'msg'), 'Penerima tidak melihat pesan ditahan');
reset role;

select tests.authenticate_as(:'ani');
select is(public.export_my_data() ->> 'dm_policy', 'everyone', 'Ekspor data memuat kebijakan DM bawaan');
select ok(public.set_dm_policy('following') is not null, 'Kebijakan DM diubah');
reset role;
delete from private.rate_limit_events where user_id = :'ani' and action = 'data_export';
select tests.authenticate_as(:'ani');
select is(public.export_my_data() ->> 'dm_policy', 'following', 'Ekspor data memuat kebijakan DM terbaru');

select ok(public.get_notification_prefs() -> 'types' @> '[{"type": "appeal", "in_app": true, "push": true}]',
  'Notifikasi banding punya preferensi bawaan aktif');
select is((select config -> 'notification_types' from (select public.get_client_config() -> 'config' as config) c) ? 'appeal',
  true, 'Konfigurasi klien memuat jenis notifikasi banding');
reset role;

insert into public.notifications (user_id, type, payload)
values (:'ani', 'appeal', '{"appeal_id": "00000000-0000-4000-8000-0000000000a1", "status": "accepted", "title": "Banding Anda diterima"}');
select tests.authenticate_as(:'ani');
select is((select payload ->> 'status' from public.get_notifications() where type = 'appeal'), 'accepted',
  'Notifikasi banding tampil di get_notifications');
select ok(public.set_notification_prefs('{"types": {"appeal": {"in_app": false, "push": false}}}')
          -> 'types' @> '[{"type": "appeal", "in_app": false, "push": false}]', 'Preferensi banding bisa diubah');
reset role;
insert into public.notifications (user_id, type, payload) values (:'ani', 'appeal', '{"status": "rejected"}');
select is((select count(*)::integer from public.notifications where user_id = :'ani' and type = 'appeal'), 1,
  'Notifikasi banding mengikuti preferensi in-app');
select is(private.push_allowed(:'ani', 'appeal'), false, 'Push banding mengikuti preferensi');

select * from finish();
rollback;
