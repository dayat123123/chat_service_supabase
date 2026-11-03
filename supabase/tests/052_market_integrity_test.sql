begin;
select plan(41);

update private.rate_limits set max_count = 1000 where action in ('message', 'room_create', 'stock_room_create');
delete from cs.manipulation_alerts;
update cs.agents set community_permissions = '{}';
update private.settings set value = '0' where key = 'rooms.busy_slow_mode';
select tests.create_agent('Dodi', '{community}', '{}') as dodi \gset
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Nadia', '{cs_agent}', '{"general": 1}') as nadia \gset
update cs.agents set community_permissions = '{community.moderate}' where user_id = :'dodi';
select tests.create_user('mi_user') as user1 \gset
select tests.create_user('mi_resmi') as resmi \gset
insert into cs.official_accounts (profile_id) values (:'resmi');

insert into public.profiles (id, olt_user_id, username, display_name, created_at)
select ('a1720000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'test:mi' || g, 'mi_old_' || g, 'Old ' || g,
       now() - interval '90 days'
from generate_series(1, 30) g;
insert into public.profiles (id, olt_user_id, username, display_name, created_at)
select ('a1720000-0000-4000-8001-' || lpad(g::text, 12, '0'))::uuid, 'test:mn' || g, 'mi_new_' || g, 'New ' || g,
       now() - interval '1 day'
from generate_series(1, 10) g;

insert into public.posts (author_id, body, created_at)
select ('a1720000-0000-4000-8000-' || lpad((g % 30 + 1)::text, 12, '0'))::uuid, 'Pantau $KMTX minggu lalu ' || g,
       now() - interval '2 days' - make_interval(hours => g)
from generate_series(1, 7) g;
insert into public.posts (author_id, body, created_at)
select ('a1720000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'Diskusi $KMTX ' || md5(g::text) || ' ' || md5((g * 7)::text),
       now() - make_interval(mins => g * 2)
from generate_series(1, 25) g;
insert into public.posts (author_id, body, created_at)
select ('a1720000-0000-4000-8001-' || lpad(g::text, 12, '0'))::uuid, 'Akun baru $KMTY ' || md5((g + 100)::text), now() - interval '10 minutes'
from generate_series(1, 9) g;
insert into public.posts (author_id, body, created_at)
select ('a1720000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'Akun lama $KMTY ' || md5((g + 200)::text), now() - interval '10 minutes'
from generate_series(26, 28) g;
insert into public.posts (id, author_id, body, created_at)
select ('a1720000-0000-4000-8002-' || lpad(g::text, 12, '0'))::uuid,
       ('a1720000-0000-4000-8000-' || lpad((g + 10)::text, 12, '0'))::uuid,
       '$KMTZ pasti terbang besok, borong sekarang sebelum terlambat!!' || repeat('!', g % 2), now() - make_interval(mins => g * 3)
from generate_series(1, 6) g;
insert into public.posts (id, author_id, body, created_at)
values ('a1720000-0000-4000-8002-000000000099', 'a1720000-0000-4000-8000-000000000020',
        '$KMTZ laporan keuangan Q3 rilis, laba naik tipis', now() - interval '5 minutes');

select tests.authenticate_as(:'user1');
select join_stock_room('KMTX') as room_x \gset
reset role;

select ok(cs.detect_manipulation(now()) >= 3, 'Deteksi berjalan dengan waktu acuan yang bisa ditentukan');
select is((select (evidence ->> 'mentions_last_hour')::int from cs.manipulation_alerts
           where stock = 'KMTX' and kind = 'mention_spike' and status = 'open'), 25,
  'Lonjakan mention saham terdeteksi beserta buktinya');
select ok(not exists (select 1 from cs.manipulation_alerts where stock = 'KMTX' and kind = 'new_account_concentration'),
  'Akun lama tidak memicu alert konsentrasi akun baru');
select is((select (evidence ->> 'new_account_mentions')::int from cs.manipulation_alerts
           where stock = 'KMTY' and kind = 'new_account_concentration'), 9, 'Konsentrasi akun baru terdeteksi');
select ok(not exists (select 1 from cs.manipulation_alerts where stock = 'KMTY' and kind = 'mention_spike'),
  'Di bawah minimal 20 mention tidak dianggap lonjakan');
select is((select (evidence ->> 'authors')::int from cs.manipulation_alerts where stock = 'KMTZ' and kind = 'coordinated_posts'), 6,
  'Posting mirip dari 6 penulis berbeda terdeteksi');
select is((select count(*)::int from public.posts where id::text like 'a1720000-0000-4000-8002-%' and moderation_status = 'held'), 6,
  'Posting mirip otomatis ditahan');
select is((select moderation_status from public.posts where id = 'a1720000-0000-4000-8002-000000000099'), 'visible',
  'Posting yang berbeda tidak ikut ditahan');
select is((select count(*)::int from private.content_flags f join cs.manipulation_alerts a on a.id = f.alert_id
           where a.stock = 'KMTZ' and f.categories = '{coordinated}'), 6, 'Penahanan tercatat dengan alasan dan alert');
select is((select slow_mode_seconds || '/' || slow_mode_source from private.room_moderation where room_id = :'room_x'),
  '30/alert', 'Alert mengaktifkan slow mode room saham');
select is((select auto_actions -> 'slow_mode' ->> 'seconds' from cs.manipulation_alerts where stock = 'KMTX' and kind = 'mention_spike'),
  '30', 'Aksi otomatis tercatat di alert');
select lives_ok($$select cs.detect_manipulation(now())$$, 'Deteksi bisa dijalankan ulang');
select is((select count(*)::int from cs.manipulation_alerts where status = 'open' and stock in ('KMTX', 'KMTY', 'KMTZ')), 3,
  'Deteksi ulang tidak menggandakan alert yang masih terbuka');
select is(cs.detect_manipulation(now() + interval '3 hours'), 0, 'Di luar jendela waktu tidak ada alert baru');
select ok(exists (select 1 from cron.job where jobname = 'safety-manipulation' and schedule = '*/5 * * * *'),
  'Deteksi dijadwalkan tiap 5 menit');

select tests.authenticate_as(:'user1');
select lives_ok(format($$select send_message(%L, 'Pesan pertama di room')$$, :'room_x'), 'Pesan pertama lolos slow mode');
select throws_like(format($$select send_message(%L, 'Pesan kedua terlalu cepat')$$, :'room_x'), '%"PT429"%"slow_mode"%"30"%',
  'Pesan berikutnya ditolak 429 slow_mode dengan detik tunggu');
select is((get_stock_room_state('kmtx') -> 'slow_mode' ->> 'source'), 'alert', 'Pengguna melihat slow mode aktif');
select is((get_stock_room_state('KMTX') ->> 'wait_seconds')::int, 30, 'Pengguna melihat sisa waktu tunggunya');
select throws_ok($$select get_stock_room_state('1X')$$, 'PT400', 'invalid_stock_code', 'Kode saham divalidasi');
select is(get_stock_room_state('KMQQ') ->> 'room_id', null, 'Room yang belum ada tetap mengembalikan status');

select tests.authenticate_as(:'resmi');
select join_stock_room('KMTX') as joined \gset
select lives_ok(format($$select send_message(%L, 'Pengumuman resmi satu')$$, :'room_x'), 'Akun resmi kirim pesan');
select lives_ok(format($$select send_message(%L, 'Pengumuman resmi dua')$$, :'room_x'), 'Akun resmi tidak terkena slow mode');
select id as pin_msg from public.messages where body = 'Pengumuman resmi satu' \gset

select tests.authenticate_agent(:'nadia');
select throws_ok('select cs_api.community_manipulation_alerts()', 'PT403', 'community_forbidden', 'Alert hanya untuk moderator');
select tests.authenticate_agent(:'kirana');
select throws_ok($$select cs_api.compliance_set_manipulation_settings('{"manipulation.spike_factor": 1}')$$, 'PT400', 'invalid_setting',
  'Ambang divalidasi');
select throws_ok($$select cs_api.compliance_set_manipulation_settings('{"rooms.busy_windows": [["09:30", "08:55"]]}')$$,
  'PT400', 'invalid_setting', 'Jam ramai divalidasi');
select is(cs_api.compliance_set_manipulation_settings('{"manipulation.spike_factor": 4, "rooms.busy_slow_mode": 15}')
          -> 'manipulation.spike_factor', '4'::jsonb, 'Kepatuhan mengubah ambang deteksi');

select tests.authenticate_agent(:'dodi');
select is(jsonb_array_length(cs_api.community_manipulation_alerts('open', 'KMTZ')), 1, 'Moderator melihat alert per saham');
select is(cs_api.community_pin_message(:'room_x', :'pin_msg') -> 'pinned_message' ->> 'body', 'Pengumuman resmi satu',
  'Moderator menyematkan pesan');
select throws_ok(format($$select cs_api.community_pin_message(%L, gen_random_uuid())$$, :'room_x'), 'PT400', 'invalid_message',
  'Hanya pesan di room itu yang bisa disematkan');
select (x ->> 'id') as alert_z from jsonb_array_elements(cs_api.community_manipulation_alerts('open', 'KMTZ')) x \gset
select (x ->> 'id') as alert_x from jsonb_array_elements(cs_api.community_manipulation_alerts('open', 'KMTX')) x \gset
select is((cs_api.community_manipulation_review(:'alert_z', 'dismissed', 'Promosi wajar, bukan koordinasi') ->> 'released_posts')::int, 6,
  'Alert yang ditolak melepas posting yang ditahan otomatis');
select throws_ok(format($$select cs_api.community_manipulation_review(%L, 'reviewed', 'Ulang')$$, :'alert_z'), 'PT409', 'alert_reviewed',
  'Alert tidak bisa ditinjau dua kali');
select is(cs_api.community_manipulation_review(:'alert_x', 'dismissed', 'Lonjakan karena berita resmi') ->> 'status', 'dismissed',
  'Alert lonjakan ditolak');
reset role;
select is((select slow_mode_seconds from private.room_moderation where room_id = :'room_x'), 0,
  'Slow mode dari alert yang ditolak dimatikan');
select tests.authenticate_agent(:'dodi');
select is(cs_api.community_room_settings('KMTX', 20, now() + interval '1 hour') -> 'slow_mode' ->> 'source', 'manual',
  'Moderator mengatur slow mode manual');
select throws_ok($$select cs_api.community_room_settings('KMTX', 5000)$$, 'PT400', 'invalid_slow_mode', 'Slow mode maksimal 1 jam');
select is((cs_api.community_room_state('KMTX') -> 'override' ->> 'seconds')::int, 20, 'Staf melihat pengaturan room');
reset role;
select is((select count(*)::int from cs.cs_audit_log where action in ('community.manipulation_review', 'community.room_settings',
           'community.room_pin', 'manipulation.settings')), 5, 'Tindakan staf tercatat di audit');

delete from cs.holidays where day in ('2026-11-02', '2026-11-04');
insert into cs.holidays (day, name, kind) values ('2026-11-04', 'Libur uji', 'exchange');
select is(private.busy_window_end('2026-11-02 09:00+07'), '2026-11-02 09:30+07'::timestamptz,
  'Jam ramai pagi pada hari bursa memicu slow mode terjadwal');
select ok(private.busy_window_end('2026-11-02 10:00+07') is null and private.busy_window_end('2026-11-07 09:00+07') is null
          and private.busy_window_end('2026-11-04 09:00+07') is null,
  'Di luar jam ramai, akhir pekan, dan libur bursa tidak ada slow mode terjadwal');
select cs.ensure_stock_room('KMTW') as room_w \gset
select is((select seconds || '/' || source from private.room_slow_mode(:'room_w', '2026-11-02 15:55+07')), '15/schedule',
  'Jadwal jam ramai menyalakan slow mode bila tidak ada pengaturan lain');

select * from finish();
rollback;
