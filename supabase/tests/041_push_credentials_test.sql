begin;
select plan(41);

delete from vault.secrets where id = (select secret_id from private.push_credentials);
update private.push_credentials
   set revision = 0, secret_id = null, project_id = null, client_email = null, key_id = null;
delete from private.push_instances;

select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 1}') as rina \gset

select jsonb_build_object(
  'type', 'service_account',
  'project_id', 'olt-prod',
  'private_key_id', 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678',
  'private_key', E'-----BEGIN PRIVATE KEY-----\n' || repeat('MIIEvQIBADANBgkqhkiG9w0BAQEFAASC', 12) || E'\n-----END PRIVATE KEY-----\n',
  'client_email', 'notifier@olt-prod.iam.gserviceaccount.com',
  'client_id', '1234567890',
  'auth_uri', 'https://accounts.google.com/o/oauth2/auth',
  'token_uri', 'https://oauth2.googleapis.com/token') as creds \gset

select is(private.push_credentials_problem(:'creds'), null, 'Kunci akun layanan Firebase yang lengkap diterima');
select is(private.push_credentials_problem('"teks"'), 'not_json', 'Isi selain objek JSON ditolak');
select is(private.push_credentials_problem('{"project_info": {"project_id": "olt-prod"}, "client": []}'),
  'google_services', 'File google-services.json dikenali dan ditolak');
select is(private.push_credentials_problem(jsonb_set(:'creds', '{type}', '"authorized_user"')), 'not_service_account',
  'Kredensial selain akun layanan ditolak');
select is(private.push_credentials_problem(jsonb_set(:'creds', '{project_id}', '"OLT Prod"')), 'project_id',
  'ID project yang tidak valid ditolak');
select is(private.push_credentials_problem(jsonb_set(:'creds', '{client_email}', '"admin@gmail.com"')), 'client_email',
  'Email selain akun layanan Google ditolak');
select is(private.push_credentials_problem(jsonb_set(:'creds', '{private_key_id}', '"bad id!"')), 'private_key_id',
  'ID kunci yang tidak valid ditolak');
select is(private.push_credentials_problem(jsonb_set(:'creds', '{private_key}', '"MIIEvQIBADANBg"')), 'private_key',
  'Kunci privat yang bukan PEM ditolak');
select is(private.push_credentials_problem(:'creds'::jsonb - 'private_key_id'), null,
  'ID kunci boleh tidak ada');

select tests.authenticate_agent(:'rina');
select throws_ok(format('select cs_api.push_set_credentials(%L)', :'creds'), 'PT403', null,
  'Hanya Super Admin yang bisa memasang kredensial Firebase');
select throws_ok('select cs_api.push_remove_credentials()', 'PT403', null,
  'Hanya Super Admin yang bisa menghapus kredensial Firebase');
select throws_ok('select public.push_credentials()', '42501', null,
  'Staf tidak bisa membaca kunci Firebase');
reset role;

select tests.authenticate_service();
select is(public.push_credentials() - 'revision', '{"configured": false}', 'Belum ada kredensial untuk notifier');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok(format('select cs_api.push_set_credentials(%L)', '{"project_info": {}}'), 'PT400',
  'invalid_push_credentials', 'File yang salah ditolak server');
select cs_api.push_set_credentials(:'creds') as saved \gset
select is((:'saved'::jsonb) ->> 'project_id', 'olt-prod', 'Kredensial tersimpan untuk project aplikasi');
select is((:'saved'::jsonb) ->> 'updated_by', 'Sinta', 'Pengunggah kredensial tercatat');
select ok(not ((:'saved'::jsonb) ? 'private_key'), 'Kunci privat tidak dikembalikan ke web');
select is((cs_api.push_status() -> 'credentials' ->> 'client_email'), 'notifier@olt-prod.iam.gserviceaccount.com',
  'Status push menampilkan akun layanan yang dipakai');
reset role;

select is((select count(*)::integer from vault.secrets where id = (select secret_id from private.push_credentials)), 1,
  'Kunci disimpan di Vault');
select ok((select secret not like '%PRIVATE KEY%' from vault.secrets
           where id = (select secret_id from private.push_credentials)), 'Kunci di Vault terenkripsi');
select ok((select details::text not like '%PRIVATE KEY%' and details ->> 'project_id' = 'olt-prod'
           from cs.cs_audit_log where action = 'push.credentials_set' order by created_at desc limit 1),
  'Audit mencatat project tanpa kunci privat');

select tests.authenticate_service();
select public.push_credentials() as loaded \gset
select is((:'loaded'::jsonb) -> 'credentials' ->> 'client_email', 'notifier@olt-prod.iam.gserviceaccount.com',
  'Notifier menerima kredensial');
select ok((:'loaded'::jsonb) -> 'credentials' ->> 'private_key' like '-----BEGIN PRIVATE KEY-----%',
  'Notifier menerima kunci privat yang sudah didekripsi');
select ok(not ((:'loaded'::jsonb) -> 'credentials' ? 'token_uri'), 'Alamat token tidak diambil dari file');
select is(public.push_credentials(((:'loaded'::jsonb) ->> 'revision')::bigint) ->> 'unchanged', 'true',
  'Kunci tidak dikirim ulang bila revisi sama');
select is(public.push_heartbeat('notifier-a', '0.2.0', true, 'olt-prod', null, now(),
                                ((:'loaded'::jsonb) ->> 'revision')::bigint) ->> 'queued', '0',
  'Heartbeat melaporkan revisi kredensial yang dimuat');
select is(public.push_heartbeat('notifier-b', '0.1.0', false, null, null, now()) ->> 'queued', '0',
  'Notifier versi lama tetap bisa mengirim heartbeat');
reset role;

select tests.authenticate_agent(:'sinta');
select is((select (i ->> 'credentials_revision')::bigint from jsonb_array_elements(cs_api.push_status() -> 'instances') i
           where i ->> 'instance' = 'notifier-a'), ((:'loaded'::jsonb) ->> 'revision')::bigint,
  'Web bisa melihat apakah notifier sudah memuat kredensial terbaru');
select is((cs_api.push_status() ->> 'credentials_revision')::bigint, ((:'loaded'::jsonb) ->> 'revision')::bigint,
  'Status push memuat revisi kunci yang berlaku');
select throws_ok(format('select cs_api.push_set_credentials(%L)', jsonb_set(:'creds', '{project_id}', '"olt-other"')),
  'PT409', 'push_project_changed', 'Ganti project Firebase harus dikonfirmasi');
select is(cs_api.push_set_credentials(jsonb_set(:'creds', '{project_id}', '"olt-other"'), true) ->> 'project_id',
  'olt-other', 'Project Firebase bisa diganti setelah dikonfirmasi');
select is(cs_api.push_set_credentials(jsonb_set(:'creds', '{project_id}', '"olt-other"')) ->> 'project_id',
  'olt-other', 'Mengganti kunci di project yang sama tanpa konfirmasi');
reset role;

select is((select count(*)::integer from vault.secrets where name = 'push.firebase_service_account'), 1,
  'Kunci baru menimpa kunci lama di Vault');
select is((select details ->> 'previous_project_id' from cs.cs_audit_log
           where action = 'push.credentials_set' and details ->> 'previous_project_id' is not null),
  'olt-prod', 'Audit mencatat project sebelumnya');

select vault.update_secret((select secret_id from private.push_credentials), 'bukan json') as broken \gset
select tests.authenticate_service();
select ok(public.push_credentials() ->> 'error' like 'Kredensial Firebase tersimpan tidak bisa dibuka%',
  'Kunci yang tidak bisa dibuka dilaporkan ke notifier');
reset role;

select secret_id as old_secret from private.push_credentials \gset
select tests.authenticate_agent(:'sinta');
select is(cs_api.push_remove_credentials() ->> 'removed', 'true', 'Super Admin bisa menghapus kredensial');
select ok(cs_api.push_status() -> 'credentials' = 'null'::jsonb
          and (cs_api.push_status() ->> 'credentials_revision')::bigint > ((:'loaded'::jsonb) ->> 'revision')::bigint,
  'Status push tanpa kredensial tetap memuat revisi terbaru');
select throws_ok('select cs_api.push_remove_credentials()', 'PT404', 'push_credentials_missing',
  'Menghapus kredensial yang tidak ada ditolak');
reset role;

select is((select count(*)::integer from vault.secrets where id = :'old_secret'), 0, 'Kunci dihapus dari Vault');
select ok(exists (select 1 from cs.cs_audit_log where action = 'push.credentials_removed'
                  and details ->> 'project_id' = 'olt-other'), 'Penghapusan kredensial tercatat di audit');
select tests.authenticate_service();
select is(public.push_credentials() ->> 'configured', 'false', 'Notifier tahu kredensial sudah dihapus');
reset role;

select * from finish();
rollback;
