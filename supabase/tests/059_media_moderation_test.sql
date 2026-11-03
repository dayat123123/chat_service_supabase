begin;
select plan(50);

select tests.create_user('mm_budi') as budi \gset
select tests.create_user('mm_sari') as sari \gset
select tests.create_user('mm_tono') as tono \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_agent('Dodi', '{community}', '{}') as dodi \gset
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
update cs.agents set community_permissions = '{community.moderate}' where user_id = :'dodi';

insert into public.chat_rooms (type, name, created_by) values ('group', 'Uji media', :'budi') returning id as room \gset
insert into public.chat_members (room_id, user_id, role) values (:'room', :'budi', 'owner'), (:'room', :'sari', 'member');

select 'posts/' || :'budi' || '/held.jpg' as held_path \gset
select 'posts/' || :'budi' || '/clean.jpg' as clean_path \gset
select 'rooms/' || :'room' || '/' || :'budi' || '/chat.jpg' as chat_path \gset

select tests.authenticate_service();
select ok((public.media_moderation_config() ->> 'revision')::bigint >= 1, 'Media membaca ambang beserta revisinya');
select ok(public.media_moderation_config() -> 'thresholds' -> 'porn' ? 'block', 'Ambang bawaan memblokir porn');
select is(public.media_moderation_config((public.media_moderation_config() ->> 'revision')::bigint),
  jsonb_build_object('revision', (public.media_moderation_config() ->> 'revision')::bigint, 'unchanged', true),
  'Revisi yang sama hanya dijawab unchanged');
select public.media_hold('attachments', :'held_path', :'budi', 'nsfw@1', '{"porn": 0.62, "neutral": 0.3}', 'porn', 0.62, 1)
  as held_id \gset
select public.media_hold('attachments', :'chat_path', :'budi', 'nsfw@1', '{"sexy": 0.8}', 'sexy', 0.8, 1) as chat_id \gset
select throws_ok(format($$select public.media_hold('attachments', %L, %L, 'nsfw@1', '{}', 'porn', 0.5)$$,
                        'posts/' || :'sari' || '/x.jpg', :'budi'),
  'PT403', 'not_owner', 'Penahanan hanya untuk folder milik pengunggah');
select throws_ok(format($$select public.media_hold('attachments', %L, %L, 'nsfw@1', '{}', 'porn', 0.5)$$,
                        'rooms/' || :'room' || '/' || :'sari' || '/x.jpg', :'budi'),
  'PT403', 'not_owner', 'Folder room orang lain ditolak');
select throws_ok(format($$select public.media_hold('avatars', %L, %L, 'nsfw@1', '{}', 'porn', 0.5)$$,
                        :'budi' || '/a.jpg', :'budi'),
  'PT400', 'bucket_not_holdable', 'Avatar (bucket publik) tidak bisa ditahan');
select throws_ok(format($$select public.media_hold('attachments', %L, %L, 'nsfw@1', '[]', 'porn', 1.5)$$,
                        'posts/' || :'budi' || '/y.jpg', :'budi'),
  'PT400', 'invalid_review', 'Skor di luar 0–1 ditolak');
reset role;

insert into storage.objects (bucket_id, name, owner, owner_id) values
  ('attachments', :'held_path', :'budi', :'budi'),
  ('attachments', :'clean_path', :'budi', :'budi'),
  ('attachments', :'chat_path', :'budi', :'budi');
insert into public.posts (author_id, body, attachments)
values (:'budi', 'Foto analisa', jsonb_build_array(jsonb_build_object('path', :'held_path', 'mime', 'image/jpeg'),
                                                   jsonb_build_object('path', :'clean_path', 'mime', 'image/jpeg')))
returning id as post \gset
insert into public.messages (room_id, sender_id, body, attachments)
values (:'room', :'budi', 'lihat ini', jsonb_build_array(jsonb_build_object('path', :'chat_path', 'mime', 'image/jpeg')))
returning id as message \gset

select tests.authenticate_service();
select throws_ok(format($$select public.media_hold('attachments', %L, %L, 'nsfw@1', '{}', 'porn', 0.5)$$,
                        :'clean_path', :'budi'),
  'PT409', 'already_exists', 'Objek yang sudah ada tidak bisa ditahan ulang');
select is(public.media_hold_cancel(:'held_id'), false, 'Penahanan tidak bisa dibatalkan bila objeknya sudah tersimpan');
reset role;

select tests.authenticate_as(:'sari');
select is((select count(*)::integer from storage.objects where name in (:'held_path', :'clean_path')), 1,
  'Pengguna lain hanya melihat gambar yang tidak ditahan');
select is((select count(*)::integer from storage.objects where name = :'chat_path'), 0,
  'Anggota room tidak melihat gambar chat yang ditahan');
select is(private.media_visible('attachments', :'held_path'), false, 'media_visible menolak orang lain');
reset role;

select tests.authenticate_as(:'budi');
select is((select count(*)::integer from storage.objects where name in (:'held_path', :'clean_path', :'chat_path')), 3,
  'Pengunggah tetap melihat gambarnya sendiri');
reset role;

select tests.authenticate_as(:'tono');
select is((select count(*)::integer from storage.objects where name = :'clean_path'), 1,
  'Gambar yang lolos tetap terbaca semua nasabah');
reset role;

select tests.authenticate_agent(:'rina');
select is((select count(*)::integer from storage.objects where name in (:'held_path', :'chat_path')), 0,
  'Staf tanpa izin moderasi tidak melihat gambar yang ditahan');
select throws_ok('select cs_api.community_media_reviews()', 'PT403', 'community_forbidden',
  'Antrean gambar butuh izin community.moderate');
select throws_ok('select cs_api.compliance_image_thresholds()', 'PT403', 'role_forbidden',
  'Ambang hanya untuk Kepatuhan');
reset role;

select tests.authenticate_agent(:'dodi');
select is((select count(*)::integer from storage.objects where name in (:'held_path', :'chat_path')), 2,
  'Moderator membaca gambar yang ditahan, termasuk di room yang bukan miliknya');
select is((select count(*)::integer from storage.objects where name = :'clean_path'), 1,
  'Moderator tetap membaca lampiran postingan biasa');
select cs_api.community_media_reviews() as queue \gset
select is(jsonb_array_length(:'queue'::jsonb -> 'items'), 2, 'Antrean berisi dua gambar tertahan');
select is((:'queue'::jsonb ->> 'pending')::integer >= 2, true, 'Jumlah antrean ikut dikirim');
select is((:'queue'::jsonb -> 'items' -> 0 ->> 'id')::bigint, :'held_id'::bigint, 'Antrean urut dari yang terlama');
select is(:'queue'::jsonb -> 'items' -> 0 -> 'used_in' -> 0 ->> 'id', :'post', 'Antrean menunjukkan postingan pemakainya');
select is(:'queue'::jsonb -> 'items' -> 1 -> 'used_in' -> 0 ->> 'type', 'message', 'Antrean menunjukkan pesan pemakainya');
select is(:'queue'::jsonb -> 'items' -> 0 -> 'uploader' ->> 'username', 'mm_budi', 'Antrean menunjukkan pengunggah');
select is(jsonb_array_length(cs_api.community_media_reviews('pending', null, 1) -> 'items'), 1, 'Batas per halaman dipakai');
select is((cs_api.community_media_reviews('pending', null, 1) ->> 'next_cursor')::bigint, :'held_id'::bigint,
  'Kursor halaman berikutnya dikirim');
select is((cs_api.community_media_reviews('pending', :'held_id') -> 'items' -> 0 ->> 'id')::bigint, :'chat_id'::bigint,
  'Kursor melanjutkan antrean');
select throws_ok('select cs_api.community_media_reviews(''bogus'')', 'PT400', 'invalid_status', 'Status tidak dikenal ditolak');
select throws_ok(format($$select cs_api.community_media_review_decide(%s, 'remove', 'x')$$, :'held_id'),
  'PT400', 'reason_required', 'Penghapusan wajib beralasan');
select is(cs_api.community_media_review_decide(:'chat_id', 'approve') ->> 'status', 'approved', 'Moderator menyetujui gambar');
select is(cs_api.community_media_review_decide(:'held_id', 'remove', 'Konten dewasa') ->> 'status', 'removed',
  'Moderator menghapus gambar');
select throws_ok(format($$select cs_api.community_media_review_decide(%s, 'approve')$$, :'held_id'),
  'PT409', 'media_review_decided', 'Keputusan tidak bisa diulang');
reset role;

select is((select attachments from public.posts where id = :'post'),
  jsonb_build_array(jsonb_build_object('path', :'clean_path', 'mime', 'image/jpeg')),
  'Lampiran yang dihapus dilepas dari postingan, lampiran lain tetap');
select is((select stripped -> 0 ->> 'id' from private.media_reviews where id = :'held_id'), :'post',
  'Konten yang dilepas lampirannya tercatat');
select is((select count(*)::integer from private.storage_cleanup_queue
           where bucket_id = 'attachments' and prefix = :'held_path' || '/' and reason = 'media_removed' and done_at is null), 1,
  'Objek yang dihapus masuk antrean janitor');
select is(private.storage_folder_objects('attachments', :'held_path' || '/', now(), 10), array[:'held_path'],
  'Janitor menemukan objek tunggal dari prefix-nya');
select is(private.storage_folder_objects('attachments', 'posts/' || :'budi' || '/', now(), 10),
  array[:'clean_path', :'held_path'], 'Prefix folder tetap berperilaku sama');
select is((select count(*)::integer from cs.cs_audit_log where action in ('community.media_approve', 'community.media_remove')
           and customer_id = :'budi'), 2, 'Keputusan moderator tercatat di jejak audit');

select tests.authenticate_as(:'sari');
select is((select count(*)::integer from storage.objects where name = :'chat_path'), 1,
  'Gambar yang disetujui terbaca anggota room');
reset role;
select tests.authenticate_as(:'budi');
select is((select count(*)::integer from storage.objects where name = :'held_path'), 0,
  'Gambar yang dihapus tidak terbaca lagi, termasuk oleh pengunggah');
reset role;

set local storage.allow_delete_query = 'true';
delete from storage.objects where bucket_id = 'attachments' and name = :'held_path';
select isnt((select object_deleted_at from private.media_reviews where id = :'held_id'), null,
  'Penghapusan objek dicatat di antrean review');

select tests.authenticate_agent(:'kirana');
select is(cs_api.compliance_image_thresholds() -> 'categories',
  '["drawings", "hentai", "neutral", "porn", "sexy"]'::jsonb, 'Kepatuhan melihat kategori model');
select (cs_api.compliance_image_thresholds() ->> 'revision')::bigint as rev_before \gset
select throws_ok($$select cs_api.compliance_set_image_thresholds('{"porn": {"hold": 0.9, "block": 0.5}}')$$,
  'PT400', 'invalid_image_thresholds', 'Ambang tahan tidak boleh di atas ambang blokir');
select throws_ok($$select cs_api.compliance_set_image_thresholds('{"sexy": {"hold": 0.5}}')$$,
  'PT400', 'invalid_image_thresholds', 'Ambang porn wajib ada');
select throws_ok($$select cs_api.compliance_set_image_thresholds('{"porn": {"hold": 0.5}, "gore": {"block": 0.5}}')$$,
  'PT400', 'invalid_image_thresholds', 'Kategori yang tidak dikenal model ditolak');
select is(cs_api.compliance_set_image_thresholds(
            '{"porn": {"hold": 0.4, "block": 0.8}, "sexy": {"hold": null, "block": null}, "hentai": {"hold": 0.5}}',
            'Uji ambang') -> 'thresholds',
  '{"hentai": {"hold": 0.5}, "porn": {"block": 0.8, "hold": 0.4}}'::jsonb, 'Ambang disimpan dalam bentuk ringkas');
select is((cs_api.compliance_image_thresholds() ->> 'revision')::bigint, :'rev_before'::bigint + 1,
  'Perubahan ambang menaikkan revisi untuk layanan media');
reset role;
select is((select details -> 'to' from cs.cs_audit_log where action = 'media.thresholds_set' order by created_at desc limit 1),
  '{"hentai": {"hold": 0.5}, "porn": {"block": 0.8, "hold": 0.4}}'::jsonb, 'Perubahan ambang tercatat di audit');

select tests.authenticate_as(:'budi');
select throws_ok('select public.media_moderation_config()', '42501', null, 'Nasabah tidak bisa membaca konfigurasi media');
reset role;

select * from finish();
rollback;
