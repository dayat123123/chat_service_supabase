begin;
select plan(51);

delete from public.legal_documents;
delete from cs.legal_drafts;
update cs.agents set disabled_at = now() where 'compliance' = any (roles) and disabled_at is null;
update private.settings set value = '["terms", "community_guidelines"]' where key = 'legal.required_kinds';

select tests.create_agent('Kirana', '{compliance}', '{}') as kirana \gset
select tests.create_agent('Dewi', '{compliance}', '{}') as dewi \gset
select tests.create_agent('Sinta', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Rina', '{cs_agent}', '{"general": 1}') as rina \gset
select tests.create_user('lg_budi') as budi \gset

select repeat('Pasal 1. Pengguna wajib menjaga kerahasiaan akun. ', 3) as body \gset

select tests.authenticate_agent(:'rina');
select throws_ok('select cs_api.legal_overview()', 'PT403', null, 'Agen CS tidak bisa membuka dokumen hukum');
reset role;
select tests.authenticate_agent(:'sinta');
select throws_ok('select cs_api.legal_overview()', 'PT403', null, 'Super Admin tidak mengelola dokumen hukum');
reset role;

select tests.authenticate_agent(:'kirana');
select throws_ok(format('select cs_api.legal_draft_save(null, %L, %L, %L)', 'rules', 'Aturan', :'body'),
  'PT400', 'invalid_legal_kind', 'Jenis dokumen yang tidak dikenal ditolak');
select throws_ok(format('select cs_api.legal_draft_save(null, %L, %L, %L)', 'terms', 'Syarat', 'pendek'),
  'PT400', 'invalid_legal_body', 'Isi dokumen yang terlalu pendek ditolak');
select throws_ok(format('select cs_api.legal_draft_save(null, %L, %L, %L, null, now() - interval ''1 day'')',
                        'terms', 'Syarat', :'body'),
  'PT400', 'legal_effective_past', 'Tanggal berlaku di masa lalu ditolak');
select cs_api.legal_draft_save(null, 'terms', 'Syarat dan Ketentuan Komunitas', :'body', 'Versi pertama') ->> 'id' as terms_draft \gset
select is((cs_api.legal_draft(:'terms_draft') ->> 'status'), 'draft', 'Draf tersimpan sebagai draf');
select is((cs_api.legal_draft(:'terms_draft') ->> 'created_by'), 'Kirana', 'Penyusun draf tercatat');
select cs_api.legal_draft_submit(:'terms_draft') as submitted \gset
select is((:'submitted'::jsonb ->> 'status'), 'pending', 'Draf diajukan untuk persetujuan');
select is((:'submitted'::jsonb ->> 'submitted_by_id'), :'kirana', 'ID pengaju dikirim agar web bisa menerapkan empat mata');
select throws_ok(format('select cs_api.legal_draft_save(%L, %L, %L, %L)', :'terms_draft', 'terms', 'Ubah', :'body'),
  'PT409', 'legal_draft_locked', 'Draf yang sedang ditinjau tidak bisa diubah');
select throws_ok(format('select cs_api.legal_draft_approve(%L)', :'terms_draft'), 'PT403', 'four_eyes',
  'Penyusun tidak bisa menyetujui drafnya sendiri bila ada staf kepatuhan lain');
reset role;

select tests.authenticate_agent(:'dewi');
select throws_ok(format('select cs_api.legal_draft_reject(%L, %L)', :'terms_draft', 'no'), 'PT400', 'legal_note_required',
  'Penolakan wajib disertai alasan');
select is((cs_api.legal_draft_reject(:'terms_draft', 'Tambahkan pasal tentang data pribadi') ->> 'status'), 'rejected',
  'Peninjau menolak draf');
reset role;

select tests.authenticate_agent(:'kirana');
select is((cs_api.legal_draft_save(:'terms_draft', 'terms', 'Syarat dan Ketentuan Komunitas', :'body' || ' Pasal 2. Data pribadi dilindungi.',
                                   'Versi pertama') ->> 'status'), 'draft', 'Draf yang ditolak bisa diperbaiki');
select cs_api.legal_draft_submit(:'terms_draft');
reset role;

select tests.authenticate_agent(:'dewi');
select cs_api.legal_draft_approve(:'terms_draft') as published \gset
select is((:'published'::jsonb ->> 'version')::integer, 1, 'Versi pertama terbit');
select is((:'published'::jsonb ->> 'approved_by'), 'Dewi', 'Penyetuju tercatat');
select is((:'published'::jsonb ->> 'in_effect')::boolean, true, 'Tanpa tanggal berlaku, dokumen langsung berlaku');
select is((cs_api.legal_draft(:'terms_draft') ->> 'status'), 'published', 'Draf berstatus terbit');
select is((select (details ->> 'self_approved')::boolean from cs.cs_audit_log
           where action = 'legal.published' order by created_at desc limit 1), false,
  'Audit mencatat penerbitan dengan empat mata');
select is((select (k ->> 'current')::jsonb ->> 'version' from jsonb_array_elements(cs_api.legal_overview() -> 'kinds') k
           where k ->> 'kind' = 'terms'), '1', 'Ringkasan menampilkan versi yang berlaku');
select is(jsonb_array_length(cs_api.legal_overview() -> 'drafts'), 0, 'Draf yang sudah terbit tidak muncul di daftar draf');
select is((cs_api.legal_overview() ->> 'four_eyes')::boolean, true, 'Empat mata aktif dengan dua staf kepatuhan');
select throws_ok(format('select cs_api.legal_draft_delete(%L)', :'terms_draft'), 'PT409', 'legal_draft_locked',
  'Draf yang sudah terbit tidak bisa dihapus');
reset role;

select tests.authenticate_as(:'budi');
select cs_api.open_ticket('account') ->> 'id' as ticket \gset
reset role;
select room_id as support from cs.tickets where id = :'ticket' \gset

select tests.authenticate_as(:'budi');
select is((select d ->> 'kind' from jsonb_array_elements(get_legal_documents()) d), 'terms',
  'Nasabah melihat dokumen yang berlaku');
select is((select (d ->> 'accepted')::boolean from jsonb_array_elements(get_legal_documents()) d), false,
  'Dokumen belum disetujui');
select is((select (d ->> 'required')::boolean from jsonb_array_elements(get_legal_documents()) d), true,
  'Syarat dan Ketentuan wajib disetujui');
select is((select d ->> 'change_summary' from jsonb_array_elements(get_legal_documents()) d), 'Versi pertama',
  'Ringkasan perubahan ikut dikirim');
select throws_ok($$select create_post('Halo komunitas, salam kenal', null, '[]', 'c4300000-0000-4000-8000-000000000001')$$,
  'PT403', 'consent_required', 'Posting ditolak sebelum menyetujui S&K');
select lives_ok(format($$select cs_api.send_message(%L, 'Saya butuh bantuan akun', 'c4300000-0000-4000-8000-000000000002')$$,
                       :'support'),
  'Chat CS tetap bisa dipakai tanpa menyetujui S&K');
select accept_legal_document(((get_legal_documents() -> 0) ->> 'id')::uuid);
select is((select (d ->> 'accepted')::boolean from jsonb_array_elements(get_legal_documents()) d), true,
  'Persetujuan tersimpan');
select lives_ok($$select create_post('Halo komunitas, salam kenal', null, '[]', 'c4300000-0000-4000-8000-000000000003')$$,
  'Setelah menyetujui, posting diterima');
select ok((select export_my_data() -> 'consents' -> 0 ->> 'title') = 'Syarat dan Ketentuan Komunitas',
  'Ekspor data memuat judul dokumen yang disetujui');
select is(jsonb_array_length(export_my_data() -> 'support_tickets'), 1, 'Ekspor data memuat tiket CS');
reset role;

select tests.authenticate_agent(:'kirana');
select cs_api.legal_draft_save(null, 'privacy', 'Kebijakan Privasi', :'body', null, now() + interval '1 day') ->> 'id'
  as privacy_draft \gset
select cs_api.legal_draft_submit(:'privacy_draft');
reset role;
select tests.authenticate_agent(:'dewi');
select cs_api.legal_draft_approve(:'privacy_draft') ->> 'id' as privacy_doc \gset
select is((select (k -> 'scheduled' ->> 'id') from jsonb_array_elements(cs_api.legal_overview() -> 'kinds') k
           where k ->> 'kind' = 'privacy'), :'privacy_doc', 'Dokumen dengan tanggal berlaku nanti tampil sebagai terjadwal');
select cs_api.legal_draft_save(null, 'privacy', 'Kebijakan Privasi v2', :'body') ->> 'id' as privacy_v2 \gset
select cs_api.legal_draft_submit(:'privacy_v2');
reset role;
select tests.authenticate_as(:'budi');
select is(jsonb_array_length(get_legal_documents()), 1, 'Dokumen terjadwal belum terlihat oleh nasabah');
reset role;
select tests.authenticate_agent(:'kirana');
select throws_ok(format('select cs_api.legal_draft_approve(%L)', :'privacy_v2'), 'PT409', 'legal_scheduled_exists',
  'Versi baru ditolak selama ada versi terjadwal');
select is((cs_api.legal_cancel_scheduled(:'privacy_doc') ->> 'draft'), :'privacy_draft', 'Jadwal dibatalkan');
select is((cs_api.legal_draft(:'privacy_draft') ->> 'status'), 'draft', 'Draf kembali menjadi draf');
select is((select count(*)::integer from public.legal_documents where kind = 'privacy'), 0, 'Dokumen terjadwal dihapus');
select throws_ok(format('select cs_api.legal_cancel_scheduled(%L)', (select id from public.legal_documents where kind = 'terms')),
  'PT409', 'legal_already_effective', 'Dokumen yang sudah berlaku tidak bisa dibatalkan');
reset role;

update cs.agents set disabled_at = now() where user_id = :'dewi';
select tests.authenticate_agent(:'kirana');
select is((cs_api.legal_overview() ->> 'four_eyes')::boolean, false, 'Satu staf kepatuhan: empat mata tidak bisa diterapkan');
select cs_api.legal_draft_save(null, 'community_guidelines', 'Pedoman Komunitas', :'body') ->> 'id' as guide_draft \gset
select cs_api.legal_draft_submit(:'guide_draft');
select is((cs_api.legal_draft_approve(:'guide_draft') ->> 'version')::integer, 1,
  'Staf kepatuhan tunggal boleh menyetujui drafnya sendiri');
select is((select (details ->> 'self_approved')::boolean from cs.cs_audit_log
           where action = 'legal.published' order by created_at desc limit 1), true,
  'Audit menandai persetujuan sendiri');

select throws_ok($$select cs_api.legal_set_required('{terms,cookies}')$$, 'PT400', 'invalid_legal_kind',
  'Jenis wajib yang tidak dikenal ditolak');
select is(cs_api.legal_set_required('{terms,privacy}'), '["privacy", "terms"]'::jsonb, 'Jenis dokumen wajib diubah');
select is((select details -> 'new' from cs.cs_audit_log where action = 'legal.required_changed'
           order by created_at desc limit 1), '["privacy", "terms"]'::jsonb, 'Perubahan dokumen wajib diaudit');
select lives_ok(format('select cs_api.legal_draft_delete(%L)', :'privacy_draft'), 'Draf dihapus');
select throws_ok(format('select cs_api.legal_draft(%L)', :'privacy_draft'), 'PT404', 'legal_draft_not_found',
  'Draf yang dihapus tidak bisa dibuka');
reset role;

select tests.authenticate_as(:'budi');
select lives_ok($$select create_post('Pedoman tidak wajib lagi, posting tetap jalan', null, '[]', 'c4300000-0000-4000-8000-000000000004')$$,
  'Dokumen yang tidak wajib tidak menghalangi posting');
reset role;
select tests.authenticate_agent(:'kirana');
select cs_api.legal_set_required('{community_guidelines,terms}');
reset role;
select tests.authenticate_as(:'budi');
select throws_ok($$select create_post('Postingan setelah pedoman wajib', null, '[]', 'c4300000-0000-4000-8000-000000000005')$$,
  'PT403', 'consent_required', 'Dokumen wajib baru harus disetujui sebelum posting');
reset role;

select tests.authenticate_anon();
select throws_ok('select get_legal_documents()', '42501', null, 'Anonim tidak bisa membaca dokumen lewat RPC');
reset role;

select * from finish();
rollback;
