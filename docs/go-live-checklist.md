# Checklist Go-Live

Pegangan rapat go-live bersama vendor IT, tim OLT, tim aplikasi, dan Kepatuhan. Centang setiap butir setelah buktinya dilihat bersama. Detail teknis: [server-install.md](server-install.md), [PRODUCTION.md](PRODUCTION.md) bagian 8, [operations.md](operations.md).

## A. Server & jaringan — Vendor IT

- [ ] Server Ubuntu 24.04, 4 vCPU / 8 GB / 100 GB SSD, plus disk backup terpisah — `nproc`, `free -h`, `df -h`
- [ ] IP publik dan A record domain API (dan Hub) mengarah ke server — `getent hosts <domain>`
- [ ] Firewall: 80/443 publik, 22 hanya IP admin, port lain tertutup — `nc -zv <IP> 5432` dari luar gagal
- [ ] SSH hanya dengan key; jam server sinkron — `timedatectl`
- [ ] Konfirmasi ada/tidaknya proxy, load balancer, atau Cloudflare di depan server — bila ada, pasang konfigurasi proxy tepercaya dulu

## B. Login OLT — Tim backend OLT

- [ ] JWKS (kunci publik) diserahkan; kunci privat hanya di server OLT
- [ ] Endpoint token sosial: `iss`, `aud`, `sub` tetap, `exp` ≤ 15 menit; jam server OLT sinkron
- [ ] Login dengan token OLT asli berhasil — Hub → **Pengaturan → Integrasi → Integrasi aplikasi**: Aktif, tanpa peringatan kunci dev

## C. Server sosial — Tim IT

- [ ] `server-install.sh` selesai; `make ps` semua healthy
- [ ] HTTPS valid, `http://` dialihkan ke `https://`, `https://<domain>/` menjawab 404
- [ ] OLT dummy dan Studio tidak berjalan
- [ ] Salinan `docker/.env`, `docker/secrets/`, `pgsodium_root.key` tersimpan di luar server
- [ ] Restart otomatis aktif dan mengawasi semua layanan (Kesehatan sistem → **Restart otomatis**, alamat `/system`)

## D. Hub & staf — Super Admin

- [ ] Super Admin pertama dibuat dan password sementara sudah diganti
- [ ] Hub hanya terbuka dari IP kantor/VPN — dibuka dari jaringan lain mendapat 403
- [ ] Akun staf CS, Kepatuhan, dan moderator dibuat, password ≥ 12 karakter
- [ ] **Pengaturan → Alert**: Telegram/email diisi, **Kirim uji** diterima; pemantau uptime dari luar server dipasang
- [ ] **Pengaturan → Backup**: tujuan di disk terpisah atau S3, backup penuh dan uji restore berhasil, password di luar server
- [ ] **Pengaturan → Push notification**: kunci Firebase diunggah (bila push dipakai)

## E. Aplikasi OLT — Tim aplikasi

- [ ] Library `rendezvous_community` v1.8.0; URL HTTPS produksi dan anon key dari `config/prod.json`
- [ ] Build release Android tanpa cleartext; tidak ada `service_role` key di aplikasi
- [ ] Uji manual Android dan Windows: login, feed, chat dua akun, chat CS, unggah gambar
- [ ] **Fitur & Kampanye → Fitur & versi**: versi minimum aplikasi diset; versi lama mendapat "Perbarui aplikasi"

## F. Kepatuhan & legal — Kepatuhan

- [ ] Dokumen hukum (S&K, Pedoman Komunitas, Kebijakan Privasi) diterbitkan; dokumen wajib setuju ditentukan
- [ ] Kata terlarang dan kebijakan konten ditinjau
- [ ] Kalender libur bursa tahun ini dan tahun depan diverifikasi
- [ ] Retensi arsip regulator ditetapkan; jam layanan dan pesan otomatis CS disetujui
- [ ] Staf CS, Kepatuhan, dan moderator sudah dilatih dengan Panduan Hub

## G. Uji sebelum dibuka — Pengembang / Manajemen

- [ ] Uji beban di server dev/staging yang setara produksi; hasil dicatat
- [ ] Pentest independen; temuan kritis dan tinggi ditutup
- [ ] Review kode oleh developer senior (login auth-bridge, RLS, chat CS)

## H. Hari-H — Semua

- [ ] Rilis di luar jam bursa; `make backup` sebelum rilis
- [ ] Penanggung jawab kill switch (**Fitur & Kampanye → Fitur & versi**) siaga
- [ ] Kontak darurat vendor IT, tim OLT, dan pengembang dibagikan; runbook gangguan dicetak
