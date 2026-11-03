package config

import (
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

var keys = []string{
	"PORT", "OPS_PORT", "LOG_LEVEL", "JWT_SECRET", "JWT_SECRET_FILE", "JWT_ISSUER", "POSTGREST_URL", "INSTANCE_ID",
	"MODEL_DIR", "ONNXRUNTIME_LIBRARY", "MAX_CONCURRENT", "THREADS_PER_INFERENCE", "QUEUE_WAIT", "REQUEST_TIMEOUT",
	"HEARTBEAT_INTERVAL", "SHUTDOWN_TIMEOUT",
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
		cfg.PostgRESTURL != "http://rest:3000" || cfg.ModelDir != "/model" ||
		cfg.RuntimeLibrary != "/usr/lib/onnxruntime/libonnxruntime.so" || cfg.MaxConcurrent != 2 || cfg.Threads != 1 ||
		cfg.QueueWait != 5*time.Second || cfg.RequestTimeout != 30*time.Second ||
		cfg.HeartbeatInterval != 30*time.Second || cfg.ShutdownTimeout != 20*time.Second || cfg.InstanceID == "" {
		t.Fatalf("cfg = %+v", cfg)
	}
}

func TestLoadReadsOverridesAndSecretFiles(t *testing.T) {
	clearEnv(t)
	secret := filepath.Join(t.TempDir(), "jwt_secret")
	_ = os.WriteFile(secret, []byte(strings.Repeat("s", 40)+"\n"), 0o600)
	t.Setenv("JWT_SECRET_FILE", secret)
	t.Setenv("PORT", "8081")
	t.Setenv("OPS_PORT", "9200")
	t.Setenv("LOG_LEVEL", "debug")
	t.Setenv("POSTGREST_URL", "http://rest.local:3000/")
	t.Setenv("INSTANCE_ID", "classifier-2")
	t.Setenv("MODEL_DIR", "/opt/model")
	t.Setenv("ONNXRUNTIME_LIBRARY", "/opt/ort.so")
	t.Setenv("MAX_CONCURRENT", "64")
	t.Setenv("THREADS_PER_INFERENCE", "4")
	t.Setenv("QUEUE_WAIT", "100ms")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != 8081 || cfg.OpsPort != 9200 || cfg.LogLevel != slog.LevelDebug ||
		cfg.PostgRESTURL != "http://rest.local:3000" || cfg.InstanceID != "classifier-2" || cfg.ModelDir != "/opt/model" ||
		cfg.RuntimeLibrary != "/opt/ort.so" || cfg.MaxConcurrent != 64 || cfg.Threads != 4 ||
		cfg.QueueWait != 100*time.Millisecond || string(cfg.JWTSecret) != strings.Repeat("s", 40) {
		t.Fatalf("cfg = %+v", cfg)
	}
}

func TestLoadRejectsBadValues(t *testing.T) {
	clearEnv(t)
	t.Setenv("JWT_SECRET", "short")
	t.Setenv("PORT", "9100")
	t.Setenv("MAX_CONCURRENT", "0")
	t.Setenv("THREADS_PER_INFERENCE", "x")
	t.Setenv("QUEUE_WAIT", "1m")
	t.Setenv("REQUEST_TIMEOUT", "1s")
	t.Setenv("POSTGREST_URL", "ftp://rest")
	t.Setenv("LOG_LEVEL", "loud")
	_, err := Load()
	if err == nil {
		t.Fatal("expected errors")
	}
	for _, want := range []string{"JWT_SECRET", "PORT and OPS_PORT", "MAX_CONCURRENT", "THREADS_PER_INFERENCE",
		"QUEUE_WAIT", "REQUEST_TIMEOUT", "POSTGREST_URL", "LOG_LEVEL"} {
		if !strings.Contains(err.Error(), want) {
			t.Fatalf("missing %q in %v", want, err)
		}
	}
	t.Setenv("JWT_SECRET_FILE", filepath.Join(t.TempDir(), "missing"))
	if _, err := Load(); err == nil || !strings.Contains(err.Error(), "JWT_SECRET_FILE could not be read") {
		t.Fatalf("err = %v", err)
	}
}
