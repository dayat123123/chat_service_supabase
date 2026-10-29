// Package config membaca konfigurasi auth-bridge dari environment variable.
package config

import (
	"encoding/json"
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

// OLTMode menentukan cara auth-bridge memverifikasi token OLT.
type OLTMode string

const (
	// OLTModeMock memverifikasi token dummy tanpa menghubungi server OLT (khusus development).
	OLTModeMock OLTMode = "mock"
	// OLTModeWebSocket memverifikasi token dengan login-token ke WebSocket server OLT.
	OLTModeWebSocket OLTMode = "websocket"
)

const (
	// TokenPlaceholder diganti dengan token OLT di template pesan login WebSocket.
	TokenPlaceholder = "{{token}}"
	// RequestIDPlaceholder diganti dengan id unik per request (UUID v4).
	RequestIDPlaceholder = "{{request_id}}"
)

// Config adalah seluruh konfigurasi runtime auth-bridge.
type Config struct {
	Port               int
	AppEnv             string
	LogLevel           slog.Level
	JWTSecret          string
	JWTTTL             time.Duration
	JWTIssuer          string
	PostgRESTURL       string
	VerifyCacheTTL     time.Duration
	RateLimitPerMinute int
	// RateLimitPerUserPerMinute membatasi exchange per user OLT (setelah token
	// terverifikasi), selain batas per IP.
	RateLimitPerUserPerMinute int
	TrustedProxies            []netip.Prefix
	// Valkey dipakai bersama semua replika untuk rate limit & cache verifikasi.
	// Kosong = in-memory per instance (hanya untuk development satu replika).
	ValkeyAddr     string
	ValkeyPassword string
	ValkeyDB       int
	// Circuit breaker ke server OLT.
	BreakerThreshold int
	BreakerCooldown  time.Duration
	// OpsPort menyajikan /metrics, /livez, /readyz di port internal yang tidak
	// diteruskan Kong. 0 = mati.
	OpsPort int
	OLT     OLTConfig
}

// OLTConfig mengatur verifikasi token ke server OLT.
//
// Default-nya mengikuti Protokol v1 (docs/market-integration.md), sehingga di
// produksi cukup mengisi OLT_WS_URL. Bila format OLT berbeda, request dibangun
// dari template JSON dan field respons dibaca lewat path bertitik
// (mis. "data.user.id", indeks array: "items.0.id").
type OLTConfig struct {
	Mode               OLTMode
	WebSocketURL       string
	Timeout            time.Duration
	Origin             string
	LoginTemplate      string
	ResponseMatchPath  string
	ResponseMatchValue string
	SuccessPath        string
	SuccessValue       string
	ErrorMessagePath   string
	UserIDPath         string
	UsernamePath       string
	EmailPath          string
	DisplayNamePath    string
}

// IsProduction bernilai true jika APP_ENV=production.
func (c Config) IsProduction() bool {
	return c.AppEnv == "production"
}

// Load membaca dan memvalidasi konfigurasi dari environment.
func Load() (Config, error) {
	var errs []error

	cfg := Config{
		Port:                      intEnv("PORT", 8080, &errs),
		AppEnv:                    strings.ToLower(envOr("APP_ENV", "development")),
		JWTSecret:                 secretEnv("JWT_SECRET", &errs),
		JWTTTL:                    secondsEnv("JWT_TTL", 900, &errs),
		JWTIssuer:                 envOr("JWT_ISSUER", "olt-auth-bridge"),
		PostgRESTURL:              strings.TrimRight(envOr("POSTGREST_URL", "http://rest:3000"), "/"),
		VerifyCacheTTL:            secondsEnv("VERIFY_CACHE_TTL", 60, &errs),
		RateLimitPerMinute:        intEnv("RATE_LIMIT_PER_MINUTE", 30, &errs),
		RateLimitPerUserPerMinute: intEnv("RATE_LIMIT_PER_USER_PER_MINUTE", 10, &errs),
		ValkeyAddr:                os.Getenv("VALKEY_ADDR"),
		ValkeyPassword:            secretEnv("VALKEY_PASSWORD", &errs),
		ValkeyDB:                  intEnvMin("VALKEY_DB", 0, 0, &errs),
		BreakerThreshold:          intEnv("BREAKER_FAILURE_THRESHOLD", 5, &errs),
		BreakerCooldown:           secondsEnv("BREAKER_COOLDOWN", 30, &errs),
		OpsPort:                   intEnvMin("OPS_PORT", 9100, 0, &errs),
		OLT: OLTConfig{
			Mode:         OLTMode(strings.ToLower(envOr("OLT_MODE", string(OLTModeMock)))),
			WebSocketURL: os.Getenv("OLT_WS_URL"),
			Timeout:      secondsEnv("OLT_WS_TIMEOUT", 5, &errs),
			Origin:       os.Getenv("OLT_WS_ORIGIN"),
			// Default = Protokol v1. Satu koneksi per login, jadi respons cukup
			// dicocokkan lewat type.
			LoginTemplate: envOr("OLT_WS_LOGIN_TEMPLATE",
				`{"v":1,"type":"login","request_id":"{{request_id}}","method":"token","payload":{"token":"{{token}}"}}`),
			ResponseMatchPath:  envOr("OLT_WS_RESPONSE_MATCH_PATH", "type"),
			ResponseMatchValue: envOr("OLT_WS_RESPONSE_MATCH_VALUE", "login_result"),
			SuccessPath:        envOr("OLT_WS_SUCCESS_PATH", "status"),
			SuccessValue:       envOr("OLT_WS_SUCCESS_VALUE", "OK"),
			ErrorMessagePath:   envOr("OLT_WS_ERROR_MESSAGE_PATH", "error.message"),
			UserIDPath:         envOr("OLT_WS_USER_ID_PATH", "data.user.id"),
			UsernamePath:       envOr("OLT_WS_USERNAME_PATH", "data.user.username"),
			EmailPath:          envOr("OLT_WS_EMAIL_PATH", "data.user.email"),
			DisplayNamePath:    envOr("OLT_WS_DISPLAY_NAME_PATH", "data.user.full_name"),
		},
	}

	if err := cfg.LogLevel.UnmarshalText([]byte(envOr("LOG_LEVEL", "info"))); err != nil {
		errs = append(errs, fmt.Errorf("LOG_LEVEL: %w", err))
	}
	if len(cfg.JWTSecret) < 32 {
		errs = append(errs, errors.New("JWT_SECRET wajib diisi, minimal 32 karakter"))
	}
	if _, err := url.ParseRequestURI(cfg.PostgRESTURL); err != nil {
		errs = append(errs, fmt.Errorf("POSTGREST_URL tidak valid: %w", err))
	}
	if cfg.IsProduction() && cfg.ValkeyAddr == "" {
		errs = append(errs, errors.New("VALKEY_ADDR wajib diisi saat APP_ENV=production (rate limit & cache harus dibagi antar replika)"))
	}
	if cfg.OpsPort == cfg.Port {
		errs = append(errs, errors.New("OPS_PORT tidak boleh sama dengan PORT"))
	}

	proxies, err := parsePrefixes(envOr("TRUSTED_PROXIES", "127.0.0.0/8,::1/128,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,fc00::/7"))
	if err != nil {
		errs = append(errs, fmt.Errorf("TRUSTED_PROXIES: %w", err))
	}
	cfg.TrustedProxies = proxies

	switch cfg.OLT.Mode {
	case OLTModeMock:
		if cfg.IsProduction() {
			errs = append(errs, errors.New("OLT_MODE=mock tidak boleh dipakai saat APP_ENV=production"))
		}
	case OLTModeWebSocket:
		errs = append(errs, validateWebSocket(cfg.OLT)...)
	default:
		errs = append(errs, fmt.Errorf("OLT_MODE tidak dikenal: %q (mock|websocket)", cfg.OLT.Mode))
	}

	return cfg, errors.Join(errs...)
}

func validateWebSocket(o OLTConfig) []error {
	var errs []error
	u, err := url.Parse(o.WebSocketURL)
	if o.WebSocketURL == "" || err != nil || (u.Scheme != "ws" && u.Scheme != "wss") {
		errs = append(errs, errors.New("OLT_WS_URL wajib berupa URL ws:// atau wss:// saat OLT_MODE=websocket"))
	}
	var tmpl any
	if err := json.Unmarshal([]byte(o.LoginTemplate), &tmpl); err != nil {
		errs = append(errs, fmt.Errorf("OLT_WS_LOGIN_TEMPLATE harus JSON valid: %w", err))
	} else if !strings.Contains(o.LoginTemplate, TokenPlaceholder) {
		errs = append(errs, fmt.Errorf("OLT_WS_LOGIN_TEMPLATE harus memuat %s", TokenPlaceholder))
	}
	if o.UserIDPath == "" {
		errs = append(errs, errors.New("OLT_WS_USER_ID_PATH wajib diisi"))
	}
	return errs
}

func parsePrefixes(s string) ([]netip.Prefix, error) {
	var out []netip.Prefix
	for _, part := range strings.Split(s, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		p, err := netip.ParsePrefix(part)
		if err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, nil
}

func envOr(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return def
}

// secretEnv membaca rahasia dari file <KEY>_FILE (Docker secrets) bila diset,
// atau dari env <KEY>. Spasi/baris baru di ujung isi file diabaikan.
func secretEnv(key string, errs *[]error) string {
	path := os.Getenv(key + "_FILE")
	if path == "" {
		return os.Getenv(key)
	}
	b, err := os.ReadFile(path)
	if err != nil {
		*errs = append(*errs, fmt.Errorf("%s_FILE: %w", key, err))
		return ""
	}
	return strings.TrimSpace(string(b))
}

func intEnv(key string, def int, errs *[]error) int {
	return intEnvMin(key, def, 1, errs)
}

// intEnvMin membaca bilangan bulat >= floor.
func intEnvMin(key string, def, floor int, errs *[]error) int {
	v := envOr(key, strconv.Itoa(def))
	n, err := strconv.Atoi(v)
	if err != nil || n < floor {
		*errs = append(*errs, fmt.Errorf("%s harus bilangan bulat >= %d, dapat %q", key, floor, v))
		return def
	}
	return n
}

func secondsEnv(key string, def int, errs *[]error) time.Duration {
	return time.Duration(intEnv(key, def, errs)) * time.Second
}
