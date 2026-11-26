package config

import (
	"strings"
	"testing"
	"time"
)

func TestDefaults(t *testing.T) {
	t.Setenv("JWT_SECRET", strings.Repeat("s", 40))
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != 8080 || cfg.OpsPort != 9100 || cfg.MaxFileBytes != 8<<20 || cfg.MaxUploads != 2 ||
		cfg.ClamdAddr != "clamav:3310" || cfg.StorageURL != "http://storage:5000" || cfg.PostgRESTURL != "http://rest:3000" ||
		cfg.JobTimeout != time.Minute || cfg.Lease != 2*time.Minute || cfg.PollInterval != 15*time.Second {
		t.Fatalf("defaults = %+v", cfg)
	}
}

func TestValidation(t *testing.T) {
	t.Setenv("JWT_SECRET", "short")
	t.Setenv("MAX_FILE_BYTES", "99999999")
	t.Setenv("MAX_UPLOADS", "0")
	t.Setenv("LEASE", "30s")
	t.Setenv("JOB_TIMEOUT", "1m")
	t.Setenv("STORAGE_URL", "ftp://storage")
	t.Setenv("POLL_INTERVAL", "soon")
	_, err := Load()
	if err == nil {
		t.Fatal("expected errors")
	}
	for _, want := range []string{"JWT_SECRET", "MAX_FILE_BYTES", "MAX_UPLOADS", "LEASE must be longer", "STORAGE_URL",
		"POLL_INTERVAL"} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("missing %q in %v", want, err)
		}
	}
}
