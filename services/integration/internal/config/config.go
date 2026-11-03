package config

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"net/netip"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
)

const defaultTrustedProxies = "127.0.0.0/8,::1/128,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,fc00::/7"

type Config struct {
	Port                  int
	OpsPort               int
	LogLevel              slog.Level
	JWTSecret             []byte
	JWTIssuer             string
	PostgRESTURL          string
	InstanceID            string
	TrustedProxies        []netip.Prefix
	KeyCacheTTL           time.Duration
	MaxBodyBytes          int64
	MaxConcurrent         int
	AuthFailuresPerMinute int
	RequestTimeout        time.Duration
	HeartbeatInterval     time.Duration
	ShutdownTimeout       time.Duration
}

func Load() (Config, error) {
	var errs []error
	cfg := Config{
		Port:                  intEnv("PORT", 8080, &errs),
		OpsPort:               intEnv("OPS_PORT", 9100, &errs),
		JWTIssuer:             stringEnv("JWT_ISSUER", "supabase"),
		PostgRESTURL:          urlEnv("POSTGREST_URL", "http://rest:3000", &errs),
		InstanceID:            stringEnv("INSTANCE_ID", hostname()+"-"+suffix()),
		KeyCacheTTL:           durationEnv("KEY_CACHE_TTL", 30*time.Second, &errs),
		MaxBodyBytes:          int64(intEnv("MAX_BODY_BYTES", 2<<20, &errs)),
		MaxConcurrent:         intEnv("MAX_CONCURRENT", 8, &errs),
		AuthFailuresPerMinute: intEnv("AUTH_FAILURES_PER_MINUTE", 30, &errs),
		RequestTimeout:        durationEnv("REQUEST_TIMEOUT", 30*time.Second, &errs),
		HeartbeatInterval:     durationEnv("HEARTBEAT_INTERVAL", 30*time.Second, &errs),
		ShutdownTimeout:       durationEnv("SHUTDOWN_TIMEOUT", 20*time.Second, &errs),
		JWTSecret:             []byte(secretEnv("JWT_SECRET", &errs)),
	}
	if err := cfg.LogLevel.UnmarshalText([]byte(stringEnv("LOG_LEVEL", "info"))); err != nil {
		errs = append(errs, fmt.Errorf("LOG_LEVEL: %w", err))
	}
	proxies, err := parsePrefixes(stringEnv("TRUSTED_PROXIES", defaultTrustedProxies))
	if err != nil {
		errs = append(errs, fmt.Errorf("TRUSTED_PROXIES: %w", err))
	}
	cfg.TrustedProxies = proxies
	rules := []struct {
		ok      bool
		message string
	}{
		{len(cfg.JWTSecret) >= 32, "JWT_SECRET must be at least 32 characters"},
		{cfg.Port >= 1 && cfg.Port <= 65535, "PORT must be a port number"},
		{cfg.OpsPort >= 1 && cfg.OpsPort <= 65535, "OPS_PORT must be a port number"},
		{cfg.Port != cfg.OpsPort, "PORT and OPS_PORT must differ"},
		{len(cfg.InstanceID) <= 100, "INSTANCE_ID must be at most 100 characters"},
		{within(cfg.KeyCacheTTL, time.Second, 5*time.Minute), "KEY_CACHE_TTL must be between 1s and 5m"},
		{cfg.MaxBodyBytes >= 64<<10 && cfg.MaxBodyBytes <= 16<<20, "MAX_BODY_BYTES must be between 65536 and 16777216"},
		{cfg.MaxConcurrent >= 1 && cfg.MaxConcurrent <= 256, "MAX_CONCURRENT must be between 1 and 256"},
		{cfg.AuthFailuresPerMinute >= 1 && cfg.AuthFailuresPerMinute <= 10000, "AUTH_FAILURES_PER_MINUTE must be between 1 and 10000"},
		{within(cfg.RequestTimeout, 5*time.Second, 5*time.Minute), "REQUEST_TIMEOUT must be between 5s and 5m"},
		{within(cfg.HeartbeatInterval, 5*time.Second, time.Minute), "HEARTBEAT_INTERVAL must be between 5s and 60s"},
		{within(cfg.ShutdownTimeout, time.Second, 5*time.Minute), "SHUTDOWN_TIMEOUT must be between 1s and 5m"},
	}
	for _, rule := range rules {
		if !rule.ok {
			errs = append(errs, errors.New(rule.message))
		}
	}
	return cfg, errors.Join(errs...)
}

func parsePrefixes(raw string) ([]netip.Prefix, error) {
	var out []netip.Prefix
	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		p, err := netip.ParsePrefix(part)
		if err != nil {
			return nil, err
		}
		out = append(out, p.Masked())
	}
	return out, nil
}

func within(v, lo, hi time.Duration) bool {
	return v >= lo && v <= hi
}

func hostname() string {
	name, err := os.Hostname()
	if err != nil || strings.TrimSpace(name) == "" {
		return "integration"
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
