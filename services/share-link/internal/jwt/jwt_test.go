package jwt

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestServiceRoleIsAShortLivedHS256Token(t *testing.T) {
	secret := []byte("an-integration-test-secret-of-32-chars-or-more")
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
		t.Fatal("tanda tangan tidak cocok")
	}
	raw, _ := b64.DecodeString(parts[1])
	var claims map[string]any
	if err := json.Unmarshal(raw, &claims); err != nil {
		t.Fatal(err)
	}
	if claims["role"] != "service_role" || claims["iss"] != "supabase" || claims["exp"] != float64(now.Unix()+60) {
		t.Fatalf("claims = %v", claims)
	}
}
