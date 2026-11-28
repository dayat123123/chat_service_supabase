package config

import (
	"os"
	"strings"
	"testing"
	"time"
)

func TestDefaults(t *testing.T) {
	t.Setenv("JWT_SECRET", strings.Repeat("s", 32))
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != 8080 || cfg.OpsPort != 9100 || cfg.StorageURL != "http://storage:5000" || cfg.ConfigTTL != 30*time.Second ||
		cfg.ImageWidth != 1200 || cfg.MaxImageBytes != 5<<20 {
		t.Fatalf("cfg = %+v", cfg)
	}
}

func TestInvalidValuesAreReported(t *testing.T) {
	t.Setenv("JWT_SECRET", "short")
	t.Setenv("PORT", "9100")
	t.Setenv("IMAGE_WIDTH", "50")
	t.Setenv("STORAGE_URL", "ftp://storage")
	_, err := Load()
	if err == nil {
		t.Fatal("expected an error")
	}
	for _, want := range []string{"JWT_SECRET", "PORT and OPS_PORT", "IMAGE_WIDTH", "STORAGE_URL"} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("error is missing %q: %v", want, err)
		}
	}
}

func TestSecretFromFile(t *testing.T) {
	path := t.TempDir() + "/secret"
	if err := os.WriteFile(path, []byte(strings.Repeat("f", 40)+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("JWT_SECRET_FILE", path)
	cfg, err := Load()
	if err != nil || string(cfg.JWTSecret) != strings.Repeat("f", 40) {
		t.Fatalf("cfg = %+v err = %v", cfg, err)
	}
}
