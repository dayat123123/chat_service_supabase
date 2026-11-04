package config

import (
	"crypto/rand"
	"encoding/hex"
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

type OLTMode string

const (
	OLTModeMock      OLTMode = "mock"
	OLTModeWebSocket OLTMode = "websocket"
	OLTModeJWT       OLTMode = "jwt"
)

const (
	TokenPlaceholder     = "{{token}}"
	RequestIDPlaceholder = "{{request_id}}"
)

type Config struct {
	Port                      int
	AppEnv                    string
	LogLevel                  slog.Level
	JWTSecret                 string
	JWTTTL                    time.Duration
	JWTIssuer                 string
	PostgRESTURL              string
	VerifyCacheTTL            time.Duration
	RateLimitPerMinute        int
	RateLimitPerUserPerMinute int
	TrustedProxies            []netip.Prefix
	ValkeyAddr                string
	ValkeyPassword            string
	ValkeyDB                  int
	BreakerThreshold          int
	BreakerCooldown           time.Duration
	OpsPort                   int
	InstanceID                string
	HeartbeatInterval         time.Duration
	OLT                       OLTConfig
}

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
	JWKS               []byte
	JWTIssuer          string
	JWTAudience        string
	JWTMaxTTL          time.Duration
	JWTLeeway          time.Duration
}

func (c Config) IsProduction() bool {
	return c.AppEnv == "production"
}

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
		RateLimitPerMinute:        intEnv("RATE_LIMIT_PER_MINUTE", 1500, &errs),
		RateLimitPerUserPerMinute: intEnv("RATE_LIMIT_PER_USER_PER_MINUTE", 10, &errs),
		ValkeyAddr:                os.Getenv("VALKEY_ADDR"),
		ValkeyPassword:            secretEnv("VALKEY_PASSWORD", &errs),
		ValkeyDB:                  intEnvMin("VALKEY_DB", 0, 0, &errs),
		BreakerThreshold:          intEnv("BREAKER_FAILURE_THRESHOLD", 5, &errs),
		BreakerCooldown:           secondsEnv("BREAKER_COOLDOWN", 30, &errs),
		OpsPort:                   intEnvMin("OPS_PORT", 9100, 0, &errs),
		InstanceID:                envOr("INSTANCE_ID", hostname()+"-"+suffix()),
		HeartbeatInterval:         secondsEnv("HEARTBEAT_INTERVAL", 30, &errs),
		OLT: OLTConfig{
			Mode:         OLTMode(strings.ToLower(envOr("OLT_MODE", string(OLTModeMock)))),
			WebSocketURL: os.Getenv("OLT_WS_URL"),
			Timeout:      secondsEnv("OLT_WS_TIMEOUT", 5, &errs),
			Origin:       os.Getenv("OLT_WS_ORIGIN"),
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
			JWTIssuer:          envOr("OLT_JWT_ISSUER", "olt"),
			JWTAudience:        envOr("OLT_JWT_AUDIENCE", "olt-social"),
			JWTMaxTTL:          secondsEnv("OLT_JWT_MAX_TTL", 900, &errs),
			JWTLeeway:          time.Duration(intEnvMin("OLT_JWT_LEEWAY", 30, 0, &errs)) * time.Second,
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
	if len(cfg.InstanceID) > 100 {
		errs = append(errs, errors.New("INSTANCE_ID maksimal 100 karakter"))
	}
	if cfg.HeartbeatInterval < 5*time.Second || cfg.HeartbeatInterval > time.Minute {
		errs = append(errs, errors.New("HEARTBEAT_INTERVAL harus 5–60 detik"))
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
	case OLTModeJWT:
		cfg.OLT.JWKS, err = readJWKS()
		if err != nil {
			errs = append(errs, err)
		}
	default:
		errs = append(errs, fmt.Errorf("OLT_MODE tidak dikenal: %q (jwt|mock|websocket)", cfg.OLT.Mode))
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

func readJWKS() ([]byte, error) {
	path := os.Getenv("OLT_JWT_JWKS_FILE")
	if path == "" {
		return nil, errors.New("OLT_JWT_JWKS_FILE wajib diisi saat OLT_MODE=jwt (kunci publik OLT dalam format JWKS)")
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("OLT_JWT_JWKS_FILE: %w", err)
	}
	return b, nil
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

func hostname() string {
	name, err := os.Hostname()
	if err != nil || strings.TrimSpace(name) == "" {
		return "auth-bridge"
	}
	return name
}

func suffix() string {
	b := make([]byte, 3)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func envOr(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return def
}

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
