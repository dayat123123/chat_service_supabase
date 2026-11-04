package config

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Port               int
	LogLevel           slog.Level
	JWTSecret          []byte
	JWTIssuer          string
	PostgRESTURL       string
	InstanceID         string
	PGHost             string
	PGPort             int
	PGUser             string
	PGPassword         string
	PGDatabase         string
	DataDir            string
	StorageDir         string
	LocalRepoDir       string
	ConfigPoll         time.Duration
	HeartbeatInterval  time.Duration
	RequestTimeout     time.Duration
	RestoreTestTimeout time.Duration
	ShutdownTimeout    time.Duration
}

var (
	pgName = regexp.MustCompile(`^[a-z_][a-z0-9_]{0,62}$`)
	pgHost = regexp.MustCompile(`^[A-Za-z0-9._:/-]{1,253}$`)
)

func Load() (Config, error) {
	var errs []error
	cfg := Config{
		Port:               intEnv("PORT", 8080, &errs),
		JWTIssuer:          stringEnv("JWT_ISSUER", "supabase"),
		PostgRESTURL:       urlEnv("POSTGREST_URL", "http://rest:3000", &errs),
		InstanceID:         stringEnv("INSTANCE_ID", instanceID()),
		PGHost:             stringEnv("PGHOST", "db"),
		PGPort:             intEnv("PGPORT", 5432, &errs),
		PGUser:             stringEnv("PGUSER", "olt_backup"),
		PGDatabase:         stringEnv("PGDATABASE", "postgres"),
		DataDir:            filepath.Clean(stringEnv("DATA_DIR", "/var/lib/olt-backup")),
		StorageDir:         filepath.Clean(stringEnv("STORAGE_DIR", "/mnt/storage")),
		LocalRepoDir:       filepath.Clean(stringEnv("LOCAL_REPO_DIR", "/var/lib/olt-backup-repo")),
		ConfigPoll:         durationEnv("CONFIG_POLL", 15*time.Second, &errs),
		HeartbeatInterval:  durationEnv("HEARTBEAT_INTERVAL", 30*time.Second, &errs),
		RequestTimeout:     durationEnv("REQUEST_TIMEOUT", 10*time.Second, &errs),
		RestoreTestTimeout: durationEnv("RESTORE_TEST_TIMEOUT", 2*time.Hour, &errs),
		ShutdownTimeout:    durationEnv("SHUTDOWN_TIMEOUT", 60*time.Second, &errs),
		JWTSecret:          []byte(secretEnv("JWT_SECRET", &errs)),
		PGPassword:         secretEnv("PGPASSWORD", &errs),
	}
	if err := cfg.LogLevel.UnmarshalText([]byte(stringEnv("LOG_LEVEL", "info"))); err != nil {
		errs = append(errs, fmt.Errorf("LOG_LEVEL: %w", err))
	}
	rules := []struct {
		ok      bool
		message string
	}{
		{len(cfg.JWTSecret) >= 32, "JWT_SECRET must be at least 32 characters"},
		{cfg.Port >= 1 && cfg.Port <= 65535, "PORT must be a port number"},
		{len(cfg.InstanceID) <= 100, "INSTANCE_ID must be at most 100 characters"},
		{pgHost.MatchString(cfg.PGHost), "PGHOST must be a host name or socket directory"},
		{cfg.PGPort >= 1 && cfg.PGPort <= 65535, "PGPORT must be a port number"},
		{pgName.MatchString(cfg.PGUser), "PGUSER must be a plain role name"},
		{pgName.MatchString(cfg.PGDatabase), "PGDATABASE must be a plain database name"},
		{cfg.PGPassword != "", "PGPASSWORD_FILE (or PGPASSWORD) is required"},
		{filepath.IsAbs(cfg.DataDir) && cfg.DataDir != "/", "DATA_DIR must be an absolute directory other than /"},
		{filepath.IsAbs(cfg.StorageDir), "STORAGE_DIR must be an absolute directory"},
		{!nested(cfg.DataDir, cfg.StorageDir), "DATA_DIR and STORAGE_DIR must not contain each other"},
		{filepath.IsAbs(cfg.LocalRepoDir) && cfg.LocalRepoDir != "/", "LOCAL_REPO_DIR must be an absolute directory other than /"},
		{!nested(cfg.LocalRepoDir, cfg.DataDir) && !nested(cfg.LocalRepoDir, cfg.StorageDir),
			"LOCAL_REPO_DIR must not contain or sit inside DATA_DIR or STORAGE_DIR"},
		{within(cfg.ConfigPoll, time.Second, 10*time.Minute), "CONFIG_POLL must be between 1s and 10m"},
		{within(cfg.HeartbeatInterval, 5*time.Second, time.Minute), "HEARTBEAT_INTERVAL must be between 5s and 60s"},
		{within(cfg.RequestTimeout, time.Second, 2*time.Minute), "REQUEST_TIMEOUT must be between 1s and 2m"},
		{within(cfg.RestoreTestTimeout, 5*time.Minute, 24*time.Hour), "RESTORE_TEST_TIMEOUT must be between 5m and 24h"},
		{within(cfg.ShutdownTimeout, 5*time.Second, 10*time.Minute), "SHUTDOWN_TIMEOUT must be between 5s and 10m"},
	}
	for _, rule := range rules {
		if !rule.ok {
			errs = append(errs, errors.New(rule.message))
		}
	}
	return cfg, errors.Join(errs...)
}

func nested(a, b string) bool {
	return a == b || strings.HasPrefix(a, b+string(filepath.Separator)) || strings.HasPrefix(b, a+string(filepath.Separator))
}

func within(v, lo, hi time.Duration) bool {
	return v >= lo && v <= hi
}

func instanceID() string {
	name, err := os.Hostname()
	if err != nil || strings.TrimSpace(name) == "" {
		name = "backup"
	}
	suffix := make([]byte, 3)
	if _, err := rand.Read(suffix); err != nil {
		return name
	}
	return name + "-" + hex.EncodeToString(suffix)
}

func stringEnv(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func intEnv(key string, fallback int, errs *[]error) int {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	v, err := strconv.Atoi(raw)
	if err != nil {
		*errs = append(*errs, fmt.Errorf("%s must be a whole number", key))
		return fallback
	}
	return v
}

func durationEnv(key string, fallback time.Duration, errs *[]error) time.Duration {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	v, err := time.ParseDuration(raw)
	if err != nil {
		*errs = append(*errs, fmt.Errorf("%s must be a duration such as 15s", key))
		return fallback
	}
	return v
}

func urlEnv(key, fallback string, errs *[]error) string {
	raw := stringEnv(key, fallback)
	u, err := url.Parse(raw)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		*errs = append(*errs, fmt.Errorf("%s must be an http(s) URL", key))
		return ""
	}
	return strings.TrimSuffix(raw, "/")
}

func secretEnv(key string, errs *[]error) string {
	if path := os.Getenv(key + "_FILE"); path != "" {
		data, err := os.ReadFile(path)
		if err != nil {
			*errs = append(*errs, fmt.Errorf("%s_FILE could not be read", key))
			return ""
		}
		return strings.TrimSpace(string(data))
	}
	return os.Getenv(key)
}
