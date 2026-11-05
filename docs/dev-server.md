# Server Development untuk Integrasi Aplikasi Client

Panduan menyiapkan server development yang dipakai tim aplikasi OLT untuk mengintegrasikan fitur chat dan komunitas (library [`rendezvous_community`](https://github.com/dayat123123/rendezvous_community)). Isinya: spek, akses jaringan, domain, langkah pasang, dan data yang perlu diberikan ke tim aplikasi. Panduan produksi ada di [PRODUCTION.md](PRODUCTION.md).

Rendezvous Hub (web CS) berjalan di jaringan internal dan tidak dibahas di sini.

## Ringkasan

| | |
|---|---|
| Sistem operasi | Ubuntu Server 24.04 LTS |
| Spek rekomendasi | 4 vCPU, 8 GB RAM, 100 GB SSD |
| Lokasi | Data center di Indonesia |
| Yang dibuka ke aplikasi | Satu endpoint API (REST, Realtime, auth-bridge, unggah media) |
| Tahap A (sekarang) | Profil `dev` + OLT dummy, HTTP, akses dibatasi IP tim |
| Tahap B (nanti) | Profil `single` + domain dev + HTTPS, token dari backend OLT dev |

## 1. Spek server

| | Minimum | Rekomendasi |
|---|---|---|
| vCPU | 2 | **4** |
| RAM | 4 GB + swap 4 GB | **8 GB** |
| Disk | 60 GB SSD | **100 GB SSD** |
| Cocok untuk | Stack berjalan dan beberapa developer mencoba integrasi; build image sebaiknya tidak di server karena lambat | Seluruh stack, build image di server, beberapa developer aplikasi menguji bersamaan |

- Saat idle stack memakai sekitar 2,6 GB RAM. Sisa RAM dipakai saat build image dan lonjakan.
- Disk: sekitar 10–15 GB untuk image Docker, sisanya untuk database, file lampiran, dan log (dirotasi otomatis).
- Uji beban (k6 ratusan pengguna) butuh 8 vCPU / 16 GB. Jangan dijalankan di server yang dipakai bersama tim.

## 2. Dua tahap pemakaian

### Tahap A — profil `dev` + OLT dummy (sekarang)

Dipakai selama backend OLT belum menerbitkan token sosial. [OLT dummy](../services/dummy-olt/README.md) berperan sebagai backend OLT tiruan: login dan menerbitkan token sosial dengan kunci dev. auth-bridge memverifikasinya lewat jalur yang sama dengan produksi (mode `jwt`), jadi kode aplikasi yang memanggil `tokenProvider` tidak perlu diubah saat pindah ke token OLT asli.

- API diakses lewat HTTP di port 8000. OLT dummy (login dummy) di port 8090.
- **Tidak ada domain dan HTTPS.** Kedua port **hanya boleh dibuka untuk IP tim**, atau diakses lewat VPN.
- Data di server ini dummy. Jangan memasukkan data nasabah asli.

### Tahap B — profil `single` + domain dev (setelah backend OLT dev siap)

Dipakai saat backend OLT dev sudah menerbitkan token sosial bertanda tangan ([olt-integration.md](olt-integration.md)). Konfigurasinya sama dengan produksi: HTTPS Let's Encrypt, hanya path API yang publik, Studio hanya lewat SSH tunnel.

- OLT dummy tidak tersedia di profil ini. Aplikasi memakai token dari backend OLT dev.
- Kunci publik (JWKS) backend OLT dev disimpan di `docker/secrets/olt_jwks`.

## 3. Domain (tahap B)

Ganti `<domain>` dengan domain perusahaan.

| Domain | Untuk | Akses |
|---|---|---|
| `social-api-dev.<domain>` | Semua kebutuhan aplikasi: REST, Realtime (WebSocket), auth-bridge, unggah media | Publik, atau dibatasi IP tim |

Record DNS yang dibuat di pengelola DNS perusahaan:

| Tipe | Nama | Nilai |
|---|---|---|
| A | `social-api-dev` | `<IP publik server dev>` |

Sertifikat HTTPS dibuat dan diperpanjang otomatis oleh Traefik (Let's Encrypt), jadi tidak perlu membeli SSL.

## 4. Port dan firewall

> **Penting:** port yang di-publish container Docker **melewati aturan `ufw`**. Batasi akses di **firewall penyedia server** (security group / cloud firewall). `ufw` di server hanya lapisan tambahan.

### Masuk (inbound)

| Port | Tahap | Dari | Fungsi |
|---|---|---|---|
| 22/TCP | A dan B | IP admin | SSH (key-only) |
| 8000/TCP | A | IP tim | API untuk aplikasi + Studio |
| 8090/TCP | A | IP tim | OLT dummy (login dummy) |
| 443/TCP | B | Semua, atau IP tim | HTTPS API untuk aplikasi |
| 80/TCP | B | Semua | Validasi Let's Encrypt dan redirect ke HTTPS |

Port lain tetap tertutup, termasuk Postgres (5432), Valkey (6379), dan port layanan internal. Semua itu hanya ada di network Docker internal. Di tahap B, Studio hanya bisa dibuka lewat SSH tunnel ke `127.0.0.1:8000`.

### Keluar (outbound)

| Tujuan | Port | Untuk |
|---|---|---|
| Docker Hub, ghcr.io, GitHub | 443 | Unduh image dan kode saat update |
| Let's Encrypt | 443 | Sertifikat HTTPS (tahap B) |
| Firebase Cloud Messaging | 443 | Push notification ke aplikasi |
| Situs web umum | 80/443 | Pratinjau link di post dan chat (dibatasi aman SSRF) |
| DNS, NTP | 53, 123/UDP | Resolusi nama dan sinkron jam |

## 5. Persiapan Ubuntu

Jalankan sebagai user dengan `sudo`.

```bash
sudo apt update && sudo apt -y upgrade
sudo apt -y install git make curl ca-certificates unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades       # patch keamanan otomatis

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update && sudo apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER                         # login ulang setelah ini
docker compose version                                 # wajib v2.24 atau lebih baru

timedatectl set-ntp true && timedatectl                # jam harus sinkron: token sosial hanya toleran selisih 30 detik
```

- **Docker:** pasang dari repo resmi Docker (seperti di atas), bukan dari snap.
- **SSH:** login dengan key saja. Di `/etc/ssh/sshd_config`, isi `PasswordAuthentication no` dan `PermitRootLogin no`, lalu `sudo systemctl restart ssh`.
- **Swap** (khusus spek minimum 4 GB RAM):

  ```bash
  sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  ```

## 6. Pemasangan

### Tahap A (profil `dev` + OLT dummy)

```bash
git clone https://github.com/dayat123123/chat_service_supabase.git
cd chat_service_supabase
make gen-secrets
```

Rendezvous Hub ada di repo terpisah ([`rendezvous_hub`](https://github.com/dayat123123/rendezvous_hub)) dan tidak wajib di server ini. Tanpa checkout-nya, `make up` profil dev menampilkan peringatan `Rendezvous Hub checkout not found at ...` lalu berjalan tanpa `cs-console`. Bila Hub ingin dicoba juga, clone repo itu di sebelah `chat_service_supabase` (`git clone <repo rendezvous_hub> ../rendezvous_hub`) sebelum `make up`.

Ubah di `docker/.env`:

```bash
EDGE_HTTP_BIND=0.0.0.0          # buka port 8000/8090 di semua interface; akses dibatasi firewall penyedia
```

Lalu jalankan:

```bash
make up DUMMY_OLT=1
make seed                       # akun dummy, post, thread, chat contoh
make smoke-dummy                # semua cek harus ok
make anon-key                   # ANON_KEY untuk aplikasi
```

### Tahap B (profil `single` + domain dev)

Isi di `docker/.env`:

```bash
PROXY_DOMAIN=social-api-dev.<domain>
SUPABASE_PUBLIC_URL=https://social-api-dev.<domain>
API_EXTERNAL_URL=https://social-api-dev.<domain>/auth/v1
ACME_EMAIL=<email tim IT>                    # notifikasi sertifikat Let's Encrypt
```

Simpan JWKS backend OLT dev di `docker/secrets/olt_jwks`, lalu:

```bash
make gen-secrets PROFILE=single
make up PROFILE=single
make anon-key
```

Untuk Studio, buka SSH tunnel dari laptop: `ssh -L 8000:127.0.0.1:8000 <user>@<IP-server>`, lalu buka `http://localhost:8000`.

## 7. Data untuk tim aplikasi

Berikan ke tim aplikasi OLT. Detail kodenya ada di [panduan integrasi library](https://github.com/dayat123123/rendezvous_community/blob/main/doc/integration.md).

| Data | Tahap A | Tahap B |
|---|---|---|
| `supabaseUrl` | `http://<IP-server>:8000` | `https://social-api-dev.<domain>` |
| `anonKey` | hasil `make anon-key` (aman disimpan di aplikasi) | sama |
| Token sosial untuk `tokenProvider` | dari OLT dummy: `POST http://<IP-server>:8090/api/login` (username + password, balasan berisi `social_token`), perpanjang lewat `POST /api/social-token`, atau `make dummy-token U=<user>` di server | dari endpoint token sosial backend OLT dev |
| Akun uji | user seed `budi_santoso`, `sari_invest`, `andi_trader`, `rina_saham`, `dewi_cuan`, password `olt12345` ([daftar lengkap](../services/dummy-olt/README.md)) | akun OLT dev |
| Versi library | `ref: v1.7.0` | sama |

Catatan untuk aplikasi:
- **Android di tahap A:** server memakai HTTP. Izinkan cleartext **hanya** di build debug (`src/debug/AndroidManifest.xml` atau network security config untuk IP server dev). Windows tidak butuh pengaturan tambahan. Di tahap B semuanya HTTPS.
- **Chat CS:** untuk mencoba chat CS dari aplikasi, CS membalas dari Rendezvous Hub di jaringan internal.
- **Push notification:** butuh kunci Firebase yang diisi Super Admin dari Hub, dan aplikasi memanggil `registerPushToken(...)`.

## 8. Pemeriksaan setelah pasang

| Cek | Cara | Hasil yang diharapkan |
|---|---|---|
| Semua container sehat | `make ps` | Semua `healthy`; `migrate` dan `volume-init` keluar dengan kode 0 |
| End-to-end | `make smoke-dummy` (tahap A) | Semua cek ok |
| auth-bridge | `curl -H "apikey: <ANON_KEY>" <supabaseUrl>/bridge/v1/health` | `olt_mode: jwt`, `status: ok` |
| Dari aplikasi | Login dengan akun uji, buka feed dan chat | Feed tampil, pesan antar dua akun masuk realtime |
| Port tertutup | `nc -zv <IP-server> 5432` dari luar | Gagal tersambung |

## 9. Pemeliharaan

```bash
git pull && make up DUMMY_OLT=1  # tahap B: make up PROFILE=single; migrasi baru berjalan otomatis
make logs s=<service>            # log satu service
make backup                      # salinan sesaat (pg_dump + file storage) ke backups/, misalnya sebelum update besar
```

## 10. Yang perlu disiapkan

- [ ] Server Ubuntu 24.04 sesuai spek bagian 1, di data center Indonesia
- [ ] IP publik server (dari penyedia server)
- [ ] IP publik tim untuk firewall
- [ ] Akses SSH dengan key untuk admin
- [ ] Tahap B: domain `social-api-dev.<domain>` mengarah ke IP server
- [ ] Tahap B: JWKS dan endpoint token sosial dari backend OLT dev
- [ ] Tahap B: email tim IT untuk notifikasi sertifikat
