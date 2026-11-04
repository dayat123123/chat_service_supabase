begin;
select plan(36);

delete from private.backup_runs;
delete from private.backup_state;
delete from private.backup_requests;
delete from vault.secrets where name in ('backup.s3_secret_access_key', 'backup.restic_password');
update private.backup_config
   set revision = 0, kind = 's3', endpoint = null, bucket = null, prefix = null, region = null, access_key_id = null,
       secret_id = null, password_secret_id = null, password_set_at = null, configured_at = null;

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 1}') as rina \gset

select has_column('private', 'backup_config', 'kind', 'Konfigurasi backup punya jenis tujuan');
select is((select column_default from information_schema.columns
           where table_schema = 'private' and table_name = 'backup_config' and column_name = 'kind'),
  '''s3''::text', 'Jenis tujuan bawaan s3 agar data lama tetap berlaku');
select ok((select detail from private.health_checks_backup() where key = 'backup:config') like '%folder lokal%',
  'Alert backup belum diatur menyebut pilihan folder lokal');

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.backup_set_target(p_kind => 'local', p_password => 'password-lokal-panjang')$$,
  'PT403', null, 'Agen CS tidak bisa mengatur tujuan backup');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.backup_set_target(p_kind => 'ftp', p_password => 'password-lokal-panjang')$$,
  'PT400', 'invalid_backup_kind', 'Jenis tujuan selain s3 atau local ditolak');
select throws_ok($$select cs_api.backup_set_target(p_kind => 'local')$$,
  'PT400', 'weak_backup_password', 'Folder lokal tetap wajib password enkripsi');
select throws_ok($$select cs_api.backup_set_target(p_kind => 'local', p_password => 'pendek')$$,
  'PT400', 'weak_backup_password', 'Password enkripsi folder lokal minimal 16 karakter');
select cs_api.backup_set_target('https://abaikan.example.co.id', 'abaikan', 'x', 'id-jkt-1', 'AKIA999', 's3-abaikan',
                                'password-lokal-panjang', 'LOCAL') as cfg \gset
select is((:'cfg'::jsonb) ->> 'configured', 'true', 'Tujuan folder lokal tersimpan tanpa endpoint dan access key');
select is((:'cfg'::jsonb) ->> 'kind', 'local', 'Jenis tujuan tersimpan sebagai local');
select ok((:'cfg'::jsonb) ->> 'endpoint' is null and (:'cfg'::jsonb) ->> 'bucket' is null
          and (:'cfg'::jsonb) ->> 'access_key_id' is null and not ((:'cfg'::jsonb) ->> 'secret_set')::boolean,
  'Isian S3 diabaikan untuk folder lokal');
select is((:'cfg'::jsonb) ->> 'local_repository', '/var/lib/olt-backup-repo', 'Web melihat path repositori lokal di container');
select ok(:'cfg'::text not like '%password-lokal-panjang%' and :'cfg'::text not like '%s3-abaikan%',
  'Rahasia tidak dikirim balik ke web');
select throws_ok($$select cs_api.backup_set_target(p_kind => 'local', p_password => 'password-lokal-lain-sekali')$$,
  'PT409', 'backup_password_locked', 'Password repositori lokal yang sudah ada tidak bisa diganti');
select lives_ok($$select cs_api.backup_set_target(p_kind => 'local')$$, 'Folder lokal bisa disimpan ulang tanpa password');
select is(cs_api.backup_overview() #>> '{summary,kind}', 'local', 'Ringkasan backup menampilkan jenis tujuan');
select is(cs_api.backup_overview() #>> '{summary,target}', '/var/lib/olt-backup-repo', 'Ringkasan backup menampilkan folder repositori');
reset role;

select is((select count(*)::integer from vault.secrets where name = 'backup.s3_secret_access_key'), 0,
  'Secret S3 tidak disimpan untuk folder lokal');
select is((select array_agg(distinct details ->> 'kind') from cs.cs_audit_log
           where action = 'backup.target_set' and actor_id = :'sinta'), '{local}'::text[], 'Audit mencatat jenis tujuan');
select ok((select bool_and(details::text not like '%password-lokal%' and details::text not like '%s3-abaikan%')
           from cs.cs_audit_log where action = 'backup.target_set' and actor_id = :'sinta'),
  'Audit tujuan folder lokal tanpa rahasia');

select tests.authenticate_service();
select public.backup_config() as conf \gset
select is((:'conf'::jsonb) ->> 'kind', 'local', 'Layanan backup menerima jenis tujuan');
select is((:'conf'::jsonb) ->> 'repository', '/var/lib/olt-backup-repo', 'Repositori restic lokal memakai path tetap di container');
select is((:'conf'::jsonb) -> 's3', 'null'::jsonb, 'Tidak ada kredensial S3 untuk folder lokal');
select is((:'conf'::jsonb) ->> 'password', 'password-lokal-panjang', 'Layanan backup menerima password enkripsi');
select public.backup_heartbeat('backup-a', '0.2.0', now(), 3, jsonb_build_object(
  'repository_ready', true, 'wal', jsonb_build_object('streaming', true),
  'offsite', jsonb_build_object('last_ok_at', now()), 'disk', jsonb_build_object('total_bytes', 100, 'avail_bytes', 50),
  'repository_disk', jsonb_build_object('total_bytes', 100, 'avail_bytes', 50)));
reset role;

select is((select count(*)::integer from private.health_checks_backup()), 0, 'Backup lokal yang sehat tanpa masalah');
select is((select count(*)::integer from private.health_checks_secrets() where key = 'backup:secret'), 0,
  'Folder lokal tidak butuh secret S3 agar dianggap terbaca');

update private.backup_state set state = jsonb_set(state, '{repository_disk,avail_bytes}', '8');
select is((select severity from private.health_checks_backup() where key = 'backup:repository_disk'), 'warning',
  'Disk repositori lokal tersisa < 10 % menjadi peringatan');
update private.backup_state set state = jsonb_set(state, '{repository_disk,avail_bytes}', '3');
select is((select severity from private.health_checks_backup() where key = 'backup:repository_disk'), 'critical',
  'Disk repositori lokal tersisa < 5 % menjadi kritis');

update private.backup_config set configured_at = now() - interval '1 day';
update private.backup_state
   set state = jsonb_set(state - 'offsite', '{repository_disk,avail_bytes}', '50') || '{"offsite": {}}';
select is((select title from private.health_checks_backup() where key = 'backup:offsite'),
  'Pengiriman WAL ke repositori backup tertunda', 'Alert kiriman WAL memakai teks netral');

update private.backup_state set state = '{"repository_ready": false}';
select ok((select detail from private.health_checks_backup() where key = 'backup:repository') like '%BACKUP_LOCAL_REPO_DIR%',
  'Repositori lokal yang tidak terbuka menyarankan cek mount folder');

delete from vault.secrets where name = 'backup.restic_password';
select ok((select detail from private.health_checks_secrets() where key = 'backup:secret')
          not like '%secret access key%', 'Rahasia folder lokal yang hilang hanya meminta password enkripsi');
select tests.authenticate_agent(:'sinta');
select lives_ok($$select cs_api.backup_set_target(p_kind => 'local', p_password => 'password-lokal-panjang')$$,
  'Password folder lokal yang sama boleh diisi ulang bila rahasia lama tidak terbaca');

select throws_ok($$select cs_api.backup_set_target('https://s3.example.co.id', 'olt-backup', 'prod', null, 'AKIA123', 's3-rahasia')$$,
  'PT400', 'weak_backup_password', 'Pindah dari folder lokal ke S3 wajib password baru');
select throws_ok($$select cs_api.backup_set_target('https://s3.example.co.id', 'olt-backup', 'prod', null, 'AKIA123', null, 'password-s3-baru-panjang')$$,
  'PT400', 'invalid_backup_credentials', 'Pindah ke S3 wajib secret access key');
select is(cs_api.backup_set_target('https://s3.example.co.id', 'olt-backup', 'prod', null, 'AKIA123', 's3-rahasia',
                                   'password-s3-baru-panjang') ->> 'kind', 's3', 'Tujuan bisa dipindah kembali ke S3');
select is(cs_api.backup_set_target(p_kind => 'local', p_password => 'password-lokal-kedua-panjang') ->> 'secret_set', 'false',
  'Pindah ke folder lokal menghapus secret S3');
reset role;

select is((select count(*)::integer from vault.secrets where name = 'backup.s3_secret_access_key'), 0,
  'Secret S3 lama dihapus dari Vault');

select * from finish();
rollback;
