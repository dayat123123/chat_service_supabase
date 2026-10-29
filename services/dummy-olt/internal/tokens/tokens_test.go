package tokens

import (
	"errors"
	"strings"
	"testing"
	"time"
)

func TestIssueVerifyRevoke(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	iss := NewIssuer("rahasia-test")
	iss.now = func() time.Time { return now }

	token, exp, err := iss.Issue("1001", time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(token, Prefix) || !exp.Equal(now.Add(time.Hour)) {
		t.Fatalf("token=%s exp=%v", token, exp)
	}
	claims, err := iss.Verify(token)
	if err != nil || claims.UserID != "1001" {
		t.Fatalf("verify: %+v %v", claims, err)
	}

	if err := iss.Revoke(token); err != nil {
		t.Fatal(err)
	}
	if _, err := iss.Verify(token); !errors.Is(err, ErrRevoked) {
		t.Fatalf("token logout harus ditolak, err=%v", err)
	}
}

func TestVerifyRejectsExpiredTamperedForeign(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	iss := NewIssuer("rahasia-test")
	iss.now = func() time.Time { return now }

	expired, _, _ := iss.Issue("1001", -time.Minute)
	if _, err := iss.Verify(expired); !errors.Is(err, ErrExpired) {
		t.Errorf("expired: err=%v", err)
	}

	valid, _, _ := iss.Issue("1001", time.Hour)
	_, sig, _ := strings.Cut(strings.TrimPrefix(valid, Prefix), ".")
	forged := Prefix + b64.EncodeToString([]byte(`{"uid":"1006","iat":1,"exp":9999999999,"jti":"x"}`)) + "." + sig
	if _, err := iss.Verify(forged); !errors.Is(err, ErrSignature) {
		t.Errorf("payload diubah: err=%v", err)
	}

	other := NewIssuer("secret-lain")
	if _, err := other.Verify(valid); !errors.Is(err, ErrSignature) {
		t.Errorf("secret berbeda: err=%v", err)
	}

	for _, bad := range []string{"", "mock:1:a", "olt_", "olt_abc", "olt_!!.??"} {
		if _, err := iss.Verify(bad); err == nil {
			t.Errorf("token %q harus ditolak", bad)
		}
	}
}
