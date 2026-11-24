begin;
select plan(54);

update private.rate_limits set max_count = 100000 where action in ('message', 'room_create', 'stock_room_create', 'comment', 'post');
update private.settings set value = '0' where key = 'safety.new_account_days';
update cs.tickets set status = 'closed', closed_at = now() where status <> 'closed';

create function pg_temp.rewind_room(p_room uuid, p_years integer) returns void language sql security definer as $$
  update public.messages set created_at = created_at - make_interval(years => p_years) where room_id = p_room;
  update public.chat_rooms set last_message_at = last_message_at - make_interval(years => p_years),
                               created_at = created_at - make_interval(years => p_years) where id = p_room;
$$;
create function pg_temp.value(p_key text) returns integer language sql security definer as $$
  select private.retention_value(p_key)
$$;

select tests.create_user('rt_ani') as ani \gset
select tests.create_user('rt_budi') as budi \gset
select tests.create_user('rt_cici') as cici \gset
select tests.create_user('rt_dodi') as dodi \gset
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Laras', '{compliance}', '{}') as laras \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 2}') as rina \gset

select throws_ok($$update private.settings set value = '1' where key = 'retention.posts_years'$$,
  'PT409', 'retention_locked', 'Batas retensi tidak bisa diubah langsung lewat SQL');
select throws_ok($$delete from private.settings where key = 'retention.posts_years'$$,
  'PT409', 'retention_locked', 'Pengaturan retensi tidak bisa dihapus');
select throws_ok($$select cs.set_setting('retention.chat_years', '5', null)$$,
  'PT409', 'retention_locked', 'Retensi chat CS juga terkunci di pengaturan CS');
select throws_ok($$update private.settings set value = '7' where key = 'retention.notifications_days'$$,
  'PT400', 'invalid_retention', 'Nilai di luar batas ditolak sebelum dicek persetujuan');
select is(pg_temp.value('retention.audit_log_days'), 1825, 'Audit log admin kini disimpan lima tahun');

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.retention_overview()$$, 'PT403', 'role_forbidden', 'Agen CS biasa tidak bisa membuka retensi');
select tests.authenticate_agent(:'kirana');
select throws_ok($$select cs_api.compliance_confirm_policy('retention.chat_years', '7')$$, 'PT403', 'policy_locked',
  'Retensi chat CS tidak lagi diubah dari tab Kebijakan');
select cs_api.retention_overview() as overview \gset
select is(jsonb_array_length(:'overview'::jsonb -> 'rules'), 14, 'Katalog retensi memuat empat belas aturan');
select is((select r ->> 'value' from jsonb_array_elements(:'overview'::jsonb -> 'rules') r where r ->> 'key' = 'retention.posts_years'),
  '5', 'Post bawaan disimpan lima tahun');
select throws_ok($$select cs_api.retention_request_change('retention.posts_years', 31, 'Penyesuaian kebijakan internal')$$,
  'PT400', 'invalid_retention', 'Nilai di atas batas maksimal ditolak');
select throws_ok($$select cs_api.retention_request_change('retention.posts_years', 3, 'pendek')$$,
  'PT400', 'invalid_reason', 'Alasan perubahan wajib 10–500 karakter');
select cs_api.retention_request_change('retention.posts_years', 3, 'Arahan kepatuhan nomor 12/2026') as req \gset
select is(:'req'::jsonb ->> 'status' || '|' || (:'req'::jsonb ->> 'direction'), 'pending|delete_sooner',
  'Permintaan mempercepat penghapusan menunggu persetujuan');
select throws_ok($$select cs_api.retention_request_change('retention.posts_years', 4, 'Arahan kepatuhan nomor 13/2026')$$,
  'PT409', 'retention_change_open', 'Satu aturan hanya boleh punya satu permintaan terbuka');
select throws_ok(format('select cs_api.retention_decide_change(%s, true)', :'req'::jsonb ->> 'id'),
  'PT403', 'four_eyes_required', 'Pengaju tidak bisa menyetujui permintaannya sendiri');
select tests.authenticate_agent(:'laras', 'aal1');
select throws_ok(format('select cs_api.retention_decide_change(%s, true)', :'req'::jsonb ->> 'id'),
  'PT403', 'retention_mfa_required', 'Persetujuan wajib memakai sesi 2FA');
select tests.authenticate_agent(:'laras');
select cs_api.retention_decide_change((:'req'::jsonb ->> 'id')::bigint, true, 'Sesuai arahan') as approved \gset
select is(:'approved'::jsonb ->> 'status', 'approved', 'Permintaan disetujui staf lain');
select ok((:'approved'::jsonb ->> 'effective_at')::timestamptz between now() + interval '6 days 23 hours' and now() + interval '7 days 1 hour',
  'Penghapusan lebih cepat baru berlaku tujuh hari setelah disetujui');
reset role;
select private.retention_apply_due() as due \gset
select is(pg_temp.value('retention.posts_years'), 5, 'Nilai belum berubah sebelum masa tunggu selesai');
update private.retention_changes set effective_at = now() - interval '1 minute' where id = (:'req'::jsonb ->> 'id')::bigint;
select private.retention_apply_due() as due \gset
select is(pg_temp.value('retention.posts_years'), 3, 'Nilai berlaku setelah masa tunggu selesai');
select is((select source || '|' || coalesce(change_id::text, '-') from private.retention_history
           where key = 'retention.posts_years' order by id desc limit 1),
  'approved_change|' || (:'req'::jsonb ->> 'id'), 'Riwayat mencatat perubahan dan nomor permintaannya');
select throws_ok($$delete from private.retention_history$$, '42501', null, 'Riwayat retensi tidak bisa dihapus');

select tests.authenticate_agent(:'kirana');
select cs_api.retention_request_change('retention.stock_chat_years', 10, 'Diperpanjang untuk investigasi pasar') as longer \gset
select tests.authenticate_agent(:'laras');
select is(cs_api.retention_decide_change((:'longer'::jsonb ->> 'id')::bigint, true) ->> 'status', 'applied',
  'Memperpanjang masa simpan langsung berlaku setelah disetujui');
select cs_api.retention_request_change('retention.comments_years', 2, 'Usulan yang akhirnya dibatalkan') as cancel_me \gset
select tests.authenticate_agent(:'kirana');
select is(cs_api.retention_cancel_change((:'cancel_me'::jsonb ->> 'id')::bigint, 'Tidak jadi diubah') ->> 'status', 'withdrawn',
  'Permintaan bisa dibatalkan sebelum berlaku');
select cs_api.retention_request_change('retention.direct_chat_years', 4, 'Permintaan yang dibiarkan kedaluwarsa') as stale \gset
reset role;
update private.retention_changes set requested_at = now() - interval '15 days' where id = (:'stale'::jsonb ->> 'id')::bigint;
select private.retention_apply_due() as due \gset
select is((select status from private.retention_changes where id = (:'stale'::jsonb ->> 'id')::bigint), 'expired',
  'Permintaan yang tidak diputuskan 14 hari kedaluwarsa');
select is(pg_temp.value('retention.stock_chat_years') || '|' || pg_temp.value('retention.comments_years') || '|'
          || pg_temp.value('retention.direct_chat_years'), '10|5|5', 'Hanya perubahan yang disetujui yang berlaku');

insert into public.posts (author_id, body, attachments)
values (:'ani', 'Post lama Ani', jsonb_build_array(jsonb_build_object('path', 'posts/' || :'ani' || '/lama.jpg', 'mime', 'image/jpeg')))
returning id as old_post \gset
insert into public.posts (author_id, body) values (:'ani', 'Post baru Ani') returning id as new_post \gset
insert into public.posts (author_id, body) values (:'budi', 'Post lama Budi yang dilaporkan') returning id as reported_post \gset
insert into public.posts (author_id, body) values (:'cici', 'Post lama Cici yang ditahan') returning id as held_post \gset
update public.posts set created_at = now() - interval '4 years' where id in (:'old_post', :'reported_post', :'held_post');
insert into public.reports (reporter_id, target_type, target_id, reason) values (:'dodi', 'post', :'reported_post', 'scam');

select tests.authenticate_as(:'budi');
select id as old_comment from create_comment(:'new_post', null, 'Komentar lama') \gset
select id as parent_comment from create_comment(:'new_post', null, 'Komentar lama yang dibalas') \gset
select tests.authenticate_as(:'cici');
select id as reply_comment from create_comment(:'new_post', :'parent_comment', 'Balasan baru') \gset
reset role;
update public.comments set created_at = now() - interval '6 years' where id in (:'old_comment', :'parent_comment');

select tests.authenticate_as(:'ani');
select get_or_create_direct_room(:'budi') as dm \gset
select id as dm_old from send_message(:'dm', 'Pesan lama') \gset
select join_stock_room('BBCA') as stock \gset
select id as stock_msg from send_message(:'stock', 'Diskusi BBCA lama') \gset
select tests.authenticate_as(:'budi');
select get_or_create_direct_room(:'dodi') as dm_old_room \gset
reset role;
update private.dm_requests set status = 'accepted', responded_at = now() where room_id in (:'dm', :'dm_old_room');
select tests.authenticate_as(:'budi');
select id as all_old from send_message(:'dm_old_room', 'Semua pesan di room ini lama') \gset
reset role;
select pg_temp.rewind_room(:'dm', 6);
select pg_temp.rewind_room(:'dm_old_room', 6);
select pg_temp.rewind_room(:'stock', 6);
select tests.authenticate_as(:'budi');
select id as dm_new from send_message(:'dm', 'Pesan baru') \gset
select tests.authenticate_as(:'dodi');
select join_stock_room('BBCA') as stock_again \gset
select id as stock_ancient from send_message(:'stock', 'Diskusi BBCA sangat lama') \gset
reset role;
update public.messages set created_at = now() - interval '11 years' where id = :'stock_ancient';

select cs.ensure_room(:'ani') as support_old \gset
select cs.ensure_room(:'budi') as support_new \gset
insert into public.messages (room_id, sender_id, body) values (:'support_old', :'ani', 'Pertanyaan CS lama') returning id as cs_old \gset
insert into public.messages (room_id, sender_id, body) values (:'support_new', :'budi', 'Pertanyaan CS baru') returning id as cs_new \gset
select pg_temp.rewind_room(:'support_old', 11);
update cs.tickets set status = 'closed', closed_at = now() - interval '11 years' where room_id = :'support_old';
update cs.tickets set status = 'closed', closed_at = now() where room_id = :'support_new' and status <> 'closed';

select tests.authenticate_agent(:'kirana');
select cs_api.retention_add_hold('user', '@rt_cici', 'Permintaan penyidik terkait kasus 7/2026', 'BAP-7/2026') as hold \gset
select is(:'hold'::jsonb ->> 'target_label', '@rt_cici', 'Penahanan pengguna bisa memakai username');
select throws_ok(format('select cs_api.retention_release_hold(%L, %L)', :'hold'::jsonb ->> 'id', 'Kasus selesai'),
  'PT403', 'four_eyes_required', 'Pembuat penahanan tidak bisa melepasnya sendiri');
select cs_api.retention_preview() as preview \gset
select is(:'preview'::jsonb -> 'categories' -> 'posts' ->> 'count', '1', 'Pratinjau menghitung post yang akan dihapus');
reset role;

select private.retention_guard_run('cron') as run \gset
select is(:'run'::jsonb -> 'deleted' ->> 'posts', '1', 'Penjaga menghapus post yang melewati batas');
select is((select array_agg(id order by body) from public.posts where id in (:'old_post', :'new_post', :'reported_post', :'held_post')),
  array[:'new_post', :'reported_post', :'held_post']::uuid[],
  'Post baru, post yang dilaporkan, dan post yang ditahan tetap ada');
select is((select count(*)::integer from private.storage_cleanup_queue
           where bucket_id = 'attachments' and prefix = 'posts/' || :'ani' || '/lama.jpg/' and reason = 'retention'), 1,
  'Lampiran post yang dihapus masuk antrean pembersihan file');
select is((select count(*)::integer from public.comments where id = :'old_comment'), 0, 'Komentar lama dihapus');
select is((select count(*)::integer from public.comments where id in (:'parent_comment', :'reply_comment')), 2,
  'Komentar lama yang punya balasan baru tetap ada');
select is((select array_agg(body order by body) from public.messages where room_id = :'dm'), array['Pesan baru'],
  'Pesan DM lama dihapus, pesan baru tetap');
select is((select last_message_preview from public.chat_rooms where id = :'dm_old_room'), null::text,
  'Pratinjau room dikosongkan bila semua pesannya terhapus');
select is((select count(*)::integer from public.messages where id = :'stock_msg') || '|'
          || (select count(*)::integer from public.messages where id = :'stock_ancient'), '1|0',
  'Room saham mengikuti batasnya sendiri (10 tahun)');
select is((select count(*)::integer from public.messages where id = :'cs_old') || '|'
          || (select count(*)::integer from public.messages where id = :'cs_new'), '0|1',
  'Chat CS dihapus sepuluh tahun setelah aktivitas terakhir');
select is((select count(*)::integer from private.retention_runs where source = 'cron'), 1, 'Setiap run tercatat');
select is((select count(*)::integer from private.health_checks_retention()), 0, 'Kesehatan sistem tenang setelah run berhasil');

select tests.authenticate_agent(:'laras');
select is(cs_api.retention_release_hold((:'hold'::jsonb ->> 'id')::uuid, 'Kasus sudah ditutup penyidik') ->> 'released_at' is not null,
  true, 'Staf lain bisa melepas penahanan');
select tests.authenticate_agent(:'kirana');
select cs_api.retention_request_change('retention.max_rows_per_run', 1000, 'Batasi beban hapus per malam') as smaller \gset
select tests.authenticate_agent(:'laras');
select is(cs_api.retention_decide_change((:'smaller'::jsonb ->> 'id')::bigint, true) ->> 'status', 'applied',
  'Memperkecil batas baris langsung berlaku');
reset role;
insert into public.posts (author_id, body, created_at)
select :'ani', 'Post massal ' || g, now() - interval '4 years' from generate_series(1, 1005) g;
select private.retention_guard_run('cron') as capped \gset
select is((:'capped'::jsonb -> 'deleted' ->> 'posts') || '|' || (:'capped'::jsonb -> 'capped' ->> 0), '1000|posts',
  'Satu run tidak menghapus melebihi batas baris');
select private.retention_guard_run('cron') as rest \gset
select is(:'rest'::jsonb -> 'deleted' ->> 'posts', '6', 'Sisa antrean dihapus pada run berikutnya');
select is((select count(*)::integer from public.posts where id = :'held_post'), 0, 'Penahanan yang dilepas tidak melindungi lagi');

select tests.authenticate_agent(:'kirana');
select throws_ok($$select cs_api.retention_run_now()$$, 'PT403', 'role_forbidden', 'Hanya Super Admin yang bisa menjalankan manual');
select cs_api.retention_request_change('retention.purge_enabled', 0, 'Hentikan sementara selama audit') as stop \gset
select tests.authenticate_agent(:'laras');
select is(cs_api.retention_decide_change((:'stop'::jsonb ->> 'id')::bigint, true) ->> 'status', 'applied',
  'Menghentikan penjaga langsung berlaku');
select tests.authenticate_agent(:'sinta');
select cs_api.retention_run_now() as stopped \gset
select is((:'stopped'::jsonb ->> 'enabled') || '|' || (:'stopped'::jsonb -> 'deleted'), 'false|{}',
  'Penjaga yang dihentikan tidak menghapus apa pun');
select throws_ok($$select cs_api.retention_run_now()$$, 'PT429', 'retention_run_recent', 'Run manual dibatasi sekali per 10 menit');
select tests.authenticate_agent(:'kirana');
select is(cs_api.retention_request_change('retention.purge_enabled', 1, 'Aktifkan lagi setelah audit') ->> 'direction',
  'delete_sooner', 'Menyalakan lagi dianggap mempercepat penghapusan');
reset role;

update private.retention_runs set finished_at = now() - interval '30 hours';
select is((select count(*)::integer from private.health_checks_retention()), 0,
  'Penjaga yang sengaja dihentikan tidak memicu peringatan');
select id as resume_id from private.retention_changes where key = 'retention.purge_enabled' and status = 'pending' \gset
select tests.authenticate_agent(:'laras');
select cs_api.retention_decide_change(:'resume_id', true) as resume \gset
reset role;
update private.retention_changes set effective_at = now() - interval '1 minute' where key = 'retention.purge_enabled' and status = 'approved';
select private.retention_apply_due() as due \gset
select is((select key from private.health_checks_retention()), 'job:retention_guard',
  'Kesehatan sistem memperingatkan bila penjaga tidak berjalan lebih dari 26 jam');
select ok(exists (select 1 from cron.job where jobname = 'retention-guard' and schedule = '41 19 * * *'),
  'Job retention-guard terjadwal setiap hari pukul 02.41 WIB');
select ok(exists (select 1 from cron.job where jobname = 'retention-apply-due'), 'Job penerapan perubahan terjadwal');
select ok((select count(*) from cs.cs_audit_log where action like 'retention.%') >= 10, 'Semua aksi retensi tercatat di audit');

select * from finish();
rollback;
