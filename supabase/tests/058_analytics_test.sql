begin;
select plan(31);

select tests.create_user('an_ani') as ani \gset
select tests.create_user('an_budi') as budi \gset
select tests.create_agent('Super AN', '{cs_super_admin}', '{}') as sa \gset
select tests.create_agent('Agen AN', '{cs_agent}', '{"general": 1}') as agen \gset
insert into public.posts (id, author_id, body) values ('00000000-0000-4000-8000-00000000f801', :'budi', 'Analisa $ANXA');

select tests.authenticate_anon();
select throws_ok($$select public.track_events('[]')$$, '42501', null, 'Pengguna anonim tidak bisa mengirim event');
reset role;

select tests.authenticate_as(:'ani');
select throws_ok($$select public.track_events('{"event": "feed_open"}')$$, 'PT400', 'invalid_events', 'Batch harus array');
select throws_ok($$select public.track_events((select jsonb_agg(jsonb_build_object('event', 'feed_open')) from generate_series(1, 51)))$$,
  'PT400', 'too_many_events', 'Batch dibatasi 50 event');
select throws_ok($$select public.track_events('[{"event": "feed_open"}]', 'nokia')$$, 'PT400', 'invalid_platform',
  'Platform divalidasi');
select is(public.track_events(jsonb_build_array(
    jsonb_build_object('event', 'feed_open', 'props', jsonb_build_object('scope', 'global', 'source', 'push')),
    jsonb_build_object('event', 'search', 'props', jsonb_build_object('query', 'saham bbca bagus', 'query_length', 16,
                                                                      'type', 'posts', 'result_count', 4)),
    jsonb_build_object('event', 'stock_tap', 'props', jsonb_build_object('stock_code', 'anxa', 'source', 'feed',
                                                                         'post_id', 'bukan-uuid')),
    jsonb_build_object('event', 'order_tap', 'props', jsonb_build_object('stock_code', 'ANXA', 'source', 'post',
                                                                         'side', 'buy', 'note', 'beli banyak')),
    jsonb_build_object('event', 'screen_view'),
    '"feed_open"'::jsonb,
    jsonb_build_object('event', 'share_chart', 'ts', to_char(now() - interval '2 days', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                       'props', jsonb_build_object('interval', '1m', 'stock_code', 'ANXA')),
    jsonb_build_object('event', 'feed_open', 'ts', '2001-01-01T00:00:00Z')), 'android', '2.4.1'),
  '{"accepted": 6, "dropped": 2}'::jsonb, 'Event yang tidak dikenal atau bukan objek dibuang');
reset role;

select is((select props from private.analytics_events where user_id = :'ani' and event = 'search'),
  '{"type": "posts", "query_length": 16, "result_count": 4}'::jsonb, 'Properti teks bebas tidak disimpan');
select is((select props from private.analytics_events where user_id = :'ani' and event = 'stock_tap'),
  '{"source": "feed", "stock_code": "ANXA"}'::jsonb, 'Properti tidak valid dibuang dan kode saham dinormalkan');
select is((select props ->> 'side' from private.analytics_events where user_id = :'ani' and event = 'order_tap'), 'buy',
  'Properti order_tap yang diizinkan disimpan');
select ok((select created_at < now() - interval '47 hours' from private.analytics_events
           where user_id = :'ani' and event = 'share_chart'), 'Waktu event dari klien dipakai bila wajar');
select is((select count(*)::integer from private.analytics_events
           where user_id = :'ani' and event = 'feed_open' and created_at = now()), 2,
  'Event tanpa waktu atau dengan waktu tidak wajar memakai waktu server');
select is((select platform || ' ' || app_version from private.analytics_events where user_id = :'ani' and event = 'search'),
  'android 2.4.1', 'Platform dan versi aplikasi dicatat');
select ok((select bool_and(tableoid::regclass::text like 'private.analytics_events_p%')
           from private.analytics_events where user_id = :'ani'), 'Event tersimpan di partisi bulanan');

select tests.authenticate_as(:'budi');
select is(public.track_events('[{"event": "stock_tap", "props": {"stock_code": "ANXA"}}]') ->> 'accepted', '1',
  'Pengguna lain mengirim event');
reset role;

update private.feature_flags set enabled = false where key = 'analytics';
select tests.authenticate_as(:'budi');
select is(public.track_events('[{"event": "feed_open"}]'), '{"accepted": 0, "dropped": 1, "disabled": true}'::jsonb,
  'Flag analitik mati menghentikan pencatatan');
reset role;
update private.feature_flags set enabled = true where key = 'analytics';

update private.rate_limits set max_count = 2 where action = 'analytics' and window_seconds = 60;
select tests.authenticate_as(:'budi');
select throws_like($$select public.track_events('[{"event": "feed_open"}]')$$, '%"PT429"%rate_limited%',
  'Pengiriman event dibatasi rate limit');
reset role;

select tests.authenticate_agent(:'agen');
select throws_ok($$select cs_api.admin_analytics()$$, 'PT403', 'role_forbidden', 'Analitik khusus Super Admin');
reset role;
select tests.authenticate_agent(:'sa');
select throws_ok($$select cs_api.admin_analytics('2026-02-01', '2026-01-01')$$, 'PT400', 'invalid_range',
  'Rentang tanggal divalidasi');
select cs_api.admin_analytics() as rep \gset
reset role;
select ok(:'rep'::jsonb ?& array['active_users', 'retention', 'content', 'top_stocks', 'events', 'order_taps'],
  'Laporan analitik memuat semua bagian');
select is(jsonb_array_length(:'rep'::jsonb -> 'active_users' -> 'dau'), 30, 'DAU harian untuk 30 hari terakhir');
select ok((:'rep'::jsonb -> 'active_users' -> 'dau' -> 29 ->> 'users')::integer >= 2, 'DAU hari ini menghitung pengguna aktif');
select ok((:'rep'::jsonb -> 'active_users' ->> 'mau')::integer >= 2, 'MAU dihitung');
select ok((:'rep'::jsonb -> 'order_taps' ->> 'taps')::integer >= 1, 'Klik sosial ke order dihitung');
select ok(:'rep'::jsonb -> 'order_taps' -> 'top_stocks' @> '[{"code": "ANXA"}]', 'Saham paling sering diklik ke order');
select ok(:'rep'::jsonb -> 'top_stocks' @> '[{"code": "ANXA"}]', 'Saham paling dibahas dari postingan');
select ok(:'rep'::jsonb -> 'retention' @> jsonb_build_array(jsonb_build_object(
            'cohort_week', date_trunc('week', now() at time zone 'Asia/Jakarta')::date)),
  'Kohort retensi mingguan dari pengguna baru');

select to_char(date_trunc('month', now() at time zone 'UTC') - interval '14 months', 'YYYYMM') as old_month \gset
select format('create table private.analytics_events_p%s partition of private.analytics_events for values from (%L) to (%L)',
              :'old_month', date_trunc('month', now() at time zone 'UTC') - interval '14 months',
              date_trunc('month', now() at time zone 'UTC') - interval '13 months') as ddl \gset
select lives_ok(:'ddl', 'Partisi lama dibuat untuk uji retensi');
select ok((private.analytics_maintenance() ->> 'dropped_partitions')::integer >= 1, 'Partisi lebih dari 12 bulan dihapus');
select is(to_regclass('private.analytics_events_p' || :'old_month'), null, 'Partisi lama sudah tidak ada');

select tests.authenticate_as(:'ani');
select public.export_my_data() as export \gset
reset role;
select ok(:'export'::jsonb ?& array['bookmarks', 'notification_preferences', 'linked_accounts', 'appeals',
                                    'message_reactions', 'analytics_events'],
  'Ekspor data memuat bookmark, preferensi notifikasi, rekening tertaut, banding, dan analitik');
select is(jsonb_array_length(:'export'::jsonb -> 'analytics_events'), 6, 'Ekspor memuat event analitik milik sendiri');

select tests.authenticate_as(:'ani');
select public.delete_my_account() as deleted \gset
reset role;
select is((select count(*)::integer from private.analytics_events where user_id = :'ani'), 0,
  'Hapus akun menghapus event analitik');

select * from finish();
rollback;
