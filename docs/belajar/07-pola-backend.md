# Modul 7: Pola Backend yang Dipakai Berulang

**Tujuan:** mengenali beberapa "resep" yang muncul di banyak fitur. Begitu mengenalinya, fitur baru jadi mudah dibaca: biasanya hanya kombinasi resep-resep ini.

---

## 7.1 Antrean di database + lease

Pekerjaan yang lambat atau bergantung pada pihak luar (kirim push ke Google, hapus file, siaran ke ribuan orang) **tidak** dikerjakan di dalam request pengguna. Request hanya mencatat tugas ke tabel antrean, lalu pekerja terpisah mengambilnya.

```
Transaksi pengguna ──insert──► private.push_queue (status = queued)
                                      │
notifier (Go, 1 detik sekali) ── push_claim(batch 100, lease 60 dtk) ──► kirim ke FCM ──► push_report(hasil)
```

Mengapa begitu?
- Pengguna tidak menunggu Google menjawab.
- Kalau FCM sedang gangguan, pesan tetap tersimpan. Pengiriman diulang nanti dengan **backoff** (jeda yang makin panjang).
- Tugas ikut transaksi: pesan batal, maka push-nya ikut batal.

**Lease** (sewa): saat diambil, baris diberi `locked_until = now() + 60 detik` dan nama pekerjanya. Kalau notifier mati di tengah jalan, setelah sewa habis baris itu kembali bisa diambil pekerja lain. Hasilnya **at-least-once**: dijamin terkirim, walaupun sesekali bisa terkirim dua kali. Itu sebabnya push memakai `collapse_key` supaya duplikat saling menimpa di HP.

```sql
\sf private.push_claim
```

Cari `for update skip locked` (modul 5.3) dan `locked_until`.

Antrean lain yang memakai pola sama:

| Antrean | Pekerja |
|---|---|
| `private.push_queue` | notifier (Go) → FCM |
| `private.storage_cleanup_queue` | janitor (Go): hapus file milik akun/pesan yang dihapus |
| `private.integration_broadcasts` | cron `integration-broadcasts` (15 detik), 2.000 penerima per putaran dengan kursor |
| `private.room_preview_queue` | cron `chat-room-preview` (10 detik), menghindari *hot row* |

## 7.2 Cron di dalam database (`pg_cron`)

Tugas berkala dijalankan langsung oleh Postgres:

```sql
select jobname, schedule, active, left(command, 60) from cron.job order by jobname;
```

| Bentuk `schedule` | Arti |
|---|---|
| `* * * * *` | Setiap menit (menit jam tanggal bulan hari) |
| `*/5 * * * *` | Setiap 5 menit |
| `47 3 * * *` | Setiap hari 03:47 UTC |
| `15 seconds` | Setiap 15 detik (fitur pg_cron, di bawah satu menit) |

Contohnya `olt-retention` (hapus data lama sesuai aturan retensi), `social-trending` (hitung trending), dan `health-evaluate` (evaluasi alert). Riwayat jalannya bisa dilihat di `cron.job_run_details`.

## 7.3 Idempotensi

"Request yang diulang tidak boleh punya efek ganda." Jaringan HP sering putus **setelah** server menyimpan tetapi **sebelum** jawaban sampai, jadi klien mengirim ulang.

| Tempat | Kunci idempotensi | Mekanisme |
|---|---|---|
| `send_message` | `p_client_id` (UUID buatan klien) | Index unik `(sender_id, client_id)`; kiriman ulang mengembalikan pesan yang sama |
| `create_post` | `client_id` | Sama |
| API notifikasi OLT | `id` per pesan per key | `insert … on conflict do nothing` di `integration_receipts` → `duplicate` |
| Push | `collapse_key` | FCM menimpa notifikasi lama di HP |

## 7.4 Dari pesan ke push: rantai trigger

```
insert public.messages
  └─ trigger messages_after_insert
       └─ untuk setiap anggota DM/grup (bukan pengirim, tidak membisukan room):
            private.notify(...) ──insert──► public.notifications (type 'message')
                                               └─ trigger notifications_push
                                                    └─ preferensi notifikasi mengizinkan push?
                                                    └─ jam tenang? → available_at digeser
                                                    └─ private.push_enqueue ──► private.push_queue
```

Room saham hanya membuat notifikasi untuk pengguna yang di-mention, karena satu pesan di room 2.000 orang tidak boleh menjadi 2.000 push.

Notifikasi kotak masuk dan push sengaja dipisah. Pengguna bisa mematikan push tapi tetap melihat notifikasinya di app. Preferensinya diatur per jenis (`get_notification_prefs`).

## 7.5 Kode error yang stabil

Setiap penolakan punya kode tetap (`slow_mode`, `dm_not_allowed`) di `message`, status HTTP yang tepat, dan teks manusia di `detail`. Klien memetakan kode itu ke terjemahan. Teks boleh berubah tanpa merusak aplikasi, sedangkan kode tidak boleh berubah. Ini kontrak, sama pentingnya dengan nama parameter.

## 7.6 Rate limit dan slow mode

```sql
\sf private.consume_rate_limit
```

Rate limit di database memakai tabel hitungan per pengguna per jenis aksi per jendela waktu. Ada beberapa lapis:

| Lapis | Melindungi dari |
|---|---|
| Traefik/Kong per IP | Banjir request dari satu alamat |
| auth-bridge per IP dan per user | Penukaran token berlebihan |
| `consume_rate_limit` per aksi | Spam reaksi, pesan, komentar |
| Slow mode room saham | Room ramai saat jam bursa (`429 slow_mode`, `details` = detik tunggu) |
| API key integrasi per menit | Server luar yang terlalu agresif |

Batas per IP harus longgar karena banyak pengguna seluler berbagi satu IP publik (CGNAT). Batas yang sebenarnya diletakkan per pengguna.

## 7.7 Layanan Go: untuk yang tidak cocok di SQL

| Kebutuhan | Kenapa tidak di SQL | Layanan |
|---|---|---|
| Verifikasi JWT OLT (EdDSA, JWKS) | Kriptografi kunci publik, caching | auth-bridge |
| Memeriksa dan membersihkan file | Byte biner, EXIF, PDF, video, antivirus | media (+ classifier, clamav) |
| Kirim ke FCM | HTTP keluar ke Google, OAuth | notifier |
| API key dan IP untuk server luar | Lapisan HTTP khusus | integration |
| Ambil pratinjau tautan | HTTP keluar, perlindungan SSRF | link-preview |
| Hapus file storage | Panggilan ke Storage API | janitor |
| Pantau dan restart container | Akses Docker | sentinel, healer |

Polanya selalu sama: layanan Go **tidak menyimpan keputusan bisnis**. Ia mengambil tugas lewat RPC (memakai token `service_role` berumur pendek), mengerjakan bagian teknisnya, lalu melapor balik lewat RPC. Aturan tetap di database.

## 7.8 Pipeline media

```
App ──POST /media/v1/object/attachments/rooms/<room>/<saya>/<uuid>.jpg──► media
  1. verifikasi JWT pengguna
  2. cek bucket dan path; ukuran ≤ batas
  3. deteksi jenis dari magic bytes (bukan ekstensi, bukan Content-Type)
  4. buang EXIF/GPS (tanpa re-encode)
  5. classifier NSFW: tolak / tahan untuk ditinjau / izinkan
  6. (dokumen/video CS) antivirus ClamAV, ffmpeg remux
  7. teruskan ke Storage dengan JWT baru + klaim media_verified
App ──send_message(p_attachments = [{bucket, path, mime, …}])──► trigger memeriksa path milik pengirim dan room
```

Policy storage hanya menerima upload yang membawa `media_verified`, jadi aplikasi tidak bisa melewati pemeriksaan dengan upload langsung ke `/storage/v1`. Semua pemeriksaan bersifat **fail-closed**: bila classifier atau antivirus mati, upload ditolak, bukan diloloskan.

---

## Latihan

1. Dari `cron.job`, pilih tiga job dan baca fungsinya dengan `\sf`. Tulis satu kalimat tentang tugas masing-masing.
2. Lihat `select * from cron.job_run_details order by start_time desc limit 10;`. Ada job yang gagal?
3. Baca `\sf private.push_claim`. Apa yang terjadi pada baris yang `attempts`-nya sudah melewati batas?
4. Kirim pesan dua kali dengan `p_client_id` yang sama lewat `curl`/Postman (modul 4). Bandingkan `id` yang dikembalikan.
5. Rancang di atas kertas: fitur "pengingat harga" kirim push 08:00 WIB setiap hari ke pemantau saham. Antrean apa yang dipakai, cron apa yang dibuat, dan bagaimana mencegah push ganda bila cron berjalan dua kali?

## Cek pemahaman

- Kenapa push tidak dikirim langsung di dalam `send_message`?
- Apa itu lease, dan masalah apa yang diselesaikannya?
- Kenapa layanan Go tidak boleh menyimpan aturan bisnis?

**Bacaan:** pg_cron README (GitHub citusdata/pg_cron); artikel tentang *transactional outbox pattern* dan *idempotency keys*.
