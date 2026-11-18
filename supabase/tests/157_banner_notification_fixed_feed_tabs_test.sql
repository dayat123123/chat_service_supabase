begin;
select plan(31);

delete from public.banned_words;
insert into public.banned_words (word, action) values ('tipuan', 'block');
select cs.set_setting('community.four_eyes', 'true', null) as four_eyes_on \gset

select tests.create_user('bn_budi') as budi \gset
select tests.create_user('bn_resmi_lama') as resmi_lama \gset
select tests.create_user('bn_resmi_baru') as resmi_baru \gset
select tests.create_agent('Pandu Produk', '{product}', '{}') as product \gset
select tests.create_agent('Rani Penerbit', '{community}', '{}') as rani \gset
select tests.create_agent('Cici CS', '{cs_agent}', '{"general": 1}') as cici \gset
update cs.agents set community_permissions = '{community.publish}' where user_id = :'rani';
update cs.official_accounts set disabled_at = now() where disabled_at is null;

select tests.authenticate_agent(:'product');
select is(cs_api.admin_save_banner(null, 'Tanpa notifikasi') ->> 'campaign_id', null,
  'Banner tanpa p_notify tidak membuat notifikasi');
select throws_ok($$select cs_api.admin_save_banner(null, 'Promo akhir tahun', p_notify => true)$$,
  'PT400', 'no_official_account', 'Notifikasi butuh akun resmi aktif');
reset role;
select is((select count(*)::int from private.app_banners where title = 'Promo akhir tahun'), 0,
  'Banner batal tersimpan bila notifikasinya gagal');

insert into cs.official_accounts (profile_id, created_at) values
  (:'resmi_lama', now() - interval '2 days'),
  (:'resmi_baru', now() - interval '1 day');

select tests.authenticate_agent(:'product');
select throws_ok($$select cs_api.admin_save_banner(null, 'Hi', p_notify => true)$$,
  'PT400', 'notification_title_short', 'Judul notifikasi minimal 3 karakter');
select throws_ok($$select cs_api.admin_save_banner(null, 'Promo tipuan', p_notify => true)$$,
  'PT422', 'content_blocked', 'Kata terlarang ditolak untuk notifikasi banner');
select cs_api.admin_save_banner(null, 'Promo akhir tahun', 'Diskon biaya transaksi 50%', 'https://olt.example/promo',
  p_display => 'popup', p_notify => true) as promo \gset
select ok((:'promo'::jsonb ->> 'campaign_id') is not null, 'Banner dengan notifikasi mengembalikan campaign_id');
reset role;

select is((select status from cs.community_campaigns where id = (:'promo'::jsonb ->> 'campaign_id')::uuid), 'pending',
  'Notifikasi banner langsung menunggu persetujuan');
select is((select account_id from cs.community_campaigns where id = (:'promo'::jsonb ->> 'campaign_id')::uuid),
  :'resmi_lama'::uuid, 'Dikirim atas nama akun resmi aktif paling lama');
select is((select created_by from cs.community_campaigns where id = (:'promo'::jsonb ->> 'campaign_id')::uuid),
  :'product'::uuid, 'Pembuat notifikasi = pembuat banner');
select is((select banner_id from cs.community_campaigns where id = (:'promo'::jsonb ->> 'campaign_id')::uuid),
  (:'promo'::jsonb ->> 'id')::uuid, 'Notifikasi tertaut ke banner');
select is((select title || ' | ' || body || ' | ' || link_url || ' | ' || audience
             from cs.community_campaigns where id = (:'promo'::jsonb ->> 'campaign_id')::uuid),
  'Promo akhir tahun | Diskon biaya transaksi 50% | https://olt.example/promo | all',
  'Judul, isi, tautan https, dan penerima disalin dari banner');
select is((select count(*)::int from cs.cs_audit_log where action = 'community.campaign_submit'
             and details ->> 'banner' = :'promo'::jsonb ->> 'id'), 1, 'Pengajuan notifikasi tercatat di audit');
select is((select details ->> 'campaign' from cs.cs_audit_log where action = 'banner.save'
             and details ->> 'id' = :'promo'::jsonb ->> 'id'), :'promo'::jsonb ->> 'campaign_id',
  'Audit banner menyebut notifikasinya');

select tests.authenticate_agent(:'product');
select cs_api.admin_save_banner(null, 'Fitur baru', '', 'olt://promo/akhir-tahun', p_platforms => '{android}',
  p_starts_at => now() + interval '1 day', p_notify => true) ->> 'campaign_id' as deep \gset
select cs_api.admin_save_banner(null, 'Selamat datang', repeat('a', 300), p_audience => 'new_users',
  p_audience_days => 14, p_platforms => '{android,ios}', p_notify => true) ->> 'campaign_id' as fresh \gset
select is(cs_api.admin_save_banner((:'promo'::jsonb ->> 'id')::uuid, 'Promo akhir tahun diperpanjang',
  p_display => 'popup', p_notify => true) ->> 'campaign_id', null, 'Mengubah banner tidak membuat notifikasi baru');
reset role;

select is((select link_url from cs.community_campaigns where id = :'deep'), null,
  'Deep link aplikasi tidak disalin ke notifikasi');
select is((select body from cs.community_campaigns where id = :'deep'), 'Fitur baru',
  'Isi kosong memakai judul banner');
select is((select audience || ':' || audience_platform from cs.community_campaigns where id = :'deep'), 'platform:android',
  'Banner satu platform dikirim ke platform itu');
select ok((select send_at between now() + interval '23 hours' and now() + interval '25 hours'
             from cs.community_campaigns where id = :'deep'), 'Banner terjadwal menjadwalkan notifikasinya');
select is((select audience || ':' || audience_days from cs.community_campaigns where id = :'fresh'), 'new_users:14',
  'Sasaran pengguna baru ikut ke notifikasi');
select is((select char_length(body) || ':' || right(body, 1) from cs.community_campaigns where id = :'fresh'), '240:…',
  'Isi banner panjang dipotong 240 karakter');
select is((select count(*)::int from cs.community_campaigns where banner_id = (:'promo'::jsonb ->> 'id')::uuid), 1,
  'Satu banner satu notifikasi');

select tests.authenticate_agent(:'product');
select throws_ok(format($$select cs_api.community_review_campaign(%L, true)$$, :'promo'::jsonb ->> 'campaign_id'),
  'PT403', null, 'Pembuat banner tidak bisa menyetujui notifikasinya');
select tests.authenticate_agent(:'rani');
select ok(cs_api.community_review_campaign((:'promo'::jsonb ->> 'campaign_id')::uuid, true) ->> 'status' in ('sent', 'sending'),
  'Penerbit Komunitas menyetujui notifikasi banner');
reset role;

select is((select count(*)::int from public.feed_filters), 4, 'Tab Stream tetap empat tab bawaan');
select throws_ok($$insert into public.feed_filters (key, label_en, label_id) values ('video', 'Video', 'Video')$$,
  '23514', null, 'Tab Stream baru ditolak');
select hasnt_function('cs_api', 'admin_save_feed_filter', 'Tidak ada lagi RPC tambah/ubah tab Stream');
select hasnt_function('cs_api', 'admin_delete_feed_filter', 'Tidak ada lagi RPC hapus tab Stream');

select tests.authenticate_agent(:'cici');
select throws_ok($$select cs_api.admin_set_feed_filter_enabled('media', false)$$, 'PT403', null,
  'Agen CS tidak bisa mematikan tab Stream');
select tests.authenticate_agent(:'product');
select is((select e ->> 'enabled' from jsonb_array_elements(cs_api.admin_set_feed_filter_enabled('MEDIA', false)) e
            where e ->> 'key' = 'media'), 'false', 'Product mematikan tab Grafik & Media');
select throws_ok($$select cs_api.admin_set_feed_filter_enabled('video', false)$$, 'PT404', 'filter_not_found',
  'Tab yang tidak ada ditolak');
select cs_api.admin_set_feed_filter_enabled('media', false);
reset role;
select is((select count(*)::int from cs.cs_audit_log where action = 'feed_filter.enabled' and actor_id = :'product'), 1,
  'Hanya perubahan nyata yang tercatat di audit');

select * from finish();
rollback;
