begin;
select plan(8);

select tests.create_agent('Laras Gambar', '{cs_content}', '{}') as laras \gset
select tests.create_agent('Rina Gambar', '{cs_agent}', '{"general": 1}') as rina \gset
select (select id from cs.faq_categories where code = 'account') as account \gset

select ok(exists (select 1 from storage.buckets where id = 'faq-images' and public
                  and allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']),
  'Bucket gambar FAQ publik dan hanya menerima JPEG, PNG, WebP');
select ok(exists (select 1 from pg_policies where tablename = 'objects' and policyname = 'olt_faq_images_insert'),
  'Unggah gambar FAQ dibatasi kebijakan storage');

select tests.authenticate_agent(:'laras');
select ok(private.can_manage_faq(), 'Konten Layanan boleh mengunggah gambar FAQ');
select lives_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'Di mana menu profil?', 'Where is the profile menu?',
  E'Lihat gambar:\n\n![Menu profil](https://api.olt.co.id/storage/v1/object/public/faq-images/0b6c1a52-3f4e-4c1d-9a7e-2f1b3c4d5e6f.png)',
  'See [guide](https://olt.co.id/profil).')$$, :'account'), 'Gambar dari bucket FAQ diterima');
select lives_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'Gambar di server dev', 'Image on dev server',
  '![x](http://localhost:8000/storage/v1/object/public/faq-images/0b6c1a52-3f4e-4c1d-9a7e-2f1b3c4d5e6f.jpg)', 'x')$$,
  :'account'), 'Gambar dari bucket FAQ di server dev (http) diterima');
select throws_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'Gambar luar', 'External image',
  '![pelacak](https://contoh.id/pixel.png)', 'x')$$, :'account'), 'PT400', 'invalid_answer',
  'Gambar dari situs lain ditolak');
select throws_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'Tautan http', 'Http link',
  'Lihat [ini](http://localhost:8000/storage/v1/object/public/faq-images/a.png)', 'x')$$, :'account'),
  'PT400', 'invalid_answer', 'Tautan biasa tetap harus https');
reset role;

select tests.authenticate_agent(:'rina');
select ok(not private.can_manage_faq(), 'Agen biasa tidak boleh mengunggah gambar FAQ');
reset role;

select * from finish();
rollback;
