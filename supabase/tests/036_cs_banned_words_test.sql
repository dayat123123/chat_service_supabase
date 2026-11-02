begin;
select plan(26);

delete from public.banned_words;
select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Nadia', '{cs_agent}', '{"general": 2}') as nadia \gset

select tests.authenticate_agent(:'nadia');
select throws_ok('select cs_api.compliance_banned_words()', 'PT403', 'role_forbidden',
  'CS biasa tidak bisa membuka daftar kata terlarang');
select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.compliance_add_banned_word('penipu', 'block')$$, 'PT403', 'role_forbidden',
  'Super Admin tidak mengelola kata terlarang');

select tests.authenticate_agent(:'kirana');
select is(cs_api.compliance_banned_words(), '{"limit": 2000, "words": []}'::jsonb,
  'Kepatuhan melihat daftar kosong beserta batasnya');
select is(cs_api.compliance_add_banned_word('  Jaminan   PROFIT ', 'block') -> 'words' -> 0 ->> 'word', 'jaminan profit',
  'Kata disimpan huruf kecil dengan spasi tunggal');
select throws_ok($$select cs_api.compliance_add_banned_word('jaminan profit', 'mask')$$, 'PT409', 'banned_word_exists',
  'Kata yang sudah ada tidak ditambahkan dua kali');
select throws_ok($$select cs_api.compliance_add_banned_word('a', 'mask')$$, 'PT400', 'invalid_banned_word',
  'Kata minimal 2 karakter');
select throws_ok($$select cs_api.compliance_add_banned_word('anj*ng', 'mask')$$, 'PT400', 'invalid_banned_word',
  'Hanya huruf, angka, dan spasi');
select throws_ok($$select cs_api.compliance_add_banned_word('goblok', 'hide')$$, 'PT400', 'invalid_banned_action',
  'Aksi hanya sensor atau blokir');
select is(cs_api.compliance_set_banned_word_action('Jaminan Profit', 'mask') -> 'words' -> 0 ->> 'action', 'mask',
  'Aksi kata bisa diubah');
select throws_ok($$select cs_api.compliance_set_banned_word_action('tidak ada', 'block')$$, 'PT404', 'banned_word_not_found',
  'Mengubah kata yang tidak ada ditolak');

select is(cs_api.compliance_import_banned_words('[{"word": "Penipu", "action": "block"}, {"word": "goblok"}, {"word": "penipu", "action": "block"}]')
          - 'words' - 'limit',
  '{"added": 2, "updated": 0, "unchanged": 0}'::jsonb, 'Import menambah kata baru, aksi kosong = sensor, duplikat sama diabaikan');
select is(cs_api.compliance_import_banned_words('[{"word": "goblok", "action": "block"}, {"word": "penipu", "action": "block"}]')
          - 'words' - 'limit',
  '{"added": 0, "updated": 1, "unchanged": 1}'::jsonb, 'Import mengubah aksi kata yang sudah ada');
select is((select jsonb_object_agg(w ->> 'word', w ->> 'action')
           from jsonb_array_elements(cs_api.compliance_banned_words() -> 'words') w),
  '{"goblok": "block", "penipu": "block", "jaminan profit": "mask"}'::jsonb, 'Hasil import tersimpan');
select throws_ok($$select cs_api.compliance_import_banned_words('[{"word": "bodoh", "action": "mask"}, {"word": "Bodoh", "action": "block"}]')$$,
  'PT400', 'import_conflict', 'Kata yang sama dengan aksi berbeda di satu file ditolak');
select throws_ok($$select cs_api.compliance_import_banned_words('[{"word": "bodoh"}, {"word": "x!"}]')$$,
  'PT400', 'invalid_banned_word', 'Satu baris tidak valid membatalkan seluruh import');
select ok(not exists (select 1 from jsonb_array_elements(cs_api.compliance_banned_words() -> 'words') w where w ->> 'word' = 'bodoh'),
  'Import yang ditolak tidak menyimpan apa pun');
select throws_ok($$select cs_api.compliance_import_banned_words('[]')$$, 'PT400', 'invalid_import',
  'Import kosong ditolak');
select throws_ok(format('select cs_api.compliance_import_banned_words(%L)',
                        (select jsonb_agg(jsonb_build_object('word', 'uji' || g)) from generate_series(1, 1001) g)),
  'PT400', 'import_too_large', 'Maksimal 1.000 baris per import');

select is(jsonb_array_length(cs_api.compliance_delete_banned_word('GOBLOK') -> 'words'), 2, 'Kata bisa dihapus');
select throws_ok($$select cs_api.compliance_delete_banned_word('goblok')$$, 'PT404', 'banned_word_not_found',
  'Menghapus kata yang tidak ada ditolak');

reset role;
select is(private.apply_content_policy('ini jaminan profit, bukan penipuan'), 'ini **************, bukan penipuan'::text,
  'Kata sensor dari panel langsung dipakai filter konten');
select throws_ok($$select private.apply_content_policy('dasar penipu')$$, 'PT422', 'content_blocked',
  'Kata blokir dari panel langsung menolak konten');
select is((select array_agg(action order by action) from cs.cs_audit_log
           where actor_id = :'kirana' and action like 'banned_word.%'),
  '{banned_word.add,banned_word.delete,banned_word.import,banned_word.import,banned_word.update}'::text[],
  'Semua perubahan tercatat di audit log atas nama Kepatuhan');
select is((select details from cs.cs_audit_log where actor_id = :'kirana' and action = 'banned_word.import' order by id limit 1),
  '{"added": 2, "updated": 0, "unchanged": 0, "rows": 3}'::jsonb, 'Audit import mencatat jumlahnya');

insert into public.banned_words (word, action) select 'uji' || g, 'mask' from generate_series(1, 1998) g;
select tests.authenticate_agent(:'kirana');
select throws_ok($$select cs_api.compliance_add_banned_word('kata baru', 'mask')$$, 'PT400', 'banned_word_limit',
  'Daftar dibatasi 2.000 kata agar filter konten tetap cepat');
select throws_ok($$select cs_api.compliance_import_banned_words('[{"word": "kata baru"}, {"word": "uji1", "action": "block"}]')$$,
  'PT400', 'banned_word_limit', 'Import juga tunduk pada batas');

select * from finish();
rollback;
