package jwt

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestServiceRoleIssuesAOneMinuteServiceToken(t *testing.T) {
	secret := []byte(strings.Repeat("k", 40))
	now := time.Unix(1_800_000_000, 0)
	token, err := ServiceRole(secret, "supabase", now)
	if err != nil {
		t.Fatal(err)
	}
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Fatalf("token = %q", token)
	}
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(parts[0] + "." + parts[1]))
	if b64.EncodeToString(mac.Sum(nil)) != parts[2] {
		t.Fatal("bad signature")
	}
	var header, claims map[string]any
	raw, _ := b64.DecodeString(parts[0])
	_ = json.Unmarshal(raw, &header)
	raw, _ = b64.DecodeString(parts[1])
	_ = json.Unmarshal(raw, &claims)
	if header["alg"] != "HS256" || claims["role"] != "service_role" || claims["iss"] != "supabase" ||
		claims["iat"] != float64(1_800_000_000) || claims["exp"] != float64(1_800_000_060) {
		t.Fatalf("header = %v claims = %v", header, claims)
	}
}

func TestSignRejectsUnencodableClaims(t *testing.T) {
	if _, err := Sign(map[string]any{"alg": "HS256"}, map[string]any{"bad": func() {}}, []byte("k")); err == nil {
		t.Fatal("expected an error")
	}
}
