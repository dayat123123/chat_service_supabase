package social

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"reflect"
	"strings"
	"testing"
	"time"
)

var now = time.Date(2026, 10, 31, 10, 0, 0, 0, time.UTC)

func newSigner(t *testing.T) (*Signer, ed25519.PublicKey) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	s := NewSigner(priv, "dev-olt-1", "olt", "olt-social")
	s.now = func() time.Time { return now }
	return s, pub
}

func decode(t *testing.T, segment string, out any) {
	t.Helper()
	raw, err := base64.RawURLEncoding.DecodeString(segment)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(raw, out); err != nil {
		t.Fatal(err)
	}
}

func TestSignIssuesAnEdDSATokenForOLTSocial(t *testing.T) {
	s, pub := newSigner(t)
	token, exp, err := s.Sign(Identity{ID: "1001", Username: "budi_santoso", Name: "Budi Santoso", Email: "budi@olt.test"}, 10*time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	if !exp.Equal(now.Add(10 * time.Minute)) {
		t.Fatalf("exp = %v", exp)
	}
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Fatalf("token = %q", token)
	}
	sig, _ := base64.RawURLEncoding.DecodeString(parts[2])
	if !ed25519.Verify(pub, []byte(parts[0]+"."+parts[1]), sig) {
		t.Fatal("tanda tangan tidak cocok dengan kunci publik")
	}

	var header map[string]any
	decode(t, parts[0], &header)
	if header["alg"] != "EdDSA" || header["kid"] != "dev-olt-1" || header["typ"] != "JWT" {
		t.Fatalf("header = %v", header)
	}
	var claims map[string]any
	decode(t, parts[1], &claims)
	want := map[string]any{
		"iss": "olt", "aud": "olt-social", "sub": "1001", "preferred_username": "budi_santoso",
		"name": "Budi Santoso", "email": "budi@olt.test",
		"iat": float64(now.Unix()), "exp": float64(now.Add(10 * time.Minute).Unix()),
	}
	for k, v := range want {
		if claims[k] != v {
			t.Errorf("claim %s = %v, want %v", k, claims[k], v)
		}
	}
	if id, _ := claims["jti"].(string); len(id) < 16 {
		t.Errorf("jti = %v", claims["jti"])
	}
}

func TestSignCanIssueAlreadyExpiredTokensForTests(t *testing.T) {
	s, _ := newSigner(t)
	token, _, err := s.Sign(Identity{ID: "1001", Username: "budi_santoso"}, -time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	var claims map[string]any
	decode(t, strings.Split(token, ".")[1], &claims)
	if claims["exp"].(float64) >= float64(now.Unix()) {
		t.Fatalf("exp = %v harus sudah lewat", claims["exp"])
	}
	if claims["iat"].(float64) >= claims["exp"].(float64) {
		t.Fatalf("iat = %v harus sebelum exp", claims["iat"])
	}
}

func TestSignForAudienceOverridesTheAudience(t *testing.T) {
	s, _ := newSigner(t)
	token, _, err := s.SignFor(Identity{ID: "1001", Username: "budi_santoso"}, time.Minute, "olt-trading")
	if err != nil {
		t.Fatal(err)
	}
	var claims map[string]any
	decode(t, strings.Split(token, ".")[1], &claims)
	if claims["aud"] != "olt-trading" {
		t.Fatalf("aud = %v", claims["aud"])
	}
}

func TestParsePrivateKeyReadsOpenSSLEd25519Keys(t *testing.T) {
	_, priv, _ := ed25519.GenerateKey(rand.Reader)
	der, err := x509.MarshalPKCS8PrivateKey(priv)
	if err != nil {
		t.Fatal(err)
	}
	pemBytes := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})
	got, err := ParsePrivateKey(pemBytes)
	if err != nil {
		t.Fatal(err)
	}
	if !got.Equal(priv) {
		t.Fatal("kunci tidak sama")
	}
	if _, err := ParsePrivateKey([]byte("bukan pem")); err == nil {
		t.Fatal("PEM rusak harus ditolak")
	}
}

func TestSignIncludesAccountsOnlyWhenKnown(t *testing.T) {
	s, _ := newSigner(t)
	cases := map[string]struct {
		accounts []string
		want     any
	}{
		"rekening nasabah": {[]string{"W137", "C1626"}, []any{"W137", "C1626"}},
		"bukan nasabah":    {[]string{}, []any{}},
		"tidak diketahui":  {nil, nil},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			token, _, err := s.Sign(Identity{ID: "1001", Username: "budi_santoso", Accounts: tc.accounts}, time.Minute)
			if err != nil {
				t.Fatal(err)
			}
			var claims map[string]any
			decode(t, strings.Split(token, ".")[1], &claims)
			got, present := claims["accounts"]
			if tc.want == nil {
				if present {
					t.Fatalf("klaim accounts harus tidak ada, claims = %v", claims)
				}
				return
			}
			if !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("accounts = %#v, want %#v", got, tc.want)
			}
		})
	}
}
