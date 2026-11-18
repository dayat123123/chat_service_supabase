# Modul 9: Pengujian

**Tujuan:** bisa membaca dan menulis tes pgTAP. Karena logika bisnis ada di database, tes pgTAP adalah jaring pengaman utama kita: sekitar 4.000 tes di ±150 file.

---

## 9.1 Piramida tes kita

| Lapis | Alat | Di mana | Menguji |
|---|---|---|---|
| Database | **pgTAP** | [supabase/tests](../../supabase/tests) | Fungsi, trigger, RLS, grant, aturan bisnis |
| Layanan Go | `go test` | `services/*/` | Verifikasi token, pemrosesan file, antrean push |
| Library Flutter | `flutter test` | repo `rendezvous_community/test` | Cubit, model, widget |
| Hub | Vitest, Playwright | repo `rendezvous_hub` | Komponen dan alur web |
| Ujung ke ujung | skrip smoke, E2E | `make smoke`, `make smoke-cs`, `make e2e-*` | Alur nyata lewat Kong |
| Keamanan | probe otorisasi | `make test-security` | Pengguna lain, anon, atau agen tanpa izin mencoba mengakses |
| Beban & chaos | k6, skrip chaos | `make load-test`, `make chaos-test` | Ratusan penerima, container dimatikan |

## 9.2 pgTAP dalam lima menit

pgTAP adalah kumpulan fungsi SQL yang menghasilkan laporan format **TAP** (`ok 1 - …`, `not ok 2 - …`). Coba langsung di psql:

```sql
begin;
select plan(5);

select has_function('public', 'get_dm_policy', 'get_dm_policy tersedia');
select is((select count(*)::int from public.profiles where username = 'budi_santoso'), 1, 'Budi ada di data contoh');
select throws_ok($$select private.api_error(404, 'room_not_found')$$,
                 'PT404', 'room_not_found', 'api_error memakai SQLSTATE PT<status>');

select set_config('role', 'authenticated', true),
       set_config('request.jwt.claims',
                  json_build_object('sub', (select id from public.profiles where username = 'budi_santoso'))::text, true);

select ok(public.get_dm_policy() ->> 'policy' in ('everyone', 'following', 'none'), 'Kebijakan DM bernilai sah');
select throws_ok($$select count(*) from private.dm_preferences$$, '42501', null,
                 'Pengguna tidak bisa membaca schema private');

select * from finish();
rollback;
```

| Fungsi | Lulus bila |
|---|---|
| `plan(n)` | Jumlah tes yang dijalankan harus tepat `n` (melindungi dari tes yang diam-diam tidak jalan) |
| `ok(kondisi, nama)` | Kondisi `true` |
| `is(hasil, harapan, nama)` / `isnt` | Sama / tidak sama (aman untuk null) |
| `results_eq(query, query)` | Dua query menghasilkan baris yang sama |
| `throws_ok(sql, sqlstate, pesan, nama)` | SQL gagal dengan kode dan pesan itu |
| `lives_ok(sql, nama)` | SQL tidak error |
| `has_table`, `has_function`, `has_column` | Objek ada |
| `policies_are`, `table_privs_are` | Daftar policy / izin persis seperti yang diharapkan |
| `finish()` | Laporan akhir |

Kenapa selalu `begin … rollback`? Setiap file tes membuat pengguna, room, dan pesan sendiri, lalu membatalkan semuanya. Database tetap bersih, dan file tes bisa dijalankan berulang dalam urutan apa pun.

## 9.3 Membaca tes kita

Buka [supabase/tests/148_notify_olt_user_target_test.sql](../../supabase/tests/148_notify_olt_user_target_test.sql) (20 tes, ditulis untuk fitur alert harga). Polanya:

```sql
begin;
select plan(20);

select tests.create_user('ou_budi') as budi \gset             -- 1. siapkan data
update public.profiles set olt_user_id = 'ou-2001' where id = :'budi';

select tests.authenticate_service();                            -- 2. jadi siapa
select public.integration_notify(:'plain_key', '[…]', null) as a1 \gset   -- 3. aksi
reset role;

select is(:'a1'::jsonb -> 'results' -> 0,                       -- 4. periksa
  '{"index": 0, "id": "ou-a1", "status": "queued", "devices": 1, "inbox": 1}'::jsonb,
  'Target olt_user_id dikirim langsung …');
…
select * from finish();
rollback;
```

| Alat bantu | Arti |
|---|---|
| `\gset` | Fitur psql: simpan hasil `select` ke variabel psql, lalu pakai sebagai `:'nama'` |
| `tests.create_user('nama')` | Membuat profil uji, mengembalikan id |
| `tests.authenticate_as(id)` | Meniru pengguna (sama seperti modul 3.4) |
| `tests.authenticate_service()` | Meniru layanan internal (`service_role`) |
| `tests.authenticate_agent(id)` / `tests.create_agent(…)` | Meniru staf CS dengan peran tertentu |
| `reset role` | Kembali menjadi `postgres` untuk memeriksa tabel internal |

Helper ini ada di [supabase/tests/helpers/test_helpers.sql](../../supabase/tests/helpers/test_helpers.sql). `make test-db` memasangnya sebelum tes dan menghapusnya sesudahnya.

### Apa yang selalu diuji untuk fitur baru

1. **Jalur bahagia**: aksi yang sah berhasil dan hasilnya tepat.
2. **Setiap penolakan**: kode error yang tepat (`throws_ok` dengan SQLSTATE dan `message`).
3. **Orang yang tidak berhak**: pengguna lain, anon, atau agen tanpa izin. Contohnya matriks audiens × peran di tes 146.
4. **Jalur memutar**: insert langsung lewat REST, bukan lewat RPC, tetap ditolak trigger/RLS (tes 147).
5. **Efek samping**: notifikasi, push, broadcast, audit log benar-benar tercatat.
6. **Batas**: nilai kosong, terlalu panjang, angka di luar rentang, data ganda.

## 9.4 Menjalankan tes

```powershell
.\make.ps1 test-db      # semua tes pgTAP di DB dev
```

`test-db` menguji database **sebagaimana adanya**. Bila DB dev belum menjalankan migrasi terbaru, tes untuk migrasi itu gagal. Itu wajar, bukan bug.

Untuk menguji migrasi baru **tanpa** memigrasi DB dev, tim memakai salinan DB sekali pakai: salin isi DB dev lewat `pg_basebackup`, jalankan di container Postgres terpisah tanpa jaringan, lalu jalankan `migrate` + `test-db` di sana dan buang setelah selesai. Ini yang dipakai untuk migrasi 0169–0171 sebelum di-push.

Tes layanan Go dan library:

```powershell
.\make.ps1 test-notifier                  # contoh: satu layanan Go (di dalam container)
cd ..\rendezvous_community; flutter test  # library Flutter
```

## 9.5 TDD: tulis tesnya dulu

Alur yang dipakai untuk setiap fitur server:

1. Tulis file tes baru dengan `plan(n)` dan semua harapan. Tesnya masih gagal karena fungsinya belum ada.
2. Jalankan, pastikan gagal **dengan alasan yang benar** (fungsi tidak ada, bukan salah ketik).
3. Tulis migrasi minimal sampai tes lulus.
4. Jalankan **semua** tes, bukan hanya file baru, karena perubahan fungsi lama bisa merusak fitur lain.

Contoh nyata dari 0171: tes nomor 7 sempat gagal karena data push ternyata juga memuat `kind`. Yang diperbaiki adalah **harapan** di tes, karena perilaku servernya memang benar. Membaca pesan kegagalan dengan teliti sebelum memperbaiki apa pun adalah separuh pekerjaan.

---

## Latihan

1. Jalankan contoh 9.2. Ubah satu harapan menjadi salah, lalu lihat bentuk `not ok`.
2. Tulis tes kecil (dalam `begin … rollback`, tanpa helper) yang membuktikan Budi **tidak** bisa membaca pesan di room yang bukan miliknya. Petunjuk: `is((select count(*) from public.messages where room_id = '<room orang lain>'), 0::bigint, …)`.
3. Baca [supabase/tests/146_comment_controls_test.sql](../../supabase/tests/146_comment_controls_test.sql). Bagaimana `pg_temp.attempt` dan `pg_temp.matrix` membuat 20-an kombinasi audiens × peran tanpa menulis tes satu per satu?
4. Pilih satu fungsi dari modul 2 latihan 2 (`statistik_room`) dan tulis 4 tes untuknya: hasil benar, room tidak ada → `PT404`, room kosong, dan room dengan pesan yang dihapus.
5. Baca [docs/testing/report-2026-11-03.md](../testing/report-2026-11-03.md) bagian T1 dan T17. Masalah apa yang hanya bisa ditemukan uji beban, bukan pgTAP?

## Cek pemahaman

- Kenapa setiap file tes diakhiri `rollback`?
- Apa gunanya `plan(n)`?
- Kenapa tes "pengguna yang tidak berhak" paling penting untuk fungsi `security definer`?

**Bacaan:** <https://pgtap.org/documentation.html>; *Test Anything Protocol* (testanything.org).
