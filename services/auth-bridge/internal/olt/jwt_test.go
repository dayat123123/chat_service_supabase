package olt

import (
	"context"
	"crypto/ecdsa"
	"crypto/ed25519"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"math/big"
	"strings"
	"testing"
	"time"
)

var testNow = time.Date(2026, 10, 31, 10, 0, 0, 0, time.UTC)

type testKeys struct {
	edKID string
	ed    ed25519.PrivateKey
	ecKID string
	ec    *ecdsa.PrivateKey
}

func newTestKeys(t *testing.T) testKeys {
	t.Helper()
	_, ed, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	ec, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	return testKeys{edKID: "olt-2026-10", ed: ed, ecKID: "olt-ec-1", ec: ec}
}

func b64url(b []byte) string { return base64.RawURLEncoding.EncodeToString(b) }

func (k testKeys) jwks(t *testing.T) []byte {
	t.Helper()
	pad := func(n *big.Int) []byte {
		out := make([]byte, 32)
		n.FillBytes(out)
		return out
	}
	doc := map[string]any{"keys": []map[string]any{
		{"kty": "OKP", "crv": "Ed25519", "kid": k.edKID, "alg": "EdDSA", "use": "sig",
			"x": b64url(k.ed.Public().(ed25519.PublicKey))},
		{"kty": "EC", "crv": "P-256", "kid": k.ecKID, "alg": "ES256", "use": "sig",
			"x": b64url(pad(k.ec.X)), "y": b64url(pad(k.ec.Y))},
	}}
	b, err := json.Marshal(doc)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func validClaims() map[string]any {
	return map[string]any{
		"iss":                "olt",
		"aud":                "olt-social",
		"sub":                "1001",
		"preferred_username": "budi_santoso",
		"name":               "Budi Santoso",
		"email":              "budi@olt.test",
		"iat":                testNow.Add(-time.Minute).Unix(),
		"exp":                testNow.Add(9 * time.Minute).Unix(),
	}
}

func sign(t *testing.T, header, claims map[string]any, signer func(input []byte) []byte) string {
	t.Helper()
	h, _ := json.Marshal(header)
	c, _ := json.Marshal(claims)
	input := b64url(h) + "." + b64url(c)
	return input + "." + b64url(signer([]byte(input)))
}

func (k testKeys) edToken(t *testing.T, claims map[string]any) string {
	return sign(t, map[string]any{"alg": "EdDSA", "typ": "JWT", "kid": k.edKID}, claims, func(in []byte) []byte {
		return ed25519.Sign(k.ed, in)
	})
}

func (k testKeys) ecToken(t *testing.T, claims map[string]any) string {
	return sign(t, map[string]any{"alg": "ES256", "typ": "JWT", "kid": k.ecKID}, claims, func(in []byte) []byte {
		digest := sha256.Sum256(in)
		r, s, err := ecdsa.Sign(rand.Reader, k.ec, digest[:])
		if err != nil {
			t.Fatal(err)
		}
		out := make([]byte, 64)
		r.FillBytes(out[:32])
		s.FillBytes(out[32:])
		return out
	})
}

func newTestVerifier(t *testing.T, k testKeys) *JWTVerifier {
	t.Helper()
	v, err := NewJWTVerifier(k.jwks(t), JWTOptions{
		Issuer:   "olt",
		Audience: "olt-social",
		MaxTTL:   15 * time.Minute,
		Leeway:   30 * time.Second,
	})
	if err != nil {
		t.Fatal(err)
	}
	v.now = func() time.Time { return testNow }
	return v
}

func with(claims map[string]any, key string, value any) map[string]any {
	out := map[string]any{}
	for k, v := range claims {
		out[k] = v
	}
	if value == nil {
		delete(out, key)
	} else {
		out[key] = value
	}
	return out
}

func TestJWTVerifierAcceptsEdDSATokensSignedByOLT(t *testing.T) {
	k := newTestKeys(t)
	u, err := newTestVerifier(t, k).Verify(context.Background(), k.edToken(t, validClaims()))
	if err != nil {
		t.Fatal(err)
	}
	want := User{ID: "1001", Username: "budi_santoso", Email: "budi@olt.test", DisplayName: "Budi Santoso"}
	if u != want {
		t.Fatalf("user = %+v, want %+v", u, want)
	}
}

func TestJWTVerifierListsKeyIDsAndAlgorithmsOnly(t *testing.T) {
	got := newTestVerifier(t, newTestKeys(t)).Keys()
	want := []KeyInfo{{Kid: "olt-2026-10", Alg: "EdDSA"}, {Kid: "olt-ec-1", Alg: "ES256"}}
	if len(got) != len(want) || got[0] != want[0] || got[1] != want[1] {
		t.Fatalf("keys = %+v, want %+v", got, want)
	}
}

func TestJWTVerifierAcceptsES256Tokens(t *testing.T) {
	k := newTestKeys(t)
	u, err := newTestVerifier(t, k).Verify(context.Background(), k.ecToken(t, validClaims()))
	if err != nil {
		t.Fatal(err)
	}
	if u.ID != "1001" {
		t.Fatalf("user = %+v", u)
	}
}

func TestJWTVerifierAcceptsAnAudienceList(t *testing.T) {
	k := newTestKeys(t)
	token := k.edToken(t, with(validClaims(), "aud", []string{"olt-trading", "olt-social"}))
	if _, err := newTestVerifier(t, k).Verify(context.Background(), token); err != nil {
		t.Fatal(err)
	}
}

func TestJWTVerifierToleratesSmallClockSkew(t *testing.T) {
	k := newTestKeys(t)
	claims := with(validClaims(), "exp", testNow.Add(-20*time.Second).Unix())
	claims = with(claims, "iat", testNow.Add(-5*time.Minute).Unix())
	if _, err := newTestVerifier(t, k).Verify(context.Background(), k.edToken(t, claims)); err != nil {
		t.Fatal(err)
	}
}

func TestJWTVerifierRejectsInvalidTokens(t *testing.T) {
	k := newTestKeys(t)
	v := newTestVerifier(t, k)
	other := newTestKeys(t)
	good := k.edToken(t, validClaims())
	parts := strings.Split(good, ".")
	tamperedClaims, _ := json.Marshal(with(validClaims(), "sub", "1002"))

	cases := map[string]string{
		"kosong":                  "",
		"bukan JWT":               "olt_abc.def",
		"payload diubah":          parts[0] + "." + b64url(tamperedClaims) + "." + parts[2],
		"kunci lain":              other.edToken(t, validClaims()),
		"kedaluwarsa":             k.edToken(t, with(with(validClaims(), "exp", testNow.Add(-time.Minute).Unix()), "iat", testNow.Add(-5*time.Minute).Unix())),
		"tanpa exp":               k.edToken(t, with(validClaims(), "exp", nil)),
		"tanpa iat":               k.edToken(t, with(validClaims(), "iat", nil)),
		"iat di masa depan":       k.edToken(t, with(validClaims(), "iat", testNow.Add(5*time.Minute).Unix())),
		"nbf di masa depan":       k.edToken(t, with(validClaims(), "nbf", testNow.Add(5*time.Minute).Unix())),
		"umur melebihi batas":     k.edToken(t, with(with(validClaims(), "iat", testNow.Unix()), "exp", testNow.Add(2*time.Hour).Unix())),
		"issuer lain":             k.edToken(t, with(validClaims(), "iss", "evil")),
		"audience lain":           k.edToken(t, with(validClaims(), "aud", "olt-trading")),
		"tanpa sub":               k.edToken(t, with(validClaims(), "sub", nil)),
		"sub bukan string":        k.edToken(t, with(validClaims(), "sub", 1001)),
		"tanpa username":          k.edToken(t, with(validClaims(), "preferred_username", nil)),
		"alg none":                sign(t, map[string]any{"alg": "none", "kid": k.edKID}, validClaims(), func([]byte) []byte { return nil }),
		"alg HS256":               sign(t, map[string]any{"alg": "HS256", "kid": k.edKID}, validClaims(), func([]byte) []byte { return []byte("x") }),
		"alg tidak cocok kunci":   sign(t, map[string]any{"alg": "ES256", "kid": k.edKID}, validClaims(), func(in []byte) []byte { return ed25519.Sign(k.ed, in) }),
		"kid tidak dikenal":       sign(t, map[string]any{"alg": "EdDSA", "kid": "nope"}, validClaims(), func(in []byte) []byte { return ed25519.Sign(k.ed, in) }),
		"tanpa kid, banyak kunci": sign(t, map[string]any{"alg": "EdDSA"}, validClaims(), func(in []byte) []byte { return ed25519.Sign(k.ed, in) }),
		"terlalu panjang":         strings.Repeat("a", 17000),
	}
	for name, token := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := v.Verify(context.Background(), token); !errors.Is(err, ErrInvalidToken) {
				t.Fatalf("err = %v, want ErrInvalidToken", err)
			}
		})
	}
}

func TestJWTVerifierUsesTheOnlyKeyWhenKidIsMissing(t *testing.T) {
	_, ed, _ := ed25519.GenerateKey(rand.Reader)
	jwks, _ := json.Marshal(map[string]any{"keys": []map[string]any{
		{"kty": "OKP", "crv": "Ed25519", "kid": "olt-1", "x": b64url(ed.Public().(ed25519.PublicKey))},
	}})
	v, err := NewJWTVerifier(jwks, JWTOptions{Issuer: "olt", Audience: "olt-social", MaxTTL: 15 * time.Minute})
	if err != nil {
		t.Fatal(err)
	}
	v.now = func() time.Time { return testNow }
	token := sign(t, map[string]any{"alg": "EdDSA"}, validClaims(), func(in []byte) []byte { return ed25519.Sign(ed, in) })
	if _, err := v.Verify(context.Background(), token); err != nil {
		t.Fatal(err)
	}
}

func TestNewJWTVerifierRejectsUnusableKeySets(t *testing.T) {
	k := newTestKeys(t)
	devJWKS := strings.Replace(string(k.jwks(t)), k.edKID, "dev-olt-1", 1)
	cases := map[string]struct {
		jwks []byte
		opts JWTOptions
	}{
		"bukan JSON":             {[]byte("{"), JWTOptions{}},
		"tanpa kunci":            {[]byte(`{"keys":[]}`), JWTOptions{}},
		"kty tidak didukung":     {[]byte(`{"keys":[{"kty":"RSA","kid":"r","n":"AQ","e":"AQAB"}]}`), JWTOptions{}},
		"kunci Ed25519 rusak":    {[]byte(`{"keys":[{"kty":"OKP","crv":"Ed25519","kid":"a","x":"AQ"}]}`), JWTOptions{}},
		"kunci EC di luar kurva": {[]byte(`{"keys":[{"kty":"EC","crv":"P-256","kid":"a","x":"` + b64url(make([]byte, 32)) + `","y":"` + b64url(make([]byte, 32)) + `"}]}`), JWTOptions{}},
		"kid ganda":              {[]byte(strings.Replace(string(k.jwks(t)), k.ecKID, k.edKID, 1)), JWTOptions{}},
		"kunci dev di produksi":  {[]byte(devJWKS), JWTOptions{RejectDevKeys: true}},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			tc.opts.Issuer, tc.opts.Audience, tc.opts.MaxTTL = "olt", "olt-social", 15*time.Minute
			if _, err := NewJWTVerifier(tc.jwks, tc.opts); err == nil {
				t.Fatal("harus ditolak")
			}
		})
	}
	if _, err := NewJWTVerifier([]byte(devJWKS), JWTOptions{Issuer: "olt", Audience: "olt-social", MaxTTL: time.Minute}); err != nil {
		t.Fatalf("kunci dev boleh di luar produksi: %v", err)
	}
}

func TestJWTVerifierRejectsNonCanonicalBase64(t *testing.T) {
	k := newTestKeys(t)
	token := k.edToken(t, validClaims())
	const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
	idx := strings.IndexByte(alphabet, token[len(token)-1])
	alt := alphabet[(idx&^0x0F)|((idx+1)&0x0F)]
	malleable := token[:len(token)-1] + string(alt)
	if _, err := newTestVerifier(t, k).Verify(context.Background(), malleable); !errors.Is(err, ErrInvalidToken) {
		t.Fatalf("tanda tangan dengan bit sisa berbeda harus ditolak, err = %v", err)
	}
}
