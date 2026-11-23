# Spesifikasi Kebutuhan

Dokumen kebutuhan resmi sistem Rendezvous (fitur sosial dan layanan nasabah di aplikasi OLT). Versi 1.0, 23 November 2026, status Draf.

| Dokumen | Untuk | Isi |
|---|---|---|
| [brd.md](brd.md) ([PDF](brd.pdf)) | Manajemen, Kepatuhan, tim CS/Komunitas/Pusat Bantuan, tim OLT | Business Requirements Document: latar belakang, tujuan dan KPI, ruang lingkup, pemangku kepentingan, persona, proses bisnis, kebutuhan bisnis `BR-<MODUL>-nn`, aturan bisnis `ATR-nn`, regulasi, risiko, tahapan rilis |
| [srs.md](srs.md) ([PDF](srs.pdf)) | Developer, tim IT, QA, vendor, tim integrasi | Software Requirements Specification (gaya IEEE 29148): arsitektur, kebutuhan fungsional `FR-<MODUL>-nn`, antarmuka dan API, data, kebutuhan non-fungsional `NFR-*`, keamanan, konfigurasi, kriteria penerimaan, katalog error dan RPC |

Kedua dokumen memakai kode modul yang sama, sehingga setiap `FR` di SRS bisa dilacak ke kelompok `BR` di BRD:

| Kode | Modul |
|---|---|
| AKUN | Login lewat OLT, profil, privasi, hapus akun |
| KOM | Komunitas: feed, postingan, komentar, ikuti, akun resmi |
| CHAT | DM, grup, room saham, permintaan pesan |
| CS | Chat CS dan tiket |
| BANTU | Pusat Bantuan dan FAQ |
| NOTIF | Notifikasi, push, Banner & Popup |
| MOD | Moderasi dan keamanan konten |
| PATUH | Kepatuhan, audit, dokumen hukum, data pribadi |
| HUB | Rendezvous Hub: staf, peran, pengaturan, laporan |
| INT | Integrasi dengan OLT dan klien lain |
| OPS | Operasional server: pemantauan, backup, deploy |
| TRADE | Berbagi Trade (dijeda) |

Gambaran sistem yang lebih ringkas ada di [panduan/pengetahuan-sistem.md](../panduan/pengetahuan-sistem.md).
