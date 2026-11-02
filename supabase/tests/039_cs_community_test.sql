begin;
select plan(66);

delete from public.banned_words;
insert into public.banned_words (word, action) values ('tipuan', 'block');
select cs.set_setting('community.four_eyes', 'true', null) as four_eyes_on \gset

select tests.create_user('km_budi') as budi \gset
select tests.create_user('km_sari') as sari \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_agent('Maya', '{community}', '{}') as maya \gset
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Dodi', '{community}', '{}') as dodi \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
insert into public.stock_watchers (user_id, stock_code) values (:'budi', 'KMTS');

select tests.authenticate_agent(:'maya');
select throws_ok('select cs_api.community_overview()', 'PT403', 'community_forbidden',
  'Staf tanpa izin komunitas tidak bisa membuka menu Komunitas');
select tests.authenticate_agent(:'rina');
select throws_ok(format($$select cs_api.admin_set_community_permissions(%L, '{community.post}')$$, :'maya'),
  'PT403', 'role_forbidden', 'Hanya Super Admin yang mengatur izin komunitas');

select tests.authenticate_agent(:'sinta');
select throws_ok(format($$select cs_api.admin_set_community_permissions(%L, '{community.everything}')$$, :'maya'),
  'PT400', 'invalid_permission', 'Izin komunitas yang tidak dikenal ditolak');
select is(cs_api.admin_set_community_permissions(:'maya', '{community.post}') -> 'community_permissions',
  '["community.post"]'::jsonb, 'Super Admin memberi izin tulis postingan');
select is(cs_api.admin_set_community_permissions(:'kirana', '{community.publish,community.post}') -> 'community_permissions',
  '["community.post", "community.publish"]'::jsonb, 'Izin bisa diberikan ke akun Kepatuhan');
select cs_api.admin_set_community_permissions(:'dodi', '{community.moderate,community.sanction}') as dodi_perms \gset
select cs_api.admin_set_community_permissions(:'sinta', '{community.accounts}') as sinta_perms \gset
select is((select count(*)::integer from cs.cs_audit_log where action = 'agent.community_permissions'
             and details ->> 'agent' in (:'maya', :'kirana', :'dodi', :'sinta')), 4,
  'Perubahan izin komunitas tercatat di audit');
reset role;
select lives_ok($$select cs.check_agent_input('Maya', '{community}', 'general', 1)$$, 'Peran Komunitas diterima saat membuat akun');

select tests.authenticate_agent(:'maya');
select is(cs_api.agent_me() -> 'community_permissions', '["community.post"]'::jsonb, 'Profil staf memuat izin komunitas');
select is(cs_api.agent_me() -> 'settings' -> 'community_four_eyes', 'true'::jsonb, 'Profil staf memuat aturan empat mata');
select throws_ok($$select cs_api.community_save_account(null, 'olt_research', 'OLT Research')$$, 'PT403',
  'community_forbidden', 'Penulis postingan tidak bisa membuat akun resmi');

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.community_save_account(null, 'olt research', 'OLT Research')$$, 'PT400',
  'invalid_username', 'Username akun resmi divalidasi');
select cs_api.community_save_account(null, 'km_research', 'OLT Research', 'Riset pasar resmi') ->> 'id' as account \gset
reset role;
select is((select olt_user_id || '/' || is_verified || '/' || trust_level from public.profiles where id = :'account'),
  'official:' || :'account' || '/true/3', 'Akun resmi tidak terikat login OLT, terverifikasi, dan berstatus resmi');
select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.community_save_account(null, 'km_research', 'Tiruan')$$, 'PT409', 'username_taken',
  'Username akun resmi unik');
select throws_ok(format($$select cs_api.community_save_account(%L, 'km_research', 'OLT Research', null, 'https://evil.example/a.png')$$, :'account'),
  'PT400', 'invalid_avatar', 'Foto akun resmi harus dari storage avatar akun itu');
select is(cs_api.community_save_account(:'account', 'km_research', 'OLT Research', 'Riset pasar resmi',
  'http://localhost:8000/storage/v1/object/public/avatars/' || :'account' || '/logo.png') ->> 'avatar_url',
  'http://localhost:8000/storage/v1/object/public/avatars/' || :'account' || '/logo.png', 'Foto akun resmi tersimpan');

select tests.authenticate_as(:'budi');
select ok(exists (select 1 from public.get_official_accounts() where id = :'account'),
  'Aplikasi nasabah mengenali akun resmi untuk badge');

select tests.authenticate_agent(:'maya');
select ok(cs.can_upload_official(:'account', 'community.post'), 'Penulis boleh mengunggah gambar ke folder akun resmi');
select ok(not cs.can_upload_official(gen_random_uuid()::text, 'community.post'), 'Folder selain akun resmi ditolak');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'announcement', null, 'Bursa libur besok')$$, :'account'),
  'PT400', 'invalid_title', 'Pengumuman wajib berjudul');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'post', null, 'Ini tipuan')$$, :'account'),
  'PT422', 'content_blocked', 'Kata terlarang ditolak sejak draf');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'post', null, 'Grafik', '[{"path": "posts/lain/a.png"}]')$$, :'account'),
  'PT400', 'invalid_attachments', 'Gambar harus di folder akun resmi');
select cs_api.community_save_post(null, :'account', 'announcement', 'Libur Bursa', 'Bursa libur pada 25 Desember. $BBCA',
  '[]', null, null, null, true) as draft \gset
select is(:'draft'::jsonb ->> 'status', 'draft', 'Penulis membuat draf pengumuman');
select is(:'draft'::jsonb ->> 'pin_scope', 'global', 'Pengumuman otomatis disematkan di stream umum');
select (:'draft'::jsonb ->> 'id') as ann \gset
select throws_ok(format($$select cs_api.community_review_post(%L, true)$$, :'ann'), 'PT403', 'community_forbidden',
  'Penulis tidak bisa menerbitkan sendiri');
select is(cs_api.community_submit_post(:'ann') ->> 'status', 'pending', 'Draf diajukan untuk ditinjau');
select throws_ok(format($$select cs_api.community_submit_post(%L)$$, :'ann'), 'PT409', 'invalid_status',
  'Draf yang sudah diajukan tidak bisa diajukan ulang');

select tests.authenticate_agent(:'kirana');
select throws_ok(format($$select cs_api.community_review_post(%L, true, null, 1)$$, :'ann'), 'PT409', 'stale_version',
  'Versi lama ditolak');
select cs_api.community_review_post(:'ann', true) as approved \gset
select is(:'approved'::jsonb ->> 'status', 'published', 'Kepatuhan menyetujui dan postingan langsung terbit');
select (:'approved'::jsonb ->> 'post_id') as ann_post \gset
select is((select author_id::text || '|' || body from public.posts where id = :'ann_post'),
  :'account' || '|Bursa libur pada 25 Desember. $BBCA', 'Postingan terbit atas nama akun resmi');
select ok(exists (select 1 from public.post_stocks where post_id = :'ann_post' and stock_code = 'BBCA'),
  'Cashtag postingan resmi ikut terindeks');
select is(:'approved'::jsonb -> 'campaign' ->> 'status', 'sent', 'Notifikasi pengumuman langsung dikirim');

select tests.authenticate_as(:'budi');
select is((select kind || '|' || title || '|' || (post ->> 'author_username') from public.get_pinned_posts()
            where post ->> 'author_username' = 'km_research'),
  'announcement|Libur Bursa|km_research', 'Nasabah melihat pengumuman tersemat di atas stream');
select is((select payload ->> 'title' from public.notifications where user_id = :'budi' and type = 'announcement'),
  'Libur Bursa', 'Nasabah menerima notifikasi pengumuman');
reset role;
select ok(not exists (select 1 from public.notifications n
                      join public.profiles p on p.id = n.user_id
                      where n.type = 'announcement' and (p.olt_user_id like 'cs-staff:%' or p.olt_user_id like 'official:%')),
  'Akun staf dan akun resmi tidak ikut menerima notifikasi');

select tests.authenticate_agent(:'kirana');
select cs_api.community_save_post(null, :'account', 'post', null, 'Analisa pagi: IHSG menguat') ->> 'id' as own \gset
select cs_api.community_submit_post(:'own') ->> 'status' as own_pending \gset
select throws_ok(format($$select cs_api.community_review_post(%L, true)$$, :'own'), 'PT403', 'four_eyes',
  'Pembuat tidak bisa menyetujui postingannya sendiri');
reset role;
select cs.set_setting('community.four_eyes', 'false', null) as four_eyes_off \gset
select tests.authenticate_agent(:'kirana');
select is(cs_api.community_review_post(:'own', true) ->> 'status', 'published',
  'Bila aturan empat mata dimatikan, penerbit boleh menerbitkan postingannya sendiri');
reset role;
select cs.set_setting('community.four_eyes', 'true', null) as four_eyes_back \gset

select tests.authenticate_agent(:'maya');
select cs_api.community_save_post(null, :'account', 'post', null, 'Promo biaya transaksi') ->> 'id' as promo \gset
select cs_api.community_submit_post(:'promo') ->> 'status' as promo_pending \gset
select tests.authenticate_agent(:'kirana');
select throws_ok(format($$select cs_api.community_review_post(%L, false, 'no')$$, :'promo'), 'PT400', 'note_required',
  'Penolakan wajib beralasan');
select is(cs_api.community_review_post(:'promo', false, 'Tambahkan syarat dan ketentuan') ->> 'status', 'rejected',
  'Kepatuhan menolak dengan catatan');
select tests.authenticate_agent(:'maya');
select is(cs_api.community_save_post(:'promo', :'account', 'post', null, 'Promo biaya transaksi. S&K berlaku') ->> 'status',
  'draft', 'Penulis memperbaiki draf yang ditolak');

select cs_api.community_save_post(null, :'account', 'post', null, 'Jadwal webinar besok', '[]', 'stock', 'bbri', null,
  false, now() + interval '1 day') ->> 'id' as later \gset
select cs_api.community_submit_post(:'later') ->> 'status' as later_pending \gset
select tests.authenticate_agent(:'kirana');
select is(cs_api.community_review_post(:'later', true) ->> 'status', 'scheduled', 'Postingan berjadwal menunggu waktunya');
reset role;
update cs.community_posts set publish_at = now() - interval '1 second' where id = :'later';
select is((cs.community_tick() ->> 'published')::integer, 1, 'Job terjadwal menerbitkan postingan yang jatuh tempo');
select tests.authenticate_as(:'budi');
select is((select count(*)::integer from public.get_pinned_posts('stock', 'BBRI')), 1, 'Sematan stream saham tampil di saham itu');
select is((select count(*)::integer from public.get_pinned_posts('stock', 'BBCA')), 0, 'Sematan saham tidak tampil di saham lain');

select tests.authenticate_agent(:'kirana');
select is(cs_api.community_pin_post(:'ann', null) ->> 'pinned', 'false', 'Penerbit melepas sematan');
select is(cs_api.community_pin_post(:'ann', 'global', null, now() + interval '2 days') ->> 'pinned', 'true',
  'Penerbit menyematkan ulang dengan batas waktu');
select is(cs_api.community_delete_post(:'later', 'Webinar dibatalkan') -> 'post' ->> 'deleted', 'true',
  'Penerbit menghapus postingan resmi');
reset role;
select ok(exists (select 1 from private.content_archive where target_id = (select post_id from cs.community_posts where id = :'later')),
  'Postingan resmi yang dihapus tetap diarsipkan');

select tests.authenticate_agent(:'maya');
select throws_ok(format($$select cs_api.community_save_campaign(null, %L, 'Promo', 'Biaya transaksi turun', null, 'http://olt.example')$$, :'account'),
  'PT400', 'invalid_link', 'Tautan notifikasi wajib https');
select is(cs_api.community_audience_size('stock', 'kmts'), 1, 'Jumlah penerima pemantau saham dihitung sebelum dikirim');
select cs_api.community_save_campaign(null, :'account', 'Info BBCA', 'Dividen BBCA dibagikan hari ini', null,
  'https://olt.example/dividen', 'stock', 'KMTS') ->> 'id' as camp \gset
select cs_api.community_submit_campaign(:'camp') ->> 'status' as camp_pending \gset
select tests.authenticate_agent(:'kirana');
select is(cs_api.community_review_campaign(:'camp', true) ->> 'status', 'sent', 'Notifikasi disetujui lalu dikirim');
reset role;
select is((select string_agg(p.username::text, ',') from public.notifications n join public.profiles p on p.id = n.user_id
           where n.type = 'announcement' and n.payload ->> 'campaign_id' = :'camp'), 'km_budi',
  'Notifikasi pemantau saham hanya ke pemantau saham itu');
select is((select payload ->> 'url' from public.notifications where user_id = :'budi' and payload ->> 'campaign_id' = :'camp'),
  'https://olt.example/dividen', 'Notifikasi membawa tautan tujuan');

select tests.authenticate_agent(:'maya');
select cs_api.community_save_campaign(null, :'account', 'Pengingat', 'Jangan lupa cek portofolio', null, null, 'all', null,
  now() + interval '3 hours') ->> 'id' as camp2 \gset
select cs_api.community_submit_campaign(:'camp2') ->> 'status' as camp2_pending \gset
select tests.authenticate_agent(:'kirana');
select is(cs_api.community_review_campaign(:'camp2', true) ->> 'status', 'scheduled', 'Notifikasi bisa dijadwalkan');
select is(cs_api.community_cancel_campaign(:'camp2') ->> 'status', 'cancelled', 'Notifikasi terjadwal bisa dibatalkan');

reset role;
insert into public.posts (author_id, body) values (:'sari', 'Saham ini pasti naik 300%, beli sekarang!') returning id as sari_post \gset
insert into public.reports (reporter_id, target_type, target_id, reason) values (:'budi', 'post', :'sari_post', 'pump_and_dump');
select tests.authenticate_agent(:'maya');
select throws_ok('select cs_api.community_reports()', 'PT403', 'community_forbidden', 'Penulis tidak bisa membuka antrean laporan');
select tests.authenticate_agent(:'dodi');
select is((select count(*)::integer from jsonb_array_elements(cs_api.community_reports()) r where r ->> 'target_id' = :'sari_post'), 1,
  'Moderator melihat laporan di antrean');
select is(cs_api.community_resolve_report('post', :'sari_post', 'hide', 'Ajakan pom-pom saham') ->> 'action', 'hide',
  'Moderator menyembunyikan postingan');
reset role;
select is((select moderation_status from public.posts where id = :'sari_post'), 'hidden', 'Postingan disembunyikan dari publik');
select is((select customer_id::text from cs.cs_audit_log where action = 'community.report_resolve' order by created_at desc limit 1),
  :'sari', 'Tindakan moderasi tercatat atas nama penulis konten');

select tests.authenticate_agent(:'dodi');
select is(cs_api.community_sanction_user(:'sari', 'Mengulang ajakan pom-pom') -> 'sanctions' -> 0 ->> 'kind', 'warning',
  'Sanksi pertama mengikuti tangga: peringatan');
select is(cs_api.community_sanction_user(:'sari', 'Mengulang lagi', 'mute', 24) -> 'profile' ->> 'muted', 'true',
  'Moderator membisukan pengguna 24 jam');
select throws_ok(format($$select cs_api.community_sanction_user(%L, 'Akun resmi dicoba diblokir')$$, :'account'),
  'PT400', 'protected_account', 'Akun resmi tidak bisa diberi sanksi');
select is((select count(*)::integer from jsonb_array_elements(cs_api.community_find_users('km_sar'))), 1,
  'Moderator mencari pengguna');
reset role;
select id as mute_id from private.user_sanctions where user_id = :'sari' and kind = 'mute' \gset
select tests.authenticate_agent(:'dodi');
select is(cs_api.community_revoke_sanction(:'mute_id', 'Banding diterima') -> 'profile' ->> 'muted', 'false',
  'Sanksi bisa dicabut dengan alasan');

select tests.authenticate_agent(:'sinta');
select is(cs_api.community_set_verified(:'sari', true, 'Analis bersertifikat') ->> 'is_verified', 'true',
  'Pengelola akun resmi memberi badge verifikasi');
select ok((cs_api.community_overview() ->> 'accounts')::integer >= 1, 'Ringkasan komunitas tersedia');

select * from finish();
rollback;
