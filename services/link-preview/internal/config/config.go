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
)

const DefaultUserAgent = "OLTSocialLinkPreview/1.0 (+https://olt-social.invalid/link-preview)"

type Config struct {
	Port              int
	LogLevel          slog.Level
	JWTSecret         []byte
	JWTIssuer         string
	PostgRESTURL      string
	StorageURL        string
	InstanceID        string
	UserAgent         string
	BatchSize         int
	Concurrency       int
	Lease             time.Duration
	PollInterval      time.Duration
	FetchTimeout      time.Duration
	RequestTimeout    time.Duration
	HeartbeatInterval time.Duration
	ShutdownTimeout   time.Duration
	MaxHTMLBytes      int64
	MaxImageBytes     int64
}

func Load() (Config, error) {
	var errs []error
	cfg := Config{
		Port:              intEnv("PORT", 8080, &errs),
		JWTIssuer:         stringEnv("JWT_ISSUER", "supabase"),
		PostgRESTURL:      urlEnv("POSTGREST_URL", "http://rest:3000", &errs),
		StorageURL:        urlEnv("STORAGE_URL", "http://storage:5000", &errs),
		InstanceID:        stringEnv("INSTANCE_ID", hostname()+"-"+suffix()),
		UserAgent:         stringEnv("USER_AGENT", DefaultUserAgent),
		BatchSize:         intEnv("BATCH_SIZE", 8, &errs),
		Concurrency:       intEnv("CONCURRENCY", 4, &errs),
		Lease:             durationEnv("LEASE", 2*time.Minute, &errs),
		PollInterval:      durationEnv("POLL_INTERVAL", 5*time.Second, &errs),
		FetchTimeout:      durationEnv("FETCH_TIMEOUT", 5*time.Second, &errs),
		RequestTimeout:    durationEnv("REQUEST_TIMEOUT", 15*time.Second, &errs),
		HeartbeatInterval: durationEnv("HEARTBEAT_INTERVAL", 30*time.Second, &errs),
		ShutdownTimeout:   durationEnv("SHUTDOWN_TIMEOUT", 20*time.Second, &errs),
		MaxHTMLBytes:      int64(intEnv("MAX_HTML_BYTES", 1<<20, &errs)),
		MaxImageBytes:     int64(intEnv("MAX_IMAGE_BYTES", 5<<20, &errs)),
		JWTSecret:         []byte(secretEnv("JWT_SECRET", &errs)),
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
		{printable(cfg.UserAgent) && len(cfg.UserAgent) <= 200, "USER_AGENT must be printable ASCII, at most 200 characters"},
		{cfg.BatchSize >= 1 && cfg.BatchSize <= 100, "BATCH_SIZE must be between 1 and 100"},
		{cfg.Concurrency >= 1 && cfg.Concurrency <= 32, "CONCURRENCY must be between 1 and 32"},
		{within(cfg.Lease, 30*time.Second, time.Hour), "LEASE must be between 30s and 1h"},
		{within(cfg.PollInterval, time.Second, 10*time.Minute), "POLL_INTERVAL must be between 1s and 10m"},
		{within(cfg.FetchTimeout, time.Second, 10*time.Second), "FETCH_TIMEOUT must be between 1s and 10s"},
		{within(cfg.RequestTimeout, time.Second, 2*time.Minute), "REQUEST_TIMEOUT must be between 1s and 2m"},
		{within(cfg.HeartbeatInterval, 5*time.Second, time.Minute), "HEARTBEAT_INTERVAL must be between 5s and 60s"},
		{within(cfg.ShutdownTimeout, time.Second, 5*time.Minute), "SHUTDOWN_TIMEOUT must be between 1s and 5m"},
		{cfg.MaxHTMLBytes >= 64<<10 && cfg.MaxHTMLBytes <= 2<<20, "MAX_HTML_BYTES must be between 65536 and 2097152"},
		{cfg.MaxImageBytes >= 256<<10 && cfg.MaxImageBytes <= 5<<20, "MAX_IMAGE_BYTES must be between 262144 and 5242880"},
		{cfg.Lease >= 2*cfg.FetchTimeout+cfg.RequestTimeout+10*time.Second, "LEASE must be at least 2 x FETCH_TIMEOUT + REQUEST_TIMEOUT + 10s"},
	}
	for _, rule := range rules {
		if !rule.ok {
			errs = append(errs, errors.New(rule.message))
		}
	}
	return cfg, errors.Join(errs...)
}

func printable(s string) bool {
	if s == "" {
		return false
	}
	for i := 0; i < len(s); i++ {
		if s[i] < 0x20 || s[i] > 0x7E {
			return false
		}
	}
	return true
}

func within(v, lo, hi time.Duration) bool {
	return v >= lo && v <= hi
}

func hostname() string {
	name, err := os.Hostname()
	if err != nil || strings.TrimSpace(name) == "" {
		return "link-preview"
	}
	return name
}

func suffix() string {
	b := make([]byte, 3)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
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
