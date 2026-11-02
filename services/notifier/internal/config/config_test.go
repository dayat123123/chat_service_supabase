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
	"PORT", "LOG_LEVEL", "JWT_SECRET", "JWT_SECRET_FILE", "JWT_ISSUER", "POSTGREST_URL", "INSTANCE_ID",
	"FIREBASE_CREDENTIALS", "FCM_BASE_URL", "ANDROID_CHANNEL_ID", "BATCH_SIZE", "CONCURRENCY", "LEASE",
	"POLL_INTERVAL", "HEARTBEAT_INTERVAL", "SEND_TIMEOUT", "CREDENTIALS_RELOAD", "SHUTDOWN_TIMEOUT",
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
	want := Config{
		Port:                8080,
		LogLevel:            slog.LevelInfo,
		JWTSecret:           []byte(strings.Repeat("s", 40)),
		JWTIssuer:           "supabase",
		PostgRESTURL:        "http://rest:3000",
		InstanceID:          host,
		FirebaseCredentials: "/run/firebase",
		FCMBaseURL:          "https://fcm.googleapis.com",
		BatchSize:           100,
		Concurrency:         20,
		Lease:               time.Minute,
		PollInterval:        time.Second,
		HeartbeatInterval:   30 * time.Second,
		SendTimeout:         10 * time.Second,
		CredentialsReload:   30 * time.Second,
		ShutdownTimeout:     20 * time.Second,
	}
	if !reflect.DeepEqual(cfg, want) {
		t.Fatalf("cfg = %+v\nwant %+v", cfg, want)
	}
}

func TestLoadReadsOverridesAndSecretFiles(t *testing.T) {
	clearEnv(t)
	secret := filepath.Join(t.TempDir(), "jwt_secret")
	_ = os.WriteFile(secret, []byte(strings.Repeat("s", 40)+"\n"), 0o600)
	t.Setenv("JWT_SECRET_FILE", secret)
	t.Setenv("INSTANCE_ID", "notifier-2")
	t.Setenv("FIREBASE_CREDENTIALS", "/secrets/firebase.json")
	t.Setenv("FCM_BASE_URL", "http://fcm.local:9000/")
	t.Setenv("ANDROID_CHANNEL_ID", "chat")
	t.Setenv("BATCH_SIZE", "500")
	t.Setenv("CONCURRENCY", "1")
	t.Setenv("LEASE", "10m")
	t.Setenv("POLL_INTERVAL", "100ms")
	t.Setenv("HEARTBEAT_INTERVAL", "5s")
	t.Setenv("LOG_LEVEL", "debug")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(cfg.JWTSecret) != 40 || cfg.InstanceID != "notifier-2" || cfg.FirebaseCredentials != "/secrets/firebase.json" ||
		cfg.FCMBaseURL != "http://fcm.local:9000" || cfg.AndroidChannelID != "chat" || cfg.BatchSize != 500 ||
		cfg.Concurrency != 1 || cfg.Lease != 10*time.Minute || cfg.PollInterval != 100*time.Millisecond ||
		cfg.HeartbeatInterval != 5*time.Second || cfg.LogLevel != slog.LevelDebug {
		t.Fatalf("cfg = %+v", cfg)
	}
}

func TestLoadRejectsUnsafeValues(t *testing.T) {
	cases := []struct {
		env  map[string]string
		want string
	}{
		{map[string]string{"JWT_SECRET": "short"}, "JWT_SECRET"},
		{map[string]string{"JWT_SECRET_FILE": filepath.Join(t.TempDir(), "missing")}, "JWT_SECRET_FILE"},
		{map[string]string{"PORT": "70000"}, "PORT"},
		{map[string]string{"POSTGREST_URL": "ftp://rest"}, "POSTGREST_URL"},
		{map[string]string{"FCM_BASE_URL": "fcm.googleapis.com"}, "FCM_BASE_URL"},
		{map[string]string{"INSTANCE_ID": strings.Repeat("n", 101)}, "INSTANCE_ID"},
		{map[string]string{"BATCH_SIZE": "0"}, "BATCH_SIZE"},
		{map[string]string{"BATCH_SIZE": "501"}, "BATCH_SIZE"},
		{map[string]string{"BATCH_SIZE": "lots"}, "BATCH_SIZE"},
		{map[string]string{"CONCURRENCY": "201"}, "CONCURRENCY"},
		{map[string]string{"LEASE": "5s"}, "LEASE"},
		{map[string]string{"LEASE": "11m"}, "LEASE"},
		{map[string]string{"POLL_INTERVAL": "50ms"}, "POLL_INTERVAL"},
		{map[string]string{"HEARTBEAT_INTERVAL": "2m"}, "HEARTBEAT_INTERVAL"},
		{map[string]string{"SEND_TIMEOUT": "soon"}, "SEND_TIMEOUT"},
		{map[string]string{"CREDENTIALS_RELOAD": "500ms"}, "CREDENTIALS_RELOAD"},
		{map[string]string{"SHUTDOWN_TIMEOUT": "0s"}, "SHUTDOWN_TIMEOUT"},
		{map[string]string{"LEASE": "12s", "SEND_TIMEOUT": "10s"}, "SEND_TIMEOUT + 5s"},
		{map[string]string{"LOG_LEVEL": "loud"}, "LOG_LEVEL"},
	}
	for _, tc := range cases {
		t.Run(tc.want, func(t *testing.T) {
			clearEnv(t)
			t.Setenv("JWT_SECRET", strings.Repeat("s", 40))
			for k, v := range tc.env {
				t.Setenv(k, v)
			}
			_, err := Load()
			if err == nil || !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("env %v: err = %v, want mention of %s", tc.env, err, tc.want)
			}
		})
	}
}
