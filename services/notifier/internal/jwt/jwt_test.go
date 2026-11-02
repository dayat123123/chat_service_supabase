package jwt

import (
	"crypto"
	"crypto/hmac"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/json"
	"strings"
	"testing"
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

func TestSignProducesAnHS256Token(t *testing.T) {
	token, err := Sign(map[string]any{"alg": "HS256", "typ": "JWT"}, map[string]any{"role": "service_role"}, []byte("k"))
	if err != nil {
		t.Fatal(err)
	}
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Fatalf("token = %q", token)
	}
	h := hmac.New(sha256.New, []byte("k"))
	h.Write([]byte(parts[0] + "." + parts[1]))
	if b64.EncodeToString(h.Sum(nil)) != parts[2] {
		t.Fatal("signature mismatch")
	}
	if decodePart(t, parts[0])["alg"] != "HS256" || decodePart(t, parts[1])["role"] != "service_role" {
		t.Fatalf("token = %q", token)
	}
}

func TestSignRS256VerifiesWithThePublicKey(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	token, err := SignRS256(map[string]any{"alg": "RS256", "typ": "JWT", "kid": "k1"}, map[string]any{"iss": "svc@demo"}, key)
	if err != nil {
		t.Fatal(err)
	}
	parts := strings.Split(token, ".")
	sig, err := b64.DecodeString(parts[2])
	if err != nil {
		t.Fatal(err)
	}
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	if err := rsa.VerifyPKCS1v15(&key.PublicKey, crypto.SHA256, digest[:], sig); err != nil {
		t.Fatal(err)
	}
	header := decodePart(t, parts[0])
	if header["alg"] != "RS256" || header["kid"] != "k1" || decodePart(t, parts[1])["iss"] != "svc@demo" {
		t.Fatalf("token = %q", token)
	}
}
