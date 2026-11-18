# Modul Belajar: Memahami Sistem Rendezvous dari Dalam

Modul ini untuk yang sudah bisa SQL dasar (`select`, `join`, `insert`, `update`, `group by`) dan ingin memahami cara kerja seluruh sistem: dari fungsi SQL sampai pesan muncul di HP orang lain. Setiap modul memakai contoh dari kode kita sendiri dan punya latihan yang bisa dicoba di server dev.

Versi cetak semua modul dalam satu file: [Modul Belajar Rendezvous.pdf](Modul%20Belajar%20Rendezvous.pdf) (54 halaman). Bila modul diubah, PDF perlu dibuat ulang.

## Peta modul

| # | Modul | Yang dipelajari | Waktu |
|---|---|---|---|
| 1 | [SQL lanjutan](01-sql-lanjutan.md) | JSONB, array, CTE, `LATERAL`, upsert, cursor pagination | 2–3 jam |
| 2 | [Fungsi dan trigger](02-fungsi-trigger.md) | PL/pgSQL, volatility, `SECURITY DEFINER`, trigger, error `api_error` | 3 jam |
| 3 | [Role, GRANT, dan RLS](03-role-grant-rls.md) | Siapa boleh apa, `auth.uid()`, policy, meniru pengguna | 3 jam |
| 4 | [PostgREST dan JWT](04-postgrest-jwt.md) | Fungsi jadi API, isi token, alur login, mencoba dengan `curl` | 2 jam |
| 5 | [Transaksi, kunci, PgBouncer](05-transaksi-kunci-pgbouncer.md) | ACID, MVCC, lock, `SKIP LOCKED`, connection pooling, index | 3 jam |
| 6 | [Realtime](06-realtime.md) | WebSocket, Phoenix, broadcast dari database, gap-fill | 2 jam |
| 7 | [Pola backend](07-pola-backend.md) | Antrean + lease, idempotensi, push FCM, media, cron | 2 jam |
| 8 | [Infrastruktur](08-infrastruktur.md) | Docker Compose, Kong, Traefik, secrets, healthcheck, replika, backup | 2–3 jam |
| 9 | [Pengujian](09-pengujian.md) | pgTAP, menulis tes sendiri, tes Go dan Flutter | 2 jam |
| 10 | [Klien Flutter](10-klien-flutter.md) | Struktur library, Cubit, model, builder slot | 2 jam |
| 11 | [Proyek akhir](11-proyek-akhir.md) | Menelusuri satu fitur dari ujung ke ujung, lalu membuat fitur kecil | 3–4 jam |

Urutan 1 → 4 adalah inti; setelah empat modul itu sebagian besar kode server sudah bisa dibaca. Modul 5 → 11 boleh dipilih sesuai kebutuhan.

## Menyiapkan lab

Semua latihan SQL dijalankan di database **dev** lewat psql:

```powershell
.\make.ps1 psql        # Windows
make psql              # Linux/macOS
```

Perintah ini membuka psql sebagai `postgres` ke container `db`. Di Supabase, `postgres` bukan superuser penuh, tetapi pemilik hampir semua tabel dan **melewati RLS** (`bypassrls`), jadi ia melihat semua data. Di modul 3 kita belajar meniru pengguna biasa. Di dalam psql:

```sql
\dn                         -- daftar schema
\dt public.*                -- daftar tabel di public
\df public.send_message     -- tanda tangan fungsi
\sf public.get_dm_policy    -- isi lengkap fungsi
\d public.messages          -- struktur tabel + index + trigger + policy
\x auto                     -- tampilan lebar otomatis untuk baris panjang
```

### Aturan aman: selalu `begin` … `rollback`

Database dev berisi data contoh yang dipakai bersama. Untuk latihan yang **mengubah** sesuatu (insert, membuat fungsi, meniru pengguna), selalu bungkus dengan transaksi lalu batalkan:

```sql
begin;
  -- latihan di sini
rollback;   -- semua perubahan dibatalkan, termasuk create function / create table
```

Di Postgres hampir semua perintah, termasuk `create table` dan `create function`, ikut dibatalkan oleh `rollback`. Ini salah satu kelebihan Postgres dibanding database lain. Jangan menjalankan `commit` dalam latihan.

Yang **tidak** boleh dilakukan di latihan: menjalankan migrasi, mengubah file di `supabase/migrations/`, mengubah `docker/.env`, atau menghapus volume Docker.

## Cara membaca kode server

| Yang dicari | Tempat |
|---|---|
| Definisi terbaru sebuah fungsi | `\sf nama_fungsi` di psql, atau cari di [supabase/migrations](../../supabase/migrations) (fungsi bisa didefinisikan ulang di migrasi yang lebih baru; ambil nomor terbesar) |
| Tes sebuah fitur | [supabase/tests](../../supabase/tests), nomornya kira-kira mengikuti migrasi |
| Layanan Go | [services/](../../services) — setiap folder punya `README.md` |
| Rute HTTP | Kong: [docker/volumes/api/kong.yml](../../docker/volumes/api/kong.yml) |
| Semua container | [docker/compose.yml](../../docker/compose.yml) |
| Kontrak API | [docs/api](../api/README.md) |

## Bacaan resmi yang dipakai di modul

- PostgreSQL: <https://www.postgresql.org/docs/17/>
- PostgREST: <https://docs.postgrest.org>
- Supabase (RLS, Realtime, Storage): <https://supabase.com/docs>
- pgTAP: <https://pgtap.org>
- JWT: <https://jwt.io/introduction>
