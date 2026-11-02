begin;
select plan(68);

delete from private.push_instances;
delete from private.push_queue;
delete from private.push_devices;
delete from private.push_ref_stats;

select tests.create_user('pu_ani') as ani \gset
select tests.create_user('pu_budi') as budi \gset
select tests.create_user('pu_cici') as cici \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Maya', '{community}', '{}') as maya \gset
update cs.agents set community_permissions = '{community.post,community.publish,community.accounts}'
 where user_id = :'maya';

select tests.authenticate_anon();
select throws_ok($$select public.register_push_device('android-token-ani-0000000001', 'android')$$, '42501', null,
  'Pengguna anonim tidak bisa mendaftarkan perangkat push');
reset role;

select tests.authenticate_as(:'ani');
select is(public.register_push_device('android-token-ani-0000000001', 'android', 'en-US', '2.4.0') ->> 'locale', 'en',
  'Perangkat terdaftar dengan bahasa dari locale aplikasi');
select is(public.register_push_device('android-token-ani-0000000001', 'android', 'en-US', '2.4.1') ->> 'platform',
  'android', 'Mendaftar ulang token yang sama tidak menggandakan perangkat');
select throws_ok($$select public.register_push_device('short', 'android')$$, 'PT400', 'invalid_push_token',
  'Token push yang terlalu pendek ditolak');
select throws_ok($$select public.register_push_device('android-token-ani-0000000002', 'blackberry')$$, 'PT400',
  'invalid_platform', 'Platform push yang tidak dikenal ditolak');
select throws_ok('select count(*) from private.push_devices', '42501', null,
  'Pengguna tidak bisa membaca tabel perangkat push secara langsung');
select throws_ok($$select public.push_claim('x', 10, 60)$$, '42501', null,
  'Pengguna tidak bisa mengambil antrean push');
reset role;

select is((select count(*)::integer from private.push_devices where user_id = :'ani'), 1,
  'Satu token tercatat sebagai satu perangkat');
select is((select app_version from private.push_devices where user_id = :'ani'), '2.4.1',
  'Versi aplikasi diperbarui saat mendaftar ulang');

insert into public.follows (follower_id, following_id) values (:'budi', :'ani');
insert into public.follows (follower_id, following_id) values (:'budi', :'cici');
select is((select title from private.push_queue where user_id = :'ani' and kind = 'follow'),
  'Pu Budi started following you', 'Notifikasi follow menjadi push berbahasa perangkat');
select is((select data ->> 'source' from private.push_queue where user_id = :'ani' and kind = 'follow'),
  'rendezvous_community', 'Data push menandai sumber paket komunitas');
select is((select data ->> 'notification_id' from private.push_queue where user_id = :'ani' and kind = 'follow'),
  (select id::text from public.notifications where user_id = :'ani' and type = 'follow'),
  'Data push membawa id notifikasi untuk dibuka dari aplikasi');
select is((select data ->> 'actor_username' from private.push_queue where user_id = :'ani' and kind = 'follow'),
  'pu_budi', 'Data push follow membawa username pengikut untuk membuka profilnya');
select is((select priority || '/' || collapse_key || '/' || badge
           from private.push_queue where user_id = :'ani' and kind = 'follow'),
  'normal/follow:' || :'budi' || '/1', 'Follow memakai prioritas normal, kunci grup, dan jumlah belum dibaca');
select is((select count(*)::integer from private.push_queue where user_id = :'cici'), 0,
  'Pengguna tanpa perangkat tidak mendapat antrean push');

insert into public.posts (id, author_id, body) values ('00000000-0000-4000-8000-000000000a01', :'ani', 'Analisa $BBCA');
insert into public.reactions (user_id, target_type, target_id) values (:'budi', 'post', '00000000-0000-4000-8000-000000000a01');
insert into public.reactions (user_id, target_type, target_id) values (:'cici', 'post', '00000000-0000-4000-8000-000000000a01');
select is((select event_count from public.notifications where user_id = :'ani' and type = 'like'), 2,
  'Like kedua digabung ke notifikasi yang sama');
select is((select count(*)::integer from private.push_queue where user_id = :'ani' and kind = 'like'), 1,
  'Like yang digabung hanya mengirim satu push agar tidak spam');

select tests.authenticate_as(:'budi');
select get_or_create_direct_room(:'ani') as dm \gset
insert into public.messages (room_id, sender_id, body) values (:'dm', :'budi', 'Halo Ani');
insert into public.messages (room_id, sender_id, body) values (:'dm', :'budi', 'Sudah lihat BBCA?');
reset role;
select is((select count(*)::integer from private.push_queue where user_id = :'ani' and kind = 'message'), 2,
  'Setiap pesan chat mengirim push walau notifikasinya digabung');
select is((select title || ' | ' || body from private.push_queue where user_id = :'ani' and kind = 'message'
           order by id desc limit 1),
  'Pu Budi · 2 new messages | Sudah lihat BBCA?', 'Push chat berikutnya menyebut jumlah pesan baru');
select is((select data ->> 'room_id' from private.push_queue where user_id = :'ani' and kind = 'message' limit 1),
  :'dm', 'Push chat membawa room untuk dibuka');

insert into public.notifications (user_id, type, payload)
values (:'ani', 'announcement',
        '{"title": "Libur Bursa", "body": "Bursa tutup 25 Desember", "campaign_id": "00000000-0000-4000-8000-0000000000c1"}');
select is((select title || ' | ' || body || ' | ' || ref from private.push_queue where kind = 'announcement'),
  'Libur Bursa | Bursa tutup 25 Desember | campaign:00000000-0000-4000-8000-0000000000c1',
  'Pengumuman memakai judul kampanye dan dicatat per kampanye');

select tests.authenticate_service();
select is(jsonb_array_length(public.push_claim('notifier-a', 100, 60)), 5, 'Notifier mengambil semua push yang siap');
select is(jsonb_array_length(public.push_claim('notifier-b', 100, 60)), 0,
  'Push yang sedang dikirim tidak diambil instance lain');
reset role;
select is((select attempts from private.push_queue where kind = 'announcement'), 1::smallint,
  'Percobaan dihitung saat push diambil');

select id as announcement from private.push_queue where kind = 'announcement' \gset
select id as follow from private.push_queue where kind = 'follow' \gset
select id as like_push from private.push_queue where kind = 'like' \gset
select min(id) as msg1, max(id) as msg2 from private.push_queue where kind = 'message' \gset

select tests.authenticate_service();
select is(public.push_report('notifier-b', jsonb_build_array(jsonb_build_object('id', :announcement, 'outcome', 'sent'))), 0,
  'Laporan dari instance yang tidak memegang push diabaikan');
select is(public.push_report('notifier-a', jsonb_build_array(
  jsonb_build_object('id', :announcement, 'outcome', 'sent'),
  jsonb_build_object('id', :follow, 'outcome', 'retry', 'error', 'UNAVAILABLE'),
  jsonb_build_object('id', :like_push, 'outcome', 'release', 'error', 'Tidak bisa menghubungi Firebase', 'retry_after', 5),
  jsonb_build_object('id', :msg1, 'outcome', 'failed', 'error', 'INVALID_ARGUMENT'))), 4,
  'Notifier melaporkan hasil kirim per push');
reset role;
select is((select status from private.push_queue where id = :announcement), 'sent', 'Push terkirim ditandai sent');
select is(cs.push_ref_view('campaign:00000000-0000-4000-8000-0000000000c1') ->> 'sent', '1',
  'Statistik kampanye bertambah saat push terkirim');
select ok((select available_at > now() and locked_until is null and status = 'queued'
           from private.push_queue where id = :follow), 'Push yang gagal sementara dijadwalkan ulang');
select is((select attempts from private.push_queue where id = :like_push), 0::smallint,
  'Gangguan layanan tidak menghabiskan jatah percobaan');
select is((select status || ' | ' || error from private.push_queue where id = :msg1), 'failed | INVALID_ARGUMENT',
  'Push yang gagal permanen ditandai failed beserta alasannya');

update private.push_queue set attempts = 6 where id = :follow;
update private.push_queue set locked_by = 'notifier-a' where id = :follow;
select tests.authenticate_service();
select is(public.push_report('notifier-a', jsonb_build_array(jsonb_build_object('id', :follow, 'outcome', 'retry'))), 1,
  'Retry pada batas percobaan tetap diterima');
reset role;
select is((select status from private.push_queue where id = :follow), 'failed',
  'Push berhenti dicoba setelah batas percobaan');

select tests.authenticate_service();
select is(public.push_report('notifier-a', jsonb_build_array(jsonb_build_object('id', :msg2, 'outcome', 'invalid', 'error', 'UNREGISTERED'))), 1,
  'Token mati dilaporkan notifier');
reset role;
select is((select count(*)::integer from private.push_devices where user_id = :'ani'), 0,
  'Perangkat dengan token mati dihapus');
select is((select count(*)::integer from private.push_queue where user_id = :'ani' and status = 'queued'), 0,
  'Push lain untuk token mati ikut dihentikan');

select is(cs.push_state(), 'offline', 'Tanpa heartbeat, layanan push dianggap mati');
select tests.authenticate_service();
select is(public.push_heartbeat('notifier-a', '0.1.0', false, null, null, now()) ->> 'queued', '0',
  'Heartbeat mengembalikan jumlah antrean');
reset role;
select is(cs.push_state(), 'not_configured', 'Layanan hidup tanpa file Firebase dianggap belum dipasang');
select tests.authenticate_service();
select public.push_heartbeat('notifier-a', '0.1.0', true, 'olt-prod', 'Firebase menolak kredensial: invalid_grant', now()) as hb \gset
reset role;
select is(cs.push_state(), 'error', 'Kredensial ditolak menjadi status bermasalah');
select tests.authenticate_service();
select public.push_heartbeat('notifier-a', '0.1.0', true, 'olt-prod', null, now()) as hb \gset
reset role;
select is(cs.push_state(), 'active', 'Kredensial valid menjadi status aktif');

select tests.authenticate_agent(:'rina');
select is(cs_api.agent_me() -> 'settings' ->> 'community_push_ready', 'true', 'Profil staf memuat status push');
select throws_ok('select cs_api.push_status()', 'PT403', null, 'Status push khusus Super Admin');
select throws_ok(format('select cs_api.push_test(%L)', :'ani'), 'PT403', null, 'Push uji khusus Super Admin');
reset role;

select tests.authenticate_as(:'ani');
select ok(public.register_push_device('ios-token-ani-000000000000001', 'ios') is not null, 'Perangkat iOS terdaftar');
reset role;
select tests.authenticate_agent(:'sinta');
select is(cs_api.push_status() -> 'devices' ->> 'ios', '1', 'Status push menghitung perangkat per platform');
select is(cs_api.push_status() ->> 'state', 'active', 'Status push menampilkan kondisi layanan');
select is(cs_api.push_status() -> 'last_24h' ->> 'invalid', '2', 'Status push menghitung token mati 24 jam terakhir');
select is(jsonb_array_length(cs_api.push_find_users('pu_')), 1, 'Pencarian push hanya menampilkan pengguna dengan perangkat');
select throws_ok(format('select cs_api.push_test(%L)', :'cici'), 'PT404', 'no_push_devices',
  'Push uji ke pengguna tanpa perangkat ditolak');
select is(cs_api.push_test(:'ani') ->> 'queued', '1', 'Super Admin mengirim push uji');
reset role;
select is((select count(*)::integer from cs.cs_audit_log where action = 'push.test' and customer_id = :'ani'), 1,
  'Push uji tercatat di audit');
select is((select badge from private.push_queue where kind = 'test'), null::integer, 'Push uji tidak mengubah badge');

select tests.authenticate_as(:'cici');
select public.register_push_device('ios-token-ani-000000000000001', 'ios', 'id') as moved \gset
reset role;
select is((select user_id from private.push_devices where token = 'ios-token-ani-000000000000001'), :'cici'::uuid,
  'Token yang dipakai akun lain berpindah ke akun terbaru');
select is((select status from private.push_queue where kind = 'test'), 'cancelled',
  'Push untuk akun lama di perangkat itu dibatalkan');

update private.settings set value = '2' where key = 'push.max_devices_per_user';
update private.push_devices set last_seen_at = now() - interval '2 hours' where user_id = :'cici';
select tests.authenticate_as(:'cici');
select public.register_push_device('web-token-cici-000000000000001', 'web') as w1 \gset
reset role;
update private.push_devices set last_seen_at = now() - interval '1 hour' where token = 'web-token-cici-000000000000001';
select tests.authenticate_as(:'cici');
select public.register_push_device('web-token-cici-000000000000002', 'web') as w2 \gset
reset role;
select is((select count(*)::integer from private.push_devices where user_id = :'cici'), 2,
  'Perangkat paling lama tidak aktif dilepas saat melewati batas');
select tests.authenticate_as(:'cici');
select lives_ok($$select public.unregister_push_device('web-token-cici-000000000000002')$$,
  'Pengguna melepas perangkat saat keluar');
reset role;
select is((select count(*)::integer from private.push_devices where user_id = :'cici'), 1, 'Perangkat yang keluar dihapus');

insert into public.notifications (user_id, type, payload) values (:'cici', 'announcement', '{"title": "Uji", "body": "Isi"}');
update private.push_queue set expires_at = now() - interval '1 minute' where user_id = :'cici' and status = 'queued';
select is(private.push_maintenance() ->> 'closed', '1', 'Pembersihan menutup push kedaluwarsa');
select is((select status from private.push_queue where user_id = :'cici' and kind = 'announcement'), 'expired',
  'Push kedaluwarsa ditandai expired');
update private.push_queue set finished_at = now() - interval '8 days' where user_id = :'cici';
select private.push_maintenance() as cleaned \gset
select is((select count(*)::integer from private.push_queue where user_id = :'cici'), 0,
  'Riwayat push lebih tua dari masa simpan dihapus');

update public.profiles set deleted_at = now() where id = :'cici';
select is((select count(*)::integer from private.push_devices where user_id = :'cici'), 0,
  'Perangkat push dihapus saat akun dihapus');

select ok(exists (select 1 from pg_policies where tablename = 'objects' and policyname = 'olt_official_avatar_delete'),
  'Staf pengelola akun resmi bisa menghapus foto lama');
select is(cs.setting('community.push_ready'), null, 'Status push tidak lagi diatur manual');

select tests.authenticate_agent(:'maya');
select cs_api.community_save_account(null, 'pu_research', 'PU Research') ->> 'id' as account \gset
select is(cs_api.community_save_account(:'account', 'pu_research', 'PU Riset', 'Riset harian') ->> 'display_name',
  'PU Riset', 'Nama akun resmi bisa diubah');
select cs_api.community_save_account(:'account', 'pu_research', 'PU Riset', 'Riset harian') as same \gset
select is((cs_api.community_overview() ->> 'push_state'), 'active', 'Menu Komunitas memuat status push');
reset role;
select is((select details -> 'changes' -> 'display_name' ->> 'from' from cs.cs_audit_log
           where action = 'community.account_update' and customer_id = :'account'), 'PU Research',
  'Audit mencatat nama lama dan baru');
select is((select count(*)::integer from cs.cs_audit_log where action = 'community.account_update' and customer_id = :'account'), 1,
  'Simpan tanpa perubahan tidak menambah audit');

select * from finish();
rollback;
