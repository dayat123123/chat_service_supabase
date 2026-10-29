package token

import (
	"strings"
	"testing"
	"time"
)

const secret = "test-secret-yang-panjangnya-lebih-dari-32-karakter"

func TestUserTokenClaims(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	iss := NewIssuer(secret, 15*time.Minute, "olt-auth-bridge")
	iss.now = func() time.Time { return now }

	tok, exp, err := iss.UserToken(User{ID: "uuid-1", OLTUserID: "1001", Username: "budi", Email: "b@x.id"})
	if err != nil {
		t.Fatal(err)
	}
	if !exp.Equal(now.Add(15 * time.Minute)) {
		t.Fatalf("exp = %v", exp)
	}

	claims, err := Verify(tok, []byte(secret), now)
	if err != nil {
		t.Fatal(err)
	}
	for key, want := range map[string]any{
		"sub": "uuid-1", "role": "authenticated", "aud": "authenticated",
		"iss": "olt-auth-bridge", "email": "b@x.id",
	} {
		if claims[key] != want {
			t.Errorf("claim %s = %v, want %v", key, claims[key], want)
		}
	}
	if claims["exp"].(float64) != float64(now.Add(15*time.Minute).Unix()) {
		t.Errorf("claim exp salah: %v", claims["exp"])
	}
	meta := claims["app_metadata"].(map[string]any)
	if meta["olt_user_id"] != "1001" {
		t.Errorf("app_metadata.olt_user_id = %v", meta["olt_user_id"])
	}
}

func TestVerifyRejectsTamperingAndExpiry(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	tok, err := Sign(map[string]any{"sub": "a", "exp": now.Add(time.Minute).Unix()}, []byte(secret))
	if err != nil {
		t.Fatal(err)
	}

	if _, err := Verify(tok, []byte("secret-lain-yang-juga-panjang-sekali-ya"), now); err == nil {
		t.Error("secret berbeda harus ditolak")
	}
	parts := strings.Split(tok, ".")
	forged := parts[0] + "." + b64.EncodeToString([]byte(`{"sub":"admin","exp":9999999999}`)) + "." + parts[2]
	if _, err := Verify(forged, []byte(secret), now); err == nil {
		t.Error("payload yang diubah harus ditolak")
	}
	if _, err := Verify(tok, []byte(secret), now.Add(2*time.Minute)); err == nil {
		t.Error("token kedaluwarsa harus ditolak")
	}
}

func TestServiceTokenCachedAndRefreshed(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	iss := NewIssuer(secret, time.Minute, "olt-auth-bridge")
	iss.now = func() time.Time { return now }

	first, err := iss.ServiceToken()
	if err != nil {
		t.Fatal(err)
	}
	claims, err := Verify(first, []byte(secret), now)
	if err != nil || claims["role"] != "service_role" {
		t.Fatalf("service token tidak valid: %v %v", claims, err)
	}

	now = now.Add(30 * time.Second)
	if again, _ := iss.ServiceToken(); again != first {
		t.Error("token masih berlaku harus dipakai ulang")
	}
	now = now.Add(25 * time.Second) // sisa < 10 detik
	if renewed, _ := iss.ServiceToken(); renewed == first {
		t.Error("token hampir kedaluwarsa harus diperbarui")
	}
}
