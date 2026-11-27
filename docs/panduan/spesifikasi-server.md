# Spesifikasi Server

Kebutuhan server untuk menjalankan server sosial dan Rendezvous Hub. Untuk vendor IT dan tim yang menyiapkan server. Spesifikasi server development untuk tim aplikasi ada di [server-development.md](server-development.md).

## 1. Dasar perhitungan

- **Batas resource semua container** (profil produksi, 2 replika untuk layanan sibuk, tanpa Studio): sekitar **25 vCPU dan 15 GB RAM**. Ini batas atas tiap container, bukan pemakaian rata-rata. Penyumbang terbesar: database 2 GB, ClamAV 2 GB, Kong 1 GB, Realtime 1 GB, media 2 × 768 MB, backup 1 GB.
- **Pemakaian saat sepi** sekitar 4 GB RAM dan CPU hampir nol (dari Peta layanan).
- **Uji beban 3–4 November** ([laporan](../testing/report-2026-11-03.md)): API ringan sampai 400 pengguna simultan; batas pertama di sekitar 450–600 penerima dalam satu room chat (Realtime), lalu CPU database.

## 2. Rekomendasi

| Tahap | CPU | RAM | Disk | Cocok untuk |
|---|---|---|---|---|
| Minimum (UAT, pilot) | 8 vCPU | 16 GB | 200 GB SSD NVMe | Uji coba, ratusan pengguna aktif |
| **Produksi awal (disarankan)** | **16 vCPU** | **32 GB** | **500 GB NVMe** | Peluncuran, ribuan nasabah, ramai saat bursa buka |
| Tumbuh besar | Server aplikasi 16–32 vCPU / 32–64 GB, **ditambah server database terpisah** 8–16 vCPU / 32–64 GB | | NVMe terpisah untuk database | Belasan ribu pengguna aktif |

Alasan produksi awal 16 vCPU / 32 GB:

- RAM di luar batas container dipakai Postgres sebagai cache data, yang paling berpengaruh ke kecepatan. Dengan RAM lebih besar, naikkan juga `DB_MEMORY` di `docker/.env`.
- Tidak semua container memakai batasnya bersamaan, jadi 16 vCPU sudah longgar.
- Database dan Realtime sensitif terhadap kecepatan disk, karena itu NVMe.

## 3. Disk

| Pengisi | Perkiraan |
|---|---|
| Image Docker | 10–15 GB |
| Database | Tumbuh mengikuti jumlah pesan, postingan, dan notifikasi |
| File unggahan | Lampiran chat CS (gambar dan PDF sampai 10 MB), foto profil, gambar postingan |
| Staging backup | Sekitar satu kali ukuran database ditambah WAL beberapa jam |
| Repositori backup lokal | Beberapa kali ukuran database + file (7 harian, 4 mingguan, 6 bulanan) |
| Log container | ±1–2 GB (10 MB × 5 file per container) |

Sebaiknya repositori backup di **disk terpisah** dari database, dan salinannya di luar server ([backup.md](backup.md)).

## 4. Sistem operasi dan jaringan

- **Produksi:** Linux, disarankan Ubuntu LTS, sesuai [instalasi-server.md](instalasi-server.md). Docker di Windows (Docker Desktop) berjalan di dalam VM sehingga ada overhead, dan Hyper-V mencadangkan rentang port tertentu. Untuk server lokal atau development, Windows tidak masalah.
- **IP publik** dengan port 80/443 untuk aplikasi nasabah; port 22 (SSH) hanya dari IP admin.
- **LAN/VPN kantor** untuk membuka Hub (`VPN_SOURCE_RANGES`, opsional; kosong = hanya jaringan internal (IP privat LAN kantor dan VPN), internet 403).
- **Jaringan keluar (HTTPS)** untuk Let's Encrypt, Firebase (push), pembaruan tanda tangan ClamAV, dan S3 bila dipakai.
- **GPU tidak diperlukan.**

## 5. Setelah server siap

1. Pasang sesuai [instalasi-server.md](instalasi-server.md).
2. Ukur kapasitas server itu sendiri dengan `make load-test P=step` sebelum dibuka ke nasabah ([testing](../testing/README.md)). Angka di atas berasal dari komputer uji; kapasitas sesungguhnya bergantung pada mesinnya.
3. Bila satu server besar sudah tidak cukup, rencanakan database terpisah lalu cluster ([skalabilitas.md](skalabilitas.md)).
