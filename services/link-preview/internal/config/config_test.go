package config

import (
	"log/slog"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

var keys = []string{
	"PORT", "LOG_LEVEL", "JWT_SECRET", "JWT_SECRET_FILE", "JWT_ISSUER", "POSTGREST_URL", "STORAGE_URL", "INSTANCE_ID",
	"USER_AGENT", "BATCH_SIZE", "CONCURRENCY", "LEASE", "POLL_INTERVAL", "FETCH_TIMEOUT", "REQUEST_TIMEOUT",
	"HEARTBEAT_INTERVAL", "SHUTDOWN_TIMEOUT", "MAX_HTML_BYTES", "MAX_IMAGE_BYTES",
	"CLASSIFIER_URL", "CLASSIFIER_TIMEOUT", "MODERATION_REFRESH",
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
	host, _ := os.Hostname()
	if !strings.HasPrefix(cfg.InstanceID, host+"-") || len(cfg.InstanceID) != len(host)+7 {
		t.Fatalf("instance = %q", cfg.InstanceID)
	}
	cfg.InstanceID = ""
	want := Config{
		Port:              8080,
		LogLevel:          slog.LevelInfo,
		JWTSecret:         []byte(strings.Repeat("s", 40)),
		JWTIssuer:         "supabase",
		PostgRESTURL:      "http://rest:3000",
		StorageURL:        "http://storage:5000",
		UserAgent:         DefaultUserAgent,
		BatchSize:         8,
		Concurrency:       4,
		Lease:             2 * time.Minute,
		PollInterval:      5 * time.Second,
		FetchTimeout:      5 * time.Second,
		RequestTimeout:    15 * time.Second,
		HeartbeatInterval: 30 * time.Second,
		ShutdownTimeout:   20 * time.Second,
		MaxHTMLBytes:      1 << 20,
		MaxImageBytes:     5 << 20,
		ClassifierURL:     "http://classifier:8080",
		ClassifierTimeout: 10 * time.Second,
		ModerationRefresh: 30 * time.Second,
	}
	if string(cfg.JWTSecret) != string(want.JWTSecret) {
		t.Fatal("secret not loaded")
	}
	cfg.JWTSecret, want.JWTSecret = nil, nil
	if !reflect.DeepEqual(cfg, want) {
		t.Fatalf("cfg = %+v\nwant %+v", cfg, want)
	}
}

func TestLoadReadsOverridesAndSecretFiles(t *testing.T) {
	clearEnv(t)
	secret := filepath.Join(t.TempDir(), "jwt_secret")
	_ = os.WriteFile(secret, []byte(strings.Repeat("k", 40)+"\n"), 0o600)
	t.Setenv("JWT_SECRET_FILE", secret)
	t.Setenv("USER_AGENT", "OLTSocialLinkPreview/1.0 (+https://olt.example/bot)")
	t.Setenv("FETCH_TIMEOUT", "3s")
	t.Setenv("MAX_HTML_BYTES", "524288")
	t.Setenv("INSTANCE_ID", "lp-1")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if string(cfg.JWTSecret) != strings.Repeat("k", 40) || cfg.FetchTimeout != 3*time.Second ||
		cfg.MaxHTMLBytes != 524288 || cfg.InstanceID != "lp-1" || !strings.Contains(cfg.UserAgent, "olt.example") {
		t.Fatalf("cfg = %+v", cfg)
	}
}

func TestLoadRejectsUnsafeValues(t *testing.T) {
	cases := map[string]map[string]string{
		"JWT_SECRET":                           {"JWT_SECRET": "short"},
		"USER_AGENT":                           {"USER_AGENT": "bot\r\nX-Injected: 1"},
		"FETCH_TIMEOUT":                        {"FETCH_TIMEOUT": "30s"},
		"MAX_HTML_BYTES":                       {"MAX_HTML_BYTES": "10485760"},
		"MAX_IMAGE_BYTES":                      {"MAX_IMAGE_BYTES": "10485760"},
		"LEASE must be":                        {"LEASE": "30s"},
		"CONCURRENCY":                          {"CONCURRENCY": "0"},
		"POSTGREST_URL":                        {"POSTGREST_URL": "rest:3000"},
		"BATCH_SIZE":                           {"BATCH_SIZE": "x"},
		"CLASSIFIER_URL":                       {"CLASSIFIER_URL": "classifier:8080"},
		"CLASSIFIER_TIMEOUT":                   {"CLASSIFIER_TIMEOUT": "2m"},
		"MODERATION_REFRESH":                   {"MODERATION_REFRESH": "1s"},
		"CLASSIFIER_TIMEOUT + REQUEST_TIMEOUT": {"LEASE": "45s", "CLASSIFIER_TIMEOUT": "30s"},
	}
	for want, env := range cases {
		t.Run(want, func(t *testing.T) {
			clearEnv(t)
			t.Setenv("JWT_SECRET", strings.Repeat("s", 40))
			for k, v := range env {
				t.Setenv(k, v)
			}
			_, err := Load()
			if err == nil || !strings.Contains(err.Error(), want) {
				t.Fatalf("err = %v, want mention of %s", err, want)
			}
		})
	}
}
