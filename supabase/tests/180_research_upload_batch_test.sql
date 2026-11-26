begin;
select plan(12);

select tests.create_agent('Sinta Batch', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina Batch', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_agent('Budi Batch', '{cs_agent}', '{"general": 1}') as budi \gset
update cs.agents set community_permissions = '{community.post}' where user_id in (:'rina', :'budi');
select tests.create_user('rb_resmi') as resmi \gset
insert into cs.official_accounts (profile_id) values (:'resmi');

select format('hub/%s/0d6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/report.zip', :'rina') as zip_a,
       format('hub/%s/1d6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/report.zip', :'rina') as zip_b,
       'research/2d6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/file.pdf' as pdf,
       'research/3d6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/file.xlsx' as xlsx,
       'research/4d6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/file.pdf' as budi_pdf \gset

insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('financial-reports', :'zip_a', :'rina', '{"size": 90000}'),
  ('financial-reports', :'zip_b', :'rina', '{"size": 90000}'),
  ('post-files', :'pdf', :'rina', '{"size": 2500000, "mimetype": "application/pdf"}'),
  ('post-files', :'xlsx', :'rina',
   '{"size": 64000, "mimetype": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}'),
  ('post-files', :'budi_pdf', :'budi', '{"size": 1000, "mimetype": "application/pdf"}');

select tests.authenticate_agent(:'sinta');
select cs_api.research_save_config(:'resmi', true) is not null as configured \gset
reset role;

select tests.authenticate_agent(:'rina');
select throws_ok(format($$select cs_api.research_upload(%L, %L)$$, :'zip_b',
                        jsonb_build_array(jsonb_build_object('object', :'pdf'), jsonb_build_object('object', :'budi_pdf'))),
  'PT404', 'object_not_found', 'Dokumen milik staf lain membatalkan seluruh unggahan');
select throws_ok(format($$select cs_api.research_upload(%L, %L)$$, :'zip_b',
                        jsonb_build_array(jsonb_build_object('object', :'pdf'), jsonb_build_object('object', :'xlsx'),
                                          jsonb_build_object('object', :'pdf'), jsonb_build_object('object', :'xlsx'))),
  'PT409', 'too_many_documents', 'Maksimal 3 dokumen per laporan dalam satu unggahan');
select throws_ok(format($$select cs_api.research_upload(%L, %L)$$, :'zip_b',
                        jsonb_build_array(jsonb_build_object('object', :'pdf', 'name', 'a/b.pdf'))),
  'PT400', 'invalid_document_name', 'Nama dokumen divalidasi');
reset role;
select is((select count(*)::integer from private.research_files where object_name = :'zip_b')
          + (select count(*)::integer from private.research_documents), 0,
  'Unggahan yang gagal tidak meninggalkan file maupun dokumen');

select tests.authenticate_agent(:'rina');
select cs_api.research_upload(:'zip_a', jsonb_build_array(
  jsonb_build_object('object', :'pdf'),
  jsonb_build_object('object', :'xlsx', 'name', 'Data keuangan.xlsx'))) ->> 'id' as file_a \gset
select ok(cs_api.research_upload(:'zip_b') ->> 'status' = 'queued', 'Unggahan tanpa dokumen tetap berjalan seperti biasa');
reset role;
select is((select array_agg(d.status || ':' || coalesce(d.name, '-') order by d.object_name)
           from private.research_documents d where d.file_id = :'file_a'),
  array['queued:-', 'queued:Data keuangan.xlsx'], 'Zip dan dokumennya didaftarkan bersama');
select ok(exists (select 1 from cs.cs_audit_log where action = 'research.upload'
                  and details ->> 'file' = :'file_a' and (details ->> 'documents')::integer = 2),
  'Jumlah dokumen tercatat di jejak audit');

select tests.authenticate_service();
select is(public.research_claim('w1', 120) ->> 'object_name', :'zip_b',
  'Zip yang dokumennya belum diperiksa dilewati dulu');
select ok(public.research_claim('w2', 120) is null, 'Tidak ada zip lain yang siap diproses');
select public.research_document_claim('w1', 120) ->> 'id' as doc_1 \gset
select public.research_document_done(:'doc_1', 'w1', repeat('1', 64)) is not null as d1 \gset
select ok(public.research_claim('w2', 120) is null, 'Zip tetap menunggu selama masih ada dokumen yang diperiksa');
select public.research_document_claim('w1', 120) ->> 'id' as doc_2 \gset
select public.research_document_done(:'doc_2', 'w1', repeat('2', 64)) is not null as d2 \gset
select is(public.research_claim('w2', 120) ->> 'id', :'file_a', 'Zip diproses setelah semua dokumennya selesai diperiksa');
select public.research_complete(:'file_a', 'w2', jsonb_build_object(
  'sha256', repeat('a', 64), 'kind', 'financial_report',
  'document', jsonb_build_object('version', 1, 'title', 'Laporan Keuangan Kuartal III 2026', 'headline', 'Laba naik',
                                 'blocks', jsonb_build_array(jsonb_build_object('type', 'paragraph', 'text', 'Isi'))),
  'entity_code', 'ADES', 'entity_name', 'Akasha Wira International Tbk', 'period', 'Q3',
  'period_start', '2026-01-01', 'period_end', '2026-09-30', 'audit', 'unaudited', 'currency', 'IDR',
  'template', 'general', 'facts', jsonb_build_object('current', jsonb_build_object('SalesAndRevenue', 10)),
  'metrics', jsonb_build_object('version', 1), 'summary', '$ADES — Laporan Keuangan Kuartal III 2026',
  'warnings', '[]'::jsonb)) #>> '{report,id}' as rep \gset
reset role;
select is((select jsonb_path_query_array(p.attachments, '$[*].type')
           from public.posts p join cs.community_posts c on c.post_id = p.id
           join private.research_reports r on r.community_post_id = c.id where r.id = :'rep'),
  '["file", "file", "card"]'::jsonb, 'Postingan langsung terbit dengan dokumen dari unggahan yang sama');

select * from finish();
rollback;
