package config

import (
	"log/slog"
	"reflect"
	"strings"
	"testing"
	"time"
)

var keys = []string{
	"LOG_LEVEL", "HEALER_ENABLED", "HEALER_PROJECT", "HEALER_DOCKER_SOCKET", "HEALER_STATE_FILE", "HEALER_INTERVAL_SECONDS",
	"HEALER_UNHEALTHY_SECONDS", "HEALER_MIN_UPTIME_SECONDS", "HEALER_MAX_RESTARTS_PER_HOUR", "HEALER_GLOBAL_COOLDOWN_SECONDS",
	"HEALER_SYSTEMIC_FRACTION",
}

func clearEnv(t *testing.T) {
	t.Helper()
	for _, key := range keys {
		t.Setenv(key, "")
	}
}

func TestLoadUsesSafeDefaults(t *testing.T) {
	clearEnv(t)
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	want := Config{
		LogLevel:         slog.LevelInfo,
		Enabled:          true,
		Socket:           "/var/run/docker.sock",
		StateFile:        "/var/lib/olt-healer/state.json",
		Interval:         10 * time.Second,
		UnhealthyFor:     60 * time.Second,
		MinUptime:        120 * time.Second,
		MaxRestarts:      3,
		GlobalCooldown:   30 * time.Second,
		SystemicFraction: 0.5,
	}
	if !reflect.DeepEqual(cfg, want) {
		t.Fatalf("cfg = %+v\nwant %+v", cfg, want)
	}
}

func TestLoadReadsOverrides(t *testing.T) {
	clearEnv(t)
	t.Setenv("LOG_LEVEL", "debug")
	t.Setenv("HEALER_ENABLED", "false")
	t.Setenv("HEALER_PROJECT", "olt-social")
	t.Setenv("HEALER_STATE_FILE", "/tmp/h/state.json")
	t.Setenv("HEALER_INTERVAL_SECONDS", "5")
	t.Setenv("HEALER_UNHEALTHY_SECONDS", "20")
	t.Setenv("HEALER_MIN_UPTIME_SECONDS", "30")
	t.Setenv("HEALER_MAX_RESTARTS_PER_HOUR", "5")
	t.Setenv("HEALER_GLOBAL_COOLDOWN_SECONDS", "0")
	t.Setenv("HEALER_SYSTEMIC_FRACTION", "0.75")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Enabled || cfg.LogLevel != slog.LevelDebug || cfg.Project != "olt-social" || cfg.StateFile != "/tmp/h/state.json" ||
		cfg.Interval != 5*time.Second || cfg.UnhealthyFor != 20*time.Second || cfg.MinUptime != 30*time.Second ||
		cfg.MaxRestarts != 5 || cfg.GlobalCooldown != 0 || cfg.SystemicFraction != 0.75 {
		t.Fatalf("cfg = %+v", cfg)
	}
}

func TestLoadRejectsUnsafeValues(t *testing.T) {
	cases := map[string][2]string{
		"enabled":   {"HEALER_ENABLED", "kadang"},
		"project":   {"HEALER_PROJECT", "Olt Social"},
		"socket":    {"HEALER_DOCKER_SOCKET", "docker.sock"},
		"state":     {"HEALER_STATE_FILE", "/var/lib/olt-healer/state.txt"},
		"interval":  {"HEALER_INTERVAL_SECONDS", "1"},
		"unhealthy": {"HEALER_UNHEALTHY_SECONDS", "2"},
		"uptime":    {"HEALER_MIN_UPTIME_SECONDS", "7200"},
		"restarts":  {"HEALER_MAX_RESTARTS_PER_HOUR", "0"},
		"cooldown":  {"HEALER_GLOBAL_COOLDOWN_SECONDS", "-1"},
		"fraction":  {"HEALER_SYSTEMIC_FRACTION", "0"},
		"fraction2": {"HEALER_SYSTEMIC_FRACTION", "1.5"},
		"number":    {"HEALER_MAX_RESTARTS_PER_HOUR", "tiga"},
		"float":     {"HEALER_SYSTEMIC_FRACTION", "setengah"},
		"level":     {"LOG_LEVEL", "loud"},
	}
	for name, kv := range cases {
		t.Run(name, func(t *testing.T) {
			clearEnv(t)
			t.Setenv(kv[0], kv[1])
			_, err := Load()
			if err == nil {
				t.Fatalf("%s=%s accepted", kv[0], kv[1])
			}
			if kv[0] != "LOG_LEVEL" && !strings.Contains(err.Error(), kv[0]) {
				t.Fatalf("error %q does not name %s", err, kv[0])
			}
		})
	}
}
