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

[ "$(id -u)" -ne 0 ] || die "Run as a regular user with sudo, not as root."
. /etc/os-release
[ "${ID:-}" = ubuntu ] || die "This script is for Ubuntu (detected: ${ID:-unknown})."
sudo -v

say "1/9 System packages, automatic security updates, clock"
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq install git make curl ca-certificates unattended-upgrades ufw python3
echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive unattended-upgrades
sudo timedatectl set-ntp true
ok "packages installed, automatic security updates on, NTP on"

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
  ok "user $USER added to the docker group; continuing with the new group"
  exec sg docker -c "bash '$SCRIPT_PATH'"
fi
compose_version=$(docker compose version --short | sed 's/^v//')
printf '%s\n2.24.0\n' "$compose_version" | sort -V -C -r || die "docker compose $compose_version is too old (needs 2.24 or newer)."
ok "docker $(docker version --format '{{.Server.Version}}'), compose $compose_version"

say "3/9 Swap (only when RAM < 8 GB)"
mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if [ "$mem_kb" -lt 7500000 ] && ! swapon --show | grep -q .; then
  sudo fallocate -l 4G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile > /dev/null
  sudo swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
  ok "4 GB swap created"
else
  ok "no extra swap needed"
fi

say "4/9 Server firewall (ufw, extra layer)"
ssh_port=$(sudo sshd -T 2>/dev/null | awk '/^port / && !seen {print $2; seen = 1}' || true)
ssh_port=${ssh_port:-22}
sudo ufw allow "$ssh_port/tcp" > /dev/null
sudo ufw allow 80/tcp > /dev/null
sudo ufw allow 443/tcp > /dev/null
sudo ufw --force enable > /dev/null
ok "ufw: $ssh_port (SSH), 80, 443"
warn "Docker container ports bypass ufw; the main restriction stays in the hosting provider's firewall"

say "5/9 Code from GitHub"
if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" pull --ff-only
  ok "code updated in $APP_DIR"
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
    echo "  Add this deploy key on GitHub:"
    echo "  repo chat_service_supabase -> Settings -> Deploy keys -> Add deploy key"
    echo "  (any title, do NOT tick \"Allow write access\")"
    echo
    cat "$HOME/.ssh/github_deploy.pub"
    echo
    read -r -p "  Press Enter once the deploy key is added... " _
  done
  ok "code in $APP_DIR"
fi
cd "$APP_DIR"

say "6/9 Configuration (docker/.env)"
make -s gen-secrets
domain=$(ask "API domain (e.g. social-api.company.co.id)" "$(env_get PROXY_DOMAIN)")
[[ $domain =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || die "Invalid domain: $domain"
acme_email=$(ask "IT team email for HTTPS certificates" "$(env_get ACME_EMAIL)")
[[ $acme_email == *@*.* ]] || die "Invalid email: $acme_email"
hub_domain=$(ask "Rendezvous Hub domain (leave empty if none yet)" "$(env_get CS_CONSOLE_DOMAIN)")
vpn_ranges=""
if [ -n "$hub_domain" ]; then
  [[ $hub_domain =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || die "Invalid Hub domain: $hub_domain"
  vpn_ranges=$(ask "IPs/ranges allowed to open the Hub, comma separated (e.g. 203.0.113.10/32)" "$(env_get VPN_SOURCE_RANGES)")
  [[ $vpn_ranges =~ ^[0-9./,\ ]+$ ]] || die "Invalid Hub IP list: $vpn_ranges"
  [[ $vpn_ranges != *0.0.0.0/0* ]] || die "0.0.0.0/0 opens the Hub to the whole internet. Enter office/VPN IPs only."
fi
backup_default=$(env_get BACKUP_LOCAL_REPO_DIR)
[ -n "$backup_default" ] || { [ -d /mnt/backup ] && backup_default=/mnt/backup/restic; }
backup_dir=$(ask "Local backup folder on a separate disk (empty = backups/restic in the repo)" "$backup_default")

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
  [[ $backup_dir == /* ]] || die "The backup folder must be an absolute path: $backup_dir"
  sudo install -d -o 10001 -g 10001 -m 700 "$backup_dir"
  env_set BACKUP_LOCAL_REPO_DIR "$backup_dir"
fi
ok "docker/.env updated"

say "7/9 OLT public keys (docker/secrets/olt_jwks)"
jwks_file="$APP_DIR/docker/secrets/olt_jwks"
jwks_check() {
  python3 - "$1" <<'PY'
import json, sys
try:
    keys = json.load(open(sys.argv[1]))["keys"]
except Exception as e:
    sys.exit(f"not a valid JWKS: {e}")
if not keys:
    sys.exit("the JWKS contains no keys")
for k in keys:
    if str(k.get("kid", "")).startswith("dev-"):
        sys.exit("still a dev key (kid starts with dev-); the production profile rejects it")
    if k.get("alg") not in ("EdDSA", "ES256") or "d" in k:
        sys.exit("keys must be public with alg EdDSA or ES256")
print(", ".join(k.get("kid", "?") for k in keys))
PY
}
if kids=$(jwks_check "$jwks_file" 2>/dev/null); then
  ok "OLT JWKS installed (kid: $kids)"
else
  echo "  Paste the JWKS (PUBLIC keys) from the OLT backend team, then press Enter and Ctrl+D:"
  tmp_jwks=$(mktemp)
  cat > "$tmp_jwks"
  if kids=$(jwks_check "$tmp_jwks"); then
    (umask 077; cat "$tmp_jwks" > "$jwks_file")
    rm -f "$tmp_jwks"
    ok "OLT JWKS saved (kid: $kids)"
  else
    rm -f "$tmp_jwks"
    die "JWKS rejected. Ask the OLT team for the public-key JWKS (docs/olt-integration.md), then run this script again."
  fi
fi

say "8/9 DNS check"
check_dns() {
  local name=$1 resolved
  resolved=$(getent ahostsv4 "$name" | awk '!seen {print $1; seen = 1}' || true)
  [ -n "$resolved" ] || die "$name does not resolve to any IP yet. Ask the IT team to create an A record, wait, then run again."
  echo "  $name -> $resolved   (IPs on this server: $(hostname -I | xargs))"
}
check_dns "$domain"
[ -z "$hub_domain" ] || check_dns "$hub_domain"
confirm "Is the IP above this server's public IP (or the office public IP forwarded to this server)?" \
  || die "Fix DNS first, then run this script again."

say "9/9 Starting services"
export PROFILE=single
bashrc_export PROFILE single
if [ -n "$hub_domain" ]; then
  export CS=1
  bashrc_export CS 1
fi
make up
ok "all services running"

if [ -n "$hub_domain" ] && confirm "Create the first Hub Super Admin account now?"; then
  admin_email=$(ask "Super Admin email")
  admin_name=$(ask "Super Admin full name")
  make cs-bootstrap-admin EMAIL="$admin_email" NAME="$admin_name" \
    || warn "account not created (a Super Admin may already exist). See the message above."
fi

say "Public access check"
anon_key=$(cat docker/secrets/anon_key)
health=""
for _ in $(seq 1 18); do
  health=$(curl -fsS -m 10 -H "apikey: $anon_key" "https://$domain/bridge/v1/health" 2>/dev/null || true)
  [[ $health == *'"olt_mode":"jwt"'* ]] && break
  sleep 10
done
[[ $health == *'"olt_mode":"jwt"'* ]] && ok "https://$domain/bridge/v1/health: olt_mode jwt" \
  || warn "health is not answering yet. Check the certificate: make logs s=traefik (DNS/port 80 must be open)"
code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "http://$domain/" || true)
[[ $code =~ ^30[1278]$ ]] && ok "http redirects to https ($code)" || warn "http://$domain/ answered $code (expected a redirect)"
code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "https://$domain/" || true)
[ "$code" = 404 ] && ok "https://$domain/ 404 (only API paths are open)" || warn "https://$domain/ answered $code (expected 404)"

cat <<EOF

Done.

  URL API (supabaseUrl) : https://$domain
  Anon key (anonKey)    : $anon_key
EOF
[ -z "$hub_domain" ] || echo "  Rendezvous Hub        : https://$hub_domain   (only from: $vpn_ranges)"
cat <<EOF

Next steps (docs/server-install.md section 5):
  1. Log in to the Hub as Super Admin and change the temporary password.
  2. Pengaturan -> Backup: choose a destination, create an encryption password, store it off the server.
  3. Pengaturan -> Alert: fill in Telegram/email, then Kirim uji.
  4. Store off the server: docker/.env, docker/secrets/, the backup password.
  5. Give the API URL and anon key to the OLT app team.
EOF
