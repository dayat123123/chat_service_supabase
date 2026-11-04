package config

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"olt-social/sentinel/internal/disk"
	"olt-social/sentinel/internal/probe"
	"olt-social/sentinel/internal/scrape"
)

type Config struct {
	Port            int
	LogLevel        slog.Level
	JWTSecret       []byte
	JWTIssuer       string
	PostgRESTURL    string
	InstanceID      string
	Probes          []probe.Target
	Disks           []disk.Target
	Metrics         []scrape.Source
	StatsPassword   string
	ReportInterval  time.Duration
	ProbeTimeout    time.Duration
	AlertPoll       time.Duration
	DBDownAfter     time.Duration
	TelegramAPIURL  string
	SMTPTimeout     time.Duration
	RequestTimeout  time.Duration
	BatchSize       int
	Lease           time.Duration
	ShutdownTimeout time.Duration
}

func Load() (Config, error) {
	var errs []error
	cfg := Config{
		Port:            intEnv("PORT", 8080, &errs),
		JWTIssuer:       stringEnv("JWT_ISSUER", "supabase"),
		PostgRESTURL:    urlEnv("POSTGREST_URL", "http://rest:3000", &errs),
		InstanceID:      stringEnv("INSTANCE_ID", defaultInstance()),
		ReportInterval:  durationEnv("REPORT_INTERVAL", 30*time.Second, &errs),
		ProbeTimeout:    durationEnv("PROBE_TIMEOUT", 5*time.Second, &errs),
		AlertPoll:       durationEnv("ALERT_POLL", 5*time.Second, &errs),
		DBDownAfter:     durationEnv("DB_DOWN_AFTER", 2*time.Minute, &errs),
		TelegramAPIURL:  urlEnv("TELEGRAM_API_URL", "https://api.telegram.org", &errs),
		SMTPTimeout:     durationEnv("SMTP_TIMEOUT", 20*time.Second, &errs),
		RequestTimeout:  durationEnv("REQUEST_TIMEOUT", 10*time.Second, &errs),
		BatchSize:       intEnv("BATCH_SIZE", 20, &errs),
		Lease:           durationEnv("LEASE", time.Minute, &errs),
		ShutdownTimeout: durationEnv("SHUTDOWN_TIMEOUT", 20*time.Second, &errs),
		JWTSecret:       []byte(secretEnv("JWT_SECRET", &errs)),
	}
	if err := cfg.LogLevel.UnmarshalText([]byte(stringEnv("LOG_LEVEL", "info"))); err != nil {
		errs = append(errs, fmt.Errorf("LOG_LEVEL: %w", err))
	}
	var err error
	if cfg.Probes, err = probe.Parse(os.Getenv("PROBES") + "," + os.Getenv("PROBES_EXTRA")); err != nil {
		errs = append(errs, fmt.Errorf("PROBES/PROBES_EXTRA: %w", err))
	}
	if cfg.Disks, err = disk.Parse(os.Getenv("DISKS")); err != nil {
		errs = append(errs, fmt.Errorf("DISKS: %w", err))
	}
	if cfg.Metrics, err = scrape.Parse(os.Getenv("METRICS_SOURCES")); err != nil {
		errs = append(errs, fmt.Errorf("METRICS_SOURCES: %w", err))
	}
	if scrape.NeedsPgBouncerPassword(cfg.Metrics) {
		cfg.StatsPassword = secretEnv("PGBOUNCER_STATS_PASSWORD", &errs)
		if cfg.StatsPassword == "" {
			errs = append(errs, errors.New("PGBOUNCER_STATS_PASSWORD or PGBOUNCER_STATS_PASSWORD_FILE is required for pgbouncer:// metrics sources"))
		}
	}
	rules := []struct {
		ok      bool
		message string
	}{
		{len(cfg.JWTSecret) >= 32, "JWT_SECRET must be at least 32 characters"},
		{cfg.Port >= 1 && cfg.Port <= 65535, "PORT must be a port number"},
		{len(cfg.InstanceID) <= 100, "INSTANCE_ID must be at most 100 characters"},
		{within(cfg.ReportInterval, 5*time.Second, 10*time.Minute), "REPORT_INTERVAL must be between 5s and 10m"},
		{within(cfg.ProbeTimeout, time.Second, time.Minute), "PROBE_TIMEOUT must be between 1s and 60s"},
		{cfg.ProbeTimeout < cfg.ReportInterval, "PROBE_TIMEOUT must be shorter than REPORT_INTERVAL"},
		{within(cfg.AlertPoll, time.Second, 5*time.Minute), "ALERT_POLL must be between 1s and 5m"},
		{within(cfg.DBDownAfter, 30*time.Second, time.Hour), "DB_DOWN_AFTER must be between 30s and 1h"},
		{cfg.DBDownAfter >= 2*cfg.AlertPoll, "DB_DOWN_AFTER must be at least twice ALERT_POLL"},
		{within(cfg.SMTPTimeout, time.Second, 5*time.Minute), "SMTP_TIMEOUT must be between 1s and 5m"},
		{within(cfg.RequestTimeout, time.Second, time.Minute), "REQUEST_TIMEOUT must be between 1s and 60s"},
		{cfg.BatchSize >= 1 && cfg.BatchSize <= 100, "BATCH_SIZE must be between 1 and 100"},
		{within(cfg.Lease, 10*time.Second, 10*time.Minute), "LEASE must be between 10s and 10m"},
		{cfg.Lease >= max(cfg.SMTPTimeout, cfg.RequestTimeout)+10*time.Second, "LEASE must be at least SMTP_TIMEOUT and REQUEST_TIMEOUT + 10s"},
		{within(cfg.ShutdownTimeout, time.Second, 5*time.Minute), "SHUTDOWN_TIMEOUT must be between 1s and 5m"},
	}
	for _, rule := range rules {
		if !rule.ok {
			errs = append(errs, errors.New(rule.message))
		}
	}
	return cfg, errors.Join(errs...)
}

func within(v, lo, hi time.Duration) bool {
	return v >= lo && v <= hi
}

func defaultInstance() string {
	name, err := os.Hostname()
	if err != nil || strings.TrimSpace(name) == "" {
		name = "sentinel"
	}
	if len(name) > 80 {
		name = name[:80]
	}
	var suffix [3]byte
	_, _ = rand.Read(suffix[:])
	return name + "-" + hex.EncodeToString(suffix[:])
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
