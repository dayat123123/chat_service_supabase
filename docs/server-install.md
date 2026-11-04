# Instalasi Server Baru

Panduan memasang server sosial di server Ubuntu baru sampai API bisa diakses publik lewat domain dengan HTTPS. Sebagian besar langkah dikerjakan satu script, [`scripts/server-install.sh`](../scripts/server-install.sh), yang dikirim ke server dengan `scp` sebelum repo di-clone di sana. Isinya juga ada di bagian 3.

Hasil akhirnya:

- `https://<domain API>` untuk aplikasi OLT (REST, Realtime, login, unggah media), sertifikat Let's Encrypt otomatis.
- Rendezvous Hub di `https://<domain Hub>`, hanya dari IP kantor/VPN (opsional).
- Backup berjalan ke folder di disk terpisah setelah diatur dari Hub.

Rujukan lain: [operations.md](operations.md) (operasional), [runbook-gangguan.md](runbook-gangguan.md) (gangguan), [PRODUCTION.md](PRODUCTION.md) (detail produksi), [dev-server.md](dev-server.md) (spek dan mode dev).

## 1. Yang harus ada sebelum mulai

| | Dari | Contoh |
|---|---|---|
| Server Ubuntu 24.04, 4 vCPU / 8 GB / 100 GB SSD (+ disk backup terpisah, mis. `/mnt/backup`) | Vendor IT | — |
| IP publik server (atau port forwarding 80/443 dari IP publik kantor) | Vendor IT | `203.0.113.10` |
| A record domain API ke IP itu | Vendor IT / pengelola DNS | `social-api.perusahaan.co.id` |
| A record domain Hub ke IP yang sama (opsional) | Vendor IT / pengelola DNS | `hub.perusahaan.co.id` |
| Firewall penyedia: 80 dan 443 dari internet, 22 hanya dari IP admin | Vendor IT | — |
| User SSH dengan `sudo`, login dengan SSH key | Vendor IT | — |
| JWKS (kunci **publik**) penanda tangan token sosial | Tim backend OLT ([olt-integration.md](olt-integration.md)) | `{"keys":[{"kty":"OKP",...}]}` |
| Email tim IT (notifikasi sertifikat) | Anda | `it@perusahaan.co.id` |
| IP publik kantor / subnet VPN untuk Hub | Tim IT | `198.51.100.7/32` |
| Akses admin repo GitHub `chat_service_supabase` (untuk menambah deploy key) | Anda | — |

Tanpa JWKS dari OLT, mode produksi tidak bisa dipakai (kunci dummy ditolak). Selama JWKS belum ada, pakai mode dev di bagian 7.

## 2. Menjalankan script

1. Kirim script ke server. Cara paling aman: dari laptop yang sudah punya repo ini (PowerShell atau terminal di folder repo):

   ```bash
   scp scripts/server-install.sh <user>@<IP-server>:~/install.sh
   ```

   Cara lain bila repo tidak ada di laptop: setelah masuk ke server (langkah 2), jalankan `nano install.sh`, tempel isi bagian 3 dari file Markdown atau dari GitHub, lalu Ctrl+O, Enter, Ctrl+X. Jangan menyalin script dari PDF: baris panjang yang terlipat bisa ikut tersalin sebagai baris baru dan merusak script.

2. Masuk ke server:

   ```bash
   ssh <user>@<IP-server>
   ```

3. Jalankan di server:

   ```bash
   bash install.sh
   ```

Script menanyakan beberapa hal dan berhenti dengan pesan jelas bila ada yang belum siap. Aman dijalankan ulang: langkah yang sudah selesai dilewati, isian sebelumnya menjadi nilai bawaan.

| Langkah | Yang dilakukan | Yang ditanyakan |
|---|---|---|
| 1 | Update sistem, paket dasar, update keamanan otomatis, NTP | — |
| 2 | Pasang Docker dan compose dari repo resmi Docker | — |
| 3 | Swap 4 GB bila RAM < 8 GB | — |
| 4 | `ufw`: SSH, 80, 443 | — |
| 5 | Deploy key GitHub (baca saja), clone repo ke `~/chat_service_supabase` | Tambahkan deploy key yang ditampilkan di GitHub, lalu Enter |
| 6 | `make gen-secrets`, isi `docker/.env` | Domain API, email, domain Hub dan IP kantor (opsional), folder backup |
| 7 | Simpan JWKS OLT ke `docker/secrets/olt_jwks`, tolak kunci dev atau kunci privat | Tempel JWKS, Enter, Ctrl+D |
| 8 | Cek DNS domain mengarah ke server | Konfirmasi IP |
| 9 | `make up` profil `single`, akun Super Admin pertama, verifikasi HTTPS | Email dan nama Super Admin |

Di akhir, script mencetak URL API, anon key, dan alamat Hub. Password sementara Super Admin hanya tampil **sekali**; catat sebelum menutup terminal.

Waktu: ±15–30 menit, sebagian besar untuk mengunduh dan build image pertama kali.

## 3. Isi script

Sama dengan [`scripts/server-install.sh`](../scripts/server-install.sh). Setelah repo ter-clone, jalankan ulang dari repo: `bash ~/chat_service_supabase/scripts/server-install.sh`.

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_SSH="${REPO_SSH:-git@github.com:dayat123123/chat_service_supabase.git}"
APP_DIR="${APP_DIR:-$HOME/chat_service_supabase}"
SCRIPT_PATH="$(readlink -f "$0")"

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok() { printf '\033[32m  ok  %s\033[0m\n' "$*"; }
warn() { printf '\033[33m  !   %s\033[0m\n' "$*"; }
die() { printf '\033[31m  x   %s\033[0m\n' "$*" >&2; exit 1; }
ask() {
  local prompt=$1 default=${2:-} reply
  read -r -p "  $prompt${default:+ [$default]}: " reply
  printf '%s' "${reply:-$default}"
}
confirm() {
  local reply
  read -r -p "  $1 [y/N]: " reply
  [[ $reply =~ ^[Yy]$ ]]
}
env_get() {
  [ -f "$APP_DIR/docker/.env" ] || return 0
  sed -n "s/^$1=//p" "$APP_DIR/docker/.env" | tail -1
}
env_set() {
  local file="$APP_DIR/docker/.env" tmp
  tmp=$(mktemp)
  awk -v k="$1" -v v="$2" '
    $0 ~ "^"k"=" { if (!done) print k"="v; done = 1; next }
    { print }
    END { if (!done) print k"="v }
  ' "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}
bashrc_export() {
  grep -qx "export $1=$2" "$HOME/.bashrc" 2>/dev/null || echo "export $1=$2" >> "$HOME/.bashrc"
}

[ "$(id -u)" -ne 0 ] || die "Jalankan sebagai user biasa yang punya sudo, bukan root."
. /etc/os-release
[ "${ID:-}" = ubuntu ] || die "Script ini untuk Ubuntu (terdeteksi: ${ID:-tidak dikenal})."
sudo -v

say "1/9 Paket sistem, update keamanan otomatis, jam"
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq install git make curl ca-certificates unattended-upgrades ufw python3
echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive unattended-upgrades
sudo timedatectl set-ntp true
ok "paket terpasang, update keamanan otomatis aktif, NTP aktif"

say "2/9 Docker"
if ! command -v docker >/dev/null 2>&1; then
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
sudo systemctl enable --now docker > /dev/null
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
fi
if ! docker info > /dev/null 2>&1; then
  ok "user $USER ditambahkan ke grup docker; melanjutkan dengan grup baru"
  exec sg docker -c "bash '$SCRIPT_PATH'"
fi
compose_version=$(docker compose version --short | sed 's/^v//')
printf '%s\n2.24.0\n' "$compose_version" | sort -V -C -r || die "docker compose $compose_version terlalu lama (butuh 2.24 atau lebih baru)."
ok "docker $(docker version --format '{{.Server.Version}}'), compose $compose_version"

say "3/9 Swap (hanya bila RAM < 8 GB)"
mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if [ "$mem_kb" -lt 7500000 ] && ! swapon --show | grep -q .; then
  sudo fallocate -l 4G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile > /dev/null
  sudo swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
  ok "swap 4 GB dibuat"
else
  ok "tidak perlu swap tambahan"
fi

say "4/9 Firewall server (ufw, lapisan tambahan)"
ssh_port=$(sudo sshd -T 2>/dev/null | awk '/^port / && !seen {print $2; seen = 1}' || true)
ssh_port=${ssh_port:-22}
sudo ufw allow "$ssh_port/tcp" > /dev/null
sudo ufw allow 80/tcp > /dev/null
sudo ufw allow 443/tcp > /dev/null
sudo ufw --force enable > /dev/null
ok "ufw: $ssh_port (SSH), 80, 443"
warn "port container Docker melewati ufw; pembatasan utama tetap di firewall penyedia server"

say "5/9 Kode dari GitHub"
if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" pull --ff-only
  ok "kode diperbarui di $APP_DIR"
else
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  [ -f "$HOME/.ssh/github_deploy" ] || ssh-keygen -q -t ed25519 -N "" -C "deploy@$(hostname)" -f "$HOME/.ssh/github_deploy"
  grep -q 'IdentityFile ~/.ssh/github_deploy' "$HOME/.ssh/config" 2>/dev/null \
    || printf 'Host github.com\n  IdentityFile ~/.ssh/github_deploy\n  IdentitiesOnly yes\n' >> "$HOME/.ssh/config"
  chmod 600 "$HOME/.ssh/config"
  ssh-keygen -F github.com > /dev/null 2>&1 || ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
  until git clone -q "$REPO_SSH" "$APP_DIR" 2>/dev/null; do
    echo
    echo "  Tambahkan deploy key berikut di GitHub:"
    echo "  repo chat_service_supabase -> Settings -> Deploy keys -> Add deploy key"
    echo "  (judul bebas, JANGAN centang \"Allow write access\")"
    echo
    cat "$HOME/.ssh/github_deploy.pub"
    echo
    read -r -p "  Tekan Enter setelah deploy key ditambahkan... " _
  done
  ok "kode di $APP_DIR"
fi
cd "$APP_DIR"

say "6/9 Konfigurasi (docker/.env)"
make -s gen-secrets
domain=$(ask "Domain API (mis. social-api.perusahaan.co.id)" "$(env_get PROXY_DOMAIN)")
[[ $domain =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || die "Domain tidak valid: $domain"
acme_email=$(ask "Email tim IT untuk sertifikat HTTPS" "$(env_get ACME_EMAIL)")
[[ $acme_email == *@*.* ]] || die "Email tidak valid: $acme_email"
hub_domain=$(ask "Domain Rendezvous Hub (kosongkan bila belum)" "$(env_get CS_CONSOLE_DOMAIN)")
vpn_ranges=""
if [ -n "$hub_domain" ]; then
  [[ $hub_domain =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || die "Domain Hub tidak valid: $hub_domain"
  vpn_ranges=$(ask "IP/rentang yang boleh membuka Hub, pisah koma (mis. 203.0.113.10/32)" "$(env_get VPN_SOURCE_RANGES)")
  [[ $vpn_ranges =~ ^[0-9./,\ ]+$ ]] || die "Daftar IP Hub tidak valid: $vpn_ranges"
  [[ $vpn_ranges != *0.0.0.0/0* ]] || die "0.0.0.0/0 membuka Hub ke seluruh internet. Isi IP kantor/VPN saja."
fi
backup_default=$(env_get BACKUP_LOCAL_REPO_DIR)
[ -n "$backup_default" ] || { [ -d /mnt/backup ] && backup_default=/mnt/backup/restic; }
backup_dir=$(ask "Folder backup lokal di disk terpisah (kosongkan = backups/restic di repo)" "$backup_default")

env_set PROXY_DOMAIN "$domain"
env_set SUPABASE_PUBLIC_URL "https://$domain"
env_set API_EXTERNAL_URL "https://$domain/auth/v1"
env_set ACME_EMAIL "$acme_email"
env_set HEALER_DOCKER_GID "$(getent group docker | cut -d: -f3)"
if [ -n "$hub_domain" ]; then
  env_set CS_CONSOLE_DOMAIN "$hub_domain"
  env_set VPN_SOURCE_RANGES "$vpn_ranges"
fi
if [ -n "$backup_dir" ]; then
  [[ $backup_dir == /* ]] || die "Folder backup harus path absolut: $backup_dir"
  sudo install -d -o 10001 -g 10001 -m 700 "$backup_dir"
  env_set BACKUP_LOCAL_REPO_DIR "$backup_dir"
fi
ok "docker/.env diperbarui"

say "7/9 Kunci publik OLT (docker/secrets/olt_jwks)"
jwks_file="$APP_DIR/docker/secrets/olt_jwks"
jwks_check() {
  python3 - "$1" <<'PY'
import json, sys
try:
    keys = json.load(open(sys.argv[1]))["keys"]
except Exception as e:
    sys.exit(f"bukan JWKS yang valid: {e}")
if not keys:
    sys.exit("JWKS tidak berisi kunci")
for k in keys:
    if str(k.get("kid", "")).startswith("dev-"):
        sys.exit("masih kunci dev (kid diawali dev-); profil produksi menolaknya")
    if k.get("alg") not in ("EdDSA", "ES256") or "d" in k:
        sys.exit("kunci harus publik dengan alg EdDSA atau ES256")
print(", ".join(k.get("kid", "?") for k in keys))
PY
}
if kids=$(jwks_check "$jwks_file" 2>/dev/null); then
  ok "JWKS OLT terpasang (kid: $kids)"
else
  echo "  Tempel JWKS (kunci PUBLIK) dari tim backend OLT, lalu tekan Enter dan Ctrl+D:"
  tmp_jwks=$(mktemp)
  cat > "$tmp_jwks"
  if kids=$(jwks_check "$tmp_jwks"); then
    (umask 077; cat "$tmp_jwks" > "$jwks_file")
    rm -f "$tmp_jwks"
    ok "JWKS OLT disimpan (kid: $kids)"
  else
    rm -f "$tmp_jwks"
    die "JWKS ditolak. Minta JWKS kunci publik ke tim OLT (docs/olt-integration.md), lalu jalankan script ini lagi."
  fi
fi

say "8/9 Cek DNS"
check_dns() {
  local name=$1 resolved
  resolved=$(getent ahostsv4 "$name" | awk '!seen {print $1; seen = 1}' || true)
  [ -n "$resolved" ] || die "$name belum mengarah ke IP mana pun. Minta tim IT membuat A record, tunggu, lalu jalankan lagi."
  echo "  $name -> $resolved   (IP di server ini: $(hostname -I | xargs))"
}
check_dns "$domain"
[ -z "$hub_domain" ] || check_dns "$hub_domain"
confirm "Apakah IP di atas adalah IP publik server ini (atau IP publik kantor yang diteruskan ke server)?" \
  || die "Perbaiki DNS dulu, lalu jalankan script ini lagi."

say "9/9 Menyalakan layanan"
export PROFILE=single
bashrc_export PROFILE single
if [ -n "$hub_domain" ]; then
  export CS=1
  bashrc_export CS 1
fi
make up
ok "semua layanan berjalan"

if [ -n "$hub_domain" ] && confirm "Buat akun Super Admin pertama untuk Hub sekarang?"; then
  admin_email=$(ask "Email Super Admin")
  admin_name=$(ask "Nama lengkap Super Admin")
  make cs-bootstrap-admin EMAIL="$admin_email" NAME="$admin_name" \
    || warn "akun tidak dibuat (mungkin Super Admin sudah ada). Lihat pesan di atas."
fi

say "Verifikasi akses publik"
anon_key=$(cat docker/secrets/anon_key)
health=""
for _ in $(seq 1 18); do
  health=$(curl -fsS -m 10 -H "apikey: $anon_key" "https://$domain/bridge/v1/health" 2>/dev/null || true)
  [[ $health == *'"olt_mode":"jwt"'* ]] && break
  sleep 10
done
[[ $health == *'"olt_mode":"jwt"'* ]] && ok "https://$domain/bridge/v1/health: olt_mode jwt" \
  || warn "health belum menjawab. Cek sertifikat: make logs s=traefik (DNS/port 80 harus terbuka)"
code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "http://$domain/" || true)
[[ $code =~ ^30[1278]$ ]] && ok "http dialihkan ke https ($code)" || warn "http://$domain/ menjawab $code (diharapkan redirect)"
code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "https://$domain/" || true)
[ "$code" = 404 ] && ok "https://$domain/ 404 (hanya path API yang dibuka)" || warn "https://$domain/ menjawab $code (diharapkan 404)"

cat <<EOF

Selesai.

  URL API (supabaseUrl) : https://$domain
  Anon key (anonKey)    : $anon_key
EOF
[ -z "$hub_domain" ] || echo "  Rendezvous Hub        : https://$hub_domain   (hanya dari: $vpn_ranges)"
cat <<EOF

Langkah berikutnya (docs/server-install.md bagian 5):
  1. Login Hub sebagai Super Admin, ganti password sementara.
  2. Pengaturan -> Backup: pilih tujuan, buat password enkripsi, simpan di luar server.
  3. Pengaturan -> Alert: isi Telegram/email, lalu Kirim uji.
  4. Simpan di luar server: docker/.env, docker/secrets/, password backup.
  5. Berikan URL API dan anon key ke tim aplikasi OLT.
EOF
```

## 4. Cek setelah selesai

Script sudah memeriksa tiga hal di bawah. Ulangi kapan saja:

```bash
cd ~/chat_service_supabase
make ps                                                      # semua healthy
curl -s -H "apikey: $(cat docker/secrets/anon_key)" https://<domain API>/bridge/v1/health
                                                             # "olt_mode":"jwt", "status":"ok"
curl -sI http://<domain API>/ | head -1                      # 301/308 ke https
curl -s -o /dev/null -w '%{http_code}\n' https://<domain API>/   # 404: hanya path API yang dibuka
```

Dari laptop di luar kantor: `nc -zv <IP-server> 5432` harus gagal, dan `https://<domain Hub>` harus 403.

## 5. Setelah server jalan

1. **Login Hub** (`https://<domain Hub>`, dari kantor/VPN) dengan email Super Admin dan password sementara, lalu ganti password.
2. **Pengaturan → Backup**: pilih tujuan (Folder lokal di server, atau S3), buat password enkripsi, simpan. Tekan **Uji restore sekarang** setelah backup penuh pertama selesai.
3. **Pengaturan → Alert**: isi Telegram/email, lalu **Kirim uji**. Tanpa kanal ini, alert gangguan tidak terkirim ke siapa pun.
4. **Pengaturan → Push notification**: unggah kunci Firebase (project Firebase aplikasi OLT), bila push dipakai.
5. **Pengaturan → Akun CS**: buat akun staf lain.
6. **Simpan di luar server** (password manager / brankas): `docker/.env`, folder `docker/secrets/`, password backup, salinan `pgsodium_root.key` ([backup](backup/README.md#pemulihan)).
7. **Data untuk tim aplikasi OLT**: `supabaseUrl` = `https://<domain API>`, `anonKey` = hasil `make anon-key`, versi library `v1.6.0` ([panduan integrasi library](https://github.com/dayat123123/rendezvous_community/blob/main/doc/integration.md)).
8. Uji dari aplikasi: login, buka feed, kirim chat antar dua akun.

## 6. Bila ada masalah saat instalasi

| Gejala | Penyebab umum | Tindakan |
|---|---|---|
| "belum mengarah ke IP mana pun" | A record belum dibuat atau belum menyebar | Minta tim IT cek DNS, tunggu beberapa menit, jalankan ulang |
| Health tidak menjawab, `make logs s=traefik` berisi error ACME | Port 80 tertutup, DNS salah, atau batas Let's Encrypt | Pastikan 80/443 terbuka dari internet dan DNS benar, lalu `make up` |
| `docker/.env masih berisi CHANGE_ME` atau `wajib diisi` | Isian `.env` kurang | Jalankan ulang script, atau edit `docker/.env` lalu `make up` |
| JWKS ditolak | Kunci dev, kunci privat, atau format salah | Minta ulang JWKS **publik** dari tim OLT |
| Clone terus gagal | Deploy key belum ditambahkan / repo lain | Periksa GitHub → Settings → Deploy keys |
| Hub 403 dari kantor | IP kantor tidak ada di `VPN_SOURCE_RANGES` | Cek IP publik kantor, perbaiki `docker/.env`, `make up` |
| `olt_mode` bukan `jwt` | Konfigurasi auth-bridge | `make logs s=auth-bridge` |
| Login dari aplikasi selalu "Sesi berakhir" | `iss`/`aud`/jam server OLT tidak cocok | `docker logs olt-social-auth-bridge-1 --since 15m` (field `reason`) |

## 7. Belum ada JWKS OLT: mode dev sementara

Mode ini memakai OLT dummy (login uji `budi_santoso` / `olt12345` dan lainnya), tanpa domain dan HTTPS, diakses lewat SSH tunnel. Langkah 1–5 script tetap bisa dipakai: jalankan script, lalu berhenti (Ctrl+C) saat ditanya domain. Sesudahnya:

```bash
cd ~/chat_service_supabase
make up DUMMY_OLT=1
make seed
make smoke-dummy        # semua ok
make cs-staff           # akun staf dev untuk Hub
```

Dari laptop:

```bash
ssh -L 8000:127.0.0.1:8000 -L 8090:127.0.0.1:8090 -L 8085:127.0.0.1:8085 <user>@<IP-server>
```

Selama terminal itu terbuka: Hub `http://localhost:8085`, API `http://localhost:8000`, login OLT dummy `http://localhost:8090`. Setelah JWKS OLT diterima: `make down`, lalu jalankan script lagi dan lanjutkan sampai selesai.

## 8. Sehari-hari

```bash
cd ~/chat_service_supabase
make ps                  # status
make logs s=rest         # log satu layanan (Ctrl+C keluar)
git pull && make up      # update versi, di luar jam bursa, setelah make backup
```

`PROFILE=single` (dan `CS=1` bila Hub dipasang) sudah disimpan script di `~/.bashrc`, jadi perintah `make` langsung memakai profil produksi. Jangan pernah menjalankan `make reset` atau `docker volume rm` di server ini.
