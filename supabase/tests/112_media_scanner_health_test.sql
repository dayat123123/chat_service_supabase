begin;
select plan(8);

delete from private.health_alerts;
delete from private.health_checks;
delete from private.service_instances;
delete from private.health_probes;
update private.settings set value = '["media"]' where key = 'health.expected_services';
update private.settings set value = '0' where key in ('health.alert_after_seconds', 'health.resolve_after_seconds');

select tests.create_agent('Sinta Pemindai', '{cs_super_admin}', '{}') as sinta \gset

select is(private.health_service_label('clamav'), 'Pemindai antivirus', 'Container clamav berlabel Pemindai antivirus');
select is(private.health_service_label('classifier'), 'Klasifikasi gambar', 'Label layanan lain tetap sama');
select is(private.health_service_label('layanan-baru'), 'layanan-baru', 'Layanan tanpa label memakai namanya sendiri');

select tests.authenticate_service();
select public.service_heartbeat('media', 'media-a', '0.3.0', now(), 'degraded',
  'Pemindai antivirus tidak bisa dihubungi (3 kali berturut-turut); upload dokumen dan video chat CS ditolak',
  '{"scanner_failures": 3, "scanned": 0, "malware_detected": 0, "attachment_policy_loaded": true}');
select public.health_report('sentinel-a', '0.4.0', now(),
  '[{"name":"clamav","target":"tcp://clamav:3310","ok":false,"status":null,"latency_ms":5000,"error":"connection refused"}]',
  '[]', '[]', null);
reset role;

select is((select severity || ' ' || title from private.health_current() where key = 'probe:clamav'),
  'critical Pemindai antivirus tidak merespons', 'Probe clamav yang gagal menjadi masalah kritis berlabel');
select is((select severity || ' ' || title from private.health_current() where key = 'service:media:status'),
  'warning Layanan Upload media bermasalah', 'Pemindai mati membuat media bermasalah');
select ok((select detail from private.health_current() where key = 'service:media:status')
            like 'Pemindai antivirus tidak bisa dihubungi%ditolak', 'Rincian menyebut pemindai dan akibatnya');

select tests.authenticate_agent(:'sinta');
select is((select p ->> 'label' from jsonb_array_elements(cs_api.system_health() -> 'probes') p where p ->> 'name' = 'clamav'),
  'Pemindai antivirus', 'Kesehatan sistem menampilkan probe pemindai dengan labelnya');
select ok((select (s -> 'instances' -> 0 -> 'detail' ->> 'scanner_failures')::integer = 3
                   and s -> 'instances' -> 0 ->> 'error' like 'Pemindai antivirus%'
           from jsonb_array_elements(cs_api.system_health() -> 'services') s where s ->> 'service' = 'media'),
  'Kesehatan sistem menampilkan status media beserta masalah pemindai');
reset role;

select * from finish();
rollback;
