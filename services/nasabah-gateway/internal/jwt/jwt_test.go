package jwt

import (
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
