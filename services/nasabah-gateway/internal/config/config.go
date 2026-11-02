package config

import (
	"crypto/ed25519"
	"errors"
	"fmt"
	"log/slog"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"olt-social/nasabah-gateway/internal/csadmin"
)

type Config struct {
	Port              int
	LogLevel          slog.Level
	JWTSecret         []byte
	JWTIssuer         string
	PostgRESTURL      string
	CSAdminURL        string
	CSAdminClientID   string
	CSAdminSigningKey ed25519.PrivateKey
	CSAdminTimeout    time.Duration
	AccessCacheTTL    time.Duration
}

func Load() (Config, error) {
	var errs []error
	cfg := Config{
		Port:            intEnv("PORT", 8080, &errs),
		JWTIssuer:       stringEnv("JWT_ISSUER", "supabase"),
		PostgRESTURL:    urlEnv("POSTGREST_URL", "http://rest:3000", &errs),
		CSAdminURL:      urlEnv("CSADMIN_URL", "", &errs),
		CSAdminClientID: stringEnv("CSADMIN_CLIENT_ID", csadmin.DefaultClientID),
		CSAdminTimeout:  durationEnv("CSADMIN_TIMEOUT", 15*time.Second, &errs),
		AccessCacheTTL:  durationEnv("ACCESS_CACHE_TTL", 30*time.Second, &errs),
		JWTSecret:       []byte(secretEnv("JWT_SECRET", &errs)),
	}
	if pem := secretEnv("CSADMIN_SIGNING_KEY", &errs); pem != "" {
		key, err := csadmin.ParsePrivateKey([]byte(pem))
		if err != nil {
			errs = append(errs, fmt.Errorf("CSADMIN_SIGNING_KEY: %w", err))
		}
		cfg.CSAdminSigningKey = key
	}
	if err := cfg.LogLevel.UnmarshalText([]byte(stringEnv("LOG_LEVEL", "info"))); err != nil {
		errs = append(errs, fmt.Errorf("LOG_LEVEL: %w", err))
	}
	if len(cfg.JWTSecret) < 32 {
		errs = append(errs, errors.New("JWT_SECRET must be at least 32 characters"))
	}
	if !csadmin.ClientIDPattern.MatchString(cfg.CSAdminClientID) {
		errs = append(errs, errors.New("CSADMIN_CLIENT_ID must be 1-50 letters, digits, dots, dashes or underscores"))
	}
	if cfg.CSAdminTimeout < time.Second || cfg.CSAdminTimeout > time.Minute {
		errs = append(errs, errors.New("CSADMIN_TIMEOUT must be between 1s and 1m"))
	}
	if cfg.AccessCacheTTL < 0 || cfg.AccessCacheTTL > 5*time.Minute {
		errs = append(errs, errors.New("ACCESS_CACHE_TTL must be between 0 and 5m"))
	}
	return cfg, errors.Join(errs...)
}

func stringEnv(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func intEnv(key string, fallback int, errs *[]error) int {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback
	}
	v, err := strconv.Atoi(raw)
	if err != nil || v <= 0 || v > 65535 {
		*errs = append(*errs, fmt.Errorf("%s must be a port number", key))
		return fallback
	}
	return v
}

func durationEnv(key string, fallback time.Duration, errs *[]error) time.Duration {
	raw := os.Getenv(key)
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
	if raw == "" {
		return ""
	}
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
