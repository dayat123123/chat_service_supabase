package config

import (
	"log/slog"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"
)

var keys = []string{
	"PORT", "OPS_PORT", "LOG_LEVEL", "JWT_SECRET", "JWT_SECRET_FILE", "JWT_ISSUER", "POSTGREST_URL", "STORAGE_URL",
	"INSTANCE_ID", "MAX_CONCURRENT", "REQUEST_TIMEOUT", "HEARTBEAT_INTERVAL", "SHUTDOWN_TIMEOUT",
}

func clearEnv(t *testing.T) {
	t.Helper()
	for _, key := range keys {
		t.Setenv(key, "")
	}
}

func TestLoadUsesDefaults(t *testing.T) {
	clearEnv(t)
	t.Setenv("JWT_SECRET", strings.Repeat("s", 40))

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != 8080 || cfg.OpsPort != 9100 || cfg.LogLevel != slog.LevelInfo || cfg.JWTIssuer != "supabase" ||
		cfg.PostgRESTURL != "http://rest:3000" || cfg.StorageURL != "http://storage:5000" || cfg.MaxConcurrent != 8 ||
		cfg.RequestTimeout != 30*time.Second || cfg.HeartbeatInterval != 30*time.Second ||
		cfg.ShutdownTimeout != 20*time.Second || string(cfg.JWTSecret) != strings.Repeat("s", 40) {
		t.Fatalf("cfg = %+v", cfg)
	}
	host, _ := os.Hostname()
	if host == "" {
		host = "media"
	}
	if !regexp.MustCompile(`^` + regexp.QuoteMeta(host) + `-[0-9a-f]{6}$`).MatchString(cfg.InstanceID) {
		t.Fatalf("instance = %q", cfg.InstanceID)
	}
}

func TestLoadReadsOverridesAndSecretFiles(t *testing.T) {
	clearEnv(t)
	secret := filepath.Join(t.TempDir(), "jwt_secret")
	_ = os.WriteFile(secret, []byte(strings.Repeat("s", 40)+"\n"), 0o600)
	t.Setenv("JWT_SECRET_FILE", secret)
	t.Setenv("PORT", "8081")
	t.Setenv("OPS_PORT", "9200")
	t.Setenv("JWT_ISSUER", "olt")
	t.Setenv("POSTGREST_URL", "http://rest.local:3000/")
	t.Setenv("STORAGE_URL", "https://storage.local/storage/v1/")
	t.Setenv("INSTANCE_ID", "media-2")
	t.Setenv("MAX_CONCURRENT", "256")
	t.Setenv("REQUEST_TIMEOUT", "5m")
	t.Setenv("HEARTBEAT_INTERVAL", "5s")
	t.Setenv("SHUTDOWN_TIMEOUT", "1s")
	t.Setenv("LOG_LEVEL", "debug")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(cfg.JWTSecret) != 40 || cfg.Port != 8081 || cfg.OpsPort != 9200 || cfg.JWTIssuer != "olt" ||
		cfg.PostgRESTURL != "http://rest.local:3000" || cfg.StorageURL != "https://storage.local/storage/v1" ||
		cfg.InstanceID != "media-2" || cfg.MaxConcurrent != 256 || cfg.RequestTimeout != 5*time.Minute ||
		cfg.HeartbeatInterval != 5*time.Second || cfg.ShutdownTimeout != time.Second || cfg.LogLevel != slog.LevelDebug {
		t.Fatalf("cfg = %+v", cfg)
	}
}

func TestLoadRejectsInvalidValues(t *testing.T) {
	cases := map[string]struct {
		env  map[string]string
		want string
	}{
		"short secret":        {map[string]string{"JWT_SECRET": "short"}, "JWT_SECRET must be at least 32 characters"},
		"missing secret file": {map[string]string{"JWT_SECRET_FILE": "/nonexistent/jwt"}, "JWT_SECRET_FILE could not be read"},
		"same ports":          {map[string]string{"OPS_PORT": "8080"}, "PORT and OPS_PORT must differ"},
		"bad port":            {map[string]string{"PORT": "70000"}, "PORT must be a port number"},
		"bad ops port":        {map[string]string{"OPS_PORT": "x"}, "OPS_PORT must be a whole number"},
		"bad url":             {map[string]string{"STORAGE_URL": "storage:5000"}, "STORAGE_URL must be an http(s) URL"},
		"bad postgrest":       {map[string]string{"POSTGREST_URL": "ftp://rest"}, "POSTGREST_URL must be an http(s) URL"},
		"concurrency":         {map[string]string{"MAX_CONCURRENT": "0"}, "MAX_CONCURRENT must be between 1 and 256"},
		"request timeout":     {map[string]string{"REQUEST_TIMEOUT": "1s"}, "REQUEST_TIMEOUT must be between 5s and 5m"},
		"heartbeat":           {map[string]string{"HEARTBEAT_INTERVAL": "2m"}, "HEARTBEAT_INTERVAL must be between 5s and 60s"},
		"shutdown":            {map[string]string{"SHUTDOWN_TIMEOUT": "abc"}, "SHUTDOWN_TIMEOUT must be a duration"},
		"log level":           {map[string]string{"LOG_LEVEL": "loud"}, "LOG_LEVEL"},
		"instance":            {map[string]string{"INSTANCE_ID": strings.Repeat("i", 101)}, "INSTANCE_ID must be at most 100 characters"},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			clearEnv(t)
			t.Setenv("JWT_SECRET", strings.Repeat("s", 40))
			for key, value := range tc.env {
				t.Setenv(key, value)
			}
			_, err := Load()
			if err == nil || !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("err = %v, want %q", err, tc.want)
			}
		})
	}
}
