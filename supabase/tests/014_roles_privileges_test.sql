begin;
select plan(18);

select ok((select 'statement_timeout=15s' = any (s.setconfig)
           from pg_db_role_setting s join pg_roles r on r.oid = s.setrole
           where r.rolname = 'service_role' and s.setdatabase = 0),
  'service_role: statement_timeout 15 detik');
select ok((select 'idle_in_transaction_session_timeout=30s' = any (s.setconfig)
           from pg_db_role_setting s join pg_roles r on r.oid = s.setrole
           where r.rolname = 'authenticator' and s.setdatabase = 0),
  'authenticator: transaksi menggantung diputus setelah 30 detik');
select is((select rolconnlimit from pg_roles where rolname = 'authenticator'), 60,
  'authenticator: batas 60 koneksi');
select ok(pg_has_role('olt_monitor', 'pg_monitor', 'member'), 'Role monitoring read-only tersedia');

select is((select count(*)::int
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private', 'admin_api') and p.prosecdef
             and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')),
  0, 'Semua fungsi SECURITY DEFINER menetapkan search_path');
select is((select count(*)::int
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('private', 'admin_api')
             and exists (select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                         where a.grantee = 0 and a.privilege_type = 'EXECUTE')),
  0, 'Tidak ada fungsi private/admin_api yang bisa dieksekusi PUBLIC');
select is((select count(*)::int
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'admin_api' and has_function_privilege('anon', p.oid, 'EXECUTE')),
  0, 'anon tidak bisa memanggil API admin');

select ok(not has_table_privilege('authenticated', 'private.admin_users', 'SELECT'), 'Daftar admin tidak terbaca user');
select ok(not has_table_privilege('authenticated', 'private.admin_audit_log', 'SELECT'), 'Audit log tidak terbaca user');
select ok(not has_table_privilege('authenticated', 'private.user_sanctions', 'SELECT'), 'Tabel sanksi tidak terbaca user');
select ok(not has_column_privilege('authenticated', 'public.posts', 'moderation_status', 'UPDATE'),
  'User tidak bisa mengubah status moderasi post-nya');
select ok(not has_column_privilege('authenticated', 'public.posts', 'moderation_status', 'INSERT'),
  'User tidak bisa menentukan status moderasi saat membuat post');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'trust_level', 'UPDATE'),
  'User tidak bisa menaikkan trust_level sendiri');

-- PostgREST runs the pre-request for every role used through the API.
select ok(has_function_privilege('service_role', 'private.check_request()', 'EXECUTE'),
  'Pre-request bisa dijalankan service_role (auth-bridge)');
select tests.authenticate_anon();
select lives_ok($$select private.check_request()$$, 'Pre-request PostgREST aman untuk anon');
reset role;
select tests.authenticate_as(gen_random_uuid());
select lives_ok($$select private.check_request()$$, 'Pre-request lolos untuk JWT tanpa sesi yang dicabut');
reset role;

select is((select count(*)::int from cron.job
           where jobname in ('olt-retention', 'olt-promote-new-accounts')), 2,
  'Job retensi & promosi akun baru terjadwal (pg_cron)');
select is((select count(distinct action)::int from private.rate_limits
           where action in ('post', 'comment', 'message', 'reaction', 'follow', 'report',
                            'room_create', 'upload', 'data_export')), 9,
  'Rate limit untuk semua aksi terkonfigurasi');

select * from finish();
rollback;
