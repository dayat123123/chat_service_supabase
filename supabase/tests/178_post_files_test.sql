begin;
select plan(18);

select tests.create_agent('Rina Dokumen', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_agent('Budi Dokumen', '{cs_agent}', '{"general": 1}') as budi \gset
select tests.create_agent('Maya Dokumen', '{cs_agent}', '{"general": 1}') as maya \gset
update cs.agents set community_permissions = '{community.post}' where user_id = :'rina';
update cs.agents set community_permissions = '{community.publish}' where user_id = :'budi';
select tests.create_user('dok_resmi') as resmi \gset
select tests.create_user('dok_lain') as lain \gset
select tests.create_user('dok_pembaca') as pembaca \gset
insert into cs.official_accounts (profile_id) values (:'resmi'), (:'lain');

select :'resmi' || '/0b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/file.pdf' as pdf,
       :'resmi' || '/1b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/file.xlsx' as xlsx,
       :'resmi' || '/2b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/file.pdf' as fakepdf,
       :'resmi' || '/3b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/file.pdf' as bigpdf,
       :'resmi' || '/4b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/file.pdf' as orphan,
       :'lain' || '/5b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/file.pdf' as otherpdf \gset

select ok(exists (select 1 from storage.buckets where id = 'post-files' and not public and file_size_limit = 20971520
                  and allowed_mime_types @> array['application/pdf', 'text/csv']
                  and not ('application/vnd.ms-excel' = any (allowed_mime_types))),
  'Bucket dokumen postingan privat, maksimal 20 MB, tanpa format lama yang bisa memuat makro');

select tests.authenticate_agent(:'rina');
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner_id, metadata) values ('post-files', %L, %L, '{"size": 120000, "mimetype": "application/pdf"}')$$,
                       :'pdf', :'rina'),
  'Staf penulis postingan resmi bisa mengunggah dokumen ke folder akun resmi');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('post-files', %L, %L)$$,
                        :'resmi' || '/6b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/file.exe', :'rina'),
  '42501', null, 'Ekstensi di luar daftar ditolak storage');
reset role;
select tests.authenticate_agent(:'maya');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner_id) values ('post-files', %L, %L)$$,
                        :'resmi' || '/7b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/file.pdf', :'maya'),
  '42501', null, 'Staf tanpa izin postingan resmi tidak bisa mengunggah dokumen');
reset role;

insert into storage.objects (bucket_id, name, metadata, created_at) values
  ('post-files', :'xlsx', '{"size": 64000, "mimetype": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}', now()),
  ('post-files', :'fakepdf', '{"size": 1000, "mimetype": "application/zip"}', now()),
  ('post-files', :'bigpdf', '{"size": 30000000, "mimetype": "application/pdf"}', now()),
  ('post-files', :'orphan', '{"size": 1000, "mimetype": "application/pdf"}', now() - interval '2 days'),
  ('post-files', :'otherpdf', '{"size": 1000, "mimetype": "application/pdf"}', now());

create function pg_temp.file(p_path text, p_name text) returns jsonb language sql as $$
  select jsonb_build_object('type', 'file', 'file', jsonb_build_object('path', p_path, 'name', p_name,
                                                                      'size', 1, 'mime', 'image/png'))
$$;

select tests.authenticate_agent(:'rina');
select cs_api.community_save_post(null, :'resmi', 'post', null, 'Laporan tahunan dan data pendukung $BBCA',
  jsonb_build_array(pg_temp.file(:'pdf', '  Laporan Tahunan 2025.pdf '), pg_temp.file(:'xlsx', 'Data.xlsx'))) as saved \gset
select (:'saved'::jsonb ->> 'id') as post \gset
select is(:'saved'::jsonb -> 'attachments' -> 0,
  jsonb_build_object('type', 'file', 'file', jsonb_build_object('bucket', 'post-files', 'path', :'pdf',
                     'name', 'Laporan Tahunan 2025.pdf', 'mime', 'application/pdf', 'size', 120000)),
  'Dokumen disimpan dengan nama dirapikan, jenis dan ukuran dari server');
select is(jsonb_array_length(:'saved'::jsonb -> 'attachments'), 2, 'Beberapa dokumen bisa dilampirkan');
select is(jsonb_array_length(cs_api.community_save_post(null, :'resmi', 'post', null, '',
  jsonb_build_array(jsonb_build_object('type', 'card', 'document', jsonb_build_object('version', 1, 'title', 'Ringkasan',
    'headline', 'Kinerja tahunan', 'blocks', jsonb_build_array(jsonb_build_object('type', 'paragraph', 'text', 'Isi')))),
    pg_temp.file(:'pdf', 'Laporan.pdf'), jsonb_build_object('path', 'posts/' || :'resmi' || '/grafik.png'))) -> 'attachments'),
  3, 'Dokumen bisa digabung dengan kartu dan gambar');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'post', null, 'x', %L)$$, :'resmi',
  jsonb_build_array(pg_temp.file(:'fakepdf', 'Palsu.pdf'))), 'PT400', 'invalid_file_type',
  'Isi file yang tidak sesuai ekstensinya ditolak');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'post', null, 'x', %L)$$, :'resmi',
  jsonb_build_array(pg_temp.file(:'bigpdf', 'Besar.pdf'))), 'PT400', 'file_too_large', 'Dokumen terlalu besar ditolak');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'post', null, 'x', %L)$$, :'resmi',
  jsonb_build_array(pg_temp.file(:'otherpdf', 'Lain.pdf'))), 'PT400', 'invalid_file',
  'Dokumen milik akun resmi lain tidak bisa dipakai');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'post', null, 'x', %L)$$, :'resmi',
  jsonb_build_array(pg_temp.file(:'resmi' || '/9b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b/file.pdf', 'Hilang.pdf'))),
  'PT404', 'file_not_found', 'Dokumen yang belum terunggah ditolak');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'post', null, 'x', %L)$$, :'resmi',
  jsonb_build_array(pg_temp.file(:'pdf', 'A.pdf'), pg_temp.file(:'pdf', 'B.pdf'))), 'PT400', 'duplicate_file',
  'Dokumen yang sama tidak bisa dipasang dua kali');
select throws_ok(format($$select cs_api.community_save_post(null, %L, 'post', null, 'x', %L)$$, :'resmi',
  jsonb_build_array(pg_temp.file(:'pdf', 'a/b.pdf'))), 'PT400', 'invalid_file_name', 'Nama dokumen divalidasi');
select is(cs_api.community_submit_post(:'post') ->> 'status', 'pending', 'Postingan berdokumen diajukan');
reset role;

select tests.authenticate_agent(:'budi');
select is(cs_api.community_review_post(:'post', true) ->> 'status', 'published', 'Postingan berdokumen terbit setelah disetujui');
reset role;
select is((select jsonb_array_length(p.attachments) from public.posts p join cs.community_posts c on c.post_id = p.id
           where c.id = :'post'), 2, 'Dokumen ikut ke postingan di Stream');

select tests.authenticate_as(:'pembaca');
select throws_ok(format($$insert into public.posts (author_id, body, attachments) values (%L, 'Palsu', %L)$$,
                        :'pembaca', jsonb_build_array(pg_temp.file(:'pembaca' || '/x/file.pdf', 'x.pdf'))),
  'PT400', 'invalid_attachments', 'Pengguna biasa tidak bisa melampirkan dokumen lewat postingan');
reset role;

select private.post_files_maintenance() as swept \gset
select is((select array_agg(prefix order by prefix) from private.storage_cleanup_queue
           where bucket_id = 'post-files' and done_at is null),
  array[regexp_replace(:'orphan', '[^/]+$', '')], 'Hanya dokumen yatim lebih dari sehari yang dijadwalkan dihapus');

select * from finish();
rollback;
