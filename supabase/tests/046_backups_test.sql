begin;
select plan(35);

delete from private.backup_runs;
delete from private.backup_state;
delete from private.backup_requests;
delete from vault.secrets where name in ('backup.s3_secret_access_key', 'backup.restic_password');
update private.backup_config
   set revision = 0, endpoint = null, bucket = null, prefix = null, region = null, access_key_id = null,
       secret_id = null, password_secret_id = null, password_set_at = null, configured_at = null;

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 1}') as rina \gset

select tests.authenticate_service();
select is(public.backup_config() - 'revision', '{"configured": false}', 'Backup belum diatur');
reset role;
select is((select severity from private.health_checks_backup() where key = 'backup:config'), 'warning',
  'Backup yang belum diatur muncul sebagai peringatan');

select tests.authenticate_agent(:'rina');
select throws_ok('select cs_api.backup_overview()', 'PT403', null, 'Agen CS tidak bisa membuka backup');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.backup_set_target('ftp://s3.example.co.id', 'olt-backup', 'prod', null, 'AKIA123', 'rahasia', 'password-backup-panjang')$$,
  'PT400', 'invalid_backup_endpoint', 'Endpoint selain http(s) ditolak');
select throws_ok($$select cs_api.backup_set_target('https://s3.example.co.id', 'Bucket_Salah', 'prod', null, 'AKIA123', 'rahasia', 'password-backup-panjang')$$,
  'PT400', 'invalid_backup_bucket', 'Nama bucket yang salah ditolak');
select throws_ok($$select cs_api.backup_set_target('https://s3.example.co.id', 'olt-backup', 'prod', null, 'AKIA123', 'rahasia', 'pendek')$$,
  'PT400', 'weak_backup_password', 'Password enkripsi pendek ditolak');
select throws_ok($$select cs_api.backup_set_target('https://s3.example.co.id', 'olt-backup', 'prod', null, 'AKIA123', null, 'password-backup-panjang')$$,
  'PT400', 'invalid_backup_credentials', 'Secret access key wajib diisi pertama kali');
select cs_api.backup_set_target('https://s3.example.co.id/', 'olt-backup', '/prod/', 'id-jkt-1', 'AKIA123',
                                's3-rahasia', 'password-backup-panjang') as cfg \gset
select is((:'cfg'::jsonb) ->> 'configured', 'true', 'Tujuan backup tersimpan');
select is((:'cfg'::jsonb) ->> 'endpoint', 'https://s3.example.co.id', 'Endpoint dinormalisasi');
select is((:'cfg'::jsonb) ->> 'prefix', 'prod', 'Prefix dinormalisasi');
select ok(:'cfg'::text not like '%s3-rahasia%' and :'cfg'::text not like '%password-backup-panjang%',
  'Rahasia tidak dikirim balik ke web');
select throws_ok($$select cs_api.backup_set_target('https://s3.example.co.id', 'olt-backup', 'prod', 'id-jkt-1', 'AKIA123', null, 'password-backup-baru-sekali')$$,
  'PT409', 'backup_password_locked', 'Password repositori yang sudah ada tidak bisa diganti');
select is((cs_api.backup_set_target('https://s3.example.co.id', 'olt-backup', 'prod', 'id-jkt-1', 'AKIA456', 's3-baru')
           ->> 'access_key_id'), 'AKIA456', 'Kunci akses S3 bisa dirotasi tanpa mengganti password');
select throws_ok($$select cs_api.backup_set_target('https://s3.example.co.id', 'olt-backup', 'prod-2', 'id-jkt-1', 'AKIA456')$$,
  'PT400', 'weak_backup_password', 'Repositori baru wajib password baru');
select throws_ok($$select cs_api.backup_set_schedule('25:00', 5, 7, 4, 6, 7, true, 0, '04:00')$$,
  'PT400', 'invalid_backup_schedule', 'Jadwal yang tidak valid ditolak');
select is((cs_api.backup_set_schedule('01:30', 10, 14, 4, 12, 10, true, 6, '05:00') ->> 'base_time'), '01:30',
  'Jadwal backup tersimpan');
select lives_ok($$select cs_api.backup_request('base')$$, 'Super Admin meminta backup penuh sekarang');
select lives_ok($$select cs_api.backup_request('base')$$, 'Permintaan ganda tidak menumpuk');
reset role;

select ok((select details::text not like '%s3-rahasia%' and details::text not like '%password-backup%'
           from cs.cs_audit_log where action = 'backup.target_set' order by created_at desc limit 1),
  'Audit tujuan backup tanpa rahasia');
select is((select count(*)::integer from private.backup_requests where taken_at is null), 1, 'Satu permintaan menunggu');

select tests.authenticate_service();
select public.backup_config() as conf \gset
select is((:'conf'::jsonb) ->> 'repository', 's3:https://s3.example.co.id/olt-backup/prod', 'Repositori restic disusun dari tujuan');
select is((:'conf'::jsonb) #>> '{s3,secret_access_key}', 's3-baru', 'Layanan backup menerima secret S3');
select is((:'conf'::jsonb) ->> 'password', 'password-backup-panjang', 'Layanan backup menerima password enkripsi');
select is((:'conf'::jsonb) #>> '{schedule,offsite_minutes}', '10', 'Jadwal dikirim ke layanan');
select is(public.backup_config(((:'conf'::jsonb) ->> 'revision')::bigint) ->> 'unchanged', 'true',
  'Konfigurasi tidak dikirim ulang bila revisi sama');
select is(public.backup_heartbeat('backup-a', '0.1.0', now(), 1,
  '{"repository_ready": true, "wal": {"streaming": false, "error": "koneksi ditolak"}, "offsite": {}}') -> 'requests',
  '["base"]'::jsonb, 'Heartbeat mengambil permintaan manual');
select is(public.backup_heartbeat('backup-a', '0.1.0', now(), 1, '{"repository_ready": true}') -> 'requests', '[]'::jsonb,
  'Permintaan hanya diambil sekali');
select throws_ok($$select public.backup_record('backup-a', '{"kind": "semua", "status": "ok"}')$$, 'PT400',
  'invalid_backup_run', 'Jenis pekerjaan yang tidak dikenal ditolak');
select lives_ok($$select public.backup_record('backup-a', jsonb_build_object('kind', 'base', 'status', 'ok',
  'started_at', now() - interval '3 minutes', 'finished_at', now(), 'bytes', 123456, 'snapshot_id', 'abc123'))$$,
  'Backup penuh dicatat');
select public.backup_heartbeat('backup-a', '0.1.0', now(), 1,
  '{"repository_ready": true, "wal": {"streaming": false, "error": "koneksi ditolak"}, "offsite": {}}');
reset role;

select is((select severity || ' ' || detail from private.health_checks_backup() where key = 'backup:wal'),
  'critical koneksi ditolak', 'Streaming WAL yang berhenti menjadi masalah kritis');
select is((select status from private.service_instances where service = 'backup' and instance = 'backup-a'), 'error',
  'Error backup tercermin di heartbeat layanan');

select tests.authenticate_service();
select public.backup_heartbeat('backup-a', '0.1.0', now(), 1, jsonb_build_object(
  'repository_ready', true, 'wal', jsonb_build_object('streaming', true),
  'offsite', jsonb_build_object('last_ok_at', now()), 'disk', jsonb_build_object('total_bytes', 100, 'avail_bytes', 50)));
reset role;
select is((select count(*)::integer from private.health_checks_backup()), 0, 'Backup sehat tanpa masalah');

update private.backup_config set configured_at = now() - interval '10 days';
update private.backup_runs set finished_at = now() - interval '30 hours' where kind = 'base';
select is((select severity from private.health_checks_backup() where key = 'backup:base'), 'critical',
  'Backup penuh yang terlalu lama menjadi masalah kritis');
select is((select severity from private.health_checks_backup() where key = 'backup:restore_test'), 'warning',
  'Uji restore yang belum berjalan seminggu menjadi peringatan');

select tests.authenticate_agent(:'sinta');
select is((cs_api.backup_overview() #>> '{summary,last_base,snapshot_id}'), 'abc123', 'Ringkasan menampilkan backup terakhir');
reset role;

select * from finish();
rollback;
