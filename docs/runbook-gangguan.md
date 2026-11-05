# Runbook Gangguan

Langkah saat ada laporan "tidak bisa kirim chat", "chat tidak muncul", "tidak bisa login", atau gangguan lain setelah rilis publik. Ikuti urutannya; langkah 1 biasanya sudah memotong separuh kemungkinan. Gambaran sistem dan perintah dasar ada di [operations.md](operations.md).

Semua perintah dijalankan di server dengan `PROFILE=single` sudah diekspor ([operations.md](operations.md#3-perintah)).

## Langkah 1 — Satu orang atau semua? (±2 menit)

Coba kirim chat dari akun uji sendiri dan tanyakan ke CS apakah ada laporan serupa.

### A. Hanya satu atau beberapa nasabah

Biasanya bukan gangguan sistem, melainkan aturan yang bekerja. Minta tangkapan layar pesan error di aplikasi.

| Pesan / gejala | Penyebab | Cek di |
|---|---|---|
| "Tunggu N detik" | Slow mode room saham (jam ramai atau alert manipulasi) | Hub → Komunitas → room saham |
| Terlalu sering / batas tercapai | Rate limit per akun | Normal, hilang sendiri |
| Pesan ditahan atau ditolak | Filter konten, kata terlarang | Hub → Kepatuhan |
| Tidak bisa kirim di room tertentu | Dibisukan moderator, akun dibatasi | Hub → Komunitas → Moderasi |
| "Perbarui aplikasi" | Versi aplikasi di bawah versi minimum | Hub → Fitur & Kampanye → Fitur & versi |
| "Sementara tidak tersedia" untuk semua fitur sosial | Kill switch sedang aktif | Hub → Fitur & Kampanye → Fitur & versi → Kill switch |
| Login gagal terus / "Sesi berakhir" | Token dari backend OLT ditolak: jam server OLT meleset, kunci OLT berubah, `iss`/`aud` tidak cocok | `docker logs olt-social-auth-bridge-1 --since 15m` (cari `exchange rejected` dan field `reason`) |

### B. Semua orang kena

Gangguan sistem. Lanjut ke langkah 2.

## Langkah 2 — Lihat apa kata sistem (±3 menit)

1. **Hub → Kesehatan sistem.** Alert terbuka biasanya langsung menunjuk layanannya.
2. **`make ps`.** Semua harus `healthy`. Yang `unhealthy` atau terus restart adalah tersangka.
3. **Cocokkan gejala:**

| Gejala | Layanan dicurigai | Log |
|---|---|---|
| Tidak bisa kirim sama sekali, error atau loading lama | `rest`, `pgbouncer`, `db` | `docker logs olt-social-rest-1 --since 15m` |
| Pesan terkirim tetapi tidak muncul live (baru muncul setelah refresh) | `realtime` | `docker logs olt-social-realtime-1 --since 15m` |
| Gambar/PDF gagal diunggah | `media`, `classifier`, `storage` | `docker logs olt-social-media-1 --since 15m` |
| Semua fitur mati, aplikasi tidak bisa konek | `traefik`, `kong`, DNS, sertifikat | `docker logs olt-social-traefik-1 --since 15m` |
| Login semua orang gagal | `auth-bridge`, `valkey`, kunci OLT | `docker logs olt-social-auth-bridge-1 --since 15m` |
| Push notifikasi tidak masuk | `notifier`, kunci Firebase | Hub → Kesehatan sistem, `docker logs olt-social-notifier-1 --since 15m` |

## Langkah 3 — Pulihkan

| Situasi | Tindakan |
|---|---|
| Satu layanan macet atau `unhealthy` | Biasanya sudah di-restart otomatis oleh healer dalam ±1–2 menit (Kesehatan sistem → Restart otomatis). Bila belum, atau alert `healer:gave_up:<layanan>` terbuka: `docker restart olt-social-<layanan>-1`. Aman, data tidak hilang. Bila restart tidak menolong, baca log layanan itu: penyebabnya biasanya ada di layanan lain (DB, PgBouncer) atau konfigurasi |
| Alert `healer:systemic` | Healer menahan restart karena database/PgBouncer tidak sehat atau banyak layanan sakit bersamaan. Perbaiki penyebab utamanya dulu (biasanya `db`/`pgbouncer`); jangan me-restart layanan satu per satu |
| Alert kapasitas (`rest:pool`, `realtime:events`, `pgbouncer:queue`) di jam ramai | Sementara: nyalakan slow mode di room saham yang ramai dari Hub. Sesudahnya: naikkan batas atau CPU di `docker/.env`, lalu `make up` |
| Disk penuh (`disk:*`) | Tambah kapasitas atau kosongkan file di luar folder data. Jangan hapus volume database atau storage |
| Database tidak sehat (`db` unhealthy, `rest:pool` terus) | `docker logs olt-social-db-1 --since 15m`. Restart database hanya bila perlu, di luar jam bursa bila bisa |
| Spam masif, konten berbahaya, atau masalah yang belum dipahami dan butuh waktu | **Kill switch** di Hub → Fitur & Kampanye → Fitur & versi. Fitur sosial tampil "sementara tidak tersedia", chat CS tetap berjalan. Nyalakan lagi setelah beres |
| Rusak setelah update | Lihat "Bila penyebabnya update" |

**Jangan lakukan saat panik:**

- `make reset` atau `docker volume rm`: menghapus database dan file.
- Restore backup untuk masalah yang bukan kerusakan data. Restore memundurkan data semua orang ke satu titik waktu ([backup](backup/README.md#pemulihan)).
- Mengedit file di dalam container.

## Bila penyebabnya update

1. Lihat apa yang baru berubah:
   - **Hub → Kepatuhan → Jejak Audit**: siapa mengubah pengaturan apa dan kapan.
   - `git log -5` di server: versi kode terakhir.
2. Kembali ke versi sebelumnya (`git checkout <tag lama> && make up`) **hanya bila update itu tidak membawa migrasi database baru** (`git diff --stat <tag lama> HEAD -- supabase/migrations`).
3. Bila ada migrasi baru, jangan mundur. Perbaiki maju dengan migrasi baru; migrasi hanya berjalan ke depan.

## Sesudah gangguan

- Pastikan semua alert di Hub selesai dan `make ps` healthy.
- Matikan lagi kill switch atau slow mode darurat yang dinyalakan.
- Catat kronologi singkat: jam mulai, gejala, penyebab, tindakan, jam pulih.

## Data untuk minta bantuan

Kumpulkan sebelum menghubungi tim pengembang:

1. Jam kejadian dan sejak kapan.
2. Satu contoh akun yang kena dan tangkapan layar pesan error.
3. Hasil `make ps`.
4. Alert yang terbuka di Hub → Kesehatan sistem.
5. `docker logs olt-social-<layanan>-1 --since 30m` dari layanan yang dicurigai. Periksa dulu bahwa log tidak berisi data pribadi nasabah sebelum dibagikan.
