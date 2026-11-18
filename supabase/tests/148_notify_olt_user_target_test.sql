begin;
select plan(20);
update private.settings set value = '0' where key = 'rooms.busy_slow_mode';

select tests.create_user('ou_budi') as budi \gset
select tests.create_user('ou_sari') as sari \gset
select tests.create_user('ou_joko') as joko \gset
update public.profiles set olt_user_id = 'ou-2001' where id = :'budi';
update public.profiles set olt_user_id = '2002' where id = :'sari';
update public.profiles set olt_user_id = 'ou-2003' where id = :'joko';

select tests.authenticate_agent(tests.create_agent('Sinta Alert', '{cs_super_admin}', '{}'));
select cs_api.integration_key_create('OLT alert harga', '{notify}') ->> 'id' as plain_key \gset
reset role;

select tests.authenticate_as(:'budi');
select public.register_push_device('ou-token-budi-0000000000000001', 'android') as dev_budi \gset
reset role;
select tests.authenticate_as(:'sari');
select public.register_push_device('ou-token-sari-0000000000000001', 'android') as dev_sari \gset
reset role;
select tests.authenticate_as(:'joko');
select public.register_push_device('ou-token-joko-0000000000000001', 'android') as dev_joko \gset
reset role;

select is(private.integration_target('{"olt_user_id": " ou-2001 "}'), '{"olt_user_id": "ou-2001"}'::jsonb,
  'Target olt_user_id dirapikan');
select is(private.integration_target('{"olt_user_id": 2002}'), '{"olt_user_id": "2002"}'::jsonb,
  'Login id berupa angka diterima sebagai string');

select tests.authenticate_service();
select public.integration_notify(:'plain_key', jsonb_build_array(
  jsonb_build_object('id', 'ou-v1', 'target', jsonb_build_object('olt_user_id', 'official:bursa'), 'title', 'x'),
  jsonb_build_object('id', 'ou-v2', 'target', jsonb_build_object('olt_user_id', jsonb_build_array('ou-2001')), 'title', 'x'),
  jsonb_build_object('id', 'ou-v3', 'target', jsonb_build_object('olt_user_id', ''), 'title', 'x'),
  jsonb_build_object('id', 'ou-v4', 'cust_id', 'OU137', 'target', jsonb_build_object('olt_user_id', 'ou-2001'), 'title', 'x'),
  jsonb_build_object('id', 'ou-v5', 'target', jsonb_build_object('olt_user_id', 'ou-2001', 'olt_user_ids', '["ou-2002"]'::jsonb),
                     'title', 'x'),
  jsonb_build_object('id', 'ou-v6', 'target', jsonb_build_object('olt_user_id', repeat('a', 65)), 'title', 'x')),
  null) as invalid \gset
reset role;
select is((select jsonb_agg(r ->> 'error' order by (r ->> 'index')::integer) from jsonb_array_elements(:'invalid'::jsonb -> 'results') r),
  '["invalid_target", "invalid_target", "invalid_target", "invalid_target", "invalid_target", "invalid_target"]'::jsonb,
  'Login id tidak valid, akun resmi, dan gabungan target ditolak');

select tests.authenticate_service();
select public.integration_notify(:'plain_key',
  '[{"id": "ou-a1", "target": {"olt_user_id": "ou-2001"}, "kind": "olt.price_alert.above",
     "title": "BBCA menyentuh 10.000", "body": "Target >= 10.000", "data": {"stock": "BBCA", "alert_id": "8812"},
     "collapse_key": "pa-BBCA", "ttl_seconds": 3600}]', null) as a1 \gset
reset role;
select is(:'a1'::jsonb -> 'results' -> 0, '{"index": 0, "id": "ou-a1", "status": "queued", "devices": 1, "inbox": 1}'::jsonb,
  'Target olt_user_id dikirim langsung dengan key notify saja, bawaan push dan kotak masuk');
select is((select count(*)::integer from private.integration_broadcasts where message_id like 'ou-%'), 0,
  'Target olt_user_id tidak menjadi siaran');
select is((select status from private.integration_receipts where message_id = 'ou-a1'), 'queued',
  'Tanda terima dicatat queued');
select is((select data - 'notification_id' from private.push_queue where user_id = :'budi' and data ->> 'message_id' = 'ou-a1'),
  '{"kind": "olt.price_alert.above", "stock": "BBCA", "alert_id": "8812", "source": "olt", "message_id": "ou-a1",
    "category": "info"}'::jsonb,
  'Data push memuat data OLT tanpa cust_id');
select ok((select collapse_key = 'pa-BBCA' and expires_at <= now() + interval '3600 seconds' + interval '5 seconds'
           and kind = 'olt.price_alert.above'
           from private.push_queue where user_id = :'budi' and data ->> 'message_id' = 'ou-a1'),
  'Opsi push collapse_key dan ttl_seconds ikut terpakai');
select is((select payload from public.notifications where user_id = :'budi' and payload ->> 'message_id' = 'ou-a1'),
  '{"source": "olt", "kind": "olt.price_alert.above", "category": "info", "title": "BBCA menyentuh 10.000",
    "body": "Target >= 10.000", "data": {"stock": "BBCA", "alert_id": "8812"}, "message_id": "ou-a1"}'::jsonb,
  'Kotak masuk memuat pengumuman OLT');
select is((select count(*)::integer from private.push_queue where data ->> 'message_id' = 'ou-a1'), 1,
  'Hanya pemilik login yang menerima');

select tests.authenticate_service();
select public.integration_notify(:'plain_key', '[{"id": "ou-a1", "target": {"olt_user_id": "ou-2001"}, "title": "Ulang"}]', null)
       -> 'results' -> 0 as a1dup \gset
reset role;
select is(:'a1dup'::jsonb, '{"index": 0, "id": "ou-a1", "status": "duplicate"}'::jsonb, 'Id yang sama dijawab duplicate');

insert into private.integration_broadcast_caps (profile_id, day, count) values (:'budi', private.integration_day(), 3);
select tests.authenticate_service();
select public.integration_notify(:'plain_key',
  '[{"id": "ou-a2", "target": {"olt_user_id": "ou-2001"}, "kind": "olt.price_alert.below", "title": "BBCA turun"},
    {"id": "ou-a3", "target": {"olt_user_id": "ou-2001"}, "kind": "olt.price_alert.below", "title": "BBCA turun lagi"}]',
  null) as caps \gset
reset role;
select is((select jsonb_agg(r ->> 'status') from jsonb_array_elements(:'caps'::jsonb -> 'results') r),
  '["queued", "queued"]'::jsonb, 'Target olt_user_id tidak kena batas harian siaran');
select is((select count from private.integration_broadcast_caps where profile_id = :'budi' and day = private.integration_day()),
  3, 'Batas harian siaran tidak bertambah');

select tests.authenticate_service();
select public.integration_notify(:'plain_key',
  '[{"id": "ou-n1", "target": {"olt_user_id": 2002}, "title": "Info"}]', null) -> 'results' -> 0 as n1 \gset
reset role;
select is(:'n1'::jsonb, '{"index": 0, "id": "ou-n1", "status": "queued", "devices": 1, "inbox": 1}'::jsonb,
  'Login id angka sampai ke profilnya');
select is((select kind from private.push_queue where user_id = :'sari' and data ->> 'message_id' = 'ou-n1'), 'olt.info',
  'Kind bawaan olt.info');

insert into private.notification_prefs (user_id, type, in_app, push) values (:'joko', 'olt.market', false, false);
select tests.authenticate_service();
select public.integration_notify(:'plain_key',
  '[{"id": "ou-p1", "target": {"olt_user_id": "ou-2003"}, "kind": "olt.price_alert.above", "title": "BBCA naik"},
    {"id": "ou-p2", "target": {"olt_user_id": "ou-2003"}, "kind": "olt.price_alert.above", "category": "important",
     "title": "BBCA naik"}]', null) as prefs \gset
reset role;
select is((select jsonb_agg(r ->> 'status' order by (r ->> 'index')::integer) from jsonb_array_elements(:'prefs'::jsonb -> 'results') r),
  '["no_recipient", "queued"]'::jsonb, 'Preferensi Pasar dihormati, important menembusnya');

insert into private.notification_settings (user_id, quiet_start, quiet_end)
values (:'sari', ((now() at time zone 'Asia/Jakarta') - interval '1 hour')::time,
        ((now() at time zone 'Asia/Jakarta') + interval '1 hour')::time);
select tests.authenticate_service();
select public.integration_notify(:'plain_key',
  '[{"id": "ou-q1", "target": {"olt_user_id": "2002"}, "kind": "olt.price_alert.above", "channels": ["push"], "title": "BBCA"}]',
  null) as quiet \gset
reset role;
select ok((select available_at > now() from private.push_queue where user_id = :'sari' and data ->> 'message_id' = 'ou-q1'),
  'Push alert mengikuti jam tenang');
select is((select count(*)::integer from public.notifications where payload ->> 'message_id' = 'ou-q1'), 0,
  'Channels push saja tidak membuat kotak masuk');

update public.profiles set deleted_at = now() where id = :'joko';
select tests.authenticate_service();
select public.integration_notify(:'plain_key',
  '[{"id": "ou-d1", "target": {"olt_user_id": "ou-2003"}, "title": "x"},
    {"id": "ou-d2", "target": {"olt_user_id": "ou-9999"}, "title": "x"}]', null) as gone \gset
reset role;
select is((select jsonb_agg(r ->> 'status' order by (r ->> 'index')::integer) from jsonb_array_elements(:'gone'::jsonb -> 'results') r),
  '["no_recipient", "no_recipient"]'::jsonb, 'Akun terhapus dan login tanpa profil dijawab no_recipient');
select is((select queued || '/' || no_recipient || '/' || duplicate || '/' || invalid || '/' || accepted
           from private.integration_daily where key_id = :'plain_key'::uuid and day = private.integration_day()),
  '6/3/1/6/0', 'Statistik harian key menghitung pesan olt_user_id');

select * from finish();
rollback;
