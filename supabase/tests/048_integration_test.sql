begin;
select plan(81);

select tests.create_user('ig_budi') as budi \gset
select tests.create_user('ig_sari') as sari \gset
select tests.create_user('ig_joko') as joko \gset
select tests.create_agent('Sinta Integrasi', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Integrasi', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_agent('Maya Integrasi', '{community}', '{}') as maya \gset
update cs.agents set community_permissions = '{community.post,community.publish,community.accounts}'
 where user_id = :'maya';

select tests.authenticate_agent(:'maya');
select cs_api.community_save_account(null, 'ig_berita', 'Berita Pasar', 'Bot berita') ->> 'id' as official \gset
reset role;

select has_function('private', 'push_allowed', array['uuid', 'text'],
  'Fungsi preferensi push tersedia (stub true atau versi agen F)');
select ok(exists (select 1 from pg_trigger where tgname = 'profiles_70_account_links_forget'),
  'Trigger penghapusan tautan rekening terpasang di profiles');

select tests.authenticate_service();
select is(public.set_olt_account_links(:'budi', '["w137", "C1626", "bad id!", 5, "W137", ""]'),
  '{"linked": 2, "ignored": 4}'::jsonb, 'Klaim accounts disaring: format salah, bukan string, dan duplikat diabaikan');
reset role;
select is((select array_agg(cust_id order by cust_id) from private.account_links where profile_id = :'budi'),
  array['C1626', 'W137'], 'Cust id disimpan dengan huruf besar');

select tests.authenticate_service();
select is(public.set_olt_account_links(:'budi', '["C1626", "X9"]') ->> 'linked', '2',
  'Set rekening diganti seluruhnya pada login berikutnya');
reset role;
select is((select array_agg(cust_id order by cust_id) from private.account_links where profile_id = :'budi'),
  array['C1626', 'X9'], 'Rekening yang tidak ada lagi di klaim dilepas');

select tests.authenticate_service();
select is(public.set_olt_account_links(:'budi', '[]') ->> 'linked', '0', 'Klaim kosong melepas semua rekening');
select throws_ok(format($$select public.set_olt_account_links(%L, '{"a": 1}')$$, :'budi'), 'PT400', 'invalid_accounts',
  'Klaim yang bukan array ditolak');
select throws_ok($$select public.set_olt_account_links(gen_random_uuid(), '["W137"]')$$, 'PT404', 'profile_not_found',
  'Profil yang tidak ada ditolak');
select is(public.set_olt_account_links(:'joko', (select jsonb_agg('A' || g) from generate_series(1, 210) g)),
  '{"linked": 200, "ignored": 10}'::jsonb, 'Maksimal 200 rekening per profil secara bawaan');
reset role;

select tests.authenticate_as(:'budi');
select throws_ok(format($$select public.set_olt_account_links(%L, '["W137"]')$$, :'budi'), '42501', null,
  'Pengguna tidak bisa menautkan rekening sendiri');
select throws_ok('select count(*) from private.account_links', '42501', null,
  'Pengguna tidak bisa membaca tabel tautan rekening');
select throws_ok($$select public.integration_authenticate(repeat('a', 64), null)$$, '42501', null,
  'Pengguna tidak bisa memeriksa API key integrasi');
reset role;
select tests.authenticate_anon();
select throws_ok($$select public.integration_notify(gen_random_uuid(), '[]', null)$$, '42501', null,
  'Anon tidak bisa memanggil RPC notifikasi integrasi');
reset role;

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.integration_key_create('OLT notifEngine', '{notify}')$$, 'PT403', 'role_forbidden',
  'Hanya Super Admin yang bisa membuat API key integrasi');
select throws_ok('select cs_api.integration_keys()', 'PT403', 'role_forbidden',
  'Hanya Super Admin yang bisa melihat API key integrasi');
reset role;

select tests.authenticate_agent(:'sinta');
select cs_api.integration_key_create('OLT notifEngine', '{notify}') as created \gset
select ok((:'created'::jsonb ->> 'key') ~ '^oik_[A-Za-z0-9_-]{43}$', 'Key baru ditampilkan sekali dengan awalan oik_');
select is(:'created'::jsonb ->> 'status', 'active', 'Key baru langsung aktif');
select is(:'created'::jsonb ->> 'prefix', substr(:'created'::jsonb ->> 'key', 5, 8),
  'Prefix 8 karakter untuk mengenali key');
select throws_ok($$select cs_api.integration_key_create('OL', '{notify}')$$, 'PT400', 'invalid_name',
  'Nama key minimal 3 karakter');
select throws_ok($$select cs_api.integration_key_create('Bot salah', '{admin}')$$, 'PT400', 'invalid_scopes',
  'Izin di luar notify/bot_post ditolak');
select throws_ok($$select cs_api.integration_key_create('Bot berita', '{bot_post}')$$, 'PT400', 'official_required',
  'Izin bot_post wajib terikat akun resmi');
select throws_ok($$select cs_api.integration_key_create('OLT LAN', '{notify}', null, '{10.0.0.0/8,bukan-ip}')$$,
  'PT400', 'invalid_cidr', 'CIDR yang tidak valid ditolak');
select cs_api.integration_key_create('Bot berita', '{bot_post}', :'official', '{}', 120) as bot \gset
select is(:'bot'::jsonb -> 'official_account' ->> 'username', 'ig_berita', 'Key bot terikat akun resmi');
select ok(not (cs_api.integration_keys()::text like '%' || (:'created'::jsonb ->> 'key') || '%')
          and not (cs_api.integration_keys()::text like '%key_hash%'),
  'Daftar key tidak memuat key maupun hash-nya');
reset role;

select is((select key_hash from private.integration_keys where id = (:'created'::jsonb ->> 'id')::uuid),
  encode(sha256(convert_to(:'created'::jsonb ->> 'key', 'UTF8')), 'hex'), 'Yang disimpan hanya hash SHA-256 key');
select ok(not exists (select 1 from cs.cs_audit_log where action like 'integration.%'
                      and details::text like '%' || (:'created'::jsonb ->> 'key') || '%'),
  'Audit tidak memuat key');
select is((select count(*)::integer from cs.cs_audit_log where action = 'integration.key_create'
           and details ->> 'key_id' = :'created'::jsonb ->> 'id'), 1, 'Pembuatan key tercatat di audit');

select (:'created'::jsonb ->> 'id') as notify_key, encode(sha256(convert_to(:'created'::jsonb ->> 'key', 'UTF8')), 'hex') as notify_hash \gset
select (:'bot'::jsonb ->> 'id') as bot_key \gset

select tests.authenticate_service();
select is(public.integration_authenticate(:'notify_hash', '203.0.113.9') ->> 'id', :'notify_key',
  'Hash key dikenali layanan integrasi');
select is(public.integration_authenticate(:'notify_hash', null) -> 'scopes', '["notify"]'::jsonb,
  'Izin key dikembalikan ke layanan');
select is(public.integration_authenticate(repeat('0', 64), null), null, 'Hash yang tidak dikenal tidak dikenali');
select is(public.integration_authenticate('bukan-hash', null), null, 'Format hash yang salah tidak dikenali');
select is(public.set_olt_account_links(:'budi', '["W137", "C1626"]') ->> 'linked', '2', 'Budi menautkan dua rekening');
select is(public.set_olt_account_links(:'sari', '["S2001"]') ->> 'linked', '1', 'Sari menautkan satu rekening');
reset role;

select tests.authenticate_as(:'budi');
select is(public.register_push_device('fcm-token-ig-budi-00000001', 'android', 'en') ->> 'locale', 'en',
  'Budi mendaftarkan perangkat push');
reset role;

select tests.authenticate_service();
select public.integration_notify(:'notify_key', jsonb_build_array(
  jsonb_build_object('id', 'trade-1', 'cust_id', 'w137', 'kind', 'olt.trade',
                     'title', jsonb_build_object('id', 'Order BBCA match', 'en', 'BBCA order matched'),
                     'body', 'Beli 10 lot BBCA @ 9.250', 'data', jsonb_build_object('order_id', 'O-77', 'lot', 10),
                     'ttl_seconds', 3600, 'collapse_key', 'order-O-77', 'priority', 'high'),
  jsonb_build_object('id', 'trade-2', 'cust_id', 'S2001', 'title', 'Order match'),
  jsonb_build_object('id', 'trade-3', 'cust_id', 'Z404', 'title', 'Order match'),
  jsonb_build_object('id', 'trade-4', 'cust_id', 'W137', 'kind', 'trade', 'title', 'x'),
  jsonb_build_object('id', 'trade-5', 'cust_id', 'W137'),
  jsonb_build_object('id', 'trade-6', 'cust_id', 'W137', 'title', 'x', 'data', jsonb_build_object('blob', repeat('x', 2100))),
  jsonb_build_object('cust_id', 'W137', 'title', 'x'),
  jsonb_build_object('id', 'trade-1', 'cust_id', 'W137', 'title', 'Kirim ulang'),
  '"bukan objek"'::jsonb), '198.51.100.7') as notified \gset
reset role;

select is((select jsonb_agg(r ->> 'status' order by (r ->> 'index')::integer) from jsonb_array_elements(:'notified'::jsonb -> 'results') r),
  '["queued", "no_recipient", "no_recipient", "invalid", "invalid", "invalid", "invalid", "duplicate", "invalid"]'::jsonb,
  'Setiap pesan mendapat hasilnya sendiri');
select is((select jsonb_agg(r ->> 'error' order by (r ->> 'index')::integer) from jsonb_array_elements(:'notified'::jsonb -> 'results') r
           where r ->> 'status' = 'invalid'),
  '["invalid_kind", "invalid_title", "invalid_data", "invalid_id", "invalid_message"]'::jsonb,
  'Pesan yang salah format menjelaskan bagian yang salah');
select is((:'notified'::jsonb -> 'results' -> 0 ->> 'devices')::integer, 1, 'Jumlah perangkat yang diantrekan dilaporkan');
select is((select title || ' | ' || body from private.push_queue where user_id = :'budi' and kind = 'olt.trade'),
  'BBCA order matched | Beli 10 lot BBCA @ 9.250', 'Push memakai judul sesuai bahasa perangkat');
select is((select data from private.push_queue where user_id = :'budi' and kind = 'olt.trade'),
  '{"kind": "olt.trade", "lot": "10", "source": "olt", "cust_id": "W137", "order_id": "O-77", "message_id": "trade-1"}'::jsonb,
  'Data push membawa rekening, id pesan, dan data dari OLT');
select is((select collapse_key || '/' || priority || '/' || ref from private.push_queue where user_id = :'budi' and kind = 'olt.trade'),
  'order-O-77/high/' || private.integration_ref(:'notify_key', private.integration_day()),
  'Opsi push dan ref statistik per key diterapkan');
select ok((select expires_at between now() + interval '59 minutes' and now() + interval '61 minutes'
           from private.push_queue where user_id = :'budi' and kind = 'olt.trade'), 'ttl_seconds dihormati');
select is((select count(*)::integer from public.notifications where user_id = :'budi'), 0,
  'Notifikasi OLT hanya push, tidak masuk kotak notifikasi');
select is((select last_used_ip from private.integration_keys where id = :'notify_key'), '198.51.100.7'::inet,
  'IP pemakai terakhir tercatat');

select tests.authenticate_service();
select is(public.integration_notify(:'notify_key', '[{"id": "trade-1", "cust_id": "W137", "title": "Order"}]', null)
          -> 'results' -> 0 ->> 'status', 'duplicate', 'Id pesan yang sama tidak dikirim dua kali');
reset role;
select is((select count(*)::integer from private.push_queue where user_id = :'budi'), 1,
  'Kiriman ulang tidak menambah antrean push');

update private.account_links set seen_at = now() - interval '31 days' where profile_id = :'budi' and cust_id = 'C1626';
select tests.authenticate_service();
select is(public.integration_notify(:'notify_key', '[{"id": "trade-7", "cust_id": "C1626", "title": "Order"}]', null)
          -> 'results' -> 0 ->> 'status', 'no_recipient', 'Tautan yang kedaluwarsa tidak menerima push');
reset role;

create or replace function private.push_allowed(p_profile uuid, p_kind text) returns boolean language sql stable
  set search_path = '' as $$ select p_kind <> 'olt.muted' $$;
select tests.authenticate_service();
select is(public.integration_notify(:'notify_key', '[{"id": "trade-8", "cust_id": "W137", "kind": "olt.muted", "title": "Order"}]', null)
          -> 'results' -> 0 ->> 'status', 'no_recipient', 'Preferensi push pengguna (push_allowed) dihormati');
select is(public.integration_notify(:'notify_key', '[{"id": "trade-9", "cust_id": "W137", "kind": "olt.trade.partial", "title": "Order"}]', null)
          -> 'results' -> 0 ->> 'status', 'queued', 'Jenis olt.* lain tetap dikirim');
select throws_ok(format($$select public.integration_notify(%L, (select jsonb_agg(jsonb_build_object('id', 'm' || g)) from generate_series(1, 501) g), null)$$, :'notify_key'),
  'PT400', 'invalid_batch', 'Batch lebih dari 500 pesan ditolak');
select throws_ok(format($$select public.integration_notify(%L, '[{"id": "x"}]', null)$$, :'bot_key'),
  'PT403', 'scope_forbidden', 'Key tanpa izin notify tidak bisa mengirim notifikasi');
reset role;

select tests.authenticate_agent(:'sinta');
select cs_api.integration_key_update(:'notify_key', 'OLT notifEngine', '{notify}', null, '{10.20.0.0/16, 10.30.1.5}', 900, true) as updated \gset
select is(:'updated'::jsonb -> 'allowed_cidrs', '["10.20.0.0/16", "10.30.1.5/32"]'::jsonb, 'Daftar IP pengirim disimpan sebagai CIDR');
reset role;
select tests.authenticate_service();
select is(public.integration_authenticate(:'notify_hash', '10.20.4.5') ->> 'ip_allowed', 'true', 'IP di dalam CIDR diizinkan');
select is(public.integration_authenticate(:'notify_hash', '192.168.1.1') ->> 'ip_allowed', 'false', 'IP di luar CIDR ditandai');
select throws_ok(format($$select public.integration_notify(%L, '[{"id": "trade-10", "cust_id": "W137", "title": "x"}]', '192.168.1.1')$$, :'notify_key'),
  'PT403', 'ip_not_allowed', 'RPC juga menolak IP di luar CIDR');
reset role;

select tests.authenticate_agent(:'sinta');
select is(cs_api.integration_key_update(:'notify_key', 'OLT notifEngine', '{notify}', null, '{}', 900, false) ->> 'status',
  'disabled', 'Key bisa dinonaktifkan sementara');
reset role;
select tests.authenticate_service();
select is(public.integration_authenticate(:'notify_hash', null), null, 'Key nonaktif tidak dikenali');
select throws_ok(format($$select public.integration_notify(%L, '[{"id": "trade-11", "cust_id": "W137", "title": "x"}]', null)$$, :'notify_key'),
  'PT401', 'invalid_key', 'Key nonaktif langsung ditolak walau masih ada di cache layanan');
reset role;
select tests.authenticate_agent(:'sinta');
select is(cs_api.integration_key_update(:'notify_key', 'OLT notifEngine', '{notify}', null, '{}', 900, true) ->> 'status',
  'active', 'Key bisa diaktifkan lagi');
select is((select (k ->> 'received')::integer from jsonb_array_elements(cs_api.integration_stats(7) -> 'keys') k
           where k ->> 'id' = :'notify_key'), 13, 'Statistik menghitung pesan yang diterima');
select is((select jsonb_build_object('queued', k ->> 'queued', 'no_recipient', k ->> 'no_recipient', 'duplicate', k ->> 'duplicate',
                                     'invalid', k ->> 'invalid', 'devices', k ->> 'devices')
           from jsonb_array_elements(cs_api.integration_stats(7) -> 'keys') k where k ->> 'id' = :'notify_key'),
  '{"queued": "2", "no_recipient": "4", "duplicate": "2", "invalid": "5", "devices": "2"}'::jsonb,
  'Statistik per key: terkirim, tanpa penerima, duplikat, tidak valid');
select is((cs_api.integration_stats(7) -> 'linked' ->> 'accounts')::integer >= 2, true, 'Statistik memuat jumlah rekening tertaut');
reset role;

select tests.authenticate_service();
select public.integration_bot_post(:'bot_key', jsonb_build_array(
  jsonb_build_object('id', 'news-1', 'body', 'Aksi korporasi $BBCA: dividen tunai Rp 270 per saham'),
  jsonb_build_object('id', 'news-2', 'body', ''),
  jsonb_build_object('id', 'news-1', 'body', 'Duplikat'),
  jsonb_build_object('id', 'news 3', 'body', 'Id salah')), '203.0.113.20') as posted \gset
reset role;
select is((select jsonb_agg(r ->> 'status' order by (r ->> 'index')::integer) from jsonb_array_elements(:'posted'::jsonb -> 'results') r),
  '["published", "invalid", "duplicate", "invalid"]'::jsonb, 'Setiap postingan bot mendapat hasilnya sendiri');
select (:'posted'::jsonb -> 'results' -> 0 ->> 'post_id') as bot_post \gset
select is((select author_id from public.posts where id = :'bot_post'), :'official'::uuid,
  'Postingan bot terbit atas nama akun resmi');
select ok(private.post_is_bot(:'bot_post'), 'Postingan ditandai sebagai bot');
select is((select status || '/' || kind from cs.community_posts c
           join private.integration_posts b on b.community_post_id = c.id where b.post_id = :'bot_post'),
  'published/post', 'Postingan bot memakai mekanisme postingan resmi');
select is(:'posted'::jsonb -> 'results' -> 2 ->> 'post_id', :'bot_post', 'Duplikat mengembalikan postingan yang sama');

insert into public.banned_words (word, action) values ('igjudionline', 'block') on conflict (word) do update set action = 'block';
select tests.authenticate_service();
select is(public.integration_bot_post(:'bot_key', '[{"id": "news-4", "body": "Ayo main igjudionline sekarang"}]', null)
          -> 'results' -> 0 ->> 'error', 'content_blocked', 'Postingan bot tetap melewati kebijakan konten');
reset role;
select is((select count(*)::integer from private.integration_posts where key_id = :'bot_key'), 1,
  'Postingan yang ditolak tidak tercatat, jadi bisa dikirim ulang setelah diperbaiki');

update private.settings set value = '1' where key = 'integration.bot_posts_per_hour';
select tests.authenticate_service();
select is(public.integration_bot_post(:'bot_key', '[{"id": "news-5", "body": "Berita kedua"}]', null)
          -> 'results' -> 0 ->> 'status', 'rate_limited', 'Batas postingan bot per jam ditegakkan');
select throws_ok(format($$select public.integration_bot_post(%L, '[{"id": "news-6", "body": "x"}]', null)$$, :'notify_key'),
  'PT403', 'scope_forbidden', 'Key tanpa izin bot_post tidak bisa memposting');
reset role;

update cs.official_accounts set disabled_at = now() where profile_id = :'official';
select tests.authenticate_service();
select throws_ok(format($$select public.integration_bot_post(%L, '[{"id": "news-7", "body": "x"}]', null)$$, :'bot_key'),
  'PT409', 'official_inactive', 'Bot berhenti bila akun resminya dinonaktifkan');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok(format($$select cs_api.integration_key_revoke(%L, 'x')$$, :'notify_key'), 'PT400', 'reason_required',
  'Pencabutan wajib beralasan');
select is(cs_api.integration_key_revoke(:'notify_key', 'Rotasi key bulanan') ->> 'status', 'revoked', 'Key bisa dicabut');
select throws_ok(format($$select cs_api.integration_key_update(%L, 'OLT notifEngine', '{notify}', null, '{}', 900, true)$$, :'notify_key'),
  'PT409', 'key_revoked', 'Key yang dicabut tidak bisa diaktifkan lagi');
reset role;
select tests.authenticate_service();
select is(public.integration_authenticate(:'notify_hash', null), null, 'Key yang dicabut tidak dikenali');
reset role;
select is((select count(*)::integer from cs.cs_audit_log where action in ('integration.key_update', 'integration.key_revoke')
           and details ->> 'key_id' = :'notify_key'), 4, 'Perubahan dan pencabutan key tercatat di audit');

select is(private.account_links_export(:'sari') -> 0 ->> 'cust_id', 'S2001', 'Ekspor data memuat rekening tertaut');
update public.profiles set deleted_at = now() where id = :'budi';
select is((select count(*)::integer from private.account_links where profile_id = :'budi'), 0,
  'Tautan rekening ikut dihapus saat akun dihapus');

update private.integration_receipts set created_at = now() - interval '8 days' where message_id = 'trade-2';
select ok((private.integration_maintenance() ->> 'receipts')::integer >= 1, 'Id pesan lama dibersihkan setelah 7 hari');
select is((select count(*)::integer from private.integration_receipts where message_id = 'trade-2'), 0,
  'Id pesan yang lewat masa simpan bisa dipakai lagi');

select * from finish();
rollback;
