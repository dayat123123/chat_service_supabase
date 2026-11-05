begin;
select plan(69);

delete from private.app_banners;
update private.rate_limits set max_count = 1000 where action = 'banner_event';

select tests.create_user('bp_baru') as baru \gset
select tests.create_user('bp_lama') as lama \gset
select tests.create_user('bp_citra') as citra \gset
update public.profiles set created_at = now() - interval '30 days' where id = :'lama';
select tests.create_agent('Sinta Popup', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Popup', '{cs_agent}', '{"general": 1}') as rina \gset
select gen_random_uuid() || '.jpg' as img \gset
select gen_random_uuid() || '.webp' as img2 \gset
select 'https://api.olt.example/storage/v1/object/public/app-banners/' as base \gset

select is((select jsonb_build_object('public', public, 'size', file_size_limit, 'mime', to_jsonb(allowed_mime_types))
           from storage.buckets where id = 'app-banners'),
  '{"public": true, "size": 2097152, "mime": ["image/jpeg", "image/png", "image/webp"]}'::jsonb,
  'Bucket app-banners publik, JPEG/PNG/WebP, maksimal 2 MB');
select ok((select relrowsecurity from pg_class where oid = 'private.app_banner_events'::regclass)
          and not has_table_privilege('authenticated', 'private.app_banner_events', 'select')
          and not has_table_privilege('anon', 'private.app_banner_events', 'select'),
  'Event banner tidak bisa dibaca langsung');
select ok(not has_function_privilege('anon', 'public.record_banner_event(uuid, text)', 'execute')
          and has_function_privilege('authenticated', 'public.record_banner_event(uuid, text)', 'execute'),
  'record_banner_event hanya untuk pengguna login');
select ok((select bool_and(p.prosecdef and p.proconfig @> array['search_path=""'])
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where (n.nspname = 'cs_api' and p.proname in ('admin_banner_stats', 'admin_banner_settings',
                                                         'admin_set_banner_link_schemes', 'admin_save_banner'))
              or (n.nspname = 'public' and p.proname = 'record_banner_event')),
  'RPC banner SECURITY DEFINER dengan search_path kosong');
select ok(exists (select 1 from cron.job where jobname = 'app-banner-maintenance'), 'Retensi event banner terjadwal');

select tests.authenticate_agent(:'sinta');
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('app-banners', %L, %L)$$,
                       :'img', :'sinta'),
  'Super Admin mengunggah gambar banner');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('app-banners', 'promo/%s', %L)$$,
                        :'img', :'sinta'),
  '42501', null, 'Nama objek gambar banner harus <uuid>.<ext>');
reset role;
select tests.authenticate_agent(:'rina');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('app-banners', %L, %L)$$,
                        :'img2', :'rina'),
  '42501', null, 'CS biasa tidak bisa mengunggah gambar banner');
select throws_ok($$select cs_api.admin_banner_stats(gen_random_uuid())$$, 'PT403', 'role_forbidden',
  'CS biasa tidak bisa membuka statistik banner');
select throws_ok($$select cs_api.admin_banner_settings()$$, 'PT403', 'role_forbidden',
  'CS biasa tidak bisa membaca skema deep link');
reset role;
select tests.authenticate_with(:'baru', '{"media_verified": true}');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('app-banners', %L, %L)$$,
                        :'img2', :'baru'),
  '42501', null, 'Nasabah tidak bisa mengunggah ke bucket banner');
select is((select count(*)::integer from storage.objects where bucket_id = 'app-banners'), 0,
  'Nasabah tidak bisa melihat daftar objek bucket banner');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.admin_save_banner(null, 'Promo', p_display => 'modal')$$, 'PT400', 'invalid_display',
  'Tampilan hanya strip atau popup');
select throws_ok($$select cs_api.admin_save_banner(null, ' ', p_display => 'popup')$$, 'PT400', 'invalid_title',
  'Popup wajib judul');
select throws_ok($$select cs_api.admin_save_banner(null, 'Promo', p_display => 'popup', p_cta_label => 'Lihat')$$,
  'PT400', 'invalid_cta', 'Label tombol butuh tautan');
select throws_ok($$select cs_api.admin_save_banner(null, 'Promo', p_link_url => 'https://olt.example',
                                                   p_cta_label => repeat('x', 25))$$,
  'PT400', 'invalid_cta', 'Label tombol maksimal 24 karakter');
select throws_ok($$select cs_api.admin_save_banner(null, 'Promo', p_display => 'popup', p_frequency => 'hourly')$$,
  'PT400', 'invalid_frequency', 'Frekuensi harus dikenal');
select throws_ok($$select cs_api.admin_save_banner(null, 'Promo', p_display => 'popup', p_audience => 'vip')$$,
  'PT400', 'invalid_audience', 'Sasaran harus dikenal');
select throws_ok($$select cs_api.admin_save_banner(null, 'Promo', p_display => 'popup', p_audience => 'new_users',
                                                   p_audience_days => 91)$$,
  'PT400', 'invalid_audience', 'Pengguna baru maksimal 90 hari');
select throws_ok(format($$select cs_api.admin_save_banner(null, 'Promo', p_image_url => %L)$$, :'base' || :'img'),
  'PT400', 'invalid_image', 'Gambar hanya untuk popup');
select throws_ok(format($$select cs_api.admin_save_banner(null, 'Promo', p_display => 'popup', p_image_url => %L)$$,
                        :'base' || :'img2'),
  'PT400', 'invalid_image', 'Gambar yang belum diunggah ditolak');
select throws_ok(format($$select cs_api.admin_save_banner(null, 'Promo', p_display => 'popup', p_image_url => %L)$$,
                        'https://api.olt.example/storage/v1/object/public/avatars/' || :'img'),
  'PT400', 'invalid_image', 'Gambar dari bucket lain ditolak');

select lives_ok($$select cs_api.admin_save_banner(null, 'Deep link', p_link_url => 'olt://promo/akhir-tahun')$$,
  'Deep link dengan skema terdaftar diterima');
select throws_ok($$select cs_api.admin_save_banner(null, 'X', p_link_url => 'javascript://%0aalert(1)')$$,
  'PT400', 'invalid_link', 'javascript:// ditolak');
select throws_ok($$select cs_api.admin_save_banner(null, 'X', p_link_url => 'javascript:alert(1)')$$,
  'PT400', 'invalid_link', 'javascript: ditolak');
select throws_ok($$select cs_api.admin_save_banner(null, 'X', p_link_url => 'intent://scan/#Intent;scheme=zxing;end')$$,
  'PT400', 'invalid_link', 'intent:// ditolak');
select throws_ok($$select cs_api.admin_save_banner(null, 'X', p_link_url => 'mitra://order/BBCA')$$,
  'PT400', 'invalid_link', 'Skema yang belum terdaftar ditolak');
select throws_ok($$select cs_api.admin_save_banner(null, 'X', p_link_url => 'http://olt.example/promo')$$,
  'PT400', 'invalid_link', 'Tautan web baru wajib https');
select throws_ok($$select cs_api.admin_save_banner(null, 'X', p_link_url => 'olt://promo dengan spasi')$$,
  'PT400', 'invalid_link', 'Deep link tanpa spasi');

select is(cs_api.admin_banner_settings() -> 'deep_link_schemes', '["olt"]'::jsonb, 'Skema deep link bawaan olt');
select throws_ok($$select cs_api.admin_set_banner_link_schemes('{olt,https}')$$, 'PT400', 'invalid_link_schemes',
  'Skema https tidak boleh menjadi deep link');
select throws_ok($$select cs_api.admin_set_banner_link_schemes('{javascript}')$$, 'PT400', 'invalid_link_schemes',
  'Skema javascript ditolak');
select throws_ok($$select cs_api.admin_set_banner_link_schemes('{olt,a,b,c,d,e}')$$, 'PT400', 'invalid_link_schemes',
  'Maksimal 5 skema');
select throws_ok($$select cs_api.admin_set_banner_link_schemes('{"9olt"}')$$, 'PT400', 'invalid_link_schemes',
  'Skema harus diawali huruf');
select is(cs_api.admin_set_banner_link_schemes('{" OLT ",mitra}') -> 'deep_link_schemes', '["mitra", "olt"]'::jsonb,
  'Super Admin menambah skema deep link');
select lives_ok($$select cs_api.admin_save_banner(null, 'Mitra', p_link_url => 'mitra://order/BBCA')$$,
  'Skema yang baru didaftarkan diterima');

select cs_api.admin_save_banner(null, 'Promo akhir tahun', 'Diskon biaya transaksi 50%', 'olt://promo/akhir-tahun', 'info',
  now() - interval '1 hour', now() + interval '7 days', '{}', null, null, true, 50,
  'popup', :'base' || :'img', 'Lihat promo', 'daily', 'new_users', 7) as popup \gset
select is(:'popup'::jsonb - array['id', 'starts_at', 'ends_at', 'created_by', 'updated_by', 'created_at', 'updated_at'],
  jsonb_build_object('title', 'Promo akhir tahun', 'body', 'Diskon biaya transaksi 50%',
                     'link_url', 'olt://promo/akhir-tahun', 'level', 'info', 'display', 'popup',
                     'image_path', :'img', 'image_url', :'base' || :'img', 'cta_label', 'Lihat promo',
                     'frequency', 'daily', 'audience', 'new_users', 'audience_days', 7, 'platforms', '[]'::jsonb,
                     'min_app_version', null, 'max_app_version', null, 'dismissible', true, 'priority', 50,
                     'status', 'active',
                     'stats', '{"impressions": 0, "clicks": 0, "dismissals": 0, "unique_viewers": 0, "ctr": null}'::jsonb),
  'Popup tersimpan lengkap dengan statistik kosong');
select cs_api.admin_save_banner(null, 'Strip info', p_frequency => 'every_open', p_audience => 'all',
                                p_audience_days => 30, p_priority => 5) as strip \gset
select is(:'strip'::jsonb ->> 'frequency', 'once', 'Frekuensi strip selalu once');
select is((:'strip'::jsonb ->> 'audience_days')::integer, 7, 'Hari sasaran diabaikan untuk semua pengguna');
select cs_api.admin_save_banner(null, 'Belum mulai', p_display => 'popup', p_starts_at => now() + interval '1 day') as later \gset
reset role;

select throws_ok($$insert into private.app_banners (title, link_url) values ('x', 'javascript://alert(1)')$$, '23514', null,
  'Constraint tabel menolak skema berbahaya walau lewat SQL langsung');
select throws_ok(format($$insert into private.app_banners (title, display, image_path, image_url) values ('x', 'strip', %L, %L)$$,
                        :'img', :'base' || :'img'),
  '23514', null, 'Constraint tabel: gambar hanya untuk popup');

select tests.authenticate_as(:'baru');
select public.get_client_config('android', '2.5.0') as cfg_baru \gset
reset role;
select is(:'cfg_baru'::jsonb #> '{banners,0}',
  jsonb_build_object('id', :'popup'::jsonb -> 'id', 'title', 'Promo akhir tahun', 'body', 'Diskon biaya transaksi 50%',
                     'link_url', 'olt://promo/akhir-tahun', 'level', 'info', 'dismissible', true, 'priority', 50,
                     'starts_at', :'popup'::jsonb -> 'starts_at', 'ends_at', :'popup'::jsonb -> 'ends_at',
                     'display', 'popup', 'image_url', :'base' || :'img', 'cta_label', 'Lihat promo',
                     'frequency', 'daily'),
  'Bentuk popup untuk klien');
select is((select jsonb_agg(b ->> 'title' order by b ->> 'title') from jsonb_array_elements(:'cfg_baru'::jsonb -> 'banners') b),
  '["Deep link", "Mitra", "Promo akhir tahun", "Strip info"]'::jsonb, 'Pengguna baru melihat popup pengguna baru');
select is((:'cfg_baru'::jsonb #>> '{banners,3,display}'), 'strip', 'Banner lama tetap strip');

select tests.authenticate_as(:'lama');
select is((select jsonb_agg(b ->> 'title' order by b ->> 'title') from jsonb_array_elements(public.get_client_config('android') -> 'banners') b),
  '["Deep link", "Mitra", "Strip info"]'::jsonb, 'Pengguna lama tidak melihat popup pengguna baru');
reset role;
select tests.authenticate_anon();
select is((select count(*)::integer from jsonb_array_elements(public.get_client_config('web') -> 'banners') b
           where b ->> 'display' = 'popup'), 0, 'Tanpa login hanya sasaran semua pengguna');
reset role;

select tests.authenticate_agent(:'sinta');
select lives_ok($$select cs_api.admin_set_banner_link_schemes('{olt}')$$, 'Skema mitra dicabut');
reset role;
select tests.authenticate_as(:'lama');
select is((select b ->> 'link_url' from jsonb_array_elements(public.get_client_config() -> 'banners') b where b ->> 'title' = 'Mitra'),
  null, 'Deep link dengan skema yang dicabut tidak dikirim ke klien');

select is(public.record_banner_event((:'popup'::jsonb ->> 'id')::uuid, 'impression'), '{"recorded": false}'::jsonb,
  'Banner di luar sasaran tetap dijawab aman');
reset role;

select tests.authenticate_as(:'baru');
select is(public.record_banner_event((:'popup'::jsonb ->> 'id')::uuid, 'impression'), '{"recorded": true}'::jsonb,
  'Tayangan tercatat');
select is(public.record_banner_event((:'popup'::jsonb ->> 'id')::uuid, 'impression'), '{"recorded": false}'::jsonb,
  'Tayangan berulang di hari yang sama tidak dihitung dua kali dan tidak error');
select is(public.record_banner_event((:'popup'::jsonb ->> 'id')::uuid, 'click'), '{"recorded": true}'::jsonb, 'Klik tercatat');
select is(public.record_banner_event(gen_random_uuid(), 'click'), '{"recorded": false}'::jsonb,
  'Banner yang tidak ada diabaikan tanpa error');
select is(public.record_banner_event((:'later'::jsonb ->> 'id')::uuid, 'impression'), '{"recorded": false}'::jsonb,
  'Banner yang belum aktif diabaikan');
select throws_ok(format($$select public.record_banner_event(%L, 'share')$$, :'popup'::jsonb ->> 'id'), 'PT400', 'invalid_event',
  'Event harus impression, click, atau dismiss');
reset role;
select tests.authenticate_as(:'citra');
select lives_ok(format($$select public.record_banner_event(%L, 'impression')$$, :'popup'::jsonb ->> 'id'),
  'Pengguna kedua mencatat tayangan');
select lives_ok(format($$select public.record_banner_event(%L, 'dismiss')$$, :'popup'::jsonb ->> 'id'),
  'Penutupan tercatat');
reset role;
update private.rate_limits set max_count = 2 where action = 'banner_event';
select tests.authenticate_as(:'citra');
select throws_like(format($$select public.record_banner_event(%L, 'dismiss')$$, :'popup'::jsonb ->> 'id'),
  '%"PT429"%"rate_limited"%', 'Event banner dibatasi rate limit');
reset role;
update private.rate_limits set max_count = 1000 where action = 'banner_event';

select tests.authenticate_agent(:'sinta');
select throws_ok(format($$select public.record_banner_event(%L, 'impression')$$, :'popup'::jsonb ->> 'id'), 'PT403',
  'customer_required', 'Akun CS tidak mencatat tayangan');
select is((select b -> 'stats' from jsonb_array_elements(cs_api.admin_banners()) b where b ->> 'id' = :'popup'::jsonb ->> 'id'),
  '{"impressions": 2, "clicks": 1, "dismissals": 1, "unique_viewers": 2, "ctr": 50.0}'::jsonb,
  'Daftar banner memuat ringkasan statistik');
select cs_api.admin_banner_stats((:'popup'::jsonb ->> 'id')::uuid) as stats \gset
select is(jsonb_array_length(:'stats'::jsonb -> 'days'), 7, 'Statistik 7 hari terakhir');
select is(:'stats'::jsonb #> '{days,6}',
  jsonb_build_object('day', (now() at time zone 'Asia/Jakarta')::date, 'impressions', 2, 'clicks', 1, 'dismissals', 1, 'ctr', 50.0),
  'Hari ini (WIB) di urutan terakhir');
select is((:'stats'::jsonb #>> '{days,0,impressions}')::integer, 0, 'Hari tanpa event bernilai nol');
select throws_ok($$select cs_api.admin_banner_stats(gen_random_uuid())$$, 'PT404', 'banner_not_found',
  'Statistik banner yang tidak ada');

select cs_api.admin_save_banner((:'popup'::jsonb ->> 'id')::uuid, 'Promo akhir tahun', p_display => 'popup') as edited \gset
reset role;
select is(:'edited'::jsonb ->> 'image_url', null, 'Gambar bisa dilepas dari popup');
select ok(exists (select 1 from private.storage_cleanup_queue where bucket_id = 'app-banners' and prefix = :'img' || '/' and done_at is null),
  'Gambar lama masuk antrean pembersihan');
select is((select count(*)::integer from cs.cs_audit_log where action = 'banner.link_schemes'
           and details -> 'after' = '["mitra", "olt"]'::jsonb), 1, 'Perubahan skema deep link tercatat di audit');
select is((select details #>> '{before,image_path}' from cs.cs_audit_log
           where action = 'banner.save' and details ->> 'id' = :'popup'::jsonb ->> 'id' and details -> 'before' <> 'null'::jsonb),
  :'img', 'Audit menyimpan isi popup sebelum diubah');

insert into private.app_banner_events (banner_id, user_id, event, day, created_at)
values ((:'popup'::jsonb ->> 'id')::uuid, :'lama', 'impression', current_date - 200, now() - interval '200 days');
select is(private.app_banner_maintenance(), 1, 'Event lebih dari 180 hari dihapus');

select * from finish();
rollback;
