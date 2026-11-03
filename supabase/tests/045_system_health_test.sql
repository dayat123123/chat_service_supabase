begin;
select plan(46);

delete from private.alert_deliveries;
delete from private.health_alerts;
delete from private.health_checks;
delete from private.service_instances;
delete from private.health_probes;
delete from private.health_disks;
delete from vault.secrets where name in ('alerts.telegram_bot_token', 'alerts.smtp_password');
update private.alert_channels
   set revision = 0, label = 'OLT Social', console_url = null, telegram_enabled = false, telegram_secret_id = null,
       telegram_chat_ids = '{}', email_enabled = false, smtp_host = null, smtp_port = null, smtp_security = null,
       smtp_username = null, smtp_secret_id = null, email_from = null, email_to = '{}';
update private.settings set value = '["media"]' where key = 'health.expected_services';
update private.settings set value = '0' where key in ('health.alert_after_seconds', 'health.resolve_after_seconds');

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_user('hs_budi') as budi \gset

select ok(exists (select 1 from private.health_current() where key = 'service:media' and severity = 'critical'),
  'Layanan wajib tanpa heartbeat dianggap tidak aktif');

select tests.authenticate_as(:'budi');
select throws_ok($$select public.service_heartbeat('media', 'a', '0.1.0', now(), 'ok', null, '{}')$$, '42501', null,
  'Nasabah tidak bisa mengirim heartbeat');
reset role;

select tests.authenticate_service();
select throws_ok($$select public.service_heartbeat('media', 'a', '0.1.0', now(), 'rusak', null, '{}')$$, 'PT400',
  'invalid_heartbeat', 'Status heartbeat yang tidak dikenal ditolak');
select lives_ok($$select public.service_heartbeat('media', 'media-a', '0.1.0', now(), 'ok', null, '{"accepted": 3}')$$,
  'Layanan mengirim heartbeat');
reset role;
select ok(not exists (select 1 from private.health_current() where key like 'service:media%'),
  'Layanan yang mengirim heartbeat dianggap sehat');

select tests.authenticate_service();
select public.service_heartbeat('media', 'media-a', '0.1.0', now(), 'error', 'Storage tidak bisa dihubungi', '{}');
reset role;
select is((select severity || ' ' || detail from private.health_current() where key = 'service:media:status'),
  'critical Storage tidak bisa dihubungi', 'Status error dari layanan menjadi masalah kritis');

select tests.authenticate_service();
select public.service_heartbeat('media', 'media-a', '0.1.0', now(), 'ok', null, '{}');
select is(public.health_report('sentinel-a', '0.1.0', now(),
  '[{"name":"storage","target":"http://storage:5000/status","ok":true,"status":200,"latency_ms":4},
    {"name":"realtime","target":"http://realtime:4000/api/ping","ok":false,"status":null,"latency_ms":5000,"error":"timeout"}]',
  '[{"name":"data","total_bytes":1000,"free_bytes":100,"avail_bytes":80}]') ? 'evaluated_at', true,
  'Sentinel melaporkan probe dan disk');
reset role;
select is((select ok from private.health_probes where name = 'storage'), true, 'Probe yang sehat tersimpan');
select is((select severity || ' ' || title from private.health_current() where key = 'probe:realtime'),
  'critical Realtime tidak merespons', 'Probe yang gagal menjadi masalah kritis');
select is((select severity from private.health_current() where key = 'disk:data'), 'critical',
  'Disk terpakai 92% menjadi masalah kritis');
select ok(exists (select 1 from private.service_instances where service = 'sentinel' and instance = 'sentinel-a'),
  'Sentinel tercatat sebagai layanan aktif');
select ok(exists (select 1 from private.health_alerts where key = 'probe:realtime' and resolved_at is null),
  'Alert dibuka saat masalah bertahan melewati batas waktu');
select is((select count(*)::integer from private.alert_deliveries), 0, 'Tanpa kanal aktif, alert hanya tampil di web');
select tests.authenticate_service();
select public.health_report('sentinel-a', '0.1.0', now(), '[]', '[]');
reset role;
select ok((select resolved_at is not null from private.health_alerts where key = 'probe:realtime'),
  'Probe yang tidak dilaporkan lagi dinyatakan pulih');

select tests.authenticate_agent(:'rina');
select throws_ok('select cs_api.system_health()', 'PT403', null, 'Agen CS tidak bisa membuka kesehatan sistem');
select throws_ok($$select cs_api.alert_set_telegram(true, '{123}', '123456:AAAA')$$, 'PT403', null,
  'Agen CS tidak bisa mengatur kanal alert');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.alert_set_telegram(true, '{-1001234567890}', 'bukan-token')$$, 'PT400',
  'invalid_telegram_token', 'Token bot yang salah format ditolak');
select throws_ok($$select cs_api.alert_set_telegram(true, '{-1001234567890}')$$, 'PT400', 'telegram_incomplete',
  'Telegram tidak bisa diaktifkan tanpa token');
select cs_api.alert_set_telegram(true, '{-1001234567890}', '123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsawQ') as tg \gset
select is((:'tg'::jsonb) #> '{telegram,token_set}', 'true'::jsonb, 'Token tersimpan');
select ok(:'tg'::text not like '%AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsawQ%', 'Token tidak dikirim balik ke web');
select throws_ok($$select cs_api.alert_set_email(true, 'smtp.example.co.id', 587, 'starttls', 'ops', 'bukan email', '{ops@example.co.id}')$$,
  'PT400', 'invalid_email_address', 'Alamat pengirim yang salah ditolak');
select throws_ok($$select cs_api.alert_set_email(true, 'smtp.example.co.id', 587, 'starttls', 'ops', 'alert@example.co.id', '{}')$$,
  'PT400', 'email_incomplete', 'Email tidak bisa diaktifkan tanpa penerima');
select is((cs_api.alert_set_email(true, 'smtp.example.co.id', 587, 'starttls', 'ops', 'alert@example.co.id',
                                  '{Ops@Example.co.id}', 'rahasia-smtp') #> '{email,password_set}'),
  'true'::jsonb, 'Kanal email tersimpan dengan password');
select is((cs_api.alert_channels_view() #>> '{email,to,0}'), 'ops@example.co.id', 'Alamat penerima dinormalisasi');
select is((cs_api.alert_set_options('OLT Produksi', 'https://cs.example.co.id/') ->> 'console_url'),
  'https://cs.example.co.id', 'Label dan alamat web CS tersimpan');
reset role;

select ok((select details::text not like '%AAHdq%' and (details ->> 'token_changed')::boolean
           from cs.cs_audit_log where action = 'alerts.telegram_set' order by created_at desc limit 1),
  'Audit Telegram tanpa token');
select ok((select details::text not like '%rahasia-smtp%' from cs.cs_audit_log where action = 'alerts.email_set'
           order by created_at desc limit 1), 'Audit email tanpa password');

select tests.authenticate_service();
select public.alert_channels() as ch \gset
select is((:'ch'::jsonb) #>> '{telegram,bot_token}', '123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsawQ',
  'Sentinel menerima token yang sudah didekripsi');
select is((:'ch'::jsonb) #>> '{email,password}', 'rahasia-smtp', 'Sentinel menerima password SMTP');
select is(public.alert_channels(((:'ch'::jsonb) ->> 'revision')::bigint) ->> 'unchanged', 'true',
  'Kanal tidak dikirim ulang bila revisi sama');
select public.service_heartbeat('media', 'media-a', '0.1.0', now(), 'error', 'Storage tidak bisa dihubungi', '{}');
select public.health_report('sentinel-a', '0.1.0', now(), '[]', '[]');
select public.alert_claim('sentinel-a', 10, 60) as claimed \gset
select is(jsonb_array_length(:'claimed'::jsonb), 2, 'Alert baru dikirim ke Telegram dan email');
select ok((:'claimed'::jsonb) -> 0 ->> 'subject' like '[OLT Produksi] KRITIS: Layanan Upload media bermasalah',
  'Subjek alert memuat label dan tingkat');
select ok((:'claimed'::jsonb) -> 0 ->> 'text' like '%Storage tidak bisa dihubungi%Buka: https://cs.example.co.id/system',
  'Isi alert memuat detail dan tautan web CS');
select is(jsonb_array_length(public.alert_claim('sentinel-b', 10, 60)), 0, 'Alert yang sedang dikirim tidak diambil dua kali');
select is(public.alert_report('sentinel-a', jsonb_build_array(
  jsonb_build_object('id', (:'claimed'::jsonb) -> 0 -> 'id', 'ok', true),
  jsonb_build_object('id', (:'claimed'::jsonb) -> 1 -> 'id', 'ok', false, 'error', 'SMTP 451', 'retry', true))), 2,
  'Hasil pengiriman dilaporkan');
reset role;
select is((select string_agg(status, ',' order by channel) from private.alert_deliveries), 'pending,sent',
  'Email yang gagal sementara dijadwalkan ulang');
select ok((select available_at > now() from private.alert_deliveries where channel = 'email'), 'Pengiriman ulang diberi jeda');

select id as media_alert from private.health_alerts where key = 'service:media:status' \gset
select tests.authenticate_agent(:'sinta');
select is(cs_api.system_health() ->> 'status', 'critical', 'Kesehatan sistem kritis saat ada masalah kritis');
select ok(jsonb_array_length(cs_api.system_health() #> '{alerts,open}') >= 1, 'Alert yang terbuka tampil di web');
select ok((cs_api.system_health_badge() ->> 'critical')::integer >= 1, 'Lencana menghitung alert kritis');
select lives_ok(format('select cs_api.health_acknowledge(%s)', :'media_alert'),
  'Super Admin menandai alert sudah ditangani');
select lives_ok($$select cs_api.alert_send_test('telegram')$$, 'Super Admin mengirim pesan uji');
select throws_ok($$select cs_api.alert_send_test('telegram')$$, 'PT429', null, 'Pesan uji dibatasi');
reset role;
select ok((select acknowledged_by = :'sinta'::uuid from private.health_alerts where key = 'service:media:status'),
  'Penanda tangan tercatat');

select tests.authenticate_service();
select public.service_heartbeat('media', 'media-a', '0.1.0', now(), 'ok', null, '{}');
select public.health_report('sentinel-a', '0.1.0', now(), '[]', '[]');
reset role;
select ok((select resolved_at is not null from private.health_alerts where key = 'service:media:status'),
  'Alert pulih saat masalah hilang');
select ok(exists (select 1 from private.alert_deliveries where kind = 'resolved' and subject like '%PULIH%'),
  'Kabar pulih dikirim ke kanal');

select * from finish();
rollback;
