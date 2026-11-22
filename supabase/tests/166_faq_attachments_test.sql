begin;
select plan(23);

select tests.create_agent('Laras Lampiran', '{cs_content}', '{}') as laras \gset
select tests.create_agent('Rina Lampiran', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_user('faq_lampiran') as budi \gset
select (select id from cs.faq_categories where code = 'account') as account \gset
select '0b6c1a52-3f4e-4c1d-9a7e-2f1b3c4d5e01.pdf' as pdf,
       '0b6c1a52-3f4e-4c1d-9a7e-2f1b3c4d5e02.png' as png,
       '0b6c1a52-3f4e-4c1d-9a7e-2f1b3c4d5e03.mp4' as mp4,
       '0b6c1a52-3f4e-4c1d-9a7e-2f1b3c4d5e04.pdf' as bigpdf,
       '0b6c1a52-3f4e-4c1d-9a7e-2f1b3c4d5e05.png' as missing \gset

insert into storage.objects (bucket_id, name, metadata) values
  ('faq-files', :'pdf', '{"size": 204800, "mimetype": "application/pdf"}'),
  ('faq-files', :'png', '{"size": 102400, "mimetype": "image/png"}'),
  ('faq-files', :'mp4', '{"size": 20971520, "mimetype": "video/mp4"}'),
  ('faq-files', :'bigpdf', '{"size": 11534336, "mimetype": "application/pdf"}');

select ok(exists (select 1 from storage.buckets where id = 'faq-files' and public and file_size_limit = 26214400
                  and allowed_mime_types @> array['application/pdf', 'image/png', 'video/mp4', 'video/quicktime']),
  'Bucket lampiran FAQ publik, menerima PDF, gambar, dan video sampai 25 MB');
select ok(exists (select 1 from pg_policies where tablename = 'objects' and policyname = 'olt_faq_files_insert'),
  'Unggah lampiran FAQ dibatasi kebijakan storage');
select ok(exists (select 1 from pg_policies where tablename = 'objects' and policyname = 'olt_faq_files_insert'
                  and with_check like '%can_manage_faq%'), 'Hanya pengelola FAQ yang boleh mengunggah lampiran');

select tests.authenticate_agent(:'laras');
select cs_api.admin_faq_save_article(null, :'account', 'Formulir ganti rekening', 'Bank account change form',
  'Unduh formulir di bawah.', 'Download the form below.', '{}', null, 0, null,
  jsonb_build_array(jsonb_build_object('path', :'pdf', 'name', '  Formulir ganti rekening.pdf  ', 'kind', 'video', 'size', 1),
                    jsonb_build_object('path', :'png', 'name', 'Contoh isian'),
                    jsonb_build_object('path', :'mp4', 'name', 'Video panduan'))) as saved \gset
select (:'saved'::jsonb ->> 'id') as article \gset
select is(jsonb_array_length(:'saved'::jsonb -> 'attachments'), 3, 'Artikel disimpan dengan tiga lampiran');
select is(:'saved'::jsonb -> 'attachments' -> 0,
  jsonb_build_object('path', :'pdf', 'name', 'Formulir ganti rekening.pdf', 'kind', 'document',
                     'mime', 'application/pdf', 'size', 204800),
  'Jenis, MIME, dan ukuran diambil dari server, nama dirapikan');
select is(:'saved'::jsonb -> 'attachments' -> 1 ->> 'kind', 'image', 'PNG tercatat sebagai gambar');
select is(:'saved'::jsonb -> 'attachments' -> 2 ->> 'mime', 'video/mp4', 'MP4 tercatat sebagai video');

select throws_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'Lampiran luar', 'External file', 'a', 'b',
  '{}', null, 0, null, '[{"path": "https://contoh.id/a.pdf", "name": "a"}]')$$, :'account'),
  'PT400', 'invalid_attachments', 'Lampiran di luar bucket FAQ ditolak');
select throws_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'Lampiran hilang', 'Missing file', 'a', 'b',
  '{}', null, 0, null, %L)$$, :'account', jsonb_build_array(jsonb_build_object('path', :'missing', 'name', 'x'))),
  'PT400', 'attachment_missing', 'Lampiran yang belum diunggah ditolak');
select throws_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'PDF besar', 'Big PDF', 'a', 'b',
  '{}', null, 0, null, %L)$$, :'account', jsonb_build_array(jsonb_build_object('path', :'bigpdf', 'name', 'x'))),
  'PT400', 'attachment_too_large', 'PDF lebih dari 10 MB ditolak');
select throws_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'Dua kali', 'Twice', 'a', 'b',
  '{}', null, 0, null, %L)$$, :'account', jsonb_build_array(jsonb_build_object('path', :'pdf', 'name', 'x'),
                                                            jsonb_build_object('path', :'pdf', 'name', 'y'))),
  'PT400', 'duplicate_attachment', 'Lampiran yang sama tidak boleh dipasang dua kali');
select throws_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'Tanpa nama', 'No name', 'a', 'b',
  '{}', null, 0, null, %L)$$, :'account', jsonb_build_array(jsonb_build_object('path', :'pdf', 'name', '   '))),
  'PT400', 'invalid_attachment_name', 'Lampiran wajib bernama');
select throws_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'Terlalu banyak', 'Too many', 'a', 'b',
  '{}', null, 0, null, %L)$$, :'account',
  (select jsonb_agg(jsonb_build_object('path', format('0b6c1a52-3f4e-4c1d-9a7e-2f1b3c4d5f%s.pdf', lpad(n::text, 2, '0')),
                                       'name', 'x')) from generate_series(1, 11) n)),
  'PT400', 'too_many_attachments', 'Maksimal 10 lampiran per artikel');

select is(jsonb_array_length(cs_api.admin_faq_save_article(:'article', :'account', 'Formulir ganti rekening bank',
  'Bank account change form', 'Unduh formulir di bawah.', 'Download the form below.', '{}', null, 0, 1) -> 'attachments'),
  3, 'Simpan tanpa p_attachments (Hub lama) mempertahankan lampiran');
select is(jsonb_array_length(cs_api.admin_faq_save_article(:'article', :'account', 'Formulir ganti rekening bank',
  'Bank account change form', 'Unduh formulir di bawah.', 'Download the form below.', '{}', null, 0, 2,
  jsonb_build_array(jsonb_build_object('path', :'pdf', 'name', 'Formulir'))) -> 'attachments'),
  1, 'Lampiran bisa dikurangi');
select is(cs_api.admin_faq_versions(:'article') -> 0 -> 'content' -> 'attachments' -> 0 ->> 'name', 'Formulir',
  'Riwayat versi menyimpan lampiran');
select cs_api.admin_faq_set_status(:'article', 'published') is not null as published \gset
reset role;

set local storage.allow_delete_query = 'true';
delete from storage.objects where bucket_id = 'faq-files' and name = :'mp4';
reset storage.allow_delete_query;

select tests.authenticate_agent(:'laras');
select is(jsonb_array_length(cs_api.admin_faq_restore(:'article', 1) -> 'attachments'), 2,
  'Memulihkan versi lama membawa lampirannya, kecuali file yang sudah tidak ada');
reset role;

select tests.authenticate_as(:'budi');
select is(cs_api.faq_article(:'article', 'id') -> 'attachments' -> 0 ->> 'path', :'pdf',
  'Nasabah menerima lampiran di artikel');
select is(cs_api.faq_article(:'article', 'en') -> 'attachments' -> 1 ->> 'kind', 'image',
  'Lampiran sama untuk kedua bahasa');
select ok(cs_api.faq('id') -> 'categories' -> 0 -> 'articles' -> 0 ? 'attachments',
  'Daftar Pusat Bantuan (cache offline) memuat lampiran');
reset role;

select tests.authenticate_agent(:'rina');
select ok(cs_api.agent_faq_search('formulir', 'id') -> 0 ? 'attachments', 'Agen CS melihat lampiran artikel');
select ok(not private.can_manage_faq(), 'Agen biasa tidak boleh mengunggah lampiran FAQ');
reset role;

select is(has_function_privilege('anon', 'cs.faq_clean_attachments(jsonb)', 'execute'), false,
  'Pemeriksa lampiran tidak bisa dipanggil langsung');

select * from finish();
rollback;
