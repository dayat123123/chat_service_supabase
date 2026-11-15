package config

import (
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
	Port            int
	LogLevel        slog.Level
	JWTSecret       []byte
	JWTIssuer       string
	PostgRESTURL    string
	InstanceID      string
	ConfigInterval  time.Duration
	StatusInterval  time.Duration
	FlushInterval   time.Duration
	BatchSize       int
	BufferSize      int
	RecvQueue       int
	RecvHWM         int
	RecvTimeout     time.Duration
	SilentReconnect time.Duration
	RequestTimeout  time.Duration
	WatchdogTimeout time.Duration
	RestartFlush    time.Duration
}

func Load() (Config, error) {
	var errs []error
	cfg := Config{
		Port:            intEnv("PORT", 8080, &errs),
		JWTIssuer:       stringEnv("JWT_ISSUER", "supabase"),
		PostgRESTURL:    urlEnv("POSTGREST_URL", "http://rest:3000", &errs),
		InstanceID:      stringEnv("INSTANCE_ID", hostname()),
		ConfigInterval:  durationEnv("CONFIG_INTERVAL", 15*time.Second, &errs),
		StatusInterval:  durationEnv("STATUS_INTERVAL", 30*time.Second, &errs),
		FlushInterval:   durationEnv("FLUSH_INTERVAL", 500*time.Millisecond, &errs),
		BatchSize:       intEnv("BATCH_SIZE", 200, &errs),
		BufferSize:      intEnv("BUFFER_SIZE", 10000, &errs),
		RecvQueue:       intEnv("RECV_QUEUE", 100000, &errs),
		RecvHWM:         intEnv("ZMQ_HWM", 100000, &errs),
		RecvTimeout:     durationEnv("RECV_TIMEOUT", 500*time.Millisecond, &errs),
		SilentReconnect: durationEnv("SILENT_RECONNECT", 10*time.Minute, &errs),
		RequestTimeout:  durationEnv("REQUEST_TIMEOUT", 10*time.Second, &errs),
		WatchdogTimeout: durationEnv("WATCHDOG_TIMEOUT", 60*time.Second, &errs),
		RestartFlush:    durationEnv("RESTART_FLUSH", 5*time.Second, &errs),
		JWTSecret:       []byte(secretEnv("JWT_SECRET", &errs)),
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
		{cfg.InstanceID != "" && len(cfg.InstanceID) <= 100, "INSTANCE_ID must be 1-100 characters"},
		{cfg.ConfigInterval >= time.Second && cfg.ConfigInterval <= 5*time.Minute, "CONFIG_INTERVAL must be between 1s and 5m"},
		{cfg.StatusInterval >= time.Second && cfg.StatusInterval <= 5*time.Minute, "STATUS_INTERVAL must be between 1s and 5m"},
		{cfg.FlushInterval >= 10*time.Millisecond && cfg.FlushInterval <= 10*time.Second, "FLUSH_INTERVAL must be between 10ms and 10s"},
		{cfg.BatchSize >= 1 && cfg.BatchSize <= 500, "BATCH_SIZE must be between 1 and 500"},
		{cfg.BufferSize >= 100 && cfg.BufferSize <= 1000000, "BUFFER_SIZE must be between 100 and 1000000"},
		{cfg.RecvQueue >= 100 && cfg.RecvQueue <= 2000000, "RECV_QUEUE must be between 100 and 2000000"},
		{cfg.RecvHWM >= 1000 && cfg.RecvHWM <= 10000000, "ZMQ_HWM must be between 1000 and 10000000"},
		{cfg.RecvTimeout >= 50*time.Millisecond && cfg.RecvTimeout <= 5*time.Second, "RECV_TIMEOUT must be between 50ms and 5s"},
		{cfg.SilentReconnect == 0 || cfg.SilentReconnect >= time.Minute, "SILENT_RECONNECT must be 0 or at least 1m"},
		{cfg.RequestTimeout >= time.Second && cfg.RequestTimeout <= time.Minute, "REQUEST_TIMEOUT must be between 1s and 1m"},
		{cfg.WatchdogTimeout >= 10*time.Second && cfg.WatchdogTimeout <= 10*time.Minute, "WATCHDOG_TIMEOUT must be between 10s and 10m"},
		{cfg.RestartFlush >= 0 && cfg.RestartFlush <= time.Minute, "RESTART_FLUSH must be between 0 and 1m"},
	}
	for _, r := range rules {
		if !r.ok {
			errs = append(errs, errors.New(r.message))
		}
	}
	return cfg, errors.Join(errs...)
}

func stringEnv(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

func intEnv(key string, def int, errs *[]error) int {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		*errs = append(*errs, fmt.Errorf("%s must be an integer", key))
		return def
	}
	return n
}

func durationEnv(key string, def time.Duration, errs *[]error) time.Duration {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return def
	}
	d, err := time.ParseDuration(v)
	if err != nil {
		*errs = append(*errs, fmt.Errorf("%s must be a duration", key))
		return def
	}
	return d
}

func urlEnv(key, def string, errs *[]error) string {
	v := stringEnv(key, def)
	u, err := url.Parse(v)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		*errs = append(*errs, fmt.Errorf("%s must be an http(s) URL", key))
	}
	return strings.TrimRight(v, "/")
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

func hostname() string {
	h, err := os.Hostname()
	if err != nil || h == "" {
		return "trade-relay"
	}
	return h
}
