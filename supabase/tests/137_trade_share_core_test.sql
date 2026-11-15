begin;
select plan(48);

update cs.cs_settings set value = 'true' where key = 'trade_share.enabled';
update cs.cs_settings set value = 'false' where key = 'trade_share.pilot_only';
delete from private.trade_sharers;
delete from private.trade_share_excluded_accounts;

select tests.create_user('ts_budi') as budi \gset
select tests.create_user('ts_sari') as sari \gset
select tests.create_user('ts_baru') as baru \gset
update public.profiles set created_at = now() - interval '90 days' where id in (:'budi', :'sari');

insert into private.account_links (cust_id, profile_id) values
  ('ACC1', :'budi'), ('ACC2', :'budi'), ('SHARED1', :'budi'), ('SHARED1', :'sari'), ('NEW1', :'baru');

insert into public.legal_documents (kind, version, title, body, effective_at)
values ('trade_share_terms', 1, 'S&K Berbagi Trade', 'Isi syarat dan ketentuan berbagi trade untuk pengujian.',
        now() - interval '1 hour')
returning id as terms \gset

select tests.create_agent('Kirana', '{compliance}') as kirana \gset
select tests.create_agent('Laras', '{compliance}') as laras \gset
select tests.create_agent('Tanpa Izin', '{cs_agent}') as plain \gset
select tests.create_agent('Super', '{cs_super_admin}') as superadmin \gset

select tests.authenticate_agent(:'superadmin');
select throws_ok(format('select cs_api.admin_set_trade_permissions(%L, %L)', :'kirana', '{trade_share.unknown}'),
  'PT400', 'invalid_permission', 'Kode izin Berbagi Trade yang tidak dikenal ditolak');
select is(cs_api.admin_set_trade_permissions(:'kirana', '{trade_share.review,trade_share.manage}') -> 'trade_permissions',
  '["trade_share.manage", "trade_share.review"]'::jsonb, 'Super Admin memberi izin Berbagi Trade ke staf');
select cs_api.admin_set_trade_permissions(:'laras', '{trade_share.review}') as laras_perm \gset

select tests.authenticate_anon();
select throws_ok('select public.get_trade_share_status()', '42501', null, 'Anon tidak bisa membaca status berbagi trade');

select tests.authenticate_as(:'budi');
select public.get_trade_share_status() as st \gset
select ok((:'st'::jsonb #>> '{eligibility,eligible}')::boolean, 'Nasabah lama dengan rekening aktif memenuhi syarat');
select is((select a ->> 'state' from jsonb_array_elements(:'st'::jsonb #> '{eligibility,accounts}') a
            where a ->> 'cust_id' = 'SHARED1'), 'shared_link', 'Rekening yang tertaut ke profil lain ditandai shared_link');
select is((select a ->> 'state' from jsonb_array_elements(:'st'::jsonb #> '{eligibility,accounts}') a
            where a ->> 'cust_id' = 'ACC1'), 'active', 'Rekening milik sendiri berstatus active');

select tests.authenticate_as(:'baru');
select ok(not (public.get_trade_share_status() #>> '{eligibility,eligible}')::boolean,
  'Profil baru belum memenuhi syarat umur akun');

select tests.authenticate_as(:'budi');
select throws_ok(format('select public.submit_trade_share_application(%L, true, true, 15, %L, %L)',
                        '{ACC1,SHARED1}', 'auto', :'terms'),
  'PT400', 'account_not_eligible', 'Rekening bersama tidak boleh dibagikan');
select throws_ok(format('select public.submit_trade_share_application(%L, true, true, 15, %L, %L)',
                        '{ACC1}', 'auto', gen_random_uuid()),
  'PT409', 'terms_outdated', 'S&K yang bukan versi terbaru ditolak');
select throws_ok(format('select public.submit_trade_share_application(%L, true, true, 5, %L, %L)',
                        '{ACC1}', 'auto', :'terms'),
  'PT400', 'invalid_delay', 'Jeda di bawah minimum ditolak');
select is(public.submit_trade_share_application('{acc1, ACC2}', true, false, 15, 'auto', :'terms') ->> 'status',
  'pending', 'Pengajuan trader tersimpan sebagai pending');
select ok(exists (select 1 from public.user_consents where user_id = :'budi' and document_id = :'terms'),
  'Persetujuan S&K tercatat saat mengajukan');
reset role;
select is((select array_agg(cust_id order by cust_id) from private.trade_sharer_accounts where profile_id = :'budi'),
  '{ACC1,ACC2}'::text[], 'Nomor rekening dinormalisasi ke huruf besar');
select tests.authenticate_as(:'budi');
select throws_ok(format('select public.submit_trade_share_application(%L, true, true, 15, %L, %L)',
                        '{ACC1}', 'auto', :'terms'),
  'PT409', 'already_applied', 'Pengajuan ganda ditolak');

select tests.authenticate_agent(:'plain');
select throws_ok('select cs_api.trade_share_list()', 'PT403', 'trade_forbidden', 'Staf tanpa izin tidak bisa melihat pengajuan');

select tests.authenticate_agent(:'kirana');
select is(jsonb_array_length(cs_api.trade_share_list('pending')), 1, 'Pengajuan pending tampil di Hub');
select throws_ok(format('select cs_api.trade_share_decide(%L, %L, null)', :'budi', 'reject'),
  'PT400', 'reason_required', 'Penolakan wajib beralasan');

reset role;
update cs.cs_settings set value = 'true' where key = 'trade_share.four_eyes';
select tests.authenticate_agent(:'kirana');
select is(cs_api.trade_share_decide(:'budi', 'approve', 'Profil layak') ->> 'status', 'pending',
  'Empat mata: persetujuan pertama hanya menjadi usulan');
select throws_ok(format('select cs_api.trade_share_decide(%L, %L, null)', :'budi', 'approve'),
  'PT409', 'four_eyes_same_agent', 'Empat mata: staf yang sama tidak bisa menyetujui dua kali');
select tests.authenticate_agent(:'laras');
select is(cs_api.trade_share_decide(:'budi', 'approve', null) ->> 'status', 'active',
  'Empat mata: staf kedua mengaktifkan trader');
reset role;
select is((select array_agg(action order by id) from private.trade_share_events where profile_id = :'budi'),
  '{applied,approval_proposed,approved}'::text[], 'Riwayat keputusan tercatat berurutan');
select ok(exists (select 1 from cs.cs_audit_log where action = 'trade_share.approve' and customer_id = :'budi'),
  'Persetujuan tercatat di jejak audit');

reset role;
delete from private.account_links where cust_id in ('ACC1', 'ACC2') and profile_id = :'budi';
select is((select status from private.trade_sharers where profile_id = :'budi'), 'paused',
  'Trader dijeda otomatis bila semua rekening tidak tertaut lagi');
select is((select pause_source from private.trade_sharers where profile_id = :'budi'), 'system',
  'Jeda otomatis ditandai dari sistem');
insert into private.account_links (cust_id, profile_id) values ('ACC1', :'budi');
select is((select status from private.trade_sharers where profile_id = :'budi'), 'active',
  'Trader aktif lagi otomatis saat rekening tertaut kembali');
select is((select state from private.trade_sharer_accounts where profile_id = :'budi' and cust_id = 'ACC2'), 'unlinked',
  'Rekening yang belum tertaut kembali tetap unlinked');

insert into private.account_links (cust_id, profile_id) values ('ACC1', :'sari');
select is((select state from private.trade_sharer_accounts where profile_id = :'budi' and cust_id = 'ACC1'), 'shared_link',
  'Rekening yang mulai tertaut ke profil kedua langsung diblokir dari berbagi');
select is((select status from private.trade_sharers where profile_id = :'budi'), 'paused',
  'Trader dijeda karena tidak ada rekening yang aman dibagikan');
delete from private.account_links where cust_id = 'ACC1' and profile_id = :'sari';
insert into private.account_links (cust_id, profile_id) values ('ACC2', :'budi');

select tests.authenticate_agent(:'kirana');
select is(jsonb_array_length(cs_api.trade_share_exclude_account('acc2', 'Rekening karyawan')), 1,
  'Kepatuhan menambah rekening dikecualikan');
reset role;
select is((select state from private.trade_sharer_accounts where profile_id = :'budi' and cust_id = 'ACC2'), 'excluded',
  'Rekening dikecualikan tidak dibagikan');

select tests.authenticate_as(:'budi');
select throws_ok(format('select public.update_trade_share_settings(%L, false, false, 20, %L)', '{ACC1}', 'approval'),
  'PT409', 'confirmation_required', 'Perubahan cakupan data wajib dikonfirmasi');
select is(public.update_trade_share_settings('{ACC1}', false, false, 20, 'approval', true) ->> 'subscribe_mode',
  'approval', 'Trader mengubah pengaturan setelah konfirmasi');
select is(public.pause_trade_share() ->> 'status', 'paused', 'Trader menjeda sendiri');
select is(public.resume_trade_share() ->> 'status', 'active', 'Trader melanjutkan sendiri');

select tests.authenticate_agent(:'laras');
select throws_ok(format('select cs_api.trade_share_update_setting(%L, %L, %L)', 'trade_share.min_delay_minutes', '30', 'Uji'),
  'PT403', 'trade_forbidden', 'Hanya izin manage yang bisa mengubah pengaturan');
select tests.authenticate_agent(:'kirana');
select throws_ok(format('select cs_api.trade_share_update_setting(%L, %L, %L)', 'trade_share.min_delay_minutes', '0', 'Uji'),
  'PT400', 'invalid_setting', 'Nilai pengaturan di luar batas ditolak');
select lives_ok(format('select cs_api.trade_share_update_setting(%L, %L, %L)', 'trade_share.min_delay_minutes', '30', 'Kebijakan baru'),
  'Kepatuhan menaikkan jeda minimum');
reset role;
select is((select delay_minutes from private.trade_sharers where profile_id = :'budi'), 30,
  'Jeda trader ikut naik ke minimum baru');
select tests.authenticate_agent(:'kirana');

select is(cs_api.trade_share_suspend(:'budi', 'Dalam pemeriksaan', now() + interval '1 day') ->> 'status', 'suspended',
  'Kepatuhan menangguhkan trader');
select tests.authenticate_as(:'budi');
select throws_ok('select public.resume_trade_share()', 'PT409', 'not_paused', 'Trader tidak bisa mengakhiri penangguhan sendiri');
select tests.authenticate_agent(:'kirana');
select is(cs_api.trade_share_reinstate(:'budi', 'Pemeriksaan selesai') ->> 'status', 'active',
  'Kepatuhan mengaktifkan kembali trader');
select is(cs_api.trade_share_revoke(:'budi', 'Melanggar ketentuan') ->> 'status', 'revoked', 'Kepatuhan mencabut trader');

select tests.authenticate_as(:'budi');
select ok(not (public.get_trade_share_status() #>> '{eligibility,eligible}')::boolean,
  'Setelah dicabut, trader dalam masa tunggu');
select throws_ok(format('select public.submit_trade_share_application(%L, true, true, 30, %L, %L)',
                        '{ACC1}', 'auto', :'terms'),
  'PT403', 'not_eligible', 'Pengajuan ulang selama masa tunggu ditolak');

reset role;
update private.trade_sharers set cooldown_until = now() - interval '1 minute' where profile_id = :'budi';
select tests.authenticate_as(:'budi');
select is(public.submit_trade_share_application('{ACC1}', true, true, 30, 'auto', :'terms') ->> 'status', 'pending',
  'Setelah masa tunggu, trader bisa mengajukan lagi');
select is(public.withdraw_trade_share() ->> 'status', 'withdrawn', 'Trader membatalkan sendiri');

reset role;
update cs.cs_settings set value = 'true' where key = 'trade_share.pilot_only';
select tests.authenticate_as(:'sari');
select ok(not (public.get_trade_share_status() #>> '{eligibility,eligible}')::boolean,
  'Mode pilot: profil tanpa undangan tidak memenuhi syarat');

reset role;
update public.profiles set deleted_at = now() where id = :'budi';
select ok(not exists (select 1 from private.trade_sharers where profile_id = :'budi'),
  'Hapus akun menghapus data berbagi trade');

select * from finish();
rollback;
