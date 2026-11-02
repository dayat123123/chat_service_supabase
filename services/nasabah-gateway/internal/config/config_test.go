package config

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/pem"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func writeKey(t *testing.T, dir string) (string, ed25519.PrivateKey) {
	t.Helper()
	_, key, _ := ed25519.GenerateKey(rand.Reader)
	der, _ := x509.MarshalPKCS8PrivateKey(key)
	path := filepath.Join(dir, "csadmin_signing_key")
	_ = os.WriteFile(path, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}), 0o600)
	return path, key
}

func TestLoadReadsSecretsFromFiles(t *testing.T) {
	dir := t.TempDir()
	jwtFile := filepath.Join(dir, "jwt_secret")
	_ = os.WriteFile(jwtFile, []byte(strings.Repeat("s", 40)+"\n"), 0o600)
	keyFile, key := writeKey(t, dir)
	t.Setenv("JWT_SECRET_FILE", jwtFile)
	t.Setenv("CSADMIN_SIGNING_KEY_FILE", keyFile)
	t.Setenv("CSADMIN_URL", "http://csadmin:8080/csAdmin/")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(cfg.JWTSecret) != 40 || !key.Equal(cfg.CSAdminSigningKey) {
		t.Fatalf("secrets not loaded: %+v", cfg)
	}
	if cfg.CSAdminURL != "http://csadmin:8080/csAdmin" || cfg.CSAdminClientID != "web-cs" ||
		cfg.CSAdminTimeout != 15*time.Second || cfg.PostgRESTURL != "http://rest:3000" {
		t.Fatalf("cfg = %+v", cfg)
	}
}

func TestLoadRejectsUnsafeValues(t *testing.T) {
	dir := t.TempDir()
	badKey := filepath.Join(dir, "bad")
	_ = os.WriteFile(badKey, []byte("not a key"), 0o600)
	t.Setenv("JWT_SECRET", "short")
	t.Setenv("CSADMIN_URL", "ftp://csadmin")
	t.Setenv("CSADMIN_TIMEOUT", "2h")
	t.Setenv("CSADMIN_CLIENT_ID", "web cs'")
	t.Setenv("CSADMIN_SIGNING_KEY_FILE", badKey)

	_, err := Load()
	if err == nil {
		t.Fatal("expected errors")
	}
	for _, want := range []string{"JWT_SECRET", "CSADMIN_URL", "CSADMIN_TIMEOUT", "CSADMIN_CLIENT_ID", "CSADMIN_SIGNING_KEY"} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("error does not mention %s: %v", want, err)
		}
	}
}

func TestLoadAllowsAnUnconfiguredUpstream(t *testing.T) {
	dir := t.TempDir()
	empty := filepath.Join(dir, "csadmin_signing_key")
	_ = os.WriteFile(empty, nil, 0o600)
	t.Setenv("JWT_SECRET", strings.Repeat("s", 40))
	t.Setenv("CSADMIN_URL", "")
	t.Setenv("CSADMIN_SIGNING_KEY_FILE", empty)

	cfg, err := Load()
	if err != nil || cfg.CSAdminURL != "" || cfg.CSAdminSigningKey != nil {
		t.Fatalf("cfg = %+v, err = %v", cfg, err)
	}
}
