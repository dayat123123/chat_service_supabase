begin;
select plan(35);

select tests.create_agent('Laras FAQ', '{cs_content}', '{}') as laras \gset
select tests.create_agent('Rina FAQ', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_user('faq_budi') as budi \gset
select tests.create_user('faq_sari') as sari \gset
select (select id from cs.faq_categories where code = 'account') as account \gset

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.admin_faq()$$, 'PT403', null, 'Agen biasa tidak bisa membuka pengelolaan FAQ');
reset role;

select tests.authenticate_agent(:'laras');
select ok(cs_api.admin_faq() -> 'categories' @> '[{"code": "account", "icon": "account"}]',
  'Kategori bawaan tersedia untuk Konten Layanan');
select cs_api.admin_faq_save_category(null, 'billing', 'Tagihan', 'Billing', 'wallet', 40, true) ->> 'id' as billing \gset
select throws_ok($$select cs_api.admin_faq_save_category(null, 'billing', 'Tagihan lagi', 'Billing again')$$,
  'PT409', 'code_taken', 'Kode kategori tidak boleh kembar');
select throws_ok($$select cs_api.admin_faq_save_category(null, 'promo', 'Promo', 'Promo', 'rocket')$$,
  'PT400', 'invalid_icon', 'Ikon kategori di luar daftar ditolak');

select cs_api.admin_faq_save_article(null, :'account', 'Bagaimana cara reset PIN?', 'How do I reset my PIN?',
  'Buka **Profil**, pilih *Reset PIN*, lalu ikuti [panduan](https://olt.co.id/pin).',
  'Open **Profile**, choose *Reset PIN*, then follow the [guide](https://olt.co.id/pin).',
  '{PIN, Lupa PIN, pin}', 'account', 10) as pin \gset
select is((:'pin'::jsonb) ->> 'status', 'draft', 'Artikel baru disimpan sebagai draf');
select is((:'pin'::jsonb) -> 'keywords', '["lupa pin", "pin"]'::jsonb, 'Kata kunci dirapikan, huruf kecil, tanpa duplikat');
select ((:'pin'::jsonb) ->> 'id') as pin_id \gset
select throws_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'Pertanyaan HTML', 'HTML question',
  '<script>alert(1)</script>', 'x')$$, :'account'), 'PT400', 'invalid_answer', 'Tag HTML di jawaban ditolak');
select throws_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'Pertanyaan tautan', 'Link question',
  '[klik](http://contoh.id)', 'x')$$, :'account'), 'PT400', 'invalid_answer', 'Tautan selain https ditolak');
select throws_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'Pertanyaan tautan', 'Link question',
  '[klik](javascript:alert(1))', 'x')$$, :'account'), 'PT400', 'invalid_answer', 'Tautan javascript ditolak');
select throws_ok(format($$select cs_api.admin_faq_save_article(null, %L, 'Pertanyaan topik', 'Topic question',
  'Jawaban', 'Answer', '{}', 'tidak_ada')$$, :'account'), 'PT400', 'invalid_topic', 'Topik chat yang tidak ada ditolak');
reset role;

select tests.authenticate_as(:'budi');
select is(cs_api.faq('id') -> 'categories', '[]'::jsonb, 'Draf tidak tampil di aplikasi');
reset role;

select tests.authenticate_agent(:'laras');
select is(cs_api.admin_faq_set_status(:'pin_id', 'published') ->> 'status', 'published', 'Artikel diterbitkan');
select is(cs_api.admin_faq_save_article(:'pin_id', :'account', 'Bagaimana cara mengganti PIN?', 'How do I change my PIN?',
  'Buka **Profil** lalu pilih *Ganti PIN*.', 'Open **Profile** and choose *Change PIN*.', '{pin}', 'account', 10, 1)
  ->> 'version', '2', 'Mengubah artikel menaikkan versi');
select throws_ok(format($$select cs_api.admin_faq_save_article(%L, %L, 'Versi lama', 'Old version', 'a', 'b',
  '{}', null, 0, 1)$$, :'pin_id', :'account'), 'PT409', 'version_conflict', 'Simpan dari versi lama ditolak');
select is(jsonb_array_length(cs_api.admin_faq_versions(:'pin_id')), 2, 'Riwayat versi menyimpan setiap simpanan');
select cs_api.admin_faq_save_article(null, :'billing', 'Kapan tagihan bulanan terbit?', 'When is the monthly bill issued?',
  'Setiap tanggal 1.', 'On the 1st of every month.', '{tagihan}', null, 0) ->> 'id' as bill_id \gset
select cs_api.admin_faq_set_status(:'bill_id', 'published') is not null as published \gset
reset role;

select tests.authenticate_as(:'budi');
select ok(cs_api.faq('id') -> 'categories' @> '[{"code": "account", "name": "Akun dan login", "articles": [{"question": "Bagaimana cara mengganti PIN?", "topic": "account"}]}]',
  'Artikel terbit tampil per kategori dalam bahasa Indonesia');
select ok(cs_api.faq('en') -> 'categories' @> '[{"code": "account", "name": "Account and login", "articles": [{"question": "How do I change my PIN?"}]}]',
  'Artikel tampil dalam bahasa Inggris');
select is(cs_api.faq('id') -> 'categories' -> 0 ->> 'code', 'account', 'Kategori diurutkan menurut urutan');
select is(jsonb_array_length(cs_api.faq_search('ganti pin', 'id')), 1, 'Pencarian menemukan artikel dari pertanyaan');
select is(jsonb_array_length(cs_api.faq_search('PIN', 'id')), 1, 'Pencarian tidak membedakan huruf besar');
select is(jsonb_array_length(cs_api.faq_search('100%', 'id')), 0, 'Tanda persen tidak dianggap wildcard');
select is(cs_api.faq_search('rekening 1234567890 budi@mail.id', 'id'), '[]'::jsonb, 'Pencarian tanpa hasil mengembalikan daftar kosong');
select throws_ok($$select cs_api.faq_search('x', 'id')$$, 'PT400', 'invalid_query', 'Kata pencarian terlalu pendek ditolak');
select is(cs_api.faq_article(:'pin_id', 'id') -> 'feedback', 'null'::jsonb, 'Artikel dibuka tanpa umpan balik sebelumnya');
select is(cs_api.faq_feedback(:'pin_id', false, '  Kurang jelas  ') ->> 'comment', 'Kurang jelas', 'Umpan balik disimpan dengan komentar');
select is(cs_api.faq_feedback(:'pin_id', true) ->> 'helpful', 'true', 'Nasabah bisa mengubah suaranya');
select is(cs_api.faq_article(:'pin_id', 'id') -> 'feedback' ->> 'helpful', 'true', 'Satu suara per nasabah per artikel');
select is(jsonb_array_length(cs_api.faq_for_topic('account', 'id')), 1, 'Artikel teratas untuk topik chat');
select throws_ok(format($$select cs_api.faq_feedback(%L, null)$$, :'pin_id'), 'PT400', 'invalid_feedback',
  'Umpan balik tanpa pilihan ditolak');
reset role;

select tests.authenticate_as(:'sari');
select cs_api.faq_article(:'pin_id', 'id') is not null as read_once \gset
select cs_api.faq_feedback(:'pin_id', false) is not null as voted \gset
reset role;

select tests.authenticate_agent(:'laras');
select ok((select x from jsonb_array_elements(cs_api.admin_faq() -> 'articles') x where x ->> 'id' = :'pin_id')
          @> '{"views": 2, "readers": 2, "helpful": 1, "not_helpful": 1}',
  'Statistik artikel: dilihat, pembaca, membantu, tidak membantu');
select ok(cs_api.admin_faq_misses(30) @> '[{"query": "rekening # @", "count": 1}]',
  'Pencarian tanpa hasil dicatat tanpa angka panjang dan email');
select is(cs_api.admin_faq_restore(:'pin_id', 1) ->> 'question_id', 'Bagaimana cara reset PIN?',
  'Versi lama bisa dipulihkan');
select is(cs_api.admin_faq_set_status(:'pin_id', 'archived') ->> 'status', 'archived', 'Artikel diarsipkan');
reset role;

select ok((select count(*) from cs.cs_audit_log where actor_id = :'laras' and action like 'faq.%') >= 6,
  'Perubahan FAQ tercatat di jejak audit');

update public.profiles set deleted_at = now() where id = :'budi';
select is((select count(*)::integer from cs.faq_feedback where customer_id = :'budi')
          + (select count(*)::integer from cs.faq_reads where customer_id = :'budi'), 0,
  'Hapus akun ikut menghapus umpan balik dan riwayat baca FAQ');

select * from finish();
rollback;
