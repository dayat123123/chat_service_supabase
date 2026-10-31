package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestLoadReadsSecretsFromFiles(t *testing.T) {
	dir := t.TempDir()
	jwtFile := filepath.Join(dir, "jwt_secret")
	passwordFile := filepath.Join(dir, "csadmin_password")
	_ = os.WriteFile(jwtFile, []byte(strings.Repeat("s", 40)+"\n"), 0o600)
	_ = os.WriteFile(passwordFile, []byte("pw\n"), 0o600)
	t.Setenv("JWT_SECRET_FILE", jwtFile)
	t.Setenv("CSADMIN_PASSWORD_FILE", passwordFile)
	t.Setenv("CSADMIN_URL", "http://csadmin:8080/csAdmin/")
	t.Setenv("CSADMIN_USERNAME", "svc")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.CSAdminPassword != "pw" || len(cfg.JWTSecret) != 40 || cfg.CSAdminUsername != "svc" {
		t.Fatalf("secrets not loaded: %+v", cfg)
	}
	if cfg.CSAdminURL != "http://csadmin:8080/csAdmin" || cfg.CSAdminTimeout != 15*time.Second || cfg.CSAdminActor != "agent" || cfg.PostgRESTURL != "http://rest:3000" {
		t.Fatalf("cfg = %+v", cfg)
	}
}

func TestLoadRejectsUnsafeValues(t *testing.T) {
	t.Setenv("JWT_SECRET", "short")
	t.Setenv("CSADMIN_URL", "ftp://csadmin")
	t.Setenv("CSADMIN_TIMEOUT", "2h")
	t.Setenv("CSADMIN_ACTOR", "nobody")

	_, err := Load()
	if err == nil {
		t.Fatal("expected errors")
	}
	for _, want := range []string{"JWT_SECRET", "CSADMIN_URL", "CSADMIN_TIMEOUT", "CSADMIN_ACTOR"} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("error does not mention %s: %v", want, err)
		}
	}
}

func TestLoadAllowsAnUnconfiguredUpstream(t *testing.T) {
	t.Setenv("JWT_SECRET", strings.Repeat("s", 40))
	t.Setenv("CSADMIN_URL", "")

	cfg, err := Load()
	if err != nil || cfg.CSAdminURL != "" {
		t.Fatalf("cfg = %+v, err = %v", cfg, err)
	}
}
