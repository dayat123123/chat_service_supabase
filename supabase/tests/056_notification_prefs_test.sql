begin;
select plan(40);

select tests.create_user('np_ani') as ani \gset
select tests.create_user('np_budi') as budi \gset
select tests.create_user('np_cici') as cici \gset
select tests.create_user('np_dodi') as dodi \gset

select tests.authenticate_as(:'ani');
select ok(public.register_push_device('np-token-ani-00000000000000001', 'android') is not null, 'Perangkat push terdaftar');
select public.get_notification_prefs() as prefs \gset
select is(jsonb_array_length(:'prefs'::jsonb -> 'types'), 8, 'Preferensi memuat delapan jenis notifikasi');
select ok(not exists (select 1 from jsonb_array_elements(:'prefs'::jsonb -> 'types') e
                      where (e ->> 'push')::boolean is false or (e ->> 'in_app')::boolean is false),
  'Tanpa pengaturan semua notifikasi aktif');
select is((select e -> 'in_app' from jsonb_array_elements(:'prefs'::jsonb -> 'types') e where e ->> 'type' = 'olt.trade'),
  'null'::jsonb, 'Notifikasi transaksi OLT hanya push');
select is(:'prefs'::jsonb -> 'quiet_hours' ->> 'enabled', 'false', 'Jam tenang mati secara default');

select throws_ok($$select public.set_notification_prefs('{"types": [{"type": "promo", "push": false}]}')$$,
  'PT400', 'invalid_notification_type', 'Jenis notifikasi tidak dikenal ditolak');
select throws_ok($$select public.set_notification_prefs('{"types": [{"type": "like", "push": "no"}]}')$$,
  'PT400', 'invalid_preferences', 'Nilai preferensi harus boolean');
select throws_ok($$select public.set_notification_prefs('{"warna": "merah"}')$$,
  'PT400', 'invalid_preferences', 'Kunci tidak dikenal ditolak');
select throws_ok($$select public.set_notification_prefs('{"quiet_hours": {"enabled": true, "start": "22:00", "end": "22:00"}}')$$,
  'PT400', 'invalid_quiet_hours', 'Jam mulai dan selesai tidak boleh sama');
select throws_ok($$select public.set_notification_prefs('{"quiet_hours": {"enabled": true, "start": "25:00", "end": "06:00"}}')$$,
  'PT400', 'invalid_quiet_hours', 'Format jam tenang divalidasi');

select is(public.set_notification_prefs('{"types": {"like": {"push": false}, "follow": {"in_app": false},
                                          "mention": {"in_app": false, "push": false}, "olt.trade": {"push": false}}}')
          -> 'types' -> 2, '{"type": "like", "in_app": true, "push": false}'::jsonb,
  'Preferensi disimpan sebagian per jenis');
reset role;

select is(private.push_allowed(:'ani', 'like'), false, 'push_allowed menghormati preferensi');
select is(private.push_allowed(:'ani', 'olt.order'), false, 'Semua jenis olt.* mengikuti preferensi transaksi OLT');
select is(private.push_allowed(:'budi', 'like'), true, 'Pengguna tanpa preferensi tetap menerima push');
select is((select count(*)::integer from private.notification_prefs where user_id = :'ani'), 4,
  'Hanya preferensi yang berbeda dari bawaan yang disimpan');

insert into public.posts (id, author_id, body) values ('00000000-0000-4000-8000-00000000f601', :'ani', 'Post ani');
insert into public.reactions (user_id, target_type, target_id) values (:'budi', 'post', '00000000-0000-4000-8000-00000000f601');
select is((select count(*)::integer from public.notifications where user_id = :'ani' and type = 'like'), 1,
  'Like tetap masuk kotak notifikasi');
select is((select count(*)::integer from private.push_queue where user_id = :'ani' and kind = 'like'), 0,
  'Push like tidak dikirim bila dimatikan');

insert into public.follows (follower_id, following_id) values (:'budi', :'ani');
select is((select count(*)::integer from public.notifications where user_id = :'ani' and type = 'follow'), 0,
  'Follow tidak masuk kotak notifikasi bila in-app dimatikan');
select is((select count(*)::integer from private.push_queue where user_id = :'ani' and kind = 'follow'), 1,
  'Push follow tetap dikirim bila push aktif');

insert into public.posts (author_id, body) values (:'budi', 'Halo @np_ani');
select is((select count(*)::integer from public.notifications where user_id = :'ani' and type = 'mention'), 0,
  'Mention dimatikan sepenuhnya');
select is((select count(*)::integer from private.push_queue where user_id = :'ani' and kind = 'mention'), 0,
  'Tidak ada push mention');

select is(private.push_enqueue(:'ani', 'olt.trade', '"Order terisi"', '"BBCA 1 lot"'), 0,
  'Push transaksi OLT dihentikan preferensi');

update private.notification_prefs set in_app = false, push = false where user_id = :'ani' and type = 'like';
insert into private.notification_prefs (user_id, type, in_app, push) values (:'ani', 'message', false, false);
insert into public.notifications (user_id, type, payload)
values (:'ani', 'message', '{"room_type": "support", "room_name": "CS", "snippet": "Tiket Anda dibalas"}');
select is((select count(*)::integer from public.notifications where user_id = :'ani' and type = 'message'), 1,
  'Balasan chat CS tidak terkena preferensi chat');
select is((select count(*)::integer from private.push_queue where user_id = :'ani' and kind = 'message'), 1,
  'Push chat CS tetap dikirim');

select to_char((now() at time zone 'Asia/Jakarta') - interval '1 hour', 'HH24:MI') as q_start,
       to_char((now() at time zone 'Asia/Jakarta') + interval '1 hour', 'HH24:MI') as q_end \gset
select tests.authenticate_as(:'ani');
select is(public.set_notification_prefs(jsonb_build_object('quiet_hours',
            jsonb_build_object('enabled', true, 'start', :'q_start', 'end', :'q_end'))) -> 'quiet_hours' ->> 'start',
  :'q_start', 'Jam tenang disimpan');
reset role;
select ok(private.quiet_hours_end(:'ani') between now() + interval '55 minutes' and now() + interval '61 minutes',
  'Akhir jam tenang dihitung dalam WIB');
insert into public.notifications (user_id, type, payload, group_key)
values (:'ani', 'announcement', '{"title": "Info 1", "body": "Pertama"}', 'np:info');
insert into public.notifications (user_id, type, payload, group_key)
values (:'ani', 'announcement', '{"title": "Info 2", "body": "Kedua"}', 'np:info2');
update private.push_queue set collapse_key = 'np:info' where user_id = :'ani' and kind = 'announcement';
select private.push_enqueue(:'ani', 'announcement', '"Info 3"', '"Ketiga"', '{}', '{"collapse_key": "np:info"}') as q3 \gset
select ok((select bool_and(available_at > now() + interval '55 minutes' and expires_at > available_at)
           from private.push_queue where user_id = :'ani' and kind = 'announcement'),
  'Push saat jam tenang ditunda sampai jam tenang selesai');
select is((select count(*)::integer from private.push_queue
           where user_id = :'ani' and kind = 'announcement' and status = 'queued'), 1,
  'Push tertunda dengan collapse_key sama hanya menyisakan yang terbaru');
select is(private.push_enqueue(:'ani', 'test', '"Tes"', '"Tes"', '{}', '{"badge": false}'), 1,
  'Push uji Super Admin tetap masuk antrean');
select ok((select available_at <= now() from private.push_queue where user_id = :'ani' and kind = 'test'),
  'Push uji Super Admin tidak ditunda jam tenang');

delete from private.notification_prefs where user_id = :'ani';
delete from private.notification_settings where user_id = :'ani';
insert into public.reactions (user_id, target_type, target_id) values (:'cici', 'post', '00000000-0000-4000-8000-00000000f601');
insert into public.reactions (user_id, target_type, target_id) values (:'dodi', 'post', '00000000-0000-4000-8000-00000000f601');
select is((select count(*)::integer from public.notifications where user_id = :'ani' and type = 'like'), 1,
  'Like dalam satu jam digabung ke satu notifikasi');
insert into public.follows (follower_id, following_id) values (:'cici', :'ani');
insert into public.follows (follower_id, following_id) values (:'dodi', :'ani');

select tests.authenticate_as(:'ani');
select is((select actor_count || '|' || event_count || '|' || (actors -> 0 ->> 'username') || '|' || jsonb_array_length(actors)
           from public.get_notifications() where type = 'like'),
  '3|3|np_dodi|3', 'Notifikasi like memuat jumlah pelaku dan pelaku terbaru');
select is((select actor_count || '|' || actor_username from public.get_notifications() where type = 'follow'),
  '2|np_dodi', 'Follow dari beberapa orang digabung');
select is((select count(*)::integer from public.get_notifications(null, 100)), 5,
  'Pemanggilan lama get_notifications tetap jalan');
reset role;
select is((select count(*)::integer from private.push_queue where user_id = :'ani' and kind = 'follow'), 2,
  'Follow yang digabung tidak mengirim push berulang');

update private.notification_actors set created_at = now() - interval '2 hours'
 where notification_id = (select id from public.notifications where user_id = :'ani' and type = 'like');
delete from public.reactions where user_id = :'budi';
insert into public.reactions (user_id, target_type, target_id) values (:'budi', 'post', '00000000-0000-4000-8000-00000000f601');
select is((select count(*)::integer from public.notifications where user_id = :'ani' and type = 'like'), 2,
  'Like setelah jendela satu jam membuat notifikasi baru');
select is((select count(*)::integer from public.notifications where user_id = :'ani' and type = 'like' and group_key is not null), 1,
  'Hanya notifikasi terbaru yang memegang kunci grup');

select tests.authenticate_as(:'ani');
select ok(public.toggle_bookmark('00000000-0000-4000-8000-00000000f601'), 'Bookmark dibuat sebelum hapus akun');
select public.set_notification_prefs('{"types": [{"type": "like", "push": false}]}') as p2 \gset
select public.delete_my_account() as deleted \gset
reset role;
select is((select count(*)::integer from public.bookmarks where user_id = :'ani')
          + (select count(*)::integer from private.notification_prefs where user_id = :'ani'), 0,
  'Hapus akun ikut menghapus bookmark dan preferensi notifikasi');

select tests.authenticate_anon();
select throws_ok($$select public.get_notification_prefs()$$, '42501', null, 'Pengguna anonim tidak punya preferensi');
reset role;

select * from finish();
rollback;
