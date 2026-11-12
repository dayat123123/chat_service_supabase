begin;
select plan(40);

update private.rate_limits set max_count = 1000 where action in ('post', 'comment', 'stock_room_create');

select tests.create_user('mi_ani') as ani \gset
select tests.create_user('mi_budi') as budi \gset
select tests.create_agent('mi_mod', '{community}', '{}') as moder \gset
select tests.create_agent('mi_poster', '{community}', '{}') as poster \gset
update cs.agents set community_permissions = '{community.moderate}' where user_id = :'moder';
update cs.agents set community_permissions = '{community.post}' where user_id = :'poster';

select is(private.extract_cashtags('Lihat $BBCA-nya naik'), array['BBCA'],
  'Kode saham diikuti akhiran -nya tetap terbaca sebagai kode saham');
select is(private.extract_cashtags('$SRI-KEHATI dan $sri-kehati-nya'), array['SRI-KEHATI'],
  'Indeks berstrip yang terdaftar terbaca utuh, termasuk dengan akhiran');
select is(private.extract_cashtags('$composite, $JCI, dan $IHSG'), array['COMPOSITE'],
  'Alias diarahkan ke kode utama tanpa duplikat');
select is(private.extract_cashtags('$ABC-DEF $A $ABCDEFGHIJKLMNOPQRSTU'), array['ABC'],
  'Kode berstrip yang tidak terdaftar jatuh ke bagian sebelum strip');
select is(private.extract_cashtags('$LQ45 $BBRI $IDXSMC-LIQ'), array['LQ45', 'BBRI', 'IDXSMC-LIQ'],
  'Urutan kemunculan dipertahankan');
select is(private.stock_code('$idxsmcliq'), 'IDXSMC-LIQ', 'stock_code menormalkan alias');
select is(private.stock_code('NGASAL-KODE'), null, 'Kode berstrip asing tidak valid');

insert into public.posts (id, author_id, body, created_at) values
  ('a2900000-0000-4000-8000-000000000001', :'budi', 'SRI-KEHATI rebound $SRI-KEHATI', now() - interval '3 minutes'),
  ('a2900000-0000-4000-8000-000000000002', :'budi', 'Pakai alias $SRIKEHATI', now() - interval '2 minutes'),
  ('a2900000-0000-4000-8000-000000000003', :'budi', 'Lama: $MIXTEST naik', now() - interval '1 minute');

select tests.authenticate_as(:'ani');
select results_eq(
  $$select id from public.get_feed('stock', 'sri-kehati', null, 10)$$,
  $$values ('a2900000-0000-4000-8000-000000000002'::uuid), ('a2900000-0000-4000-8000-000000000001'::uuid)$$,
  'Feed indeks berstrip memuat post dengan kode maupun aliasnya');
select results_eq(
  $$select id from public.get_feed('stock', '$SRIKEHATI', null, 10)$$,
  $$select id from public.get_feed('stock', 'SRI-KEHATI', null, 10)$$,
  'Feed lewat alias sama dengan feed kode utama');
select is((select stock_codes from public.get_feed('stock', 'SRI-KEHATI', null, 1)), array['SRI-KEHATI'],
  'Post menampilkan kode utama');

insert into public.stock_watchers (user_id, stock_code) values (:'ani', 'ihsg');
select is((select stock_code from public.stock_watchers where user_id = :'ani'), 'COMPOSITE',
  'Memantau lewat alias disimpan sebagai kode utama');
select throws_ok(format($$insert into public.stock_watchers (user_id, stock_code) values (%L, 'NGASAL-KODE')$$, :'ani'),
  '23514', 'invalid_stock_code', 'Kode berstrip yang tidak terdaftar ditolak saat memantau');
insert into public.muted_stocks (user_id, stock_code) values (:'ani', 'BISNIS27');
select is((select stock_code from public.muted_stocks where user_id = :'ani'), 'BISNIS-27',
  'Membisukan lewat alias disimpan sebagai kode utama');

select public.join_stock_room('srikehati') as sk_room \gset
select is((select stock_code from public.chat_rooms where id = :'sk_room'), 'SRI-KEHATI',
  'Room indeks dibuat dengan kode utama');
select is(public.get_stock_room_state('SRI-KEHATI') ->> 'room_enabled', 'true', 'State room memuat room_enabled');
select is((select code from public.get_stock('$jci')), 'COMPOSITE', 'get_stock menerima alias');
select is((select code from public.get_stock_stats(array['ihsg', 'bukan-kode'])), 'COMPOSITE',
  'Statistik menerima alias dan mengabaikan kode asing');
select is(public.get_stock_sentiment('SRIKEHATI') ->> 'code', 'SRI-KEHATI', 'Sentimen memakai kode utama');
select ok(exists (select 1 from public.get_market_instruments() where code = 'COMPOSITE' and aliases = array['IHSG', 'JCI']),
  'Daftar instrumen memuat alias');
select throws_ok($$select * from private.market_instruments$$, '42501', null, 'Tabel instrumen tidak bisa dibaca langsung');
reset role;

select is((private.search_stocks(:'ani', 'kompas', 0, 10) -> 'items' -> 0 ->> 'code'), 'KOMPAS100',
  'Pencarian menemukan indeks lewat nama');
select is((private.search_stocks(:'ani', 'SRI-K', 0, 10) -> 'items' -> 0 ->> 'kind'), 'index',
  'Pencarian menandai jenis indeks');
select is(private.validate_stock_cards('[{"code": "sri-kehati"}, {"code": "SRIKEHATI"}]', null),
  '[{"code": "SRI-KEHATI", "type": "stock"}]'::jsonb, 'Kartu chat menerima indeks dan menggabungkan alias');

select tests.authenticate_anon();
select throws_ok($$select * from public.get_market_instruments()$$, '42501', null, 'Anon tidak bisa membaca instrumen');
reset role;

select tests.authenticate_agent(:'poster');
select throws_ok($$select cs_api.community_instruments()$$, 'PT403', 'community_forbidden',
  'Staf tanpa izin moderasi tidak bisa mengelola indeks');
reset role;

insert into public.stock_watchers (user_id, stock_code) values (:'budi', 'MIXTEST');
select tests.authenticate_agent(:'moder');
select ok(jsonb_array_length(cs_api.community_instruments()) >= 30, 'Indeks bawaan tersedia');
select is((select e ->> 'posts' from jsonb_array_elements(cs_api.community_instrument_check('MIX-TEST', array['MIXTEST'])) e
           where e ->> 'role' = 'alias'), '1', 'Cek bentrok menghitung post yang memakai kode');
select is((select e ->> 'stock_format' from jsonb_array_elements(cs_api.community_instrument_check('MIX-TEST', array['MIXTEST'])) e
           where e ->> 'role' = 'alias'), 'true', 'Cek bentrok menandai kode berformat saham');
select is((select e ->> 'alias_of' from jsonb_array_elements(cs_api.community_instrument_check('IHSG')) e), 'COMPOSITE',
  'Cek bentrok menandai kode yang sudah jadi alias');
select is(cs_api.community_save_instrument('mix-test', 'Indeks Uji', array['mixtest', 'MIX-TEST']) -> 'aliases',
  '["MIXTEST"]'::jsonb, 'Indeks baru tersimpan dengan alias tanpa kode utama');
select throws_ok($$select cs_api.community_save_instrument('UJI2', 'Uji', array['LQ45'])$$,
  'PT409', 'instrument_alias_taken', 'Alias tidak boleh kode instrumen lain');
select throws_ok($$select cs_api.community_save_instrument('JCI', 'Uji')$$,
  'PT409', 'instrument_code_taken', 'Kode tidak boleh alias instrumen lain');
select throws_ok($$select cs_api.community_save_instrument('-AB', 'Uji')$$,
  'PT400', 'invalid_instrument_code', 'Format kode divalidasi');
select is(cs_api.community_save_instrument('MIX-TEST', 'Indeks Uji', array['MIXTEST'], null, null, true, false)
  ->> 'room_enabled', 'false', 'Room indeks bisa ditutup');
reset role;

select is((select array_agg(stock_code) from public.post_stocks where post_id = 'a2900000-0000-4000-8000-000000000003'),
  array['MIX-TEST'], 'Post lama yang memakai alias ditandai ulang ke kode utama');
select is((select stock_code from public.stock_watchers where user_id = :'budi'), 'MIX-TEST',
  'Pemantau alias dipindahkan ke kode utama');

select tests.authenticate_as(:'ani');
select throws_ok($$select public.join_stock_room('MIXTEST')$$, 'PT403', 'room_disabled', 'Room yang ditutup tidak bisa dimasuki');
reset role;

select tests.authenticate_agent(:'moder');
select ok(not exists (select 1 from jsonb_array_elements(cs_api.community_delete_instrument('MIX-TEST')) e
                      where e ->> 'code' = 'MIX-TEST'), 'Indeks bisa dihapus');
reset role;
select is((select array_agg(stock_code) from public.post_stocks where post_id = 'a2900000-0000-4000-8000-000000000003'),
  array['MIXTEST'], 'Setelah indeks dihapus, alias kembali menjadi kode biasa');
select is((select count(*)::integer from cs.cs_audit_log where action like 'community.instrument_%' and actor_id = :'moder'), 3,
  'Perubahan indeks tercatat di audit');

select * from finish();
rollback;
