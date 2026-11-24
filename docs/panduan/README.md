# Panduan

Kumpulan panduan untuk menjalankan server sosial (OLT Social) dan Rendezvous Hub. Semua panduan berbahasa Indonesia dan memakai perintah yang bisa langsung disalin. Panduan yang ditandai PDF juga tersedia dalam versi cetak.

## Mulai dari mana

| Saya ingin… | Buka |
|---|---|
| Memahami sistem secara utuh: node, teknologi, server | [pengetahuan-sistem.md](pengetahuan-sistem.md) |
| Melihat semua fitur yang tersedia | [daftar-fitur.md](daftar-fitur.md) |
| Menyiapkan server baru | [spesifikasi-server.md](spesifikasi-server.md), lalu [instalasi-server.md](instalasi-server.md) |
| Memastikan semua siap sebelum dibuka ke nasabah | [checklist-go-live.md](checklist-go-live.md) |
| Menjalankan server sehari-hari | [operasional.md](operasional.md) |
| Memasang versi baru atau kembali ke versi lama | [pembaruan-sistem.md](pembaruan-sistem.md) dan [catatan-rilis.md](catatan-rilis.md) |
| Mengatur backup atau memulihkan data | [backup.md](backup.md) |
| Menangani gangguan | [gangguan.md](gangguan.md) |
| Melatih staf memakai Hub | [hub-untuk-staf.md](hub-untuk-staf.md) |

## Daftar panduan

| Panduan | Untuk | Isi |
|---|---|---|
| [pengetahuan-sistem.md](pengetahuan-sistem.md) ([PDF](pengetahuan-sistem.pdf)) | Developer baru, tim IT, manajemen teknis | Gambaran sistem: empat bagian dan repo-nya, teknologi dan versinya, fungsi setiap node, database, alur penting, jaringan dan keamanan, profil dan ukuran server |
| [daftar-fitur.md](daftar-fitur.md) ([PDF](Daftar%20fitur%20Rendezvous%20Community.pdf)) | Manajemen, tim OLT, tim aplikasi | Semua fitur aplikasi nasabah, Rendezvous Hub, layanan server, dan integrasi ke aplikasi OLT |
| [spesifikasi-server.md](spesifikasi-server.md) ([PDF](spesifikasi-server.pdf)) | Vendor IT | Kebutuhan CPU, RAM, disk, sistem operasi, dan jaringan |
| [instalasi-server.md](instalasi-server.md) ([PDF](instalasi-server.pdf)) | Vendor IT, tim IT | Pemasangan server baru sampai bisa diakses publik, dengan skrip `scripts/server-install.sh` |
| [checklist-go-live.md](checklist-go-live.md) ([PDF](checklist-go-live.pdf)) | Semua pihak | Checklist rapat go-live: vendor IT, tim OLT, tim aplikasi, Kepatuhan |
| [operasional.md](operasional.md) | Tim IT | Gambaran sistem, di mana mengatur apa, perintah, pemantauan, rutinitas |
| [pembaruan-sistem.md](pembaruan-sistem.md) ([PDF](pembaruan-sistem.pdf)) | Tim IT | Update versi, pemeriksaan sesudahnya, dan rollback |
| [catatan-rilis.md](catatan-rilis.md) | Tim IT | Langkah tambahan per rilis, terbaru di atas |
| [backup.md](backup.md) ([PDF](backup.pdf)) | Super Admin, tim IT | Persiapan, pengaturan backup di Hub, pemeriksaan rutin, pemulihan per kejadian |
| [retensi-data.md](retensi-data.md) | Kepatuhan, Super Admin, tim IT | Batas simpan data dan alasannya, persetujuan perubahan, penahanan, dan cara memastikan pembersihan otomatis berjalan |
| [gangguan.md](gangguan.md) ([PDF](gangguan.pdf)) | Tim IT | Langkah saat gangguan: triase, gejala per layanan, pemulihan |
| [produksi.md](produksi.md) | Tim IT, pengembang | Arsitektur produksi, deploy pertama, moderasi, rotasi kunci, monitoring, checklist rilis |
| [skalabilitas.md](skalabilitas.md) | Pengembang | Replika, pool koneksi, dan rencana single → cluster |
| [server-development.md](server-development.md) | Tim IT, tim aplikasi | Server development untuk integrasi aplikasi client |
| [hub-untuk-staf.md](hub-untuk-staf.md) ([PDF](hub-untuk-staf.pdf)) | Staf (CS, Supervisor, Super Admin, Kepatuhan, moderator) | Pelatihan memakai Rendezvous Hub |

## Simpan di luar server

Cetak atau simpan salinan [backup.pdf](backup.pdf), [gangguan.pdf](gangguan.pdf), dan [pembaruan-sistem.pdf](pembaruan-sistem.pdf) bersama password backup, `docker/.env`, `docker/secrets/`, dan `pgsodium_root.key` ([backup.md](backup.md#2-persiapan-wajib-sekali-sebelum-ada-masalah)). Saat server bermasalah, panduan di repo mungkin tidak bisa dibuka.

## Dokumen lain

Desain per fitur, kontrak integrasi, laporan uji, dan arsip ada di [docs](../README.md).
