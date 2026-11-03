package config

import (
	"log/slog"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"strings"
	"testing"
	"time"

	"olt-social/sentinel/internal/disk"
	"olt-social/sentinel/internal/probe"
)

var keys = []string{
	"PORT", "LOG_LEVEL", "JWT_SECRET", "JWT_SECRET_FILE", "JWT_ISSUER", "POSTGREST_URL", "INSTANCE_ID", "PROBES", "PROBES_EXTRA", "DISKS",
	"REPORT_INTERVAL", "PROBE_TIMEOUT", "ALERT_POLL", "DB_DOWN_AFTER", "TELEGRAM_API_URL", "SMTP_TIMEOUT",
	"REQUEST_TIMEOUT", "BATCH_SIZE", "LEASE", "SHUTDOWN_TIMEOUT",
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
	if len(host) > 80 {
		host = host[:80]
	}
	if !regexp.MustCompile("^" + regexp.QuoteMeta(host) + "-[0-9a-f]{6}$").MatchString(cfg.InstanceID) {
		t.Fatalf("instance = %q, want hostname plus a random suffix", cfg.InstanceID)
	}
	cfg.InstanceID = ""
	want := Config{
		Port:            8080,
		LogLevel:        slog.LevelInfo,
		JWTSecret:       []byte(strings.Repeat("s", 40)),
		JWTIssuer:       "supabase",
		PostgRESTURL:    "http://rest:3000",
		ReportInterval:  30 * time.Second,
		ProbeTimeout:    5 * time.Second,
		AlertPoll:       5 * time.Second,
		DBDownAfter:     2 * time.Minute,
		TelegramAPIURL:  "https://api.telegram.org",
		SMTPTimeout:     20 * time.Second,
		RequestTimeout:  10 * time.Second,
		BatchSize:       20,
		Lease:           time.Minute,
		ShutdownTimeout: 20 * time.Second,
	}
	if !reflect.DeepEqual(cfg, want) {
		t.Fatalf("cfg = %+v\nwant %+v", cfg, want)
	}
}

func TestDefaultInstanceIsDifferentEachStart(t *testing.T) {
	if defaultInstance() == defaultInstance() {
		t.Fatal("instance ids must carry a random suffix")
	}
}

func TestLoadReadsOverridesSecretFilesProbesAndDisks(t *testing.T) {
	clearEnv(t)
	secret := filepath.Join(t.TempDir(), "jwt_secret")
	_ = os.WriteFile(secret, []byte(strings.Repeat("s", 40)+"\n"), 0o600)
	t.Setenv("JWT_SECRET_FILE", secret)
	t.Setenv("JWT_ISSUER", "olt")
	t.Setenv("POSTGREST_URL", "http://rest.local:3000/")
	t.Setenv("INSTANCE_ID", "sentinel-2")
	t.Setenv("PROBES", " storage=http://storage:5000/status , db=tcp://db:5432,,kong=http://kong:8000/")
	t.Setenv("DISKS", "data=/mnt/disks/data/, storage=/mnt/disks/storage")
	t.Setenv("REPORT_INTERVAL", "1m")
	t.Setenv("PROBE_TIMEOUT", "3s")
	t.Setenv("ALERT_POLL", "2s")
	t.Setenv("DB_DOWN_AFTER", "5m")
	t.Setenv("TELEGRAM_API_URL", "http://telegram.test/")
	t.Setenv("SMTP_TIMEOUT", "30s")
	t.Setenv("REQUEST_TIMEOUT", "5s")
	t.Setenv("BATCH_SIZE", "100")
	t.Setenv("LEASE", "2m")
	t.Setenv("SHUTDOWN_TIMEOUT", "1s")
	t.Setenv("LOG_LEVEL", "debug")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(cfg.JWTSecret) != 40 || cfg.JWTIssuer != "olt" || cfg.PostgRESTURL != "http://rest.local:3000" ||
		cfg.InstanceID != "sentinel-2" || cfg.ReportInterval != time.Minute || cfg.ProbeTimeout != 3*time.Second ||
		cfg.AlertPoll != 2*time.Second || cfg.DBDownAfter != 5*time.Minute || cfg.TelegramAPIURL != "http://telegram.test" ||
		cfg.SMTPTimeout != 30*time.Second || cfg.RequestTimeout != 5*time.Second || cfg.BatchSize != 100 ||
		cfg.Lease != 2*time.Minute || cfg.ShutdownTimeout != time.Second || cfg.LogLevel != slog.LevelDebug {
		t.Fatalf("cfg = %+v", cfg)
	}
	wantProbes := []probe.Target{
		{Name: "storage", URL: "http://storage:5000/status", Kind: probe.HTTP},
		{Name: "db", URL: "tcp://db:5432", Kind: probe.TCP, Addr: "db:5432"},
		{Name: "kong", URL: "http://kong:8000/", Kind: probe.HTTP},
	}
	if !reflect.DeepEqual(cfg.Probes, wantProbes) {
		t.Fatalf("probes = %+v", cfg.Probes)
	}
	wantDisks := []disk.Target{{Name: "data", Path: "/mnt/disks/data"}, {Name: "storage", Path: "/mnt/disks/storage"}}
	if !reflect.DeepEqual(cfg.Disks, wantDisks) {
		t.Fatalf("disks = %+v", cfg.Disks)
	}
}

func TestLoadRejectsUnsafeValues(t *testing.T) {
	cases := []struct {
		env  map[string]string
		want string
	}{
		{map[string]string{"JWT_SECRET": "short"}, "JWT_SECRET"},
		{map[string]string{"JWT_SECRET_FILE": filepath.Join(t.TempDir(), "missing")}, "JWT_SECRET_FILE"},
		{map[string]string{"PORT": "0"}, "PORT"},
		{map[string]string{"POSTGREST_URL": "ftp://rest"}, "POSTGREST_URL"},
		{map[string]string{"TELEGRAM_API_URL": "api.telegram.org"}, "TELEGRAM_API_URL"},
		{map[string]string{"INSTANCE_ID": strings.Repeat("n", 101)}, "INSTANCE_ID"},
		{map[string]string{"PROBES": "storage"}, "PROBES"},
		{map[string]string{"PROBES": "Storage=http://storage:5000/status"}, "PROBES"},
		{map[string]string{"PROBES": "db=tcp://db"}, "PROBES"},
		{map[string]string{"PROBES": "db=ftp://db:21"}, "PROBES"},
		{map[string]string{"PROBES": "a=http://a/,a=http://b/"}, "PROBES"},
		{map[string]string{"PROBES": "a=http://user:pass@a/"}, "PROBES"},
		{map[string]string{"PROBES": "a=http://a/", "PROBES_EXTRA": "a=http://b/"}, "PROBES"},
		{map[string]string{"DISKS": "data=relative/path"}, "DISKS"},
		{map[string]string{"DISKS": "data=/a,data=/b"}, "DISKS"},
		{map[string]string{"REPORT_INTERVAL": "4s"}, "REPORT_INTERVAL"},
		{map[string]string{"REPORT_INTERVAL": "11m"}, "REPORT_INTERVAL"},
		{map[string]string{"PROBE_TIMEOUT": "500ms"}, "PROBE_TIMEOUT"},
		{map[string]string{"PROBE_TIMEOUT": "10s", "REPORT_INTERVAL": "10s"}, "shorter than REPORT_INTERVAL"},
		{map[string]string{"ALERT_POLL": "0s"}, "ALERT_POLL"},
		{map[string]string{"DB_DOWN_AFTER": "10s"}, "DB_DOWN_AFTER"},
		{map[string]string{"DB_DOWN_AFTER": "1m", "ALERT_POLL": "45s"}, "twice ALERT_POLL"},
		{map[string]string{"SMTP_TIMEOUT": "later"}, "SMTP_TIMEOUT"},
		{map[string]string{"REQUEST_TIMEOUT": "2m"}, "REQUEST_TIMEOUT"},
		{map[string]string{"BATCH_SIZE": "0"}, "BATCH_SIZE"},
		{map[string]string{"BATCH_SIZE": "101"}, "BATCH_SIZE"},
		{map[string]string{"LEASE": "11m"}, "LEASE"},
		{map[string]string{"LEASE": "25s", "SMTP_TIMEOUT": "20s"}, "SMTP_TIMEOUT and REQUEST_TIMEOUT + 10s"},
		{map[string]string{"SHUTDOWN_TIMEOUT": "6m"}, "SHUTDOWN_TIMEOUT"},
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
			if strings.Contains(err.Error(), "pass") {
				t.Fatalf("error echoes URL credentials: %v", err)
			}
		})
	}
}

func TestLoadAppendsExtraProbes(t *testing.T) {
	clearEnv(t)
	t.Setenv("JWT_SECRET", strings.Repeat("s", 40))
	t.Setenv("PROBES", "storage=http://storage:5000/status")
	t.Setenv("PROBES_EXTRA", "cs-console=http://cs-console:8080/healthz")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(cfg.Probes) != 2 || cfg.Probes[1].Name != "cs-console" {
		t.Fatalf("probes = %+v", cfg.Probes)
	}
}
