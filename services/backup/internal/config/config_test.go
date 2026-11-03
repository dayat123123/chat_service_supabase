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
	"PORT", "LOG_LEVEL", "JWT_SECRET", "JWT_SECRET_FILE", "JWT_ISSUER", "POSTGREST_URL", "INSTANCE_ID",
	"PGHOST", "PGPORT", "PGUSER", "PGPASSWORD", "PGPASSWORD_FILE", "PGDATABASE", "DATA_DIR", "STORAGE_DIR",
	"CONFIG_POLL", "HEARTBEAT_INTERVAL", "REQUEST_TIMEOUT", "RESTORE_TEST_TIMEOUT", "SHUTDOWN_TIMEOUT",
}

func clearEnv(t *testing.T) {
	t.Helper()
	for _, key := range keys {
		t.Setenv(key, "")
	}
}

func validEnv(t *testing.T) {
	t.Helper()
	clearEnv(t)
	t.Setenv("JWT_SECRET", strings.Repeat("s", 40))
	t.Setenv("PGPASSWORD", "db-password")
}

func TestLoadUsesDefaults(t *testing.T) {
	validEnv(t)
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	host, _ := os.Hostname()
	if !regexp.MustCompile("^" + regexp.QuoteMeta(host) + "-[0-9a-f]{6}$").MatchString(cfg.InstanceID) {
		t.Fatalf("instance = %q", cfg.InstanceID)
	}
	checks := []struct {
		name      string
		got, want any
	}{
		{"port", cfg.Port, 8080},
		{"level", cfg.LogLevel, slog.LevelInfo},
		{"issuer", cfg.JWTIssuer, "supabase"},
		{"postgrest", cfg.PostgRESTURL, "http://rest:3000"},
		{"pghost", cfg.PGHost, "db"},
		{"pgport", cfg.PGPort, 5432},
		{"pguser", cfg.PGUser, "olt_backup"},
		{"pgpassword", cfg.PGPassword, "db-password"},
		{"pgdatabase", cfg.PGDatabase, "postgres"},
		{"data", cfg.DataDir, "/var/lib/olt-backup"},
		{"storage", cfg.StorageDir, "/mnt/storage"},
		{"poll", cfg.ConfigPoll, 15 * time.Second},
		{"heartbeat", cfg.HeartbeatInterval, 30 * time.Second},
		{"request", cfg.RequestTimeout, 10 * time.Second},
		{"restore test", cfg.RestoreTestTimeout, 2 * time.Hour},
		{"shutdown", cfg.ShutdownTimeout, 60 * time.Second},
	}
	for _, c := range checks {
		if c.got != c.want {
			t.Errorf("%s = %v, want %v", c.name, c.got, c.want)
		}
	}
}

func TestLoadReadsOverridesAndSecretFiles(t *testing.T) {
	clearEnv(t)
	dir := t.TempDir()
	jwtFile := filepath.Join(dir, "jwt_secret")
	pwFile := filepath.Join(dir, "backup_db_password")
	_ = os.WriteFile(jwtFile, []byte(strings.Repeat("j", 40)+"\n"), 0o600)
	_ = os.WriteFile(pwFile, []byte("from-file\n"), 0o600)
	t.Setenv("JWT_SECRET_FILE", jwtFile)
	t.Setenv("PGPASSWORD_FILE", pwFile)
	t.Setenv("PGPASSWORD", "ignored")
	t.Setenv("POSTGREST_URL", "http://rest.local:3000/")
	t.Setenv("INSTANCE_ID", "backup-2")
	t.Setenv("PGHOST", "db.internal")
	t.Setenv("PGPORT", "6543")
	t.Setenv("DATA_DIR", "/srv/backup/")
	t.Setenv("STORAGE_DIR", "/srv/storage")
	t.Setenv("CONFIG_POLL", "1s")
	t.Setenv("HEARTBEAT_INTERVAL", "5s")
	t.Setenv("RESTORE_TEST_TIMEOUT", "30m")
	t.Setenv("LOG_LEVEL", "debug")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if string(cfg.JWTSecret) != strings.Repeat("j", 40) || cfg.PGPassword != "from-file" {
		t.Fatal("secrets were not read from the files")
	}
	if cfg.PostgRESTURL != "http://rest.local:3000" || cfg.InstanceID != "backup-2" || cfg.PGHost != "db.internal" ||
		cfg.PGPort != 6543 || cfg.DataDir != "/srv/backup" || cfg.StorageDir != "/srv/storage" ||
		cfg.ConfigPoll != time.Second || cfg.HeartbeatInterval != 5*time.Second ||
		cfg.RestoreTestTimeout != 30*time.Minute || cfg.LogLevel != slog.LevelDebug {
		t.Fatalf("cfg = %+v", cfg)
	}
}

func TestLoadRejectsInvalidValues(t *testing.T) {
	cases := map[string]struct {
		env  map[string]string
		want string
	}{
		"short secret":       {map[string]string{"JWT_SECRET": "short"}, "JWT_SECRET must be at least 32 characters"},
		"missing password":   {map[string]string{"PGPASSWORD": ""}, "PGPASSWORD_FILE (or PGPASSWORD) is required"},
		"unreadable pw file": {map[string]string{"PGPASSWORD_FILE": "/does/not/exist"}, "PGPASSWORD_FILE could not be read"},
		"bad user":           {map[string]string{"PGUSER": "olt backup; drop"}, "PGUSER must be a plain role name"},
		"bad host":           {map[string]string{"PGHOST": "db host"}, "PGHOST must be a host name"},
		"bad port":           {map[string]string{"PGPORT": "70000"}, "PGPORT must be a port number"},
		"relative data":      {map[string]string{"DATA_DIR": "backup"}, "DATA_DIR must be an absolute directory"},
		"root data":          {map[string]string{"DATA_DIR": "/"}, "DATA_DIR must be an absolute directory"},
		"nested dirs":        {map[string]string{"DATA_DIR": "/mnt/storage/backup"}, "must not contain each other"},
		"same dirs":          {map[string]string{"DATA_DIR": "/mnt/storage"}, "must not contain each other"},
		"poll":               {map[string]string{"CONFIG_POLL": "0s"}, "CONFIG_POLL must be between 1s and 10m"},
		"heartbeat":          {map[string]string{"HEARTBEAT_INTERVAL": "2m"}, "HEARTBEAT_INTERVAL must be between 5s and 60s"},
		"restore timeout":    {map[string]string{"RESTORE_TEST_TIMEOUT": "1m"}, "RESTORE_TEST_TIMEOUT must be between 5m and 24h"},
		"shutdown":           {map[string]string{"SHUTDOWN_TIMEOUT": "1s"}, "SHUTDOWN_TIMEOUT must be between 5s and 10m"},
		"duration syntax":    {map[string]string{"CONFIG_POLL": "soon"}, "CONFIG_POLL must be a duration"},
		"number syntax":      {map[string]string{"PORT": "eighty"}, "PORT must be a whole number"},
		"url":                {map[string]string{"POSTGREST_URL": "ftp://rest"}, "POSTGREST_URL must be an http(s) URL"},
		"level":              {map[string]string{"LOG_LEVEL": "loud"}, "LOG_LEVEL"},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			validEnv(t)
			for k, v := range c.env {
				t.Setenv(k, v)
			}
			_, err := Load()
			if err == nil || !strings.Contains(err.Error(), c.want) {
				t.Fatalf("err = %v, want %q", err, c.want)
			}
		})
	}
}

func TestLoadNeverEchoesSecrets(t *testing.T) {
	validEnv(t)
	t.Setenv("JWT_SECRET", "too-short-but-secret")
	t.Setenv("PORT", "x")
	_, err := Load()
	if err == nil || strings.Contains(err.Error(), "too-short-but-secret") || strings.Contains(err.Error(), "db-password") {
		t.Fatalf("err = %v", err)
	}
}
