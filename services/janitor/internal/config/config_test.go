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
	"BATCH_SIZE", "OBJECTS_PER_ENTRY", "DELETE_CHUNK", "CONCURRENCY", "LEASE", "POLL_INTERVAL", "REQUEST_TIMEOUT",
	"SHUTDOWN_TIMEOUT",
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
		Port:            8080,
		LogLevel:        slog.LevelInfo,
		JWTSecret:       []byte(strings.Repeat("s", 40)),
		JWTIssuer:       "supabase",
		PostgRESTURL:    "http://rest:3000",
		StorageURL:      "http://storage:5000",
		InstanceID:      host,
		BatchSize:       20,
		ObjectsPerEntry: 1000,
		DeleteChunk:     100,
		Concurrency:     4,
		Lease:           5 * time.Minute,
		PollInterval:    30 * time.Second,
		RequestTimeout:  30 * time.Second,
		ShutdownTimeout: 20 * time.Second,
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
	t.Setenv("JWT_ISSUER", "olt")
	t.Setenv("POSTGREST_URL", "http://rest.local:3000/")
	t.Setenv("STORAGE_URL", "https://storage.local/storage/v1/")
	t.Setenv("INSTANCE_ID", "janitor-2")
	t.Setenv("BATCH_SIZE", "100")
	t.Setenv("OBJECTS_PER_ENTRY", "1")
	t.Setenv("DELETE_CHUNK", "1000")
	t.Setenv("CONCURRENCY", "32")
	t.Setenv("LEASE", "1h")
	t.Setenv("POLL_INTERVAL", "1s")
	t.Setenv("REQUEST_TIMEOUT", "5m")
	t.Setenv("SHUTDOWN_TIMEOUT", "1s")
	t.Setenv("LOG_LEVEL", "debug")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(cfg.JWTSecret) != 40 || cfg.JWTIssuer != "olt" || cfg.PostgRESTURL != "http://rest.local:3000" ||
		cfg.StorageURL != "https://storage.local/storage/v1" || cfg.InstanceID != "janitor-2" || cfg.BatchSize != 100 ||
		cfg.ObjectsPerEntry != 1 || cfg.DeleteChunk != 1000 || cfg.Concurrency != 32 || cfg.Lease != time.Hour ||
		cfg.PollInterval != time.Second || cfg.RequestTimeout != 5*time.Minute || cfg.ShutdownTimeout != time.Second ||
		cfg.LogLevel != slog.LevelDebug {
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
		{map[string]string{"STORAGE_URL": "storage:5000"}, "STORAGE_URL"},
		{map[string]string{"INSTANCE_ID": strings.Repeat("n", 101)}, "INSTANCE_ID"},
		{map[string]string{"BATCH_SIZE": "0"}, "BATCH_SIZE"},
		{map[string]string{"BATCH_SIZE": "101"}, "BATCH_SIZE"},
		{map[string]string{"BATCH_SIZE": "lots"}, "BATCH_SIZE"},
		{map[string]string{"OBJECTS_PER_ENTRY": "0"}, "OBJECTS_PER_ENTRY"},
		{map[string]string{"OBJECTS_PER_ENTRY": "1001"}, "OBJECTS_PER_ENTRY"},
		{map[string]string{"DELETE_CHUNK": "0"}, "DELETE_CHUNK"},
		{map[string]string{"DELETE_CHUNK": "1001"}, "DELETE_CHUNK"},
		{map[string]string{"CONCURRENCY": "0"}, "CONCURRENCY"},
		{map[string]string{"CONCURRENCY": "33"}, "CONCURRENCY"},
		{map[string]string{"LEASE": "29s"}, "LEASE"},
		{map[string]string{"LEASE": "61m"}, "LEASE"},
		{map[string]string{"POLL_INTERVAL": "500ms"}, "POLL_INTERVAL"},
		{map[string]string{"POLL_INTERVAL": "11m"}, "POLL_INTERVAL"},
		{map[string]string{"REQUEST_TIMEOUT": "soon"}, "REQUEST_TIMEOUT"},
		{map[string]string{"REQUEST_TIMEOUT": "500ms"}, "REQUEST_TIMEOUT"},
		{map[string]string{"SHUTDOWN_TIMEOUT": "0s"}, "SHUTDOWN_TIMEOUT"},
		{map[string]string{"SHUTDOWN_TIMEOUT": "6m"}, "SHUTDOWN_TIMEOUT"},
		{map[string]string{"LEASE": "39s", "REQUEST_TIMEOUT": "30s"}, "REQUEST_TIMEOUT + 10s"},
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
