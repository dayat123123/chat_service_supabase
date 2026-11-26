begin;
select plan(63);

select tests.create_agent('Sinta Riset', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Riset', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_agent('Maya Riset', '{cs_agent}', '{"general": 1}') as maya \gset
update cs.agents set community_permissions = '{community.post,community.publish}' where user_id = :'rina';
select tests.create_user('fr_resmi') as resmi \gset
insert into cs.official_accounts (profile_id) values (:'resmi');

create function pg_temp.payload(p_sha text, p_period text, p_start date, p_end date, p_warnings jsonb default '[]')
returns jsonb language sql as $$
  select jsonb_build_object(
    'sha256', p_sha, 'entity_code', 'ABCD', 'entity_name', 'PT Bank Contoh Tbk.', 'sector', 'G. Financials',
    'subsector', 'G1. Banks', 'period', p_period, 'period_start', p_start, 'period_end', p_end, 'audit', 'unaudited',
    'currency', 'IDR', 'template', 'bank',
    'facts', jsonb_build_object('current', jsonb_build_object('InterestIncome', 90), 'prior', '{}'::jsonb,
                                'current_end', jsonb_build_object('Assets', 1500), 'prior_year_end', '{}'::jsonb),
    'metrics', jsonb_build_object('version', 1, 'template', 'bank', 'flows', '[]'::jsonb),
    'summary', format('$ABCD — Laporan Keuangan %s %s (belum diaudit)', p_period, extract(year from p_end)),
    'warnings', p_warnings)
$$;
create function pg_temp.process(p_report jsonb) returns jsonb language plpgsql as $$
declare
  v_job jsonb := public.finreport_claim('w1', 120);
begin
  return public.finreport_complete((v_job ->> 'id')::uuid, 'w1', p_report);
end;
$$;

select tests.authenticate_agent(:'sinta');
select cs_api.integration_key_create('Data OLT', '{financial_report}', null, '{}', 600) as created \gset
select (:'created'::jsonb ->> 'id') as key_a \gset
select cs_api.integration_key_create('Vendor data', '{financial_report,health_read}', null, '{}', 600) ->> 'id' as key_b \gset
select cs_api.integration_key_create('Notif OLT', '{notify}', null, '{}', 600) ->> 'id' as key_notify \gset
select is(:'created'::jsonb -> 'scopes', '["financial_report"]'::jsonb, 'Super Admin membuat key khusus kirim laporan keuangan');
reset role;
select ok(public.integration_authenticate(encode(sha256(convert_to(:'created'::jsonb ->> 'key', 'UTF8')), 'hex'), null)
          -> 'scopes' ? 'financial_report', 'Izin laporan keuangan dikenali layanan finreport');
select ok(private.health_service_label('finreport') = 'Riset laporan keuangan'
          and private.setting_json('health.expected_services', '[]') ? 'finreport',
  'Layanan finreport tampil di Kesehatan sistem dan wajib mengirim heartbeat');
select ok(exists (select 1 from storage.buckets where id = 'financial-reports' and not public
                  and file_size_limit = 8388608 and allowed_mime_types = array['application/zip']),
  'Bucket laporan keuangan privat, hanya zip, maksimal 8 MiB');

select tests.authenticate_service();
select public.finreport_submit(:'key_a', repeat('a', 64), 90000, '10.0.0.5') as sub_a \gset
select is(:'sub_a'::jsonb ->> 'status', 'queued', 'File baru dari API masuk antrean');
select ok(not (:'sub_a'::jsonb ->> 'resubmitted')::boolean and :'sub_a'::jsonb -> 'report' = 'null'::jsonb
          and (:'sub_a'::jsonb ->> 'api_version') = '1', 'Respons memuat api_version tanpa laporan selama antre');
select is(public.finreport_submit(:'key_a', upper(repeat('a', 64)), 90000, '10.0.0.5') ->> 'id', :'sub_a'::jsonb ->> 'id',
  'Mengirim ulang file yang sama dengan key yang sama tidak membuat antrean baru');
select throws_ok(format($$select public.finreport_submit(%L, %L, 10, null)$$, :'key_notify', repeat('b', 64)),
  'PT403', 'scope_forbidden', 'Key tanpa izin laporan keuangan ditolak');
select throws_ok(format($$select public.finreport_submit(%L, 'abc', 10, null)$$, :'key_a'),
  'PT400', 'invalid_sha256', 'Sidik file yang tidak valid ditolak');
select throws_ok(format($$select public.finreport_submit(%L, %L, 9000000, null)$$, :'key_a', repeat('b', 64)),
  'PT400', 'invalid_size', 'File di atas 8 MiB ditolak');
select is(public.finreport_related('ABCD', '2026-01-01', '2026-06-30'),
  jsonb_build_object('previous', null, 'prior_year', null), 'Belum ada laporan pembanding');

select public.finreport_claim('w1', 120) as job \gset
select is(:'job'::jsonb ->> 'object_name', 'api/' || repeat('a', 64) || '/report.zip', 'Worker mengklaim file beserta lokasinya');
select ok(public.finreport_claim('w2', 120) is null, 'File yang sedang diproses tidak diklaim worker lain');
select throws_ok(format($$select public.finreport_complete(%L, 'w2', '{}')$$, :'job'::jsonb ->> 'id'),
  'PT409', 'not_claimed', 'Worker lain tidak bisa menyelesaikan file milik worker ini');
select throws_ok(format($$select public.finreport_complete(%L, 'w1', %L)$$, :'job'::jsonb ->> 'id',
                        pg_temp.payload(repeat('b', 64), 'Q2', '2026-01-01', '2026-06-30')),
  'PT400', 'checksum_mismatch', 'Sidik hasil worker harus sama dengan file yang diterima');
select throws_ok(format($$select public.finreport_complete(%L, 'w1', %L)$$, :'job'::jsonb ->> 'id',
                        pg_temp.payload(repeat('a', 64), 'Q5', '2026-01-01', '2026-06-30')),
  'PT400', 'invalid_report', 'Data laporan yang tidak valid ditolak');
select public.finreport_complete((:'job'::jsonb ->> 'id')::uuid, 'w1',
  pg_temp.payload(repeat('a', 64), 'Q2', '2026-01-01', '2026-06-30')) as done_a \gset
select is(:'done_a'::jsonb ->> 'status', 'done', 'Laporan Q2 tersimpan');
select (:'done_a'::jsonb #>> '{report,id}') as rep_a \gset
select is(:'done_a'::jsonb #> '{report,warnings}', '["no_official_account"]'::jsonb,
  'Tanpa akun resmi, laporan tetap tersimpan dengan peringatan dan tanpa postingan');
select is(public.finreport_file(:'key_a', (:'sub_a'::jsonb ->> 'id')::uuid, null) #>> '{report,entity_code}', 'ABCD',
  'Pengirim bisa membaca status dan hasil urai file miliknya');
select throws_ok(format($$select public.finreport_file(%L, %L, null)$$, :'key_b', :'sub_a'::jsonb ->> 'id'),
  'PT404', 'file_not_found', 'File milik key lain tidak bisa dibaca');
reset role;

select tests.authenticate_agent(:'rina');
select throws_ok(format($$select cs_api.finreport_save_config(%L, false)$$, :'resmi'),
  'PT403', null, 'Hanya Super Admin yang mengatur akun resmi riset');
reset role;
select tests.authenticate_agent(:'sinta');
select is(cs_api.finreport_save_config(:'resmi', false) #>> '{official_account,id}', :'resmi',
  'Super Admin memilih akun resmi untuk ringkasan laporan');
reset role;
select ok(exists (select 1 from cs.cs_audit_log where action = 'finreport.config'
                  and details #>> '{official_account,to}' = :'resmi'), 'Perubahan pengaturan tercatat di jejak audit');

select tests.authenticate_service();
select public.finreport_submit(:'key_a', repeat('c', 64), 90000, null) ->> 'id' as file_c \gset
select pg_temp.process(pg_temp.payload(repeat('c', 64), 'Q3', '2025-01-01', '2025-09-30')) #>> '{report,id}' as rep_c \gset
select public.finreport_submit(:'key_a', repeat('d', 64), 90000, null) ->> 'id' as file_d \gset
select pg_temp.process(pg_temp.payload(repeat('d', 64), 'Q3', '2026-01-01', '2026-09-30')) as done_d \gset
select (:'done_d'::jsonb #>> '{report,id}') as rep_d \gset
select is(public.finreport_related('ABCD', '2026-01-01', '2026-09-30') #>> '{previous,id}', :'rep_a',
  'Pembanding kuartal sebelumnya adalah laporan kumulatif terakhir di tahun buku yang sama');
select is(public.finreport_related('ABCD', '2026-01-01', '2026-09-30') #>> '{prior_year,id}', :'rep_c',
  'Pembanding tahun lalu adalah laporan periode yang sama tahun sebelumnya');
select ok(public.finreport_related('ABCD', '2026-01-01', '2026-09-30') #> '{previous,facts,current}' ? 'InterestIncome',
  'Pembanding membawa angka hasil urai');
select is(:'done_d'::jsonb #>> '{report,post,status}', 'pending', 'Ringkasan laporan menjadi postingan resmi menunggu persetujuan');
reset role;
select is((select row(c.account_id, c.created_by, c.kind, c.status, left(c.body, 6))::text from cs.community_posts c
           join private.finreport_reports r on r.community_post_id = c.id where r.id = :'rep_d'),
  row(:'resmi'::uuid, :'sinta'::uuid, 'post', 'pending', '$ABCD ')::text,
  'Postingan atas nama akun resmi, diajukan oleh pembuat key, dengan cashtag emiten');

select tests.authenticate_service();
select public.finreport_submit(:'key_b', repeat('d', 64), 90000, null) as dup_api \gset
select is(:'dup_api'::jsonb ->> 'status', 'duplicate', 'File yang sudah pernah diurai dari key lain langsung ditandai duplikat');
select is(:'dup_api'::jsonb #>> '{report,id}', :'rep_d', 'Duplikat menunjuk ke laporan yang sudah ada');
reset role;

select '0b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b' as up1, '1b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b' as up2 \gset
select tests.authenticate_agent(:'rina');
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner_id, metadata) values ('financial-reports', 'hub/%s/%s/report.zip', %L, '{"size": 90000}')$$,
                       :'rina', :'up1', :'rina'),
  'Staf dengan izin Buat postingan bisa mengunggah zip laporan ke foldernya');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('financial-reports', 'hub/%s/%s/report.zip', %L)$$,
                        :'sinta', :'up2', :'rina'),
  '42501', null, 'Staf tidak bisa mengunggah ke folder staf lain');
select is(cs_api.finreport_upload(format('hub/%s/%s/report.zip', :'rina', :'up1')) ->> 'status', 'queued',
  'Unggahan Hub masuk antrean yang sama');
select throws_ok(format($$select cs_api.finreport_upload('hub/%s/%s/report.zip')$$, :'rina', :'up1'),
  'PT409', 'already_submitted', 'File yang sama tidak bisa diajukan dua kali');
select throws_ok(format($$select cs_api.finreport_upload('hub/%s/%s/report.zip')$$, :'rina', :'up2'),
  'PT404', 'object_not_found', 'Hanya file yang benar-benar terunggah yang bisa diajukan');
reset role;
select tests.authenticate_agent(:'maya');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('financial-reports', 'hub/%s/%s/report.zip', %L)$$,
                        :'maya', :'up2', :'maya'),
  '42501', null, 'Staf tanpa izin komunitas tidak bisa mengunggah laporan');
select throws_ok($$select cs_api.finreport_files()$$, 'PT403', 'community_forbidden', 'Staf tanpa izin komunitas tidak melihat daftar laporan');
reset role;

select tests.authenticate_service();
select is(pg_temp.process(pg_temp.payload(repeat('d', 64), 'Q3', '2026-01-01', '2026-09-30')) ->> 'status', 'duplicate',
  'Unggahan Hub yang isinya sudah ada ditandai duplikat setelah diproses');
select public.finreport_submit(:'key_a', repeat('e', 64), 90000, null) ->> 'id' as file_e \gset
select pg_temp.process(pg_temp.payload(repeat('e', 64), 'Q3', '2026-01-01', '2026-09-30')) #>> '{report,id}' as rep_e \gset
reset role;
select ok((select superseded_at is not null from private.finreport_reports where id = :'rep_d')
          and (select c.status from cs.community_posts c join private.finreport_reports r on r.community_post_id = c.id
               where r.id = :'rep_d') = 'cancelled',
  'Revisi menggantikan laporan lama dan membatalkan postingannya yang belum terbit');
select ok((select warnings @> jsonb_build_array(jsonb_build_object('code', 'revision', 'supersedes', :'rep_d'))
           and community_post_id is not null from private.finreport_reports where id = :'rep_e'),
  'Laporan revisi diberi peringatan dan postingan baru');

select tests.authenticate_service();
select public.finreport_submit(:'key_a', repeat('f', 64), 90000, null) ->> 'id' as file_f \gset
select public.finreport_claim('w1', 120) ->> 'id' as claimed_f \gset
select is(public.finreport_fail(:'claimed_f', 'w1', 'not_zip', 'zip: not a valid zip file', false) ->> 'status', 'rejected',
  'File rusak ditolak tanpa dicoba ulang');
select is(public.finreport_file(:'key_a', :'file_f', null) -> 'error',
  jsonb_build_object('code', 'not_zip', 'detail', 'zip: not a valid zip file'), 'Alasan penolakan terbaca oleh pengirim');
select public.finreport_submit(:'key_a', repeat('1', 64), 90000, null) ->> 'id' as file_g \gset
select public.finreport_claim('w1', 120) ->> 'id' as claimed_g \gset
select is(public.finreport_fail(:'claimed_g', 'w1', 'storage_unavailable', 'Storage could not be reached', true) ->> 'status',
  'queued', 'Gangguan sementara membuat file dicoba lagi nanti');
select ok(public.finreport_claim('w1', 120) is null, 'File yang menunggu jeda belum bisa diklaim');
reset role;
update private.finreport_files set attempts = 5, available_at = now() where id = :'file_g';
select tests.authenticate_service();
select ok(public.finreport_claim('w1', 120) is null, 'File yang sudah 5 kali gagal tidak diklaim lagi');
reset role;
select is((select error_code from private.finreport_files where id = :'file_g'), 'too_many_attempts',
  'File yang terus gagal akhirnya ditolak');

select tests.authenticate_service();
select public.finreport_submit(:'key_a', repeat('2', 64), 90000, null) ->> 'id' as file_h \gset
select public.finreport_claim('w1', 120) ->> 'id' as claimed_h \gset
select public.finreport_fail(:'claimed_h', 'w1', 'infected', 'antivirus signature Eicar-Test', false) as infected \gset
reset role;
select ok(exists (select 1 from private.storage_cleanup_queue where bucket_id = 'financial-reports'
                  and prefix = 'api/' || repeat('2', 64) || '/' and done_at is null),
  'File terinfeksi langsung dijadwalkan untuk dihapus');

insert into storage.objects (bucket_id, name, metadata, created_at) values
  ('financial-reports', 'api/' || repeat('f', 64) || '/report.zip', '{"size": 10}', now() - interval '2 hours'),
  ('financial-reports', 'api/' || repeat('2', 64) || '/report.zip', '{"size": 10}', now() - interval '2 hours'),
  ('financial-reports', 'api/' || repeat('e', 64) || '/report.zip', '{"size": 10}', now() - interval '2 hours'),
  ('financial-reports', 'api/' || repeat('9', 64) || '/report.zip', '{"size": 10}', now() - interval '2 hours'),
  ('financial-reports', 'api/' || repeat('8', 64) || '/report.zip', '{"size": 10}', now());
select private.finreport_maintenance() as swept \gset
select is((select array_agg(substr(prefix, 5, 1) order by prefix) from private.storage_cleanup_queue
           where bucket_id = 'financial-reports' and done_at is null),
  array['2', '9'], 'Pembersih hanya menghapus file yatim dan terinfeksi, file laporan dan file ditolak tetap disimpan');

select count(*) as with_report from private.finreport_files where report_id is not null \gset
select tests.authenticate_agent(:'rina');
select cs_api.finreport_files() as list \gset
select ok(jsonb_array_length(:'list'::jsonb -> 'items') >= 8 and (:'list'::jsonb #>> '{config,official_account,id}') = :'resmi'
          and (:'list'::jsonb #>> '{counts,rejected}')::integer = 3, 'Hub menampilkan file, pengaturan, dan ringkasan status');
select is((select count(*)::integer from jsonb_array_elements(cs_api.finreport_files(null, 'abcd') -> 'items')),
  :'with_report'::integer,
  'Daftar bisa disaring per kode emiten');
select ok((select bool_and((i ->> 'retryable')::boolean = (i ->> 'id' = :'file_f'))
           from jsonb_array_elements(cs_api.finreport_files('rejected') -> 'items') i),
  'Hanya file ditolak yang masih punya file aslinya dan tidak terinfeksi yang bisa diproses ulang');
select cs_api.finreport_report(:'rep_e') as detail \gset
select ok((:'detail'::jsonb ->> 'summary') like '$ABCD%' and (:'detail'::jsonb #>> '{post,status}') = 'pending'
          and (:'detail'::jsonb #>> '{supersedes,id}') = :'rep_d'
          and jsonb_array_length(:'detail'::jsonb -> 'history') = 2,
  'Detail laporan memuat ringkasan, postingan, versi sebelumnya, dan riwayat emiten');
select is(cs_api.finreport_create_post(:'rep_a') #>> '{post,created_by,id}', :'rina',
  'Staf bisa membuat postingan untuk laporan yang belum punya postingan');
select throws_ok(format($$select cs_api.finreport_create_post(%L)$$, :'rep_a'),
  'PT409', 'post_exists', 'Laporan yang sudah punya postingan aktif tidak dibuatkan lagi');
select is(cs_api.finreport_retry(:'file_f') ->> 'status', 'queued', 'File ditolak bisa diproses ulang dari Hub');
select throws_ok(format($$select cs_api.finreport_retry(%L)$$, :'file_h'),
  'PT409', 'not_retryable', 'File terinfeksi tidak bisa diproses ulang');
reset role;

select tests.authenticate_agent(:'sinta');
select cs_api.finreport_save_config(:'resmi', true) as cfg \gset
reset role;
select tests.authenticate_service();
select public.finreport_claim('w1', 120) ->> 'id' as requeued_f \gset
select is(:'requeued_f'::uuid, :'file_f'::uuid, 'File yang diproses ulang diklaim kembali oleh worker');
select public.finreport_complete(:'requeued_f', 'w1', pg_temp.payload(repeat('f', 64), 'FY', '2025-01-01', '2025-12-31')) as auto_ok \gset
select public.finreport_submit(:'key_a', repeat('3', 64), 90000, null) ->> 'id' as file_w \gset
select pg_temp.process(pg_temp.payload(repeat('3', 64), 'FY', '2024-01-01', '2024-12-31',
  '[{"code": "restated", "lines": ["other_operating_income"]}]')) as auto_warn \gset
select is(:'auto_ok'::jsonb #>> '{report,post,status}', 'published', 'Posting otomatis menerbitkan laporan tanpa peringatan');
select is(:'auto_warn'::jsonb #>> '{report,post,status}', 'pending', 'Laporan dengan peringatan tetap menunggu persetujuan');
reset role;
select ok(exists (select 1 from public.posts p join private.finreport_reports r on true
                  join cs.community_posts c on c.id = r.community_post_id and c.post_id = p.id
                  where r.sha256 = repeat('f', 64) and p.author_id = :'resmi'),
  'Postingan terbit di Stream atas nama akun resmi');

update private.settings set value = '1' where key = 'finreport.files_per_hour';
select tests.authenticate_service();
select throws_ok(format($$select public.finreport_submit(%L, %L, 10, null)$$, :'key_b', repeat('4', 64)),
  'PT429', 'rate_limited', 'Batas file per key per jam berlaku');
reset role;

select ok(not has_function_privilege('authenticated', 'public.finreport_claim(text, integer)', 'execute')
          and not has_function_privilege('anon', 'public.finreport_submit(uuid, text, integer, text)', 'execute')
          and has_function_privilege('authenticated', 'cs_api.finreport_upload(text)', 'execute'),
  'RPC worker hanya untuk service_role, RPC Hub untuk staf');
select ok(exists (select 1 from cron.job where jobname = 'finreport-maintenance'), 'Pembersih file laporan dijadwalkan tiap jam');

select * from finish();
rollback;
