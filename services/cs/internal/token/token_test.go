package token

import (
	"encoding/base64"
	"errors"
	"strings"
	"testing"
	"time"
)

const secret = "rahasia-uji-minimal-tiga-puluh-dua-karakter"

func TestVerifyRoundTrip(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	tok, err := Sign(map[string]any{"sub": "u1", "aal": "aal2", "exp": now.Add(time.Minute).Unix()}, []byte(secret))
	if err != nil {
		t.Fatal(err)
	}
	claims, err := Verify(tok, []byte(secret), now)
	if err != nil {
		t.Fatal(err)
	}
	if claims["sub"] != "u1" || claims["aal"] != "aal2" {
		t.Fatalf("klaim salah: %v", claims)
	}
}

func TestVerifyRejects(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	valid, _ := Sign(map[string]any{"exp": now.Add(time.Minute).Unix()}, []byte(secret))
	expired, _ := Sign(map[string]any{"exp": now.Add(-time.Second).Unix()}, []byte(secret))
	noExp, _ := Sign(map[string]any{"sub": "u1"}, []byte(secret))
	parts := strings.Split(valid, ".")
	none := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"none"}`)) + "." + parts[1] + "." + parts[2]

	cases := map[string]struct {
		token string
		want  error
	}{
		"rahasia lain":  {valid, ErrSignature},
		"kedaluwarsa":   {expired, ErrExpired},
		"tanpa exp":     {noExp, ErrExpired},
		"alg none":      {none, ErrMalformed},
		"bukan JWT":     {"abc", ErrMalformed},
		"payload rusak": {parts[0] + ".%%%." + parts[2], ErrSignature},
	}
	for name, c := range cases {
		key := []byte(secret)
		if name == "rahasia lain" {
			key = []byte("rahasia-lain-yang-juga-cukup-panjang-sekali")
		}
		if _, err := Verify(c.token, key, now); !errors.Is(err, c.want) {
			t.Errorf("%s: dapat %v, ingin %v", name, err, c.want)
		}
	}
}

func TestServiceTokenCachedAndRefreshed(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	s := NewService(secret, "uji")
	s.now = func() time.Time { return now }
	first, err := s.Token()
	if err != nil {
		t.Fatal(err)
	}
	if second, _ := s.Token(); second != first {
		t.Fatal("token service harus dipakai ulang selama masih berlaku")
	}
	claims, err := Verify(first, []byte(secret), now)
	if err != nil || claims["role"] != "service_role" {
		t.Fatalf("token service tidak valid: %v %v", claims, err)
	}
	now = now.Add(55 * time.Second)
	if third, _ := s.Token(); third == first {
		t.Fatal("token service harus diperbarui sebelum kedaluwarsa")
	}
}
