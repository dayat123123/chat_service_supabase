begin;
select plan(52);

select tests.create_agent('Sinta Aman', '{cs_super_admin}', '{}') as sinta \gset
select tests.create_agent('Adi Aman', '{cs_super_admin}', '{}') as adi \gset
select tests.create_agent('Rina Aman', '{cs_agent}') as rina \gset
select tests.create_agent('Dimas Aman', '{cs_agent}') as dimas \gset
select tests.create_agent('Kirana Aman', '{compliance}', '{}') as kirana \gset
insert into auth.users (id, email, aud, role) values
  (:'sinta', 'sinta.aman@cs.test', 'authenticated', 'authenticated'),
  (:'adi', 'adi.aman@cs.test', 'authenticated', 'authenticated'),
  (:'rina', 'rina.aman@cs.test', 'authenticated', 'authenticated'),
  (:'dimas', 'dimas.aman@cs.test', 'authenticated', 'authenticated'),
  (:'kirana', 'kirana.aman@cs.test', 'authenticated', 'authenticated');
insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at) values
  (gen_random_uuid(), :'dimas', 'HP Dimas', 'totp', 'verified', now(), now()),
  (gen_random_uuid(), :'adi', 'HP Adi', 'totp', 'verified', now(), now());
insert into auth.sessions (id, user_id) values ('5e1f0000-0000-4000-8000-0000000000a1', :'adi');
update cs.agents set nasabah_permissions = '{online_user.view}' where user_id in (:'rina', :'dimas');

select is(cs.setting('security.mfa_required_roles'), '["cs_super_admin"]'::jsonb, 'Bawaan: Super Admin wajib 2FA');
select is(cs.setting_int('security.login_max_failures'), 5, 'Bawaan: dikunci setelah 5 kali gagal');
select is(cs.setting_int('security.login_lock_minutes'), 15, 'Bawaan: dikunci 15 menit');

select tests.authenticate_agent(:'sinta', 'aal1');
select throws_ok('select cs_api.agent_me()', 'PT401', 'mfa_required', 'Super Admin tanpa kode 2FA ditolak');
select ok(cs.current_agent_id() is null, 'Super Admin tanpa kode 2FA belum dianggap agen');
select is(cs_api.agent_security_status(), '{"mfa_required": true, "mfa_enrolled": false, "aal": "aal1"}'::jsonb,
  'Status keamanan memberi tahu Hub bahwa 2FA wajib dan belum didaftarkan');
reset role;

select tests.authenticate_agent(:'sinta');
select is(cs_api.agent_me() ->> 'id', :'sinta', 'Super Admin dengan kode 2FA bisa bekerja');
reset role;

select tests.authenticate_agent(:'rina', 'aal1');
select is(cs_api.agent_me() ->> 'id', :'rina', 'Agen CS tanpa kewajiban 2FA tetap bisa bekerja dengan password');
select is(cs_api.agent_security_status(), '{"mfa_required": false, "mfa_enrolled": false, "aal": "aal1"}'::jsonb,
  'Status keamanan agen CS tanpa kewajiban');
reset role;

select tests.authenticate_agent(:'dimas', 'aal1');
select throws_ok('select cs_api.agent_me()', 'PT401', 'mfa_required',
  'Staf yang sudah mendaftarkan 2FA wajib memasukkan kodenya walau perannya tidak diwajibkan');
select is(cs_api.agent_security_status() -> 'mfa_enrolled', 'true'::jsonb, 'Status keamanan tahu 2FA sudah terdaftar');
reset role;

select tests.authenticate_as(tests.create_user('aman_budi'));
select throws_ok('select cs_api.agent_security_status()', 'PT403', 'agent_required', 'Nasabah tidak punya status keamanan staf');
reset role;

select tests.authenticate_agent(:'sinta');
select throws_ok($$select cs_api.admin_set_setting('security.mfa_required_roles', '["cs_agent"]')$$,
  'PT400', 'invalid_setting', 'Super Admin tidak bisa dilepas dari kewajiban 2FA');
select throws_ok($$select cs_api.admin_set_setting('security.mfa_required_roles', '["cs_super_admin", "tamu"]')$$,
  'PT400', 'invalid_setting', 'Peran tidak dikenal ditolak');
select throws_ok($$select cs_api.admin_set_setting('security.mfa_required_roles', '["cs_super_admin", "cs_super_admin"]')$$,
  'PT400', 'invalid_setting', 'Peran ganda ditolak');
select throws_ok($$select cs_api.admin_set_setting('security.login_max_failures', '2')$$,
  'PT400', 'invalid_setting', 'Batas gagal di bawah 3 ditolak');
select throws_ok($$select cs_api.admin_set_setting('security.login_lock_minutes', '0')$$,
  'PT400', 'invalid_setting', 'Lama kunci 0 menit ditolak');
select lives_ok($$select cs_api.admin_set_setting('security.mfa_required_roles', '["cs_super_admin", "product", "compliance"]')$$,
  'Peran lain seperti Produk dan Kepatuhan bisa ikut diwajibkan 2FA');
reset role;
select is((select count(*)::int from cs.cs_audit_log where action = 'setting.update'
             and details ->> 'key' = 'security.mfa_required_roles'), 1, 'Perubahan kewajiban 2FA tercatat di audit');

select tests.authenticate_agent(:'kirana', 'aal1');
select throws_ok('select cs_api.agent_me()', 'PT401', 'mfa_required', 'Peran yang baru diwajibkan langsung diminta kode 2FA');
reset role;

select tests.authenticate_agent(:'rina');
select throws_ok($$select cs_api.admin_set_setting('security.login_max_failures', '6')$$,
  'PT403', 'role_forbidden', 'Agen CS tidak bisa mengubah pengaturan keamanan');
reset role;

select ok(has_function_privilege('supabase_auth_admin', 'private.hook_password_verification_attempt(jsonb)', 'execute'),
  'Layanan login bisa memanggil hook percobaan password');
select ok(not has_function_privilege('authenticated', 'private.hook_password_verification_attempt(jsonb)', 'execute')
          and not has_function_privilege('anon', 'private.hook_password_verification_attempt(jsonb)', 'execute'),
  'Klien tidak bisa memanggil hook percobaan password');

create function pg_temp.attempt(p_user uuid, p_valid boolean) returns jsonb language sql as $$
  select private.hook_password_verification_attempt(jsonb_build_object('user_id', p_user, 'valid', p_valid));
$$;

select is(pg_temp.attempt(:'rina', false) ->> 'decision', 'continue', 'Gagal pertama hanya ditolak sebagai password salah');
select pg_temp.attempt(:'rina', false) as r2, pg_temp.attempt(:'rina', false) as r3,
       pg_temp.attempt(:'rina', false) as r4 \gset
select ok((select locked_until is null from private.staff_login_guard where user_id = :'rina'), 'Empat kali gagal belum mengunci');
select pg_temp.attempt(:'rina', false) as lock_reply \gset
select is(:'lock_reply'::jsonb ->> 'decision', 'reject', 'Gagal kelima mengunci akun');
select ok(:'lock_reply'::jsonb ->> 'message' like 'account_locked:%', 'Pesan kunci membawa waktu buka kunci');
select ok((select locked_until between now() + interval '14 minutes' and now() + interval '16 minutes'
           from private.staff_login_guard where user_id = :'rina'), 'Akun dikunci 15 menit');
select is(pg_temp.attempt(:'rina', true) ->> 'decision', 'reject', 'Password benar pun ditolak selama terkunci');
select is((select count(*)::int from cs.cs_audit_log where action = 'security.login_locked'
             and details ->> 'user_id' = :'rina' and details ->> 'email' = 'rina.aman@cs.test'), 1,
  'Penguncian tercatat sekali di audit lengkap dengan email');

update private.staff_login_guard set locked_until = now() - interval '1 second' where user_id = :'rina';
select is(pg_temp.attempt(:'rina', true) ->> 'decision', 'continue', 'Setelah masa kunci habis password benar diterima');
select ok(not exists (select 1 from private.staff_login_guard where user_id = :'rina'), 'Login berhasil menghapus hitungan gagal');

select pg_temp.attempt(:'dimas', false) as d1, pg_temp.attempt(:'dimas', false) as d2,
       pg_temp.attempt(:'dimas', false) as d3, pg_temp.attempt(:'dimas', false) as d4 \gset
update private.staff_login_guard set window_started_at = now() - interval '16 minutes' where user_id = :'dimas';
select is(pg_temp.attempt(:'dimas', false) ->> 'decision', 'continue', 'Gagal lama di luar jendela 15 menit tidak dihitung');
select is((select failures from private.staff_login_guard where user_id = :'dimas'), 1, 'Hitungan gagal dimulai lagi');

select tests.authenticate_agent(:'sinta');
select lives_ok($$select cs_api.admin_set_setting('security.login_max_failures', '3')$$, 'Batas gagal bisa diubah');
select lives_ok($$select cs_api.admin_set_setting('security.login_lock_minutes', '30')$$, 'Lama kunci bisa diubah');
reset role;
select pg_temp.attempt(:'kirana', false) as k1, pg_temp.attempt(:'kirana', false) as k2 \gset
select is(pg_temp.attempt(:'kirana', false) ->> 'decision', 'reject', 'Batas gagal baru langsung berlaku');
select ok((select locked_until > now() + interval '29 minutes' from private.staff_login_guard where user_id = :'kirana'),
  'Lama kunci baru langsung berlaku');

select tests.authenticate_agent(:'sinta');
select is((select e ->> 'locked_until' from jsonb_array_elements(cs_api.admin_agents()) e where e ->> 'id' = :'kirana') is not null,
  true, 'Daftar akun menampilkan akun yang sedang terkunci');
select is((select e -> 'totp' from jsonb_array_elements(cs_api.admin_agents()) e where e ->> 'id' = :'adi'), 'true'::jsonb,
  'Daftar akun menampilkan status 2FA');
select ok(cs_api.admin_unlock_agent(:'kirana') ->> 'locked_until' is null, 'Super Admin bisa membuka kunci akun');
select ok(cs_api.admin_reset_agent_mfa(:'adi') -> 'totp' = 'false'::jsonb, 'Super Admin bisa mereset 2FA staf lain');
select throws_ok(format('select cs_api.admin_reset_agent_mfa(%L)', :'sinta'), 'PT400', 'cannot_reset_self',
  'Super Admin tidak bisa mereset 2FA dirinya sendiri dari Hub');
reset role;
select ok(not exists (select 1 from auth.sessions where user_id = :'adi'), 'Reset 2FA mengeluarkan semua sesi staf itu');
select is((select count(*)::int from cs.cs_audit_log where action in ('security.login_unlocked', 'security.mfa_reset')
             and actor_id = :'sinta'), 2, 'Buka kunci dan reset 2FA tercatat atas nama Super Admin');

select tests.authenticate_agent(:'rina');
select throws_ok(format('select cs_api.admin_unlock_agent(%L)', :'kirana'), 'PT403', 'role_forbidden',
  'Agen CS tidak bisa membuka kunci akun');
reset role;

select ok(cs_api.nasabah_access(:'rina', 'aal1') is not null, 'Gateway Akun Nasabah menerima agen CS tanpa kewajiban 2FA');
select ok(cs_api.nasabah_access(:'dimas', 'aal1') is null and cs_api.nasabah_access(:'dimas', 'aal2') is not null,
  'Gateway Akun Nasabah menolak staf ber-2FA sebelum kodenya dimasukkan');
select ok(not cs_api.nasabah_is_super_admin(:'sinta', 'aal1') and cs_api.nasabah_is_super_admin(:'sinta', 'aal2'),
  'Pengaturan integrasi csAdmin butuh kode 2FA Super Admin');

select ok(not has_function_privilege('authenticated', 'private.staff_security_recover(text)', 'execute'),
  'Pemulihan darurat tidak bisa dipanggil dari klien');
insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at)
values (gen_random_uuid(), :'sinta', 'HP Sinta', 'totp', 'verified', now(), now());
select is(private.staff_security_recover('SINTA.aman@cs.test') ->> 'agent_id', :'sinta',
  'Pemulihan darurat dari server menemukan staf lewat email');
select ok(not exists (select 1 from auth.mfa_factors where user_id = :'sinta'), 'Pemulihan darurat menghapus 2FA staf itu');

select * from finish();
rollback;
