begin;
select plan(44);

select tests.create_user('nt_budi') as budi \gset
select tests.create_user('nt_sari') as sari \gset
select tests.create_user('nt_joko') as joko \gset
select tests.create_user('nt_dewi') as dewi \gset
select tests.create_agent('Sinta Siaran', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Siaran', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_agent('Maya Siaran', '{community}', '{}') as maya \gset
update cs.agents set community_permissions = '{community.moderate}' where user_id = :'maya';
update public.profiles set olt_user_id = 'nt-1001', trust_level = 2 where id = :'budi';
update public.profiles set olt_user_id = 'nt-1002' where id = :'sari';
update public.profiles set olt_user_id = 'nt-1003' where id = :'joko';
insert into public.stock_watchers (user_id, stock_code) values (:'dewi', 'NTXQ');

select has_table('private', 'integration_broadcasts', 'Tabel siaran notifikasi tersedia');
select ok((select bool_and(c.relrowsecurity) from pg_class c
           where c.oid in ('private.integration_broadcasts'::regclass, 'private.integration_broadcast_caps'::regclass)),
  'RLS aktif di tabel siaran dan batas harian');
select is(private.notification_pref_types(),
  array['reply', 'mention', 'like', 'follow', 'message', 'announcement', 'appeal',
        'olt.trade', 'olt.funds', 'olt.market', 'olt.info', 'olt.promo'],
  'Preferensi OLT dipecah menjadi transaksi, dana, pasar, info, dan promo');
select is(array[private.notification_pref_type('olt.trade.partial'), private.notification_pref_type('olt.order.rejected'),
                private.notification_pref_type('olt.rdn.topup'), private.notification_pref_type('olt.withdrawal'),
                private.notification_pref_type('olt.ipo.allotment'), private.notification_pref_type('olt.price_alert'),
                private.notification_pref_type('olt.news'), private.notification_pref_type('olt.trade', 'promo'),
                private.notification_pref_type('like')],
  array['olt.trade', 'olt.trade', 'olt.funds', 'olt.funds', 'olt.market', 'olt.market', 'olt.info', 'olt.promo', 'like'],
  'Jenis olt.* dipetakan ke preferensi sesuai awalan dan kategori');

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.integration_key_create('Siaran saja', '{notify_broadcast}')$$, 'PT400', 'invalid_scopes',
  'Izin notify_broadcast tanpa notify ditolak');
select cs_api.integration_key_create('OLT notifEngine NT', '{notify}') as plain \gset
select cs_api.integration_key_create('OLT siaran NT', '{notify,notify_broadcast}') as wide \gset
select is(:'wide'::jsonb -> 'scopes', '["notify", "notify_broadcast"]'::jsonb, 'Key siaran memuat izin notify_broadcast');
select cs_api.integration_key_update((:'plain'::jsonb ->> 'id')::uuid, 'OLT notifEngine NT', '{notify,notify_broadcast}') as up1 \gset
select cs_api.integration_key_update((:'plain'::jsonb ->> 'id')::uuid, 'OLT notifEngine NT', '{notify}') as up2 \gset
reset role;
select ok(exists (select 1 from cs.cs_audit_log where action = 'integration.key_update'
                  and details ->> 'key_id' = :'plain'::jsonb ->> 'id'
                  and details #> '{changes,scopes,to}' = '["notify", "notify_broadcast"]'::jsonb),
  'Pemberian izin siaran tercatat di audit');

select tests.authenticate_agent(:'rina');
select throws_ok('select cs_api.integration_broadcasts()', 'PT403', 'role_forbidden',
  'Hanya Super Admin yang bisa melihat daftar siaran');
reset role;

select (:'plain'::jsonb ->> 'id') as plain_key, (:'wide'::jsonb ->> 'id') as wide_key \gset

select tests.authenticate_service();
select public.set_olt_account_links(:'budi', '["NT137"]') as linked \gset
reset role;
select tests.authenticate_as(:'budi');
select public.register_push_device('nt-token-budi-0000000000000001', 'android') as dev_budi \gset
reset role;
select tests.authenticate_as(:'sari');
select public.register_push_device('nt-token-sari-0000000000000001', 'android') as dev_sari \gset
reset role;
select tests.authenticate_as(:'joko');
select public.register_push_device('nt-token-joko-0000000000000001', 'android') as dev_joko \gset
reset role;

select tests.authenticate_service();
select public.integration_notify(:'wide_key', jsonb_build_array(
  jsonb_build_object('id', 'nt-v1', 'cust_id', 'NT137', 'target', jsonb_build_object('audience', 'all'), 'title', 'x'),
  jsonb_build_object('id', 'nt-v2', 'target', jsonb_build_object('audience', 'semua'), 'title', 'x'),
  jsonb_build_object('id', 'nt-v3', 'target', jsonb_build_object('olt_user_ids',
                                                                  (select jsonb_agg('u' || g) from generate_series(1, 501) g)),
                     'title', 'x'),
  jsonb_build_object('id', 'nt-v4', 'target', jsonb_build_object('audience', 'stock_watchers'), 'title', 'x'),
  jsonb_build_object('id', 'nt-v5', 'target', jsonb_build_object('olt_user_ids', jsonb_build_array('a:b')), 'title', 'x'),
  jsonb_build_object('id', 'nt-v6', 'target', jsonb_build_object('audience', 'all'), 'title', 'x', 'channels', '["sms"]'::jsonb),
  jsonb_build_object('id', 'nt-v7', 'target', jsonb_build_object('audience', 'all'), 'title', 'x', 'category', 'urgent')),
  null) as invalid \gset
select public.integration_notify(:'plain_key',
  '[{"id": "nt-s1", "target": {"audience": "all"}, "title": "x"},
    {"id": "nt-s2", "target": {"cust_id": "nt137"}, "title": "Order"}]', null) as scoped \gset
reset role;

select is((select jsonb_agg(r ->> 'error' order by (r ->> 'index')::integer) from jsonb_array_elements(:'invalid'::jsonb -> 'results') r),
  '["invalid_target", "invalid_target", "invalid_target", "invalid_target", "invalid_target", "invalid_channels", "invalid_category"]'::jsonb,
  'Target, channels, dan category yang salah ditolak per pesan');
select is((select jsonb_agg(coalesce(r ->> 'error', r ->> 'status') order by (r ->> 'index')::integer)
           from jsonb_array_elements(:'scoped'::jsonb -> 'results') r),
  '["scope_forbidden", "queued"]'::jsonb, 'Target selain cust_id butuh izin notify_broadcast; target cust_id tidak');
select is((select count(*)::integer from private.integration_receipts where message_id like 'nt-v%' or message_id = 'nt-s1'),
  0, 'Pesan yang ditolak tidak mencatat id');

select tests.authenticate_service();
select public.integration_notify(:'plain_key',
  '[{"id": "nt-c1", "cust_id": "NT137", "kind": "olt.order.matched", "title": {"id": "Order match", "en": "Order matched"},
     "body": "Beli 1 lot", "channels": ["push", "inbox"], "data": {"order_id": "O-1"}}]', null) as inboxed \gset
reset role;
select is(:'inboxed'::jsonb -> 'results' -> 0,
  '{"index": 0, "id": "nt-c1", "status": "queued", "devices": 1, "inbox": 1}'::jsonb,
  'Pesan cust_id bisa masuk kotak notifikasi sekaligus push');
select is((select jsonb_build_object('type', n.type, 'payload', n.payload) from public.notifications n
           where n.user_id = :'budi' and n.payload ->> 'message_id' = 'nt-c1'),
  '{"type": "announcement", "payload": {"source": "olt", "kind": "olt.order.matched", "category": "info",
    "title": {"id": "Order match", "en": "Order matched"}, "body": "Beli 1 lot", "data": {"order_id": "O-1"},
    "message_id": "nt-c1", "cust_id": "NT137"}}'::jsonb,
  'Kotak notifikasi memuat pengumuman OLT');
select is((select count(*)::integer from private.push_queue where user_id = :'budi' and data ->> 'message_id' = 'nt-c1'), 1,
  'Satu push per perangkat: pemicu notifikasi tidak mengirim push kedua');
select ok((select data ? 'notification_id' from private.push_queue where user_id = :'budi' and data ->> 'message_id' = 'nt-c1'),
  'Push membawa id notifikasi kotak masuk');

select tests.authenticate_service();
select public.integration_notify(:'wide_key',
  '[{"id": "nt-b1", "target": {"olt_user_ids": ["nt-1001", "nt-1002", "nt-9999", "nt-1001"]}, "kind": "olt.news",
     "title": "Info pasar", "body": "Bursa tutup lebih awal"}]', null) as b1 \gset
select public.integration_notify(:'wide_key', '[{"id": "nt-b1", "target": {"audience": "all"}, "title": "Ulang"}]', null) as b1dup \gset
reset role;
select (:'b1'::jsonb -> 'results' -> 0 ->> 'broadcast_id') as b1_id \gset

select is((:'b1'::jsonb -> 'results' -> 0) - 'broadcast_id', '{"index": 0, "id": "nt-b1", "status": "accepted"}'::jsonb,
  'Siaran diterima untuk diproses asinkron');
select is(:'b1dup'::jsonb -> 'results' -> 0,
  jsonb_build_object('index', 0, 'id', 'nt-b1', 'status', 'duplicate', 'broadcast_id', :'b1_id'),
  'Id yang sama dijawab duplicate dengan broadcast_id yang sama');
select is((select b.status || '/' || array_to_string(b.channels, ',') || '/' || b.category || '/' || (b.target -> 'olt_user_ids')::text
           from private.integration_broadcasts b where b.id = :'b1_id'),
  'queued/inbox,push/info/["nt-1001", "nt-1002", "nt-9999"]', 'Siaran default ke push dan kotak notifikasi, id OLT tanpa duplikat');
select is((select count(*)::integer from public.notifications where payload ->> 'message_id' = 'nt-b1'), 0,
  'Siaran belum dikirim sebelum giliran cron');
select is(private.integration_broadcast_batch(:'b1_id', 1), 1, 'Batch memproses sebanyak ukuran yang diminta');
select is((select status || '/' || targeted from private.integration_broadcasts where id = :'b1_id'), 'sending/1',
  'Siaran diproses bertahap dengan kursor profil');
select private.integration_broadcast_tick() as tick \gset
select is((select jsonb_build_object('status', status, 'targeted', targeted, 'recipients', recipients, 'devices', devices,
                                     'inbox', inbox, 'capped', capped, 'pref_skipped', pref_skipped)
           from private.integration_broadcasts where id = :'b1_id'),
  '{"status": "done", "targeted": 2, "recipients": 2, "devices": 2, "inbox": 2, "capped": 0, "pref_skipped": 0}'::jsonb,
  'Penghitung siaran per penerima');
select is((select count(*)::integer from private.push_queue where user_id = :'budi' and data ->> 'message_id' = 'nt-b1')
          || '/' || (select count(*)::integer from public.notifications where user_id = :'budi' and payload ->> 'message_id' = 'nt-b1'),
  '1/1', 'Budi menerima satu push dan satu notifikasi kotak masuk');
select is((select count from private.integration_broadcast_caps where profile_id = :'budi' and day = private.integration_day()),
  1, 'Siaran non-important dihitung ke batas harian');

select tests.authenticate_as(:'sari');
select ok(public.set_notification_prefs('{"types": {"olt.info": {"in_app": false, "push": false}}}')
          -> 'types' @> '[{"type": "olt.info", "in_app": false, "push": false}]', 'Preferensi info OLT bisa dimatikan');
select ok(public.get_notification_prefs() -> 'types'
          @> '[{"type": "olt.promo", "in_app": true, "push": false}, {"type": "olt.trade", "in_app": true, "push": true}]',
  'Push promo OLT mati secara default, jenis OLT lain aktif');
select ok(public.get_client_config() -> 'config' -> 'notification_types'
          @> '["olt.trade", "olt.funds", "olt.market", "olt.info", "olt.promo"]', 'Konfigurasi klien memuat jenis OLT baru');
reset role;

select tests.authenticate_service();
select public.integration_notify(:'wide_key', '[{"id": "nt-b2", "target": {"olt_user_ids": ["nt-1002"]}, "title": "Info"}]', null)
       -> 'results' -> 0 ->> 'broadcast_id' as b2_id \gset
select public.integration_notify(:'wide_key',
  '[{"id": "nt-b3", "target": {"olt_user_ids": ["nt-1001"]}, "kind": "olt.ipo.offer", "category": "promo", "title": "IPO baru"}]', null)
       -> 'results' -> 0 ->> 'broadcast_id' as b3_id \gset
reset role;
select private.integration_broadcast_tick() as tick \gset
select is((select recipients || '/' || pref_skipped from private.integration_broadcasts where id = :'b2_id'), '0/1',
  'Penerima yang mematikan jenis ini dihitung pref_skipped');
select is((select devices || '/' || inbox from private.integration_broadcasts where id = :'b3_id'), '0/1',
  'Promo masuk kotak notifikasi, push promo harus diaktifkan sendiri');

insert into private.notification_settings (user_id, quiet_start, quiet_end)
values (:'budi', ((now() at time zone 'Asia/Jakarta') - interval '1 hour')::time,
        ((now() at time zone 'Asia/Jakarta') + interval '1 hour')::time);
insert into private.notification_prefs (user_id, type, in_app, push) values (:'budi', 'olt.market', false, false);
select tests.authenticate_service();
select public.integration_notify(:'wide_key',
  '[{"id": "nt-b4", "target": {"olt_user_ids": ["nt-1001"]}, "kind": "olt.corporate_action.suspend", "category": "important",
     "title": "Suspensi"},
    {"id": "nt-c2", "cust_id": "NT137", "title": "Order"}]', null) -> 'results' -> 0 ->> 'broadcast_id' as b4_id \gset
reset role;
select private.integration_broadcast_tick() as tick \gset
select is((select devices || '/' || inbox || '/' || capped from private.integration_broadcasts where id = :'b4_id'), '1/1/0',
  'Kategori important menembus preferensi per jenis');
select ok((select available_at <= now() from private.push_queue where user_id = :'budi' and data ->> 'message_id' = 'nt-b4'),
  'Push important tidak ditunda jam tenang');
select ok((select available_at > now() from private.push_queue where user_id = :'budi' and data ->> 'message_id' = 'nt-c2'),
  'Push biasa tetap ditunda jam tenang');
select is((select count from private.integration_broadcast_caps where profile_id = :'budi' and day = private.integration_day()),
  2, 'Siaran important tidak dihitung ke batas harian');

update private.integration_broadcast_caps set count = 3 where profile_id = :'budi' and day = private.integration_day();
select tests.authenticate_service();
select public.integration_notify(:'wide_key', '[{"id": "nt-b5", "target": {"olt_user_ids": ["nt-1001", "nt-1003"]}, "title": "Info lagi"}]', null)
       -> 'results' -> 0 ->> 'broadcast_id' as b5_id \gset
select public.integration_notify(:'wide_key',
  '[{"id": "nt-b6", "target": {"audience": "stock_watchers", "stock": "ntxq"}, "channels": ["inbox"], "title": "NTXQ"}]', null)
       -> 'results' -> 0 ->> 'broadcast_id' as b6_id \gset
reset role;
select private.integration_broadcast_tick() as tick \gset
select is((select capped || '/' || recipients from private.integration_broadcasts where id = :'b5_id'), '1/1',
  'Penerima yang mencapai batas harian dilewati dan dihitung');
select is((select (target ->> 'stock') || '/' || targeted || '/' || inbox || '/' || devices
           from private.integration_broadcasts where id = :'b6_id'), 'NTXQ/1/1/0',
  'Siaran ke pemantau saham hanya menyasar pemantau saham itu');

select tests.authenticate_service();
select public.integration_notify(:'wide_key', '[{"id": "nt-b7", "target": {"audience": "all"}, "channels": ["inbox"], "title": "Semua"}]', null)
       -> 'results' -> 0 ->> 'broadcast_id' as b7_id \gset
reset role;
select is(private.integration_broadcast_batch(:'b7_id', 1), 1, 'Audiens all diproses per batch');
update private.integration_keys set disabled_at = now() where id = :'wide_key';
select private.integration_broadcast_tick() as tick \gset
select is((select status || '/' || error from private.integration_broadcasts where id = :'b7_id'), 'failed/key_inactive',
  'Siaran berhenti bila key dinonaktifkan');
update private.integration_keys set disabled_at = null where id = :'wide_key';
select private.integration_day() as today \gset

select tests.authenticate_agent(:'sinta');
select is((select (k #>> '{broadcasts,total}') || '/' || (k ->> 'accepted') || '/' || (k #>> '{broadcasts,failed}')
           from jsonb_array_elements(cs_api.integration_stats(7) -> 'keys') k where k ->> 'id' = :'wide_key'),
  '7/7/1', 'Statistik memuat total siaran per key');
select ok(cs_api.integration_broadcasts(:'wide_key'::uuid) @> jsonb_build_array(jsonb_build_object(
            'id', :'b1_id', 'status', 'done', 'recipients', 2, 'channels', '["inbox", "push"]'::jsonb,
            'target', '{"type": "olt_user_ids", "count": 3}'::jsonb)),
  'Daftar siaran per key memuat target, status, dan penghitung');
select is(jsonb_array_length(cs_api.integration_broadcasts(null, 2)), 2, 'Daftar siaran dibatasi p_limit');
select is((select (d -> 'days' -> -1 ->> 'day')::date from jsonb_array_elements(cs_api.integration_stats_daily(1, :'wide_key'::uuid)) d),
  :'today'::date, 'Statistik harian dipotong per tanggal WIB');
reset role;

update private.integration_broadcast_caps set day = private.integration_day() - 3 where profile_id = :'joko';
select private.integration_maintenance() as maint \gset
select is((select count(*)::integer from private.integration_broadcast_caps where profile_id = :'joko'), 0,
  'Batas harian yang lama dibersihkan');

select tests.authenticate_as(:'budi');
select join_stock_room('NTXR') as room \gset
select (send_message(:'room', 'Pesan satu', 'c6500000-0000-4000-8000-000000000001')).id as m1 \gset
select (send_message(:'room', 'Pesan dua', 'c6500000-0000-4000-8000-000000000002')).id as m2 \gset
reset role;
update public.messages set created_at = '2026-11-01 10:00:00+07' where id in (:'m1', :'m2');
select tests.authenticate_agent(:'maya');
select is((select jsonb_agg(i ->> 'id') from jsonb_array_elements(cs_api.community_room_messages('NTXR', 1) -> 'items') i)
          || (select jsonb_agg(i ->> 'id') from jsonb_array_elements(cs_api.community_room_messages('NTXR', 1, '2026-11-01 10:00:00+07',
                                                                       greatest(:'m1'::uuid, :'m2'::uuid)) -> 'items') i),
  jsonb_build_array(greatest(:'m1'::uuid, :'m2'::uuid), least(:'m1'::uuid, :'m2'::uuid)),
  'Paging pesan room memakai id sebagai pemecah seri');
select is(jsonb_array_length(cs_api.community_room_messages('NTXR', 10, '2026-11-01 10:00:00+07') -> 'items'), 0,
  'Parameter p_before lama tetap bekerja');
reset role;

select * from finish();
rollback;
