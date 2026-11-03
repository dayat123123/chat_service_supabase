package jwt

import (
	"encoding/json"
	"errors"
	"reflect"
	"strings"
	"testing"
	"time"
)

var secret = []byte(strings.Repeat("k", 40))

const sub = "0b7c2d4e-1f2a-4b3c-8d9e-0a1b2c3d4e5f"

func claims(now time.Time) map[string]any {
	return map[string]any{
		"iss": "olt-auth-bridge", "sub": sub, "aud": "authenticated", "role": "authenticated",
		"iat": now.Unix(), "exp": now.Add(time.Hour).Unix(),
		"app_metadata": map[string]any{"provider": "olt"},
	}
}

func sign(t *testing.T, header, c map[string]any, key []byte) string {
	t.Helper()
	token, err := Sign(header, c, key)
	if err != nil {
		t.Fatal(err)
	}
	return token
}

func payload(t *testing.T, token string) map[string]any {
	t.Helper()
	parts := strings.Split(token, ".")
	raw, err := b64.DecodeString(parts[1])
	if err != nil {
		t.Fatal(err)
	}
	var out map[string]any
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatal(err)
	}
	return out
}

func TestVerifyUserAcceptsAnAuthenticatedToken(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	user, err := VerifyUser(sign(t, map[string]any{"alg": "HS256", "typ": "JWT"}, claims(now), secret), secret, now, 30*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	if user.Subject != sub || user.Expires != now.Add(time.Hour).Unix() || user.Claims["aud"] != "authenticated" {
		t.Fatalf("user = %+v", user)
	}
}

func TestVerifyUserRejects(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	hs := map[string]any{"alg": "HS256", "typ": "JWT"}
	with := func(key string, value any) map[string]any {
		c := claims(now)
		if value == nil {
			delete(c, key)
		} else {
			c[key] = value
		}
		return c
	}
	valid := sign(t, hs, claims(now), secret)
	cases := map[string]string{
		"empty":            "",
		"two parts":        "a.b",
		"garbage":          "a.b.c",
		"wrong secret":     sign(t, hs, claims(now), []byte(strings.Repeat("x", 40))),
		"alg none":         sign(t, map[string]any{"alg": "none"}, claims(now), secret),
		"alg HS512 header": sign(t, map[string]any{"alg": "HS512"}, claims(now), secret),
		"tampered payload": strings.Split(valid, ".")[0] + "." + b64.EncodeToString([]byte(`{"role":"authenticated"}`)) + "." + strings.Split(valid, ".")[2],
		"role anon":        sign(t, hs, with("role", "anon"), secret),
		"role service":     sign(t, hs, with("role", "service_role"), secret),
		"role missing":     sign(t, hs, with("role", nil), secret),
		"sub not uuid":     sign(t, hs, with("sub", "uuid-1001"), secret),
		"sub missing":      sign(t, hs, with("sub", nil), secret),
		"exp missing":      sign(t, hs, with("exp", nil), secret),
		"exp string":       sign(t, hs, with("exp", "1800000000"), secret),
		"expired":          sign(t, hs, with("exp", now.Add(-31*time.Second).Unix()), secret),
		"expired exactly":  sign(t, hs, with("exp", now.Add(-30*time.Second).Unix()), secret),
		"exp absurd":       sign(t, hs, with("exp", 1e300), secret),
		"nbf future":       sign(t, hs, with("nbf", now.Add(time.Minute).Unix()), secret),
		"too long":         strings.Repeat("a", maxTokenLength+1),
	}
	for name, token := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := VerifyUser(token, secret, now, 30*time.Second); !errors.Is(err, ErrInvalid) {
				t.Fatalf("err = %v", err)
			}
		})
	}
}

func TestVerifyUserAllowsThirtySecondsOfClockSkew(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	c := claims(now)
	c["exp"] = now.Add(-29 * time.Second).Unix()
	c["nbf"] = now.Add(29 * time.Second).Unix()
	if _, err := VerifyUser(sign(t, map[string]any{"alg": "HS256"}, c, secret), secret, now, 30*time.Second); err != nil {
		t.Fatal(err)
	}
}

func TestVerifiedCopiesClaimsAndShortensExpiry(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	cases := map[string]struct {
		exp  int64
		want int64
	}{
		"long-lived token": {now.Add(time.Hour).Unix(), now.Add(120 * time.Second).Unix()},
		"short-lived":      {now.Add(time.Minute).Unix(), now.Add(time.Minute).Unix()},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			c := claims(now.Add(-time.Minute))
			c["exp"] = tc.exp
			user, err := VerifyUser(sign(t, map[string]any{"alg": "HS256", "typ": "JWT"}, c, secret), secret, now, 30*time.Second)
			if err != nil {
				t.Fatal(err)
			}
			token, err := Verified(user, secret, now, 120*time.Second)
			if err != nil {
				t.Fatal(err)
			}
			again, err := VerifyUser(token, secret, now, 0)
			if err != nil {
				t.Fatal(err)
			}
			got := payload(t, token)
			want := map[string]any{
				"iss": "olt-auth-bridge", "sub": sub, "aud": "authenticated", "role": "authenticated",
				"iat": float64(now.Unix()), "exp": float64(tc.want), "media_verified": true,
				"app_metadata": map[string]any{"provider": "olt"},
			}
			if !reflect.DeepEqual(got, want) || again.Expires != tc.want {
				t.Fatalf("claims = %v\nwant %v", got, want)
			}
			if _, present := user.Claims["media_verified"]; present {
				t.Fatal("original claims were modified")
			}
		})
	}
}

func TestServiceRoleIssuesAOneMinuteServiceToken(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	token, err := ServiceRole(secret, "supabase", now)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := VerifyUser(token, secret, now, 0); !errors.Is(err, ErrInvalid) {
		t.Fatal("a service token must never pass user verification")
	}
	want := map[string]any{"iss": "supabase", "role": "service_role", "iat": float64(1_800_000_000), "exp": float64(1_800_000_060)}
	if got := payload(t, token); !reflect.DeepEqual(got, want) {
		t.Fatalf("claims = %v", got)
	}
}
