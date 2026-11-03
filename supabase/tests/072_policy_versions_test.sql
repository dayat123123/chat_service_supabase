begin;
select plan(77);

select tests.create_user('pv_budi') as budi \gset
select tests.create_agent('Kirana PV', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Laras PV', '{compliance}', '{}') as laras \gset
select tests.create_agent('Rina PV', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_agent('Super PV', '{cs_super_admin}', '{}') as boss \gset

select cs.set_setting('compliance.policy_four_eyes', 'true', null) as four_eyes_on \gset
delete from public.banned_words where word in ('kripikpedas', 'cuanpasti', 'sinyaltajir');
select max(version) as v0 from cs.policy_versions \gset

insert into public.posts (author_id, body) values (:'budi', 'Beli kripikpedas sekarang juga') returning id as post \gset
insert into public.comments (post_id, author_id, body) values (:'post', :'budi', 'kripikpedas mantap');
insert into public.chat_rooms (type, name, created_by) values ('group', 'Grup PV', :'budi') returning id as room \gset
insert into public.chat_members (room_id, user_id, role) values (:'room', :'budi', 'owner');
insert into public.messages (room_id, sender_id, body) values (:'room', :'budi', 'kripikpedas rahasia grup');

select is((select source from cs.policy_versions where version = 1), 'baseline', 'Versi 1 adalah baseline');
select ok((select snapshot from cs.policy_versions where version = 1) ?& private.policy_sections(),
  'Snapshot memuat semua bagian kebijakan');

select tests.authenticate_agent(:'kirana');
select is((cs_api.compliance_policy_state() ->> 'four_eyes')::boolean, true, 'Empat mata kebijakan aktif secara bawaan');
select is(cs_api.compliance_policy_state() -> 'draft', 'null'::jsonb, 'Belum ada draf');
select throws_ok($$select cs_api.compliance_add_banned_word('kripikpedas', 'block')$$, 'PT409', 'policy_review_required',
  'Ubah langsung ditolak saat empat mata aktif');
select throws_ok($$select cs_api.compliance_policy_call('compliance_drop_everything', '{}')$$, 'PT400', 'invalid_policy_call',
  'Gerbang menolak aksi yang tidak dikenal');

select ok(cs_api.compliance_policy_call('compliance_banned_words', '{}') -> 'policy_draft' is null,
  'Baca tanpa draf memakai kebijakan aktif');
select is(cs_api.compliance_policy_call('compliance_add_banned_word', '{"p_word": "kripikpedas", "p_action": "block"}')
            #> '{policy_draft,changes}', '1'::jsonb, 'Tambah kata lewat gerbang masuk ke draf');
select ok(cs_api.compliance_policy_call('compliance_banned_words', '{}') -> 'words' @> '[{"word": "kripikpedas"}]',
  'Baca lewat gerbang menampilkan isi draf');
select ok(not (cs_api.compliance_banned_words() -> 'words' @> '[{"word": "kripikpedas"}]'),
  'Kebijakan aktif belum berubah');
select ok(cs_api.compliance_policy_call('compliance_set_content_rule',
            '{"p_category": "other_link", "p_action": "hold", "p_scope": "public"}') -> 'categories'
          @> '[{"category": "other_link", "action": "hold"}]', 'Ubah aksi kategori masuk ke draf');
select is(cs_api.compliance_policy_call('compliance_set_image_thresholds',
            '{"p_thresholds": {"porn": {"hold": 0.7, "block": 0.9}, "hentai": {"hold": 0.6, "block": 0.95}, "sexy": {"hold": 0.85}}}')
            #> '{thresholds,porn,hold}', '0.7'::jsonb, 'Ambang gambar masuk ke draf');
select throws_ok($$select cs_api.compliance_policy_call('compliance_add_banned_word', '{"p_word": "x", "p_action": "block"}')$$,
  'PT400', 'invalid_banned_word', 'Validasi RPC asli tetap berlaku di draf');
select is((cs_api.compliance_policy_state() #>> '{draft,diff,total}')::integer, 3, 'Draf berisi tiga perubahan');
select is(cs_api.compliance_policy_state() #> '{draft,diff,sections,banned_words,items,0}',
  '{"key": "kripikpedas", "op": "added", "to": "block"}'::jsonb, 'Diff draf merinci kata yang ditambah');
reset role;
select is((select count(*) from public.banned_words where word = 'kripikpedas'), 0::bigint, 'Tabel aktif tidak tersentuh draf');
select is((select max(version) from cs.policy_versions), :'v0'::integer, 'Draf tidak membuat versi');

select count(*) as audit_before from cs.cs_audit_log \gset
select tests.authenticate_agent(:'kirana');
select cs_api.compliance_policy_simulate(null, null, 'promo kripikpedas murah', 'post', 7, 300) as sim \gset
select is(:'sim'::jsonb #>> '{sample,current,action}', 'allow', 'Contoh teks lolos di kebijakan aktif');
select is(:'sim'::jsonb #>> '{sample,draft,action}', 'block', 'Contoh teks diblokir di draf');
select ok((:'sim'::jsonb #>> '{content,stricter}')::integer >= 2, 'Simulasi menemukan postingan dan komentar yang jadi diblokir');
select ok(:'sim'::jsonb #> '{content,items}' @> jsonb_build_array(jsonb_build_object('id', :'post', 'type', 'post')),
  'Postingan terkait muncul di hasil simulasi');
select ok(not (:'sim'::jsonb #> '{content,items}' @> '[{"type": "message"}]'), 'Pesan grup/DM tidak ikut disimulasikan');
select is(:'sim'::jsonb #>> '{target,kind}', 'draft', 'Target simulasi adalah draf');
select throws_ok($$select cs_api.compliance_policy_simulate(null, null, 'x', 'mars')$$, 'PT400', 'invalid_surface',
  'Tempat simulasi divalidasi');
reset role;
select is((select count(*) from cs.cs_audit_log), :'audit_before'::bigint, 'Simulasi tidak menulis jejak audit');
select is((select count(*) from public.banned_words where word = 'kripikpedas'), 0::bigint, 'Simulasi tidak mengubah kebijakan');
select is((select porn from (select m.thresholds #>> '{porn,hold}' as porn from private.media_moderation m) x), '0.5',
  'Simulasi tidak mengubah ambang gambar aktif');

insert into private.media_reviews (bucket, name, uploader, model, scores, category, score)
values ('attachments', 'posts/' || :'budi' || '/pv.jpg', :'budi', 'nsfw@1', '{"porn": 0.62}', 'porn', 0.62);
select tests.authenticate_agent(:'kirana');
select ok((cs_api.compliance_policy_simulate() #>> '{images,changed}')::integer >= 1,
  'Simulasi ambang gambar memakai skor tinjauan terbaru');

select throws_ok($$select cs_api.compliance_policy_submit('ok')$$, 'PT400', 'invalid_reason', 'Alasan wajib 5–500 karakter');
select cs_api.compliance_policy_submit('Blokir promosi kripik dan ketatkan tautan') as submitted \gset
select is(:'submitted'::jsonb ->> 'status', 'pending', 'Draf diajukan menjadi permintaan tertunda');
select :'submitted'::jsonb ->> 'id' as change_id \gset
select is(cs_api.compliance_policy_state() -> 'draft', 'null'::jsonb, 'Draf hilang setelah diajukan');
select throws_ok(format($$select cs_api.compliance_policy_decide(%s, true)$$, :'change_id'), 'PT403', 'four_eyes',
  'Pembuat tidak bisa menyetujui perubahannya sendiri');
select is((cs_api.compliance_policy_change(:'change_id') ->> 'can_decide')::boolean, false, 'Pembuat tidak melihat tombol putuskan');

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.compliance_policy_state()$$, 'PT403', 'role_forbidden', 'Agen CS biasa tidak bisa melihat');

select tests.authenticate_agent(:'boss');
select ok((cs_api.compliance_policy_versions() -> 'rows') @> '[{"version": 1}]', 'Super Admin bisa melihat riwayat versi');
select is(jsonb_array_length(cs_api.compliance_policy_changes('pending')), 1, 'Super Admin bisa melihat permintaan tertunda');
select throws_ok(format($$select cs_api.compliance_policy_decide(%s, true)$$, :'change_id'), 'PT403', 'role_forbidden',
  'Super Admin tidak bisa menyetujui kebijakan konten');
select throws_ok($$select cs_api.compliance_policy_simulate()$$, 'PT403', 'role_forbidden', 'Simulasi khusus Kepatuhan');

select tests.authenticate_agent(:'laras');
select is((cs_api.compliance_policy_change(:'change_id') ->> 'can_decide')::boolean, true, 'Staf lain boleh memutuskan');
select is((cs_api.compliance_policy_simulate(:'change_id') #>> '{target,kind}'), 'change',
  'Pemeriksa bisa menyimulasikan permintaan tertunda');
select throws_ok(format($$select cs_api.compliance_policy_decide(%s, false, '')$$, :'change_id'), 'PT400', 'note_required',
  'Penolakan wajib beralasan');
select cs_api.compliance_policy_decide(:'change_id', true, 'Sudah dicek simulasi') as approved \gset
select is(:'approved'::jsonb ->> 'status', 'approved', 'Permintaan disetujui');
select :'approved'::jsonb ->> 'applied_version' as v1 \gset
select is(:'v1'::integer, :'v0'::integer + 1, 'Persetujuan membuat versi baru');
select throws_ok(format($$select cs_api.compliance_policy_decide(%s, true)$$, :'change_id'), 'PT409', 'policy_change_decided',
  'Permintaan tidak bisa diputuskan dua kali');
reset role;
select is((select action from public.banned_words where word = 'kripikpedas'), 'block', 'Kata terlarang berlaku setelah disetujui');
select is((select action from cs.content_rules where category = 'other_link'), 'hold', 'Aksi kategori berlaku');
select is((select thresholds #>> '{porn,hold}' from private.media_moderation), '0.7', 'Ambang gambar berlaku');
select results_eq(
  format($$select source, reason, change_id, created_by from cs.policy_versions where version = %s$$, :'v1'),
  format($$values ('change'::text, 'Blokir promosi kripik dan ketatkan tautan'::text, %s::bigint, %L::uuid)$$, :'change_id', :'laras'),
  'Versi mencatat sumber, alasan, permintaan, dan penyetuju');
select is((select diff #>> '{sections,banned_words,added}' from cs.policy_versions where version = :'v1'), '1',
  'Ringkasan diff versi tersimpan');
select is((select count(*) from cs.cs_audit_log where action in ('policy_change.submit', 'policy_change.approve')
           and details ->> 'change' = :'change_id'), 2::bigint, 'Pengajuan dan persetujuan tercatat di audit');
select throws_ok(format($$update cs.policy_versions set reason = 'ubah' where version = %s$$, :'v1'), '42501', null,
  'Versi tidak bisa diubah');
select throws_ok($$delete from cs.policy_versions where version = 1$$, '42501', null, 'Versi tidak bisa dihapus');

select tests.authenticate_agent(:'kirana');
select is(cs_api.compliance_policy_call('compliance_add_promo_phrase', '{"p_phrase": "cuanpasti"}') #> '{policy_draft,changes}',
  '1'::jsonb, 'Draf kedua dibuat');
select tests.authenticate_agent(:'laras');
select is(cs_api.compliance_policy_call('compliance_add_banned_word', '{"p_word": "sinyaltajir", "p_action": "mask"}')
          #> '{policy_draft,changes}', '1'::jsonb, 'Staf lain punya draf sendiri');
select cs_api.compliance_policy_submit('Sensor ajakan sinyal tajir') ->> 'id' as laras_change \gset
select tests.authenticate_agent(:'kirana');
select cs_api.compliance_policy_decide(:'laras_change', true) ->> 'applied_version' as v2 \gset
select ok(cs_api.compliance_policy_call('compliance_content_rules', '{}') -> 'promo_phrases' @> '[{"phrase": "cuanpasti"}]',
  'Draf yang tertinggal di-rebase dan tetap memuat perubahan sendiri');
select ok(cs_api.compliance_policy_call('compliance_banned_words', '{}') -> 'words' @> '[{"word": "sinyaltajir"}]',
  'Draf yang di-rebase memuat perubahan terbaru yang sudah berlaku');
select is((cs_api.compliance_policy_state() #>> '{draft,base_version}')::integer, :'v2'::integer, 'Basis draf naik ke versi terbaru');
select is(cs_api.compliance_policy_discard() -> 'draft', 'null'::jsonb, 'Draf bisa dibuang');

select throws_ok(format($$select cs_api.compliance_policy_rollback(%s, '')$$, :'v0'), 'PT400', 'invalid_reason',
  'Pemulihan wajib beralasan');
select throws_ok(format($$select cs_api.compliance_policy_rollback(%s, 'Tidak ada perubahan')$$, :'v2'), 'PT400', 'policy_no_change',
  'Versi yang sedang berlaku tidak bisa dipulihkan');
select cs_api.compliance_policy_rollback(:'v0', 'Kembalikan kebijakan sebelum uji') as rollback \gset
select is(:'rollback'::jsonb ->> 'status', 'pending', 'Pemulihan menjadi permintaan tertunda saat empat mata aktif');
select ok((cs_api.compliance_policy_version(:'v0') #>> '{restore,total}')::integer > 0, 'Detail versi menampilkan isi pemulihan');
select tests.authenticate_agent(:'laras');
select cs_api.compliance_policy_decide((:'rollback'::jsonb ->> 'id')::bigint, true) ->> 'applied_version' as v3 \gset
reset role;
select is((select snapshot from cs.policy_versions where version = :'v3'),
          (select snapshot from cs.policy_versions where version = :'v0'), 'Versi pemulihan sama persis dengan versi lama');
select results_eq(format($$select source, restored_from from cs.policy_versions where version = %s$$, :'v3'),
  format($$values ('rollback'::text, %s::integer)$$, :'v0'), 'Versi pemulihan menunjuk versi asal');
select is((select count(*) from cs.policy_versions where version between :'v0' and :'v3'), 4::bigint,
  'Riwayat lama tetap ada setelah pemulihan');
select ok(exists (select 1 from cs.cs_audit_log where action = 'policy.rollback' and (details ->> 'to')::integer = :'v0'),
  'Pemulihan tercatat di audit');

select tests.authenticate_agent(:'kirana');
select cs_api.compliance_policy_rollback(:'v1', 'Coba pulihkan versi uji') ->> 'id' as stale_rollback \gset
select cs_api.compliance_policy_call('compliance_add_allowlist_term', '{"p_term": "cuanpasti"}') ->> 'policy_draft' as ignore \gset
select cs_api.compliance_policy_submit('Tambah pengecualian istilah') ->> 'id' as allow_change \gset
select cs_api.compliance_policy_withdraw(:'allow_change') ->> 'status' as withdrawn \gset
select is(:'withdrawn'::text, 'withdrawn', 'Pembuat bisa menarik permintaannya');
select tests.authenticate_agent(:'laras');
select throws_ok(format($$select cs_api.compliance_policy_withdraw(%s)$$, :'stale_rollback'), 'PT404', 'policy_change_not_found',
  'Hanya pembuat yang bisa menarik');
select cs_api.compliance_policy_call('compliance_set_new_account_days', '{"p_days": 5}') ->> 'policy_draft' as ignore \gset
select cs_api.compliance_policy_submit('Masa akun baru lima hari') ->> 'id' as days_change \gset
select tests.authenticate_agent(:'kirana');
select is(cs_api.compliance_policy_decide(:'days_change', true) ->> 'status', 'approved', 'Perubahan lain disetujui');
select tests.authenticate_agent(:'laras');
select throws_ok(format($$select cs_api.compliance_policy_decide(%s, true)$$, :'stale_rollback'), 'PT409', 'policy_stale',
  'Pemulihan yang basisnya sudah usang tidak bisa disetujui');
select is(cs_api.compliance_policy_decide(:'stale_rollback', false, 'Basis sudah usang') ->> 'status', 'rejected',
  'Pemulihan usang bisa ditolak');

select tests.authenticate_agent(:'kirana');
select throws_ok($$select cs_api.admin_set_policy_four_eyes(false)$$, 'PT403', 'role_forbidden',
  'Hanya Super Admin yang mengatur empat mata kebijakan');
select tests.authenticate_agent(:'boss');
select is(cs_api.admin_set_policy_four_eyes(false) ->> 'enabled', 'false', 'Super Admin mematikan empat mata kebijakan');
select tests.authenticate_agent(:'kirana');
select cs_api.compliance_policy_call('compliance_add_promo_phrase', '{"p_phrase": "cuanpasti"}') ->> 'policy_draft' as ignore \gset
select cs_api.compliance_policy_submit('Tambah frasa uji') as direct_apply \gset
select is(:'direct_apply'::jsonb ->> 'status', 'approved', 'Tanpa empat mata, draf langsung berlaku saat diaktifkan');
select is((:'direct_apply'::jsonb #>> '{decided_by,id}')::uuid, :'kirana'::uuid, 'Pembuat tercatat sebagai pengaktif');
reset role;
select max(version) as before_direct from cs.policy_versions \gset
select tests.authenticate_agent(:'kirana');
select lives_ok($$select cs_api.compliance_add_banned_word('cuanpasti', 'mask')$$, 'Tanpa empat mata, RPC lama tetap jalan');
set constraints all immediate;
set constraints all deferred;
reset role;
select results_eq(format($$select source, created_by from cs.policy_versions where version = %s + 1$$, :'before_direct'),
  format($$values ('direct'::text, %L::uuid)$$, :'kirana'), 'Ubah langsung tetap tercatat sebagai versi');

select * from finish();
rollback;
