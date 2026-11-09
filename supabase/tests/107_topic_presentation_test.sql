begin;
select plan(17);

select tests.create_agent('Laras', '{cs_content}', '{}') as laras \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_user('tp_budi') as budi \gset

select tests.authenticate_as(:'budi');
select ok(cs_api.topics('id') @> '[{"code": "account", "icon": "account", "style": "normal", "description": "Login, password, PIN, dan data akun"}]',
  'Topik bawaan dikirim dengan deskripsi dan ikon');
select ok(cs_api.topics('en') @> '[{"code": "fraud", "icon": "shield", "style": "danger", "description": "Suspicious activity or someone posing as customer service"}]',
  'Deskripsi mengikuti bahasa dan topik penipuan bergaya danger');
select is(cs_api.support_home() -> 'topic_picker', '{}'::jsonb, 'Teks halaman pilih topik kosong sampai diatur');

select tests.authenticate_agent(:'laras');
select ok(cs_api.admin_topics() @> '[{"code": "fraud", "flags": ["fraud"], "description_en": "Suspicious activity or someone posing as customer service"}]',
  'Daftar admin memuat deskripsi, ikon, gaya, dan tanda');
select ok(cs_api.admin_save_topic('promo', 'Promo', 'Promo', 'general', 'P3', null, 50, true,
                                  p_description_id => 'Program promo dan hadiah', p_description_en => 'Promotions and rewards',
                                  p_icon => 'star', p_style => 'normal')
            @> '[{"code": "promo", "icon": "star", "description_id": "Program promo dan hadiah"}]',
  'Konten Layanan menyimpan deskripsi dan ikon');
select throws_ok($$select cs_api.admin_save_topic('promo', 'Promo', 'Promo', 'general', 'P3', null, 50, true, p_icon => 'rocket')$$,
  'PT400', 'invalid_icon', 'Ikon di luar daftar ditolak');
select throws_ok($$select cs_api.admin_save_topic('promo', 'Promo', 'Promo', 'general', 'P3', null, 50, true, p_style => 'loud')$$,
  'PT400', 'invalid_style', 'Gaya di luar daftar ditolak');
select throws_ok(format('select cs_api.admin_save_topic(%L, %L, %L, %L, %L, null, 50, true, p_description_id => %L)',
                        'promo', 'Promo', 'Promo', 'general', 'P3', repeat('x', 121)),
  'PT400', 'invalid_description', 'Deskripsi lebih dari 120 karakter ditolak');
select throws_ok($$select cs_api.admin_save_topic('promo', 'Promo', 'Promo', 'general', 'P3', null, 50, true, p_flags => '{complaint}')$$,
  'PT403', 'flags_forbidden', 'Hanya Super Admin yang mengubah tanda pengaduan/penipuan');
select ok(cs_api.admin_save_topic('promo', 'Promo', 'Promo', 'general', 'P3', null, 50, true, p_description_id => 'Program promo dan hadiah', p_description_en => 'Promotions and rewards', p_icon => 'star', p_flags => null) @> '[{"code": "promo", "flags": []}]',
  'Tanpa p_flags, tanda topik tidak berubah');
select is(cs_api.admin_set_topic_picker('Ada kendala apa?', 'What do you need?', 'Pilih topik di bawah', null)
            -> 'title' ->> 'en', 'What do you need?', 'Konten Layanan mengatur judul halaman pilih topik');

select tests.authenticate_agent(:'sinta');
select ok(cs_api.admin_save_topic('promo', 'Promo', 'Promo', 'general', 'P3', null, 50, true, p_description_id => 'Program promo dan hadiah', p_description_en => 'Promotions and rewards', p_icon => 'star', p_flags => '{complaint}')
            @> '[{"code": "promo", "flags": ["complaint"]}]',
  'Super Admin mengubah tanda topik');
select throws_ok($$select cs_api.admin_save_topic('promo', 'Promo', 'Promo', 'general', 'P3', null, 50, true, p_flags => '{vip}')$$,
  'PT400', 'invalid_flags', 'Tanda hanya pengaduan atau penipuan');

select tests.authenticate_as(:'budi');
select ok(cs_api.topics('id') @> '[{"code": "promo", "description": "Program promo dan hadiah", "icon": "star"}]',
  'Nasabah menerima topik baru dari server');
select is(cs_api.support_home() -> 'topic_picker' -> 'title' ->> 'id', 'Ada kendala apa?',
  'Nasabah menerima judul halaman pilih topik dari server');

reset role;
select ok((select details -> 'before' ->> 'icon' = 'star' and details -> 'after' -> 'flags' = '["complaint"]'::jsonb
           from cs.cs_audit_log where action = 'topic.save' and actor_id = :'sinta' order by id desc limit 1),
  'Jejak audit menyimpan nilai sebelum dan sesudah');
select is((select count(*) from cs.cs_audit_log where action = 'topic.flags' and actor_id = :'sinta')::integer, 1,
  'Perubahan tanda topik tercatat terpisah untuk Kepatuhan');

select * from finish();
rollback;
