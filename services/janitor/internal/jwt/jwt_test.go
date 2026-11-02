package jwt

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/json"
	"reflect"
	"strings"
	"testing"
	"time"
)

func decodePart(t *testing.T, part string) map[string]any {
	t.Helper()
	raw, err := b64.DecodeString(part)
	if err != nil {
		t.Fatal(err)
	}
	var out map[string]any
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatal(err)
	}
	return out
}

func verify(t *testing.T, token string, secret []byte) []string {
	t.Helper()
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Fatalf("token = %q", token)
	}
	h := hmac.New(sha256.New, secret)
	h.Write([]byte(parts[0] + "." + parts[1]))
	if b64.EncodeToString(h.Sum(nil)) != parts[2] {
		t.Fatal("signature mismatch")
	}
	return parts
}

func TestSignProducesAnHS256Token(t *testing.T) {
	token, err := Sign(map[string]any{"alg": "HS256", "typ": "JWT"}, map[string]any{"role": "service_role"}, []byte("k"))
	if err != nil {
		t.Fatal(err)
	}
	parts := verify(t, token, []byte("k"))
	if decodePart(t, parts[0])["alg"] != "HS256" || decodePart(t, parts[1])["role"] != "service_role" {
		t.Fatalf("token = %q", token)
	}
}

func TestServiceRoleIssuesAOneMinuteServiceToken(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	token, err := ServiceRole([]byte("secret"), "supabase", now)
	if err != nil {
		t.Fatal(err)
	}
	parts := verify(t, token, []byte("secret"))
	if header := decodePart(t, parts[0]); header["alg"] != "HS256" || header["typ"] != "JWT" {
		t.Fatalf("header = %v", header)
	}
	want := map[string]any{"iss": "supabase", "role": "service_role", "iat": float64(1_800_000_000), "exp": float64(1_800_000_060)}
	if claims := decodePart(t, parts[1]); !reflect.DeepEqual(claims, want) {
		t.Fatalf("claims = %v", claims)
	}
}
