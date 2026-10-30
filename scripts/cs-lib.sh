#!/usr/bin/env bash
# Helper bersama smoke-cs.sh dan cs-demo-setup.sh (berjalan di container tools).

: "${JWT_SECRET:?JWT_SECRET wajib diisi}"

sql() { psql -X -q -tA -v ON_ERROR_STOP=1 -U postgres -c "$1"; }
b64url() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }

sign() {
  local head payload
  head=$(printf '%s' '{"alg":"HS256","typ":"JWT"}' | b64url)
  payload=$(printf '%s' "$1" | b64url)
  printf '%s.%s.%s' "$head" "$payload" \
    "$(printf '%s.%s' "$head" "$payload" | openssl dgst -binary -sha256 -hmac "$JWT_SECRET" | b64url)"
}

# agent_jwt <uuid> [detik]: JWT agen seperti terbitan GoTrue setelah login + TOTP (aal2).
agent_jwt() {
  local now
  now=$(date +%s)
  sign "{\"sub\":\"$1\",\"role\":\"authenticated\",\"aud\":\"authenticated\",\"aal\":\"aal2\",\"iat\":$now,\"exp\":$((now + ${2:-3600}))}"
}

# ensure_agent <uuid> <nama> <peran> <tim> <skill-json>: agen dev/uji dengan ID tetap.
ensure_agent() {
  sql "select cs.create_agent('$1', '$2', '$3', '$4', '$5', '{id,en}', 5)
       where not exists (select 1 from cs.agents where user_id = '$1');
       update cs.agents set disabled_at = null where user_id = '$1';" > /dev/null
}

# totp <secret-base32>: kode TOTP 6 digit (RFC 6238, 30 detik) untuk akun staf dev.
totp() {
  perl -MDigest::SHA=hmac_sha1 -e '
    my %map; @map{"A" .. "Z", "2" .. "7"} = 0 .. 31;
    (my $secret = uc shift) =~ s/[^A-Z2-7]//g;
    my $bits = join "", map { sprintf "%05b", $map{$_} } split //, $secret;
    my $key = pack "B*", substr($bits, 0, int(length($bits) / 8) * 8);
    my $hash = hmac_sha1(pack("N2", 0, int(time / 30)), $key);
    my $offset = ord(substr($hash, -1)) & 15;
    printf "%06d\n", (unpack("N", substr($hash, $offset, 4)) & 0x7fffffff) % 1000000;' "$1"
}
