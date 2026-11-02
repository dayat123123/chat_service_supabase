package jwt

import (
	"crypto/ed25519"
	"crypto/rand"
	"errors"
	"strings"
	"testing"
	"time"
)

var now = time.Unix(1_800_000_000, 0)

func TestSignAndVerify(t *testing.T) {
	token, err := Sign(map[string]any{"alg": "HS256", "typ": "JWS"}, map[string]any{"loginId": "rina", "exp": now.Add(time.Minute).Unix()}, []byte("k"))
	if err != nil {
		t.Fatal(err)
	}
	claims, err := Verify(token, []byte("k"), now)
	if err != nil {
		t.Fatal(err)
	}
	if claims["loginId"] != "rina" {
		t.Fatalf("claims = %v", claims)
	}
}

func TestVerifyRejectsWrongKeyExpiryAndAlgorithm(t *testing.T) {
	valid, _ := Sign(map[string]any{"alg": "HS256"}, map[string]any{"exp": now.Add(time.Minute).Unix()}, []byte("k"))
	expired, _ := Sign(map[string]any{"alg": "HS256"}, map[string]any{"exp": now.Add(-time.Second).Unix()}, []byte("k"))
	none, _ := Sign(map[string]any{"alg": "none"}, map[string]any{"exp": now.Add(time.Minute).Unix()}, []byte("k"))

	cases := []struct {
		name  string
		token string
		key   string
		want  error
	}{
		{"wrong key", valid, "other", ErrSignature},
		{"expired", expired, "k", ErrExpired},
		{"alg none", none, "k", ErrMalformed},
		{"garbage", "a.b", "k", ErrMalformed},
		{"tampered", valid[:strings.LastIndex(valid, ".")] + ".AAAA", "k", ErrSignature},
	}
	for _, tc := range cases {
		if _, err := Verify(tc.token, []byte(tc.key), now); !errors.Is(err, tc.want) {
			t.Errorf("%s: err = %v, want %v", tc.name, err, tc.want)
		}
	}
}

func TestHasAudience(t *testing.T) {
	if !HasAudience(map[string]any{"aud": "authenticated"}, "authenticated") {
		t.Error("string audience")
	}
	if !HasAudience(map[string]any{"aud": []any{"x", "authenticated"}}, "authenticated") {
		t.Error("list audience")
	}
	if HasAudience(map[string]any{"aud": "anon"}, "authenticated") {
		t.Error("wrong audience accepted")
	}
}

func TestSignEdDSAProducesAVerifiableEd25519Token(t *testing.T) {
	public, private, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	token, err := SignEdDSA(map[string]any{"iss": "web-cs", "jti": "a1"}, private)
	if err != nil {
		t.Fatal(err)
	}
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Fatalf("token = %q", token)
	}
	head, _ := b64.DecodeString(parts[0])
	if string(head) != `{"alg":"EdDSA","typ":"JWT"}` {
		t.Fatalf("header = %s", head)
	}
	sig, _ := b64.DecodeString(parts[2])
	if !ed25519.Verify(public, []byte(parts[0]+"."+parts[1]), sig) {
		t.Fatal("signature must verify with the public key")
	}
	payload, _ := b64.DecodeString(parts[1])
	if !strings.Contains(string(payload), `"iss":"web-cs"`) {
		t.Fatalf("payload = %s", payload)
	}
}
