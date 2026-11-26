begin;
select plan(24);

select tests.create_user('hk_budi') as budi \gset
select tests.create_user('hk_sari') as sari \gset
select gen_random_uuid() as room \gset
select gen_random_uuid() as camp \gset
select gen_random_uuid() as gone_post \gset

create function pg_temp.queued(p_bucket text, p_path text) returns boolean language sql as $$
  select exists (select 1 from private.storage_cleanup_queue q
                 where q.bucket_id = p_bucket and q.prefix = p_path || '/' and q.done_at is null)
$$;

select is((select array_agg(r.key || '=' || private.retention_value(r.key) order by r.sort_order)
           from private.retention_rules() r where r.sort_order between 44 and 47),
  array['retention.cs_audit_days=1825', 'retention.notification_events_days=400',
        'retention.moderation_events_days=730', 'retention.cron_history_days=7'],
  'Aturan retensi baru tampil di Retensi data dengan nilai bawaannya');
select throws_ok($$update private.settings set value = '30' where key = 'retention.cron_history_days'$$,
  'PT409', null, 'Aturan baru hanya bisa diubah lewat alur persetujuan retensi');

insert into cron.job_run_details (jobid, runid, command, status, start_time, end_time) values
  (999001, 9000000001, 'select 1', 'succeeded', '2000-01-01', '2000-01-01'),
  (999001, 9000000002, 'select 1', 'succeeded', now(), now());
select is(private.cron_history_purge('2001-01-01', 1000), 1, 'Riwayat cron yang lewat batas dihapus');
select is((select count(*)::integer from cron.job_run_details where jobid = 999001), 1, 'Riwayat cron terbaru tetap ada');

create table cs.cs_audit_log_p200101 partition of cs.cs_audit_log for values from ('2001-01-01') to ('2001-02-01');
select is(private.cs_partitions_drop('2002-01-01'), 1, 'Partisi jejak audit yang lewat batas dibuang');
select ok(to_regclass('cs.cs_audit_log_p200101') is null
          and to_regclass('cs.cs_audit_log_p' || to_char(now() at time zone 'UTC', 'YYYYMM')) is not null,
  'Partisi bulan berjalan tidak tersentuh');

insert into private.notification_events (user_id, event, source_type, source_id, created_at) values
  (null, 'opened', 'campaign', :'camp', now() - interval '500 days'),
  (null, 'opened', 'campaign', :'camp', now() - interval '500 days'),
  (null, 'tapped', 'campaign', :'camp', now() - interval '500 days'),
  (null, 'opened', 'campaign', :'camp', now());
select is(private.notification_events_purge(now() - interval '400 days', 1000), 3, 'Catatan buka notifikasi lama dihapus');
select is(private.notification_event_stats('campaign', :'camp', 10) - 'tap_rate',
  jsonb_build_object('opened', 3, 'tapped', 1, 'open_rate', 30.0),
  'Statistik kampanye tetap utuh setelah catatan lama diringkas');

insert into private.content_archive (target_type, target_id, author_id, body, attachments) values
  ('post', :'gone_post', :'budi', 'x', jsonb_build_array(jsonb_build_object('path', 'posts/' || :'budi' || '/a.jpg'))),
  ('message', gen_random_uuid(), :'budi', 'x',
   jsonb_build_array(jsonb_build_object('bucket', 'cs-documents', 'path', 'rooms/' || :'room' || '/' || :'budi' || '/d.pdf')));
delete from private.content_archive where author_id = :'budi';
select ok(pg_temp.queued('attachments', 'posts/' || :'budi' || '/a.jpg')
          and pg_temp.queued('cs-documents', 'rooms/' || :'room' || '/' || :'budi' || '/d.pdf'),
  'Lampiran konten terhapus ikut dibersihkan saat arsipnya kedaluwarsa');

insert into public.posts (author_id, body) values (:'sari', 'Masih tampil') returning id as live_post \gset
insert into private.content_archive (target_type, target_id, author_id, body, attachments) values
  ('post', :'live_post', :'sari', 'x', jsonb_build_array(jsonb_build_object('path', 'posts/' || :'sari' || '/b.jpg')));
delete from private.content_archive where author_id = :'sari';
select ok(not pg_temp.queued('attachments', 'posts/' || :'sari' || '/b.jpg'),
  'Lampiran konten yang sudah dipulihkan tidak dihapus');

update public.profiles set avatar_url = 'https://api.test/storage/v1/object/public/avatars/' || :'budi' || '/avatar-1.jpg'
 where id = :'budi';
update public.profiles set avatar_url = 'https://api.test/storage/v1/object/public/avatars/' || :'budi' || '/avatar-2.jpg'
 where id = :'budi';
select ok(pg_temp.queued('avatars', :'budi' || '/avatar-1.jpg')
          and not pg_temp.queued('avatars', :'budi' || '/avatar-2.jpg'),
  'Foto profil lama dibersihkan saat diganti');
update public.profiles set avatar_url = 'https://cdn.example.com/x.jpg' where id = :'sari';
update public.profiles set avatar_url = null where id = :'sari';
select is((select count(*)::integer from private.storage_cleanup_queue
           where bucket_id = 'avatars' and prefix like '%x.jpg/'), 0, 'URL foto di luar bucket avatar diabaikan');

insert into storage.objects (bucket_id, name, owner_id, created_at) values
  ('attachments', 'posts/' || :'budi' || '/draft.jpg', :'budi', '2001-01-01 00:00:01+00'),
  ('attachments', 'posts/' || :'budi' || '/orphan.jpg', :'budi', '2001-01-01 00:00:02+00'),
  ('attachments', 'rooms/' || :'room' || '/' || :'budi' || '/lost.jpg', :'budi', '2001-01-01 00:00:03+00'),
  ('attachments', 'misc/' || :'budi' || '/keep.jpg', :'budi', '2001-01-01 00:00:04+00'),
  ('attachments', 'posts/' || :'budi' || '/fresh.jpg', :'budi', now() - interval '1 day'),
  ('avatars', :'budi' || '/avatar-2.jpg', :'budi', '2001-01-01 00:00:05+00'),
  ('avatars', :'budi' || '/avatar-0.jpg', :'budi', '2001-01-01 00:00:06+00');
insert into public.post_drafts (user_id, client_draft_id, attachments)
values (:'budi', gen_random_uuid(), jsonb_build_array(jsonb_build_object('path', 'posts/' || :'budi' || '/draft.jpg')));
insert into private.storage_sweep_cursors (bucket_id, last_created) values
  ('attachments', '2001-01-01'), ('avatars', '2001-01-01')
on conflict (bucket_id) do update set last_created = excluded.last_created, last_name = '';

select is(private.storage_orphan_sweep('attachments', 4), jsonb_build_object('checked', 4, 'queued', 2),
  'Penyapu memeriksa file yang sudah berumur dan menjadwalkan yang tidak dipakai');
select ok(pg_temp.queued('attachments', 'posts/' || :'budi' || '/orphan.jpg')
          and pg_temp.queued('attachments', 'rooms/' || :'room' || '/' || :'budi' || '/lost.jpg'),
  'Unggahan postingan dan chat yang batal dikirim dibersihkan');
select ok(not pg_temp.queued('attachments', 'posts/' || :'budi' || '/draft.jpg')
          and not pg_temp.queued('attachments', 'misc/' || :'budi' || '/keep.jpg')
          and not pg_temp.queued('attachments', 'posts/' || :'budi' || '/fresh.jpg'),
  'File di draf, pola tak dikenal, dan unggahan baru tidak disentuh');
select is((select c.last_name from private.storage_sweep_cursors c where c.bucket_id = 'attachments'),
  'misc/' || :'budi' || '/keep.jpg', 'Penyapu melanjutkan dari file terakhir yang diperiksa, jadi setiap file diperiksa sekali');
select is(private.storage_orphan_sweep('avatars', 2), jsonb_build_object('checked', 2, 'queued', 1),
  'Foto profil yang tidak lagi dipakai ikut disapu');
select ok(pg_temp.queued('avatars', :'budi' || '/avatar-0.jpg'), 'Foto profil lama dari sebelum pembaruan ini ikut dibersihkan');
select throws_ok($$select private.storage_orphan_sweep('evidence')$$, 'PT400', 'invalid_bucket',
  'Bucket bukti tidak pernah disapu');

insert into cs.faq_categories (code, name_id, name_en) values ('hk_test', 'Uji', 'Test') returning id as cat \gset
select gen_random_uuid() as img_used \gset
select gen_random_uuid() as img_unused \gset
insert into cs.faq_articles (category_id, question_id, question_en, answer_id, answer_en) values
  (:'cat', 'Pertanyaan uji', 'Test question',
   '![a](https://api.test/storage/v1/object/public/faq-images/' || :'img_used' || '.png)', 'x');
insert into storage.objects (bucket_id, name, created_at) values
  ('faq-images', :'img_used' || '.png', now() - interval '2 days'),
  ('faq-images', :'img_unused' || '.png', now() - interval '2 days');
select private.faq_files_sweep(500) as faq_swept \gset
select ok(pg_temp.queued('faq-images', :'img_unused' || '.png') and not pg_temp.queued('faq-images', :'img_used' || '.png'),
  'Gambar Pusat Bantuan yang tidak dipakai artikel mana pun dibersihkan');

insert into private.moderation_events (target_type, target_id, status, created_at)
values ('post', gen_random_uuid(), 'hidden', now() - interval '800 days');
select private.housekeeping_run(false) as run \gset
select is(:'run'::jsonb -> 'errors', '{}'::jsonb, 'Housekeeping berjalan tanpa error');
select ok((:'run'::jsonb #>> '{result,moderation_events}')::integer >= 1
          and :'run'::jsonb -> 'result' ?& array['cron_history', 'cs_audit', 'notification_events', 'post_files',
                                                  'attachments', 'cs-documents', 'cs-videos', 'avatars'],
  'Semua langkah housekeeping dijalankan dan riwayat moderasi lama dihapus');
select ok(exists (select 1 from private.housekeeping_runs), 'Setiap run housekeeping tercatat');
select ok(exists (select 1 from cron.job where jobname = 'housekeeping')
          and not exists (select 1 from cron.job where jobname = 'post-files-maintenance'),
  'Housekeeping dijadwalkan tiap jam dan menggantikan job post-files-maintenance');

select * from finish();
rollback;
