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

type Config struct {
	Port              int
	OpsPort           int
	LogLevel          slog.Level
	JWTSecret         []byte
	JWTIssuer         string
	PostgRESTURL      string
	StorageURL        string
	InstanceID        string
	MaxConcurrent     int
	RequestTimeout    time.Duration
	HeartbeatInterval time.Duration
	ShutdownTimeout   time.Duration
}

func Load() (Config, error) {
	var errs []error
	cfg := Config{
		Port:              intEnv("PORT", 8080, &errs),
		OpsPort:           intEnv("OPS_PORT", 9100, &errs),
		JWTIssuer:         stringEnv("JWT_ISSUER", "supabase"),
		PostgRESTURL:      urlEnv("POSTGREST_URL", "http://rest:3000", &errs),
		StorageURL:        urlEnv("STORAGE_URL", "http://storage:5000", &errs),
		InstanceID:        stringEnv("INSTANCE_ID", hostname()+"-"+suffix()),
		MaxConcurrent:     intEnv("MAX_CONCURRENT", 8, &errs),
		RequestTimeout:    durationEnv("REQUEST_TIMEOUT", 30*time.Second, &errs),
		HeartbeatInterval: durationEnv("HEARTBEAT_INTERVAL", 30*time.Second, &errs),
		ShutdownTimeout:   durationEnv("SHUTDOWN_TIMEOUT", 20*time.Second, &errs),
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
		{cfg.OpsPort >= 1 && cfg.OpsPort <= 65535, "OPS_PORT must be a port number"},
		{cfg.Port != cfg.OpsPort, "PORT and OPS_PORT must differ"},
		{len(cfg.InstanceID) <= 100, "INSTANCE_ID must be at most 100 characters"},
		{cfg.MaxConcurrent >= 1 && cfg.MaxConcurrent <= 256, "MAX_CONCURRENT must be between 1 and 256"},
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

func within(v, lo, hi time.Duration) bool {
	return v >= lo && v <= hi
}

func hostname() string {
	name, err := os.Hostname()
	if err != nil || strings.TrimSpace(name) == "" {
		return "media"
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
