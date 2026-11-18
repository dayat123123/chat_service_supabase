begin;
select plan(40);

update private.rate_limits set max_count = 1000 where action in ('banner_event', 'notification_event');
update cs.cs_settings set value = '100000' where key = 'integration.broadcast_batch_size';

select tests.create_user('an_budi') as budi \gset
select tests.create_user('an_lama') as lama \gset
select tests.create_user('an_resmi') as resmi \gset
update public.profiles set created_at = now() - interval '30 days' where id = :'lama';
update public.profiles set olt_user_id = 'official:' || id where id = :'resmi';
select tests.create_agent('Pandu Produk', '{product}', '{}') as pandu \gset
select tests.create_agent('Putri Produk', '{product}', '{}') as putri \gset
select tests.create_agent('Sinta Admin', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Cici CS', '{cs_agent}', '{"general": 1}') as cici \gset

select private.notice_audience_count('all', 7) as everyone \gset
select is(private.notice_four_eyes(), false, 'Notifikasi banner langsung terkirim secara bawaan');
select hasnt_function('cs', 'banner_campaign', 'Banner tidak lagi membuat kampanye Komunitas');

select tests.authenticate_agent(:'pandu');
select ok(not (cs_api.admin_save_banner(null, 'Tanpa notifikasi') ? 'notice'), 'Banner tanpa p_notify tidak punya notifikasi');
select cs_api.admin_save_banner(null, 'Server mock trading', 'Server dipakai mock trading malam ini',
  'olt://mock-trading', p_level => 'warning', p_cta_label => 'Buka simulasi', p_notify => true) as mock \gset
select is(:'mock'::jsonb -> 'notice' ->> 'status', 'queued', 'Notifikasi banner langsung antre kirim');
select is(cs_api.admin_banner_notice_preview('all') -> 'four_eyes', 'false'::jsonb, 'Pratinjau menyebut tanpa persetujuan');
select is((cs_api.admin_banner_notice_preview('all') ->> 'recipients')::integer, :'everyone'::int,
  'Pratinjau menghitung semua penerima');
reset role;
select is((select count(*)::int from cs.community_campaigns where title = 'Server mock trading'), 0,
  'Notifikasi banner tidak masuk Komunitas › Notifikasi');

select private.app_notice_tick();
select is((select status from private.app_notices where id = (:'mock'::jsonb -> 'notice' ->> 'id')::uuid), 'sent',
  'Notifikasi selesai dikirim');
select is((select targeted from private.app_notices where id = (:'mock'::jsonb -> 'notice' ->> 'id')::uuid), :'everyone'::int,
  'Semua penerima dijangkau');
select is((select payload ->> 'title' || ' | ' || (payload ->> 'level') || ' | ' || (payload ->> 'link_url') || ' | ' || (payload ->> 'cta_label')
             from public.notifications where user_id = :'budi' and payload ->> 'notice_id' = :'mock'::jsonb -> 'notice' ->> 'id'),
  'Server mock trading | warning | olt://mock-trading | Buka simulasi', 'Isi notifikasi memuat judul, level, dan tautan in-app');
select is((select type from public.notifications where user_id = :'budi' and payload ? 'notice_id' limit 1), 'announcement',
  'Masuk daftar notifikasi nasabah');
select ok(not exists (select 1 from public.notifications where user_id = :'resmi' and payload ? 'notice_id'),
  'Akun resmi tidak menerima notifikasi info');
select ok(not (select payload ? 'source' from public.notifications where user_id = :'budi' and payload ? 'notice_id' limit 1),
  'Notifikasi info bukan notifikasi OLT/Komunitas');

select tests.authenticate_as(:'budi');
select is(public.get_app_notice((:'mock'::jsonb -> 'notice' ->> 'id')::uuid) ->> 'body', 'Server dipakai mock trading malam ini',
  'Nasabah membuka detail info');
select (select id from public.notifications where user_id = :'budi' and payload ->> 'notice_id' = :'mock'::jsonb -> 'notice' ->> 'id') as note \gset
select is(public.report_notification_event('tapped', :'note') ->> 'recorded', 'true', 'Ketukan tercatat');
select throws_ok($$select public.get_app_notice(gen_random_uuid())$$, 'PT404', 'notice_not_found', 'Info lain tidak bisa dibuka');
reset role;
select tests.authenticate_anon();
select throws_ok(format($$select public.get_app_notice(%L)$$, :'mock'::jsonb -> 'notice' ->> 'id'), '42501', null,
  'Anon tidak bisa membuka info');
reset role;

select tests.authenticate_agent(:'pandu');
select is((select (n ->> 'opened')::int || '/' || (n ->> 'tapped')::int
             from jsonb_array_elements(cs_api.admin_banner_notices()) n where n ->> 'id' = :'mock'::jsonb -> 'notice' ->> 'id'),
  '1/1', 'Hub melihat jumlah dibuka dan diketuk');
select is((select b -> 'notice' ->> 'status' from jsonb_array_elements(cs_api.admin_banners()) b
            where b ->> 'id' = :'mock'::jsonb ->> 'id'), 'sent', 'Daftar banner menampilkan status notifikasinya');
select cs_api.admin_save_banner(null, 'Selamat datang', p_audience => 'new_users', p_audience_days => 7, p_notify => true) as fresh \gset
select cs_api.admin_save_banner(null, 'Besok libur', p_starts_at => now() + interval '1 day', p_notify => true) as later \gset
select is(:'later'::jsonb -> 'notice' ->> 'status', 'scheduled', 'Banner terjadwal menjadwalkan notifikasinya');
select cs_api.admin_save_banner((:'mock'::jsonb ->> 'id')::uuid, 'Server mock trading', p_notify => true);
reset role;
select is((select count(*)::int from private.app_notices where banner_id = (:'mock'::jsonb ->> 'id')::uuid), 1,
  'Mengubah banner tidak membuat notifikasi baru');

select private.app_notice_tick();
select ok(exists (select 1 from public.notifications where user_id = :'budi' and payload ->> 'title' = 'Selamat datang')
          and not exists (select 1 from public.notifications where user_id = :'lama' and payload ->> 'title' = 'Selamat datang'),
  'Sasaran pengguna baru ikut ke notifikasi');
select is((select status from private.app_notices where id = (:'later'::jsonb -> 'notice' ->> 'id')::uuid), 'scheduled',
  'Notifikasi terjadwal belum terkirim');
update private.app_notices set send_at = now() - interval '1 minute' where id = (:'later'::jsonb -> 'notice' ->> 'id')::uuid;
select private.app_notice_tick();
select is((select status from private.app_notices where id = (:'later'::jsonb -> 'notice' ->> 'id')::uuid), 'sent',
  'Notifikasi terjadwal terkirim saat waktunya tiba');

select tests.authenticate_agent(:'pandu');
select throws_ok($$select cs_api.admin_set_setting('banners.notice_four_eyes', 'true'::jsonb)$$, 'PT403', null,
  'Hanya Super Admin yang mengubah aturan persetujuan');
select tests.authenticate_agent(:'sinta');
select is(cs_api.admin_set_setting('banners.notice_four_eyes', 'true'::jsonb) -> 'value', 'true'::jsonb,
  'Super Admin menyalakan empat mata notifikasi banner');
select throws_ok($$select cs_api.admin_set_setting('banners.notice_four_eyes', '"ya"'::jsonb)$$, 'PT400', 'invalid_setting',
  'Nilai aturan harus boolean');
reset role;

select tests.authenticate_agent(:'pandu');
select cs_api.admin_save_banner(null, 'Pemeliharaan', p_notify => true) as pending \gset
select is(:'pending'::jsonb -> 'notice' ->> 'status', 'pending', 'Dengan empat mata notifikasi menunggu persetujuan');
select throws_ok(format($$select cs_api.admin_review_banner_notice(%L, true)$$, :'pending'::jsonb -> 'notice' ->> 'id'),
  'PT403', 'four_eyes', 'Pembuat tidak bisa menyetujui notifikasinya');
reset role;
select private.app_notice_tick();
select is((select status from private.app_notices where id = (:'pending'::jsonb -> 'notice' ->> 'id')::uuid), 'pending',
  'Notifikasi yang belum disetujui tidak terkirim');

select tests.authenticate_agent(:'putri');
select throws_ok(format($$select cs_api.admin_review_banner_notice(%L, false, 'no')$$, :'pending'::jsonb -> 'notice' ->> 'id'),
  'PT400', 'note_required', 'Penolakan wajib beralasan');
select is(cs_api.admin_review_banner_notice((:'pending'::jsonb -> 'notice' ->> 'id')::uuid, true) ->> 'status', 'queued',
  'Staf Fitur & Banner lain menyetujui');
select throws_ok(format($$select cs_api.admin_review_banner_notice(%L, true)$$, :'pending'::jsonb -> 'notice' ->> 'id'),
  'PT409', 'invalid_status', 'Notifikasi yang sudah disetujui tidak bisa ditinjau lagi');
reset role;

select tests.authenticate_agent(:'pandu');
select cs_api.admin_save_banner(null, 'Promo salah', p_notify => true) as wrong \gset
select cs_api.admin_save_banner(null, 'Promo batal', p_notify => true) as dropped \gset
reset role;
select tests.authenticate_agent(:'sinta');
select is(cs_api.admin_review_banner_notice((:'wrong'::jsonb -> 'notice' ->> 'id')::uuid, false, 'Isi promo belum final')
          ->> 'status', 'rejected', 'Super Admin menolak dengan alasan');
select is(cs_api.admin_cancel_banner_notice((:'dropped'::jsonb -> 'notice' ->> 'id')::uuid) ->> 'status', 'cancelled',
  'Notifikasi yang belum terkirim bisa dibatalkan');
select throws_ok(format($$select cs_api.admin_cancel_banner_notice(%L)$$, :'mock'::jsonb -> 'notice' ->> 'id'),
  'PT409', 'invalid_status', 'Notifikasi yang sudah terkirim tidak bisa dibatalkan');
reset role;

select tests.authenticate_agent(:'pandu');
select cs_api.admin_save_banner(null, 'Akan dihapus', p_notify => true) as gone \gset
select cs_api.admin_delete_banner((:'gone'::jsonb ->> 'id')::uuid);
reset role;
select is((select status from private.app_notices where id = (:'gone'::jsonb -> 'notice' ->> 'id')::uuid), 'cancelled',
  'Menghapus banner membatalkan notifikasinya yang belum terkirim');

select tests.authenticate_agent(:'cici');
select throws_ok($$select cs_api.admin_banner_notices()$$, 'PT403', null, 'Agen CS tidak bisa melihat notifikasi banner');
reset role;
select is((select count(*)::int from cs.cs_audit_log where action = 'banner.notice_create'), 7,
  'Setiap notifikasi banner tercatat di audit');
select is((select count(*)::int from cs.cs_audit_log where action in ('banner.notice_approve', 'banner.notice_reject',
                                                                         'banner.notice_cancel')), 3,
  'Persetujuan, penolakan, dan pembatalan tercatat');

select * from finish();
rollback;
