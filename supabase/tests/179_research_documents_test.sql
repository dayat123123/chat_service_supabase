begin;
select plan(38);

select tests.create_agent('Sinta Dokumen', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Dokumen', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_agent('Maya Dokumen', '{cs_agent}', '{"general": 1}') as maya \gset
update cs.agents set community_permissions = '{community.post,community.publish}' where user_id = :'rina';
select tests.create_user('rd_resmi') as resmi \gset
select tests.create_user('rd_pembaca') as pembaca \gset
insert into cs.official_accounts (profile_id) values (:'resmi');

create function pg_temp.payload(p_sha text) returns jsonb language sql as $$
  select jsonb_build_object(
    'sha256', p_sha, 'kind', 'financial_report',
    'document', jsonb_build_object('version', 1, 'title', 'Laporan Keuangan Kuartal III 2026', 'headline', 'Laba naik',
                                   'blocks', jsonb_build_array(jsonb_build_object('type', 'paragraph', 'text', 'Isi'))),
    'entity_code', 'WXYZ', 'entity_name', 'PT Tambang Contoh Tbk.', 'period', 'Q3',
    'period_start', '2026-01-01', 'period_end', '2026-09-30', 'audit', 'unaudited', 'currency', 'USD',
    'template', 'general', 'facts', jsonb_build_object('current', jsonb_build_object('SalesAndRevenue', 10)),
    'metrics', jsonb_build_object('version', 1, 'template', 'general'),
    'summary', '$WXYZ — Laporan Keuangan Kuartal III 2026', 'warnings', '[]'::jsonb)
$$;
create function pg_temp.object(p_n integer, p_ext text) returns text language sql as $$
  select format('research/%s1b2c3d4-0000-4000-8000-00000000000%s/file.%s', p_n, p_n, p_ext)
$$;
create function pg_temp.put(p_name text, p_mime text, p_size integer, p_age interval default '0') returns void
language sql as $$
  insert into storage.objects (bucket_id, name, metadata, created_at)
  values ('post-files', p_name, jsonb_build_object('size', p_size, 'mimetype', p_mime), now() - p_age)
$$;
create function pg_temp.ready(p_sha text) returns jsonb language plpgsql as $$
declare
  v_job jsonb := public.research_document_claim('w1', 120);
begin
  return public.research_document_done((v_job ->> 'id')::uuid, 'w1', p_sha);
end;
$$;

select 'application/pdf' as pdf_mime,
       'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' as xlsx_mime \gset

select tests.authenticate_agent(:'sinta');
select cs_api.integration_key_create('Data OLT', '{research}', null, '{}', 600) ->> 'id' as key_a \gset
select cs_api.integration_key_create('Vendor', '{research}', null, '{}', 600) ->> 'id' as key_b \gset
select cs_api.research_save_config(:'resmi', true) is not null as configured \gset
reset role;

select pg_temp.put(pg_temp.object(1, 'pdf'), :'pdf_mime', 2500000);
select pg_temp.put(pg_temp.object(2, 'xlsx'), :'xlsx_mime', 64000);
select pg_temp.put(pg_temp.object(3, 'pdf'), 'application/zip', 1000);
select pg_temp.put(pg_temp.object(4, 'pdf'), :'pdf_mime', 30000000);
select pg_temp.put(pg_temp.object(5, 'pdf'), :'pdf_mime', 1000);
select pg_temp.put(pg_temp.object(6, 'pdf'), :'pdf_mime', 1000);
select pg_temp.put(pg_temp.object(7, 'pdf'), :'pdf_mime', 1000, '2 days');

select tests.authenticate_service();
select public.research_submit(:'key_a', repeat('a', 64), 90000, null) ->> 'id' as file_a \gset
select public.research_document_submit(:'key_a', :'file_a', pg_temp.object(1, 'pdf'), repeat('1', 64),
                                       null, '10.0.0.5') as doc_a \gset
reset role;
update private.research_documents set created_at = created_at - interval '1 hour' where id = (:'doc_a'::jsonb ->> 'id')::uuid;
select tests.authenticate_service();
select is((:'doc_a'::jsonb ->> 'status', :'doc_a'::jsonb ->> 'mime', (:'doc_a'::jsonb ->> 'size_bytes')::integer,
           (:'doc_a'::jsonb ->> 'resubmitted')::boolean)::text,
          ('queued', 'application/pdf', 2500000, false)::text,
  'Dokumen sumber dari API masuk antrean pemeriksaan dengan jenis dan ukuran dari storage');
select ok(:'doc_a'::jsonb -> 'name' = 'null'::jsonb, 'Nama dokumen menunggu laporan selesai diurai bila tidak diisi');
select is(public.research_document_submit(:'key_a', :'file_a', pg_temp.object(6, 'pdf'), repeat('1', 64)) ->> 'id',
          :'doc_a'::jsonb ->> 'id', 'Mengirim ulang dokumen yang sama tidak membuat antrean baru');
select is(public.research_file(:'key_a', :'file_a', null) -> 'documents' -> 0 ->> 'id', :'doc_a'::jsonb ->> 'id',
  'Status file laporan memuat dokumen sumbernya');
select throws_ok(format($$select public.research_document_submit(%L, %L, %L, %L)$$, :'key_b', :'file_a',
                        pg_temp.object(2, 'xlsx'), repeat('2', 64)),
  'PT404', 'file_not_found', 'Dokumen hanya bisa dilampirkan ke file laporan milik key yang sama');
select throws_ok(format($$select public.research_document_submit(%L, %L, %L, 'abc')$$, :'key_a', :'file_a',
                        pg_temp.object(2, 'xlsx')),
  'PT400', 'invalid_sha256', 'Sidik dokumen divalidasi');
select throws_ok(format($$select public.research_document_submit(%L, %L, %L, %L, 'a/b.pdf')$$, :'key_a', :'file_a',
                        pg_temp.object(2, 'xlsx'), repeat('2', 64)),
  'PT400', 'invalid_document_name', 'Nama dokumen divalidasi');
select throws_ok(format($$select public.research_document_submit(%L, %L, %L, %L)$$, :'key_a', :'file_a',
                        pg_temp.object(3, 'pdf'), repeat('3', 64)),
  'PT400', 'invalid_file_type', 'Isi yang tidak sesuai ekstensinya ditolak');
select throws_ok(format($$select public.research_document_submit(%L, %L, %L, %L)$$, :'key_a', :'file_a',
                        pg_temp.object(4, 'pdf'), repeat('4', 64)),
  'PT400', 'file_too_large', 'Dokumen di atas 20 MB ditolak');
select throws_ok(format($$select public.research_document_submit(%L, %L, %L, %L)$$, :'key_a', :'file_a',
                        pg_temp.object(8, 'pdf'), repeat('8', 64)),
  'PT404', 'object_not_found', 'Dokumen yang belum ada di storage ditolak');
select throws_ok(format($$select public.research_document_submit(%L, %L, 'research/x/file.exe', %L)$$, :'key_a', :'file_a',
                        repeat('9', 64)),
  'PT400', 'invalid_object', 'Lokasi dokumen di luar pola ditolak');

select public.research_document_claim('w1', 120) as job_a \gset
select is(:'job_a'::jsonb ->> 'object_name', pg_temp.object(1, 'pdf'), 'Worker mengklaim dokumen untuk diperiksa');
select ok(public.research_document_claim('w2', 120) is null, 'Dokumen yang sedang diperiksa tidak diklaim worker lain');
select throws_ok(format($$select public.research_document_done(%L, 'w1', %L)$$, :'job_a'::jsonb ->> 'id', repeat('f', 64)),
  'PT400', 'checksum_mismatch', 'Sidik hasil pemeriksaan harus sama dengan yang dikirim');
select is(public.research_document_done((:'job_a'::jsonb ->> 'id')::uuid, 'w1', repeat('1', 64)) ->> 'status', 'ready',
  'Dokumen yang lolos pemeriksaan siap dilampirkan');

select public.research_claim('w1', 120) ->> 'id' as job_file \gset
select public.research_complete(:'job_file', 'w1', pg_temp.payload(repeat('a', 64))) #>> '{report,id}' as rep \gset
reset role;
select (select c.post_id from cs.community_posts c join private.research_reports r on r.community_post_id = c.id
        where r.id = :'rep') as public_post \gset
select is((select jsonb_path_query_array(p.attachments, '$[*].type') from public.posts p where p.id = :'public_post'),
  '["file", "card"]'::jsonb, 'Postingan riset terbit dengan dokumen sumber sebelum kartu');
select is((select p.attachments -> 0 -> 'file' from public.posts p where p.id = :'public_post'),
  jsonb_build_object('bucket', 'post-files', 'path', pg_temp.object(1, 'pdf'),
                     'name', 'WXYZ Laporan Keuangan Kuartal III 2026.pdf', 'mime', :'pdf_mime', 'size', 2500000),
  'Nama dokumen dibuat dari emiten dan periode laporan');

select tests.authenticate_service();
select is(public.research_document_submit(:'key_a', :'file_a', pg_temp.object(2, 'xlsx'), repeat('2', 64),
                                          'Data keuangan WXYZ.xlsx') ->> 'name',
  'Data keuangan WXYZ.xlsx', 'Nama dokumen dari pengirim dipakai apa adanya');
select pg_temp.ready(repeat('2', 64)) as ready_b \gset
reset role;
select is((select jsonb_path_query_array(p.attachments, '$[*].file.name') from public.posts p where p.id = :'public_post'),
  jsonb_build_array('WXYZ Laporan Keuangan Kuartal III 2026.pdf', 'Data keuangan WXYZ.xlsx'),
  'Dokumen yang selesai diperiksa setelah terbit ikut ditambahkan ke postingan di Stream');
select is((select jsonb_path_query_array(c.attachments, '$[*].type') from cs.community_posts c
           join private.research_reports r on r.community_post_id = c.id where r.id = :'rep'),
  '["file", "file", "card"]'::jsonb, 'Salinan postingan di Hub ikut diperbarui');

select tests.authenticate_service();
select public.research_document_submit(:'key_a', :'file_a', pg_temp.object(5, 'pdf'), repeat('5', 64)) ->> 'id' as doc_c \gset
select public.research_document_claim('w1', 120) ->> 'id' as job_c \gset
select is(public.research_document_fail(:'job_c', 'w1', 'scanner_unavailable', 'The antivirus scanner could not be reached',
                                        true) ->> 'status', 'queued', 'Gangguan pemindai membuat dokumen dicoba lagi nanti');
reset role;
update private.research_documents set available_at = now() where id = :'doc_c';
select tests.authenticate_service();
select public.research_document_claim('w1', 120) ->> 'id' as job_c2 \gset
select is(public.research_document_fail(:'job_c2', 'w1', 'infected', 'antivirus signature Eicar-Test', false) ->> 'status',
  'rejected', 'Dokumen terinfeksi ditolak');
select is((select d #>> '{error,code}' from jsonb_array_elements(public.research_file(:'key_a', :'file_a', null) -> 'documents') d
           where d ->> 'id' = :'doc_c'), 'infected',
  'Alasan penolakan dokumen terbaca oleh pengirim');
reset role;
select ok(exists (select 1 from private.storage_cleanup_queue where bucket_id = 'post-files'
                  and prefix = regexp_replace(pg_temp.object(5, 'pdf'), '[^/]+$', '') and reason = 'research_infected'),
  'File terinfeksi langsung dijadwalkan untuk dihapus');
select is((select jsonb_array_length(p.attachments) from public.posts p where p.id = :'public_post'), 3,
  'Dokumen yang ditolak tidak muncul di postingan');

select '0c6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b' as up1, '1c6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b' as up2 \gset
select tests.authenticate_agent(:'maya');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('post-files', 'research/%s/file.pdf', %L)$$,
                        :'up1', :'maya'),
  '42501', null, 'Staf tanpa izin Buat postingan tidak bisa mengunggah dokumen riset');
reset role;
select tests.authenticate_agent(:'rina');
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner_id, metadata) values ('post-files', 'research/%s/file.pdf', %L, '{"size": 4000, "mimetype": "application/pdf"}')$$,
                       :'up1', :'rina'),
  'Staf dengan izin Buat postingan bisa mengunggah dokumen riset');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('post-files', 'research/%s/file.docx', %L)$$,
                        :'up2', :'rina'),
  '42501', null, 'Dokumen riset hanya PDF atau XLSX');
select throws_ok(format($$select cs_api.research_add_document(%L, %L)$$, :'rep', pg_temp.object(6, 'pdf')),
  'PT404', 'object_not_found', 'Staf hanya bisa memakai dokumen yang ia unggah sendiri');
select cs_api.research_add_document(:'rep', format('research/%s/file.pdf', :'up1'), 'Laporan lengkap WXYZ.pdf') as added \gset
select is((select d ->> 'status' from jsonb_array_elements(:'added'::jsonb -> 'documents') d
           where d ->> 'name' = 'Laporan lengkap WXYZ.pdf'), 'queued',
  'Dokumen dari Hub ikut diperiksa worker sebelum dilampirkan');
select throws_ok(format($$select cs_api.research_add_document(%L, %L)$$, :'rep', format('research/%s/file.pdf', :'up1')),
  'PT409', 'too_many_documents', 'Maksimal 3 dokumen per laporan');
reset role;
select ok(exists (select 1 from cs.cs_audit_log where action = 'research.document_add' and details ->> 'report' = :'rep'),
  'Penambahan dokumen tercatat di jejak audit');

select tests.authenticate_agent(:'rina');
select cs_api.research_remove_document((:'doc_a'::jsonb ->> 'id')::uuid) as removed \gset
reset role;
select is((select jsonb_path_query_array(p.attachments, '$[*].file.name') from public.posts p where p.id = :'public_post'),
  jsonb_build_array('Data keuangan WXYZ.xlsx'),
  'Dokumen yang dihapus staf hilang dari postingan di Stream');

update private.research_documents set available_at = now() + interval '1 hour'
 where object_name = format('research/%s/file.pdf', :'up1');
select tests.authenticate_agent(:'sinta');
select cs_api.research_save_config(:'resmi', false) is not null as manual \gset
reset role;
select tests.authenticate_service();
select public.research_submit(:'key_b', repeat('b', 64), 90000, null) ->> 'id' as file_b \gset
select public.research_document_submit(:'key_b', :'file_b', pg_temp.object(6, 'pdf'), repeat('6', 64)) ->> 'id' as doc_d \gset
select pg_temp.ready(repeat('6', 64)) as ready_d \gset
select public.research_claim('w1', 120) ->> 'id' as job_b \gset
select public.research_complete(:'job_b', 'w1', pg_temp.payload(repeat('b', 64)) || '{"period_start": "2026-01-01", "period_end": "2026-06-30", "period": "Q2"}')
  #>> '{report,post,id}' as pending_post \gset
reset role;
update cs.community_posts set created_by = :'maya' where id = :'pending_post';
update cs.agents set community_permissions = '{community.post}' where user_id = :'maya';
select c.attachments as pending_atts from cs.community_posts c where c.id = :'pending_post' \gset
select tests.authenticate_agent(:'rina');
select cs_api.community_review_post(:'pending_post', false, 'Perlu disunting') is not null as reviewed \gset
reset role;
select tests.authenticate_agent(:'maya');
select is(cs_api.community_save_post(:'pending_post', :'resmi', 'post', null, 'Ringkasan disunting',
  :'pending_atts'::jsonb) -> 'attachments' -> 0 -> 'file' ->> 'path',
  pg_temp.object(6, 'pdf'), 'Staf tetap bisa menyunting postingan riset yang membawa dokumen sumber');
select throws_ok(format($$select cs_api.community_save_post(%L, %L, 'post', null, 'x', %L)$$, :'pending_post', :'resmi',
  jsonb_build_array(jsonb_build_object('type', 'file', 'file', jsonb_build_object('path', pg_temp.object(7, 'pdf'),
                                                                                  'name', 'Lain.pdf')))),
  'PT400', 'invalid_file', 'Dokumen riset yang belum lolos pemeriksaan tidak bisa dipasang manual');
reset role;

select tests.authenticate_as(:'pembaca');
select throws_ok(format($$insert into public.posts (author_id, body, attachments) values (%L, 'Palsu', %L)$$, :'pembaca',
  jsonb_build_array(jsonb_build_object('type', 'file', 'file', jsonb_build_object('bucket', 'post-files',
                                                                                  'path', pg_temp.object(6, 'pdf'))))),
  'PT400', 'invalid_attachments', 'Pengguna biasa tidak bisa melampirkan dokumen riset ke postingannya');
select throws_ok(format($$select public.research_document_claim('x')$$), '42501', null,
  'Antrean dokumen hanya untuk layanan riset');
reset role;

update storage.objects set created_at = now() - interval '2 days'
 where bucket_id = 'post-files' and name in (pg_temp.object(6, 'pdf'), pg_temp.object(2, 'xlsx'));
select private.post_files_maintenance() as swept \gset
select is((select array_agg(prefix order by prefix) from private.storage_cleanup_queue
           where bucket_id = 'post-files' and reason = 'post_file_unused' and done_at is null),
  array[regexp_replace(pg_temp.object(7, 'pdf'), '[^/]+$', '')],
  'Dokumen riset yang masih dipakai tidak ikut dibersihkan, unggahan yatim dibersihkan');

select * from finish();
rollback;
