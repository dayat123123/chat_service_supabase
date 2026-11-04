begin;
select plan(4);

select ok(private.setting_json('health.expected_services', '[]') ? 'auth-bridge',
  'auth-bridge wajib mengirim heartbeat');
select ok(private.setting_json('health.expected_services', '[]') ? 'media'
          and private.setting_json('health.expected_services', '[]') ? 'sentinel',
  'Layanan wajib yang lama tetap ada');

delete from private.service_instances where service = 'auth-bridge';
select is((select severity from private.health_checks_services() where key = 'service:auth-bridge'), 'critical',
  'Tanpa heartbeat auth-bridge muncul pemeriksaan kritis');

insert into private.service_instances (service, instance, version, started_at, last_seen_at, status)
values ('auth-bridge', 'auth-bridge-test', '0.6.0', now(), now(), 'ok');
select ok(not exists (select 1 from private.health_checks_services() where key like 'service:auth-bridge%'),
  'Heartbeat auth-bridge yang segar tidak memunculkan pemeriksaan');

select * from finish();
rollback;
