package config

import (
	"errors"
	"fmt"
	"log/slog"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
)

var projectPattern = regexp.MustCompile(`^[a-z0-9][a-z0-9_-]{0,62}$`)

type Config struct {
	LogLevel         slog.Level
	Enabled          bool
	Project          string
	Socket           string
	StateFile        string
	Interval         time.Duration
	UnhealthyFor     time.Duration
	MinUptime        time.Duration
	MaxRestarts      int
	GlobalCooldown   time.Duration
	SystemicFraction float64
}

func Load() (Config, error) {
	var errs []error
	cfg := Config{
		Enabled:          boolEnv("HEALER_ENABLED", true, &errs),
		Project:          stringEnv("HEALER_PROJECT", ""),
		Socket:           stringEnv("HEALER_DOCKER_SOCKET", "/var/run/docker.sock"),
		StateFile:        stringEnv("HEALER_STATE_FILE", "/var/lib/olt-healer/state.json"),
		Interval:         secondsEnv("HEALER_INTERVAL_SECONDS", 10, &errs),
		UnhealthyFor:     secondsEnv("HEALER_UNHEALTHY_SECONDS", 60, &errs),
		MinUptime:        secondsEnv("HEALER_MIN_UPTIME_SECONDS", 120, &errs),
		MaxRestarts:      intEnv("HEALER_MAX_RESTARTS_PER_HOUR", 3, &errs),
		GlobalCooldown:   secondsEnv("HEALER_GLOBAL_COOLDOWN_SECONDS", 30, &errs),
		SystemicFraction: floatEnv("HEALER_SYSTEMIC_FRACTION", 0.5, &errs),
	}
	if err := cfg.LogLevel.UnmarshalText([]byte(stringEnv("LOG_LEVEL", "info"))); err != nil {
		errs = append(errs, fmt.Errorf("LOG_LEVEL: %w", err))
	}
	rules := []struct {
		ok      bool
		message string
	}{
		{cfg.Project == "" || projectPattern.MatchString(cfg.Project), "HEALER_PROJECT must be a compose project name"},
		{strings.HasPrefix(cfg.Socket, "/"), "HEALER_DOCKER_SOCKET must be an absolute path"},
		{strings.HasPrefix(cfg.StateFile, "/") && strings.HasSuffix(cfg.StateFile, ".json"), "HEALER_STATE_FILE must be an absolute path ending in .json"},
		{within(cfg.Interval, 2*time.Second, 5*time.Minute), "HEALER_INTERVAL_SECONDS must be between 2 and 300"},
		{within(cfg.UnhealthyFor, 5*time.Second, time.Hour), "HEALER_UNHEALTHY_SECONDS must be between 5 and 3600"},
		{within(cfg.MinUptime, 5*time.Second, time.Hour), "HEALER_MIN_UPTIME_SECONDS must be between 5 and 3600"},
		{cfg.MaxRestarts >= 1 && cfg.MaxRestarts <= 20, "HEALER_MAX_RESTARTS_PER_HOUR must be between 1 and 20"},
		{within(cfg.GlobalCooldown, 0, time.Hour), "HEALER_GLOBAL_COOLDOWN_SECONDS must be between 0 and 3600"},
		{cfg.SystemicFraction > 0 && cfg.SystemicFraction <= 1, "HEALER_SYSTEMIC_FRACTION must be greater than 0 and at most 1"},
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

func stringEnv(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func boolEnv(key string, fallback bool, errs *[]error) bool {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	v, err := strconv.ParseBool(raw)
	if err != nil {
		*errs = append(*errs, fmt.Errorf("%s must be true or false", key))
		return fallback
	}
	return v
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

func secondsEnv(key string, fallback int, errs *[]error) time.Duration {
	return time.Duration(intEnv(key, fallback, errs)) * time.Second
}

func floatEnv(key string, fallback float64, errs *[]error) float64 {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	v, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		*errs = append(*errs, fmt.Errorf("%s must be a number such as 0.5", key))
		return fallback
	}
	return v
}
