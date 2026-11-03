package config

import (
	"net/netip"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

const secret = "an-integration-test-secret-of-32-chars-or-more"

func TestLoadDefaults(t *testing.T) {
	t.Setenv("JWT_SECRET", secret)
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != 8080 || cfg.OpsPort != 9100 || cfg.PostgRESTURL != "http://rest:3000" || cfg.JWTIssuer != "supabase" {
		t.Fatalf("cfg = %+v", cfg)
	}
	if cfg.MaxBodyBytes != 2<<20 || cfg.KeyCacheTTL != 30*time.Second || cfg.MaxConcurrent != 8 || cfg.AuthFailuresPerMinute != 30 {
		t.Fatalf("limits = %+v", cfg)
	}
	if len(cfg.TrustedProxies) != 6 || !cfg.TrustedProxies[2].Contains(netip.MustParseAddr("10.1.2.3")) {
		t.Fatalf("trusted proxies = %v", cfg.TrustedProxies)
	}
	if cfg.InstanceID == "" {
		t.Fatal("instance id kosong")
	}
}

func TestLoadReadsSecretFromFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "jwt_secret")
	if err := os.WriteFile(path, []byte(secret+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("JWT_SECRET_FILE", path)
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if string(cfg.JWTSecret) != secret {
		t.Fatal("secret dari file tidak terbaca")
	}
}

func TestLoadRejectsInvalidValues(t *testing.T) {
	t.Setenv("JWT_SECRET", "short")
	t.Setenv("PORT", "9100")
	t.Setenv("MAX_BODY_BYTES", "10")
	t.Setenv("KEY_CACHE_TTL", "1h")
	t.Setenv("TRUSTED_PROXIES", "not-a-cidr")
	t.Setenv("POSTGREST_URL", "ftp://rest")
	_, err := Load()
	if err == nil {
		t.Fatal("konfigurasi salah harus ditolak")
	}
	for _, want := range []string{"JWT_SECRET", "PORT and OPS_PORT", "MAX_BODY_BYTES", "KEY_CACHE_TTL", "TRUSTED_PROXIES", "POSTGREST_URL"} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("error tidak menyebut %s: %v", want, err)
		}
	}
	if strings.Contains(err.Error(), "short") {
		t.Fatal("isi secret tidak boleh muncul di error")
	}
}
