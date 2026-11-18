# Modul 5: Transaksi, Kunci, Index, dan PgBouncer

**Tujuan:** mengerti apa yang terjadi saat ratusan orang mengirim pesan bersamaan: kenapa data tidak rusak, kenapa query tetap cepat, dan kenapa database tidak kehabisan koneksi.

Beberapa latihan butuh **dua jendela psql** bersamaan. Sebut saja **Sesi A** dan **Sesi B**.

---

## 5.1 Transaksi dan ACID

| Huruf | Arti | Contoh di sistem kita |
|---|---|---|
| **A**tomicity | Semua langkah berhasil atau semua batal | `send_message` menyimpan pesan, memperbarui room, dan membuat notifikasi. Kalau satu gagal, tidak ada yang tersimpan |
| **C**onsistency | Constraint selalu terjaga | `messages_client_id_key` unik per pengirim: pesan ganda mustahil |
| **I**solation | Transaksi yang berjalan bersamaan tidak saling mengacaukan | Dua orang bereaksi di pesan yang sama → hitungan tetap benar |
| **D**urability | Setelah `commit`, data tidak hilang walau server mati | Ditulis ke WAL lebih dulu (modul 8, backup) |

Setiap request PostgREST adalah satu transaksi. Di psql, tanpa `begin`, setiap pernyataan adalah transaksinya sendiri (*autocommit*).

## 5.2 MVCC: membaca tidak menghalangi menulis

Postgres memakai **MVCC** (*Multi-Version Concurrency Control*). Saat sebuah baris di-update, Postgres tidak menimpanya, tetapi membuat **versi baru** dan menandai versi lama sebagai usang. Transaksi lain yang sedang membaca tetap melihat versi lama yang konsisten.

Akibatnya:
- Pembaca **tidak pernah** menunggu penulis, dan sebaliknya.
- Dua penulis di **baris yang sama** harus antre (5.3).
- Versi usang dibersihkan proses **autovacuum**.

Level isolasi bawaan kita adalah `read committed` (`show default_transaction_isolation;`): setiap pernyataan melihat data yang sudah di-commit saat pernyataan itu dimulai.

### Latihan: melihat isolasi

Tabel `temp` hanya terlihat di sesinya sendiri, jadi latihan ini memakai tabel sungguhan. Tetap aman karena keduanya diakhiri `rollback`:

| Sesi A | Sesi B |
|---|---|
| `begin;` | |
| `update public.profiles set bio = 'uji A' where username = 'budi_santoso';` | |
| | `select bio from public.profiles where username = 'budi_santoso';` → **bio lama** (perubahan A belum di-commit) |
| | `begin; update public.profiles set bio = 'uji B' where username = 'budi_santoso';` → **menunggu** |
| `rollback;` | → B langsung lanjut |
| | `rollback;` |

B menunggu karena A memegang **kunci baris** (*row lock*). Begitu A selesai, B lanjut.

## 5.3 Kunci (lock)

| Kunci | Kapan | Contoh |
|---|---|---|
| Row lock | Otomatis saat `update` / `delete` / `select … for update` | Dua reaksi pada satu pesan |
| Table lock | `alter table`, `create index` (tanpa `concurrently`) | Migrasi: alasan migrasi besar dijalankan saat sepi |
| Advisory lock | Dipanggil manual: `pg_advisory_xact_lock(kunci)` | Rebuild trending tidak bentrok dengan tick 5 menit (0111) |

### Hot row: pelajaran dari uji beban

Dulu setiap pesan baru meng-update baris `chat_rooms` (`last_message_at`, preview). Di room saham dengan ratusan pengirim, **semua** transaksi antre di satu baris itu. Kunci menumpuk, pool koneksi habis, dan muncul error `PGRST003`. Temuan ini tercatat sebagai T17 di [laporan uji](../testing/report-2026-11-03.md).

Perbaikannya (0102): untuk room saham, pesan cukup ditulis ke antrean `private.room_preview_queue`, lalu cron memperbarui `chat_rooms` sekali-sekali. Lihat `\sf private.messages_after_insert`: DM dan grup langsung meng-update, room saham memakai antrean.

**Pelajaran:** hindari banyak transaksi yang meng-update satu baris yang sama secara bersamaan.

### `for update skip locked`: antrean tanpa bentrok

Pola untuk banyak pekerja yang mengambil tugas dari satu tabel:

```sql
select * from antrean
where status = 'queued'
order by id
limit 100
for update skip locked;
```

- `for update` mengunci baris yang diambil.
- `skip locked` **melewati** baris yang sedang dikunci pekerja lain, bukan menunggu.

Dua notifier yang berjalan bersamaan tidak pernah mengambil push yang sama. Lihat `\sf private.push_claim` (dibahas lagi di modul 7).

### Latihan: `skip locked`

| Sesi A | Sesi B |
|---|---|
| `begin;` | |
| `select id from public.messages order by created_at limit 3 for update;` | |
| | `begin;` |
| | `select id from public.messages order by created_at limit 3 for update skip locked;` → **3 id berbeda**, langsung |
| | `select id from public.messages order by created_at limit 3 for update;` → **menunggu** |
| `rollback;` | |
| | `rollback;` |

## 5.4 Index dan `explain`

Index adalah struktur terurut (B-tree) yang membuat Postgres bisa langsung "melompat" ke baris yang dicari, bukan membaca seluruh tabel.

```sql
\d public.messages
```

Index penting di `messages`:

| Index | Untuk query |
|---|---|
| `messages_room_created_idx (room_id, created_at desc, id desc)` | Riwayat satu room, urut terbaru: persis bentuk cursor di modul 1.6 |
| `messages_client_id_key unique (sender_id, client_id)` | Idempotensi pesan |
| `messages_held_idx … where moderation_status = 'held'` | **Partial index**: hanya pesan yang ditahan, kecil dan cepat untuk antrean moderasi |

```sql
explain (analyze, buffers, costs off)
select id from public.messages
where room_id = (select room_id from public.messages group by room_id order by count(*) desc limit 1)
order by created_at desc, id desc
limit 30;
```

Cara membaca hasilnya:

| Kata di plan | Arti |
|---|---|
| `Seq Scan` | Membaca seluruh tabel. Wajar untuk tabel kecil atau agregasi, bahaya untuk tabel besar dengan filter |
| `Index Scan` / `Index Only Scan` | Memakai index. *Only* = tidak perlu membuka tabel sama sekali |
| `actual time` | Waktu nyata dalam milidetik |
| `rows` | Jumlah baris di langkah itu |
| `Buffers: shared hit` | Halaman yang dibaca dari memori (`read` = dari disk, lebih lambat) |

Aturan index komposit: urutan kolom penting. `(room_id, created_at desc)` membantu query `where room_id = ? order by created_at desc`, tetapi tidak membantu `where created_at > ?` saja.

Index bukan gratis: setiap insert juga memperbarui semua index tabel itu. Tambahkan index hanya untuk query yang memang sering.

## 5.5 Koneksi itu mahal

Setiap koneksi ke Postgres adalah satu **proses** di server (beberapa MB RAM). Postgres kita punya `max_connections = 100`:

```sql
show max_connections;
select usename, count(*) from pg_stat_activity group by 1 order by 2 desc;
```

Padahal yang terhubung banyak sekali: replika PostgREST, Realtime, Storage, auth-bridge, layanan Go, Hub, cron. Tanpa pengaturan, koneksi bisa habis saat ramai.

## 5.6 PgBouncer: connection pooler

PgBouncer berdiri di antara aplikasi dan Postgres. Ia menerima **banyak** koneksi klien (sampai `max_client_conn = 500`) tetapi hanya membuka **sedikit** koneksi asli ke Postgres (`default_pool_size = 24` per pasangan user + database). Klien yang datang saat pool penuh menunggu sebentar.

```
rest ×2 (pool 10 + 1 listener per replika)  ─┐
realtime, storage, auth-bridge, …           ─┼─► PgBouncer ── ≤ 24 koneksi per user/db ──► Postgres (max 100)
layanan Go, Hub                             ─┘
```

Itulah asal aturan di [catatan rilis](../panduan/catatan-rilis.md) 16 November: `PGBOUNCER_DEFAULT_POOL_SIZE` minimal 22, yaitu 2 replika × (pool PostgREST 10 + 1 koneksi `LISTEN`).

### Mode pooling

| Mode | Koneksi asli dipinjam selama… | Kelebihan | Batasan |
|---|---|---|---|
| `session` | Klien tersambung | Semua fitur Postgres jalan (`LISTEN`, setting sesi, prepared statement) | Penghematan lebih kecil |
| `transaction` | Satu transaksi | Sangat hemat | `LISTEN/NOTIFY`, `set` tanpa `local`, dan beberapa fitur sesi tidak jalan |
| `statement` | Satu pernyataan | Paling hemat | Transaksi multi-pernyataan tidak boleh |

Kita memakai **`session`** ([docker/pgbouncer/entrypoint.sh](../../docker/pgbouncer/entrypoint.sh)) karena PostgREST butuh `LISTEN` untuk reload schema, dan migrasi GoTrue/Storage butuh fitur sesi. Bisa diganti lewat `PGBOUNCER_POOL_MODE` bila suatu saat dibutuhkan.

Sentinel membaca statistik PgBouncer (`SHOW POOLS`) memakai user `olt_stats`, lalu menampilkannya di Hub (Pengaturan → Sistem → Kesehatan sistem). Bila klien sering menunggu, alert berbunyi.

## 5.7 Timeout dan batas

| Pengaturan | Gunanya |
|---|---|
| `PGRST_DB_POOL_ACQUISITION_TIMEOUT` (2 detik) | PostgREST menyerah bila tidak dapat koneksi, lalu menjawab error, daripada menggantung |
| `statement_timeout` per role | Query yang terlalu lama dihentikan: `anon` 3 detik, `authenticated` 8 detik, `service_role` 15 detik. Lihat `select rolname, rolconfig from pg_roles where rolconfig is not null;` |
| `lock_timeout`, `idle_in_transaction_session_timeout` | Menunggu kunci maksimal 8 detik; transaksi yang dibiarkan menganggur diputus setelah 30 detik |
| Rate limit (`private.consume_rate_limit`) | Membatasi aksi per pengguna sebelum sempat membebani database |

---

## Latihan

1. Jalankan `explain analyze` untuk `select * from public.messages where body ilike '%halo%'`. Index apa yang dipakai? Kenapa?
2. Lihat `\d public.chat_members`. Index apa yang mendukung `private.my_room_ids()`? (Buka fungsinya dengan `\sf`.)
3. Lakukan latihan 5.2 dan 5.3 dengan dua sesi. Saat B menunggu, buka **sesi ketiga** dan jalankan:
   ```sql
   select pid, state, wait_event_type, wait_event, left(query, 60)
   from pg_stat_activity where datname = 'postgres' and state <> 'idle';
   ```
4. Cari migrasi 0102, lalu jelaskan dengan kata-kata Anda sendiri kenapa room saham memakai `room_preview_queue`.
5. Hitung: bila nanti `rest` dinaikkan menjadi 3 replika, berapa minimal `PGBOUNCER_DEFAULT_POOL_SIZE`?

## Cek pemahaman

- Kenapa pembaca tidak pernah menunggu penulis di Postgres?
- Apa beda `for update` dan `for update skip locked`?
- Kenapa kita tidak memakai PgBouncer mode `transaction`?
- Apa itu *hot row*, dan bagaimana menghindarinya?

**Bacaan:** PostgreSQL docs *Concurrency Control (MVCC)*, *Explicit Locking*, *Using EXPLAIN*, *Indexes*; PgBouncer docs *Features* (pool modes).
