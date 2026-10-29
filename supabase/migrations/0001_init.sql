-- 0001_init.sql
-- Fondasi skema OLT Social: extension yang dibutuhkan fitur berikutnya.
-- Tabel, trigger, RPC, dan RLS ditambahkan di migrasi selanjutnya (Tahap 2).

-- ltree: path komentar berantai (comments.path)
create extension if not exists ltree with schema extensions;

-- citext: username unik tanpa membedakan huruf besar/kecil
create extension if not exists citext with schema extensions;

-- pg_trgm: pencarian username / kode saham
create extension if not exists pg_trgm with schema extensions;
