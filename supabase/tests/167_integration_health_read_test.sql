begin;
select plan(25);

select tests.create_agent('Sinta Kesehatan', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Kesehatan', '{cs_agent}', '{"general": 1}') as rina \gset

insert into private.health_probes (name, target, ok, status, latency_ms, checked_at, last_ok_at)
values ('rest', 'http://rest:3000/ready', true, 200, 12, now(), now())
on conflict (name) do update set target = excluded.target, ok = true, checked_at = now();
update private.alert_channels
   set telegram_enabled = true, telegram_secret_id = null, telegram_chat_ids = '{-1001234567}', email_enabled = true,
       smtp_host = 'smtp.contoh.co.id', smtp_username = 'alert@contoh.co.id', email_to = '{it@contoh.co.id}'
 where singleton;

select tests.authenticate_agent(:'sinta');
select cs_api.integration_key_create('Dasbor Kantor', '{health_read}', null, '{}', 120) as created \gset
select (:'created'::jsonb ->> 'id') as health_key, (:'created'::jsonb ->> 'key') as health_secret \gset
select is(:'created'::jsonb -> 'scopes', '["health_read"]'::jsonb, 'Super Admin membuat key khusus baca kesehatan');
select cs_api.integration_key_create('Notif OLT', '{notify}', null, '{}', 600) ->> 'id' as notify_key \gset
select cs_api.integration_key_create('Dasbor LAN', '{health_read}', null, '{10.10.0.0/16}', 60) ->> 'id' as lan_key \gset
select is(cs_api.integration_key_create('Gabungan', '{notify,health_read}', null, '{}', 600) -> 'scopes',
  '["health_read", "notify"]'::jsonb, 'Izin baca kesehatan boleh digabung dengan izin lain');
select throws_ok($$select cs_api.integration_key_create('Salah', '{health_write}', null, '{}', 60)$$,
  'PT400', 'invalid_scopes', 'Izin yang tidak dikenal ditolak');
select cs_api.system_health() as hub_health \gset
select cs_api.system_nodes() as hub_nodes \gset
reset role;

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.system_health()$$, 'PT403', null, 'Agen biasa tetap tidak bisa membuka kesehatan sistem');
reset role;

select ok(public.integration_authenticate(encode(sha256(convert_to(:'health_secret', 'UTF8')), 'hex'), '1.2.3.4')
          -> 'scopes' ? 'health_read', 'Key baca kesehatan dikenali oleh layanan integration');

select tests.authenticate_service();
select public.integration_system_health(:'health_key', '1.2.3.4') as ext_health \gset
select public.integration_system_nodes(:'health_key', '1.2.3.4') as ext_nodes \gset
reset role;

select is(:'ext_health'::jsonb ->> 'api_version', '1', 'Respons kesehatan membawa api_version');
select is(:'ext_health'::jsonb -> 'status', :'hub_health'::jsonb -> 'status', 'Status keseluruhan sama dengan Hub');
select is(:'ext_health'::jsonb -> 'checks', :'hub_health'::jsonb -> 'checks', 'Daftar pemeriksaan sama dengan Hub');
select is(:'ext_health'::jsonb -> 'alerts', :'hub_health'::jsonb -> 'alerts', 'Alert aktif dan riwayat sama dengan Hub');
select is(:'ext_health'::jsonb -> 'services', :'hub_health'::jsonb -> 'services', 'Layanan dan instance sama dengan Hub');
select is(:'ext_health'::jsonb -> 'disks', :'hub_health'::jsonb -> 'disks', 'Disk sama dengan Hub');
select is(:'ext_health'::jsonb -> 'queues', :'hub_health'::jsonb -> 'queues', 'Antrean sama dengan Hub');
select is(:'ext_health'::jsonb -> 'cron', :'hub_health'::jsonb -> 'cron', 'Jadwal cron sama dengan Hub');
select ok(:'hub_health'::jsonb -> 'probes' -> 0 ? 'target' and not (:'ext_health'::jsonb -> 'probes' -> 0 ? 'target'),
  'Alamat internal probe tidak dikirim keluar');
select is(:'ext_health'::jsonb -> 'probes' -> 0 -> 'latency_ms', :'hub_health'::jsonb -> 'probes' -> 0 -> 'latency_ms',
  'Hasil probe lain tetap sama');
select ok(not (:'ext_health'::jsonb -> 'backup' ? 'target') and :'ext_health'::jsonb -> 'backup' ? 'state',
  'Status backup dikirim tanpa lokasi penyimpanan');
select is(jsonb_build_object('telegram', (:'ext_health'::jsonb #> '{channels,telegram}') - 'last',
                          'email', (:'ext_health'::jsonb #> '{channels,email}') - 'last'),
  jsonb_build_object('telegram', jsonb_build_object('enabled', true, 'configured', false),
                     'email', jsonb_build_object('enabled', true, 'configured', true)),
  'Kanal alert hanya diringkas: aktif, sudah diatur, dan pengiriman terakhir');
select ok(position('contoh.co.id' in :'ext_health') = 0 and position('-1001234567' in :'ext_health') = 0,
  'Tidak ada alamat email, host SMTP, atau chat ID Telegram di respons');
select is(:'ext_nodes'::jsonb - 'api_version' - 'now', :'hub_nodes'::jsonb - 'now',
  'Peta layanan sama persis dengan Hub');
select ok((select last_used_at is not null from private.integration_keys where id = :'health_key'),
  'Pemakaian key tercatat');

select tests.authenticate_service();
select throws_ok(format($$select public.integration_system_health(%L, '1.2.3.4')$$, :'notify_key'),
  'PT403', 'scope_forbidden', 'Key tanpa izin health_read ditolak');
select throws_ok(format($$select public.integration_system_nodes(%L, '1.2.3.4')$$, :'lan_key'),
  'PT403', 'ip_not_allowed', 'Key yang dibatasi IP ditolak dari alamat lain');
select lives_ok(format($$select public.integration_system_nodes(%L, '10.10.4.2')$$, :'lan_key'),
  'Key yang dibatasi IP diterima dari jaringan yang diizinkan');
reset role;

select tests.authenticate_agent(:'sinta');
select cs_api.integration_key_revoke(:'health_key', 'Dasbor sudah tidak dipakai') is not null as revoked \gset
reset role;
select tests.authenticate_service();
select throws_ok(format($$select public.integration_system_health(%L, '1.2.3.4')$$, :'health_key'),
  'PT401', 'invalid_key', 'Key yang dicabut langsung ditolak');
reset role;

select is(has_function_privilege('authenticated', 'public.integration_system_health(uuid, text)', 'execute'), false,
  'Aplikasi nasabah dan staf tidak bisa memanggil RPC integrasi kesehatan langsung');

select * from finish();
rollback;
