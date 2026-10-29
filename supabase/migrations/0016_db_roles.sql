-- olt:run-as=supabase_admin
-- 0016_db_roles.sql
-- Role & batas DB (docs/PROMPT-PRODUCTION.md 4.5). Butuh superuser karena
-- authenticator & supabase_* adalah reserved role image Supabase; karena itu
-- file ini dijalankan sebagai supabase_admin (lihat scripts/migrate.sh).
--
-- Pemisahan role:
--   anon            hampir tanpa akses (tes 001)
--   authenticated   user aplikasi (RLS), statement_timeout 8 dtk (default image)
--   service_role    service internal (auth-bridge), statement_timeout 15 dtk
--   postgres        pemilik objek & role migrasi
--   olt_monitor     read-only untuk monitoring (pg_monitor), login di Tahap 6

-- Batas koneksi per role (PgBouncer membatasi total koneksi server 80).
alter role authenticator connection limit 60;
alter role supabase_auth_admin connection limit 20;
alter role supabase_storage_admin connection limit 30;
alter role pgbouncer connection limit 5;

-- Transaksi yang menggantung tidak boleh menahan lock/koneksi.
alter role authenticator set idle_in_transaction_session_timeout = '30s';
alter role supabase_storage_admin set idle_in_transaction_session_timeout = '60s';

-- service_role (auth-bridge, job internal) juga dibatasi.
alter role service_role set statement_timeout = '15s';

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'olt_monitor') then
    create role olt_monitor nologin;
  end if;
end;
$$;
grant pg_monitor to olt_monitor;

-- Realtime: ukuran payload maks 64 KB (docs/PROMPT-PRODUCTION.md bagian 3).
-- Batas lain diatur env TENANT_MAX_* (docker/compose.yml).
update _realtime.tenants set max_payload_size_in_kb = 64 where max_payload_size_in_kb > 64;
