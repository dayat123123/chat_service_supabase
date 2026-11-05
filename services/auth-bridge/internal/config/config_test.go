package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const secret = "test-secret-yang-panjangnya-lebih-dari-32-karakter"

func TestLoadSecretFromFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "jwt_secret")
	if err := os.WriteFile(path, []byte(secret+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("JWT_SECRET", "")
	t.Setenv("JWT_SECRET_FILE", path)
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.JWTSecret != secret {
		t.Fatalf("JWT secret dari file = %q, want %q", cfg.JWTSecret, secret)
	}

	t.Setenv("JWT_SECRET_FILE", filepath.Join(t.TempDir(), "tidak-ada"))
	if _, err := Load(); err == nil || !strings.Contains(err.Error(), "JWT_SECRET_FILE") {
		t.Fatalf("file secret yang hilang harus ditolak, err=%v", err)
	}
}

func TestLoadDefaults(t *testing.T) {
	t.Setenv("JWT_SECRET", secret)
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.OLT.Mode != OLTModeMock || cfg.Port != 8080 || cfg.JWTTTL.Seconds() != 900 {
		t.Fatalf("default salah: %+v", cfg)
	}
	if len(cfg.TrustedProxies) == 0 {
		t.Fatal("TRUSTED_PROXIES default kosong")
	}
	if cfg.RateLimitPerMinute != 1500 || cfg.RateLimitPerUserPerMinute != 10 || cfg.BreakerThreshold != 5 || cfg.BreakerCooldown.Seconds() != 30 ||
		cfg.OpsPort != 9100 || cfg.ValkeyAddr != "" || cfg.ValkeyDB != 0 {
		t.Fatalf("default tahap 3 salah: %+v", cfg)
	}
	if cfg.HeartbeatInterval.Seconds() != 30 || cfg.InstanceID == "" {
		t.Fatalf("default heartbeat salah: %v %q", cfg.HeartbeatInterval, cfg.InstanceID)
	}
}

func TestLoadDefaultsFollowProtocolV1(t *testing.T) {
	t.Setenv("JWT_SECRET", secret)
	t.Setenv("OLT_MODE", "websocket")
	t.Setenv("OLT_WS_URL", "wss://olt.example.com/social")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	o := cfg.OLT
	if !strings.Contains(o.LoginTemplate, `"type":"login"`) || !strings.Contains(o.LoginTemplate, RequestIDPlaceholder) ||
		o.ResponseMatchPath != "type" || o.ResponseMatchValue != "login_result" ||
		o.SuccessPath != "status" || o.SuccessValue != "OK" || o.ErrorMessagePath != "error.message" ||
		o.UserIDPath != "data.user.id" || o.UsernamePath != "data.user.username" ||
		o.EmailPath != "data.user.email" || o.DisplayNamePath != "data.user.full_name" {
		t.Fatalf("default bukan Protokol v1: %+v", o)
	}
}

func TestLoadValkeyPasswordFromFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "valkey_password")
	if err := os.WriteFile(path, []byte("rahasia-valkey\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("JWT_SECRET", secret)
	t.Setenv("VALKEY_ADDR", "valkey:6379")
	t.Setenv("VALKEY_PASSWORD_FILE", path)
	t.Setenv("OPS_PORT", "0")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.ValkeyPassword != "rahasia-valkey" || cfg.OpsPort != 0 {
		t.Fatalf("valkey password/ops port salah: %q %d", cfg.ValkeyPassword, cfg.OpsPort)
	}
}

func TestLoadRejectsInvalidConfig(t *testing.T) {
	cases := map[string]struct {
		env  map[string]string
		want string
	}{
		"secret pendek": {
			map[string]string{"JWT_SECRET": "pendek"},
			"JWT_SECRET",
		},
		"mock di produksi": {
			map[string]string{"JWT_SECRET": secret, "APP_ENV": "production", "OLT_MODE": "mock"},
			"OLT_MODE=mock",
		},
		"websocket tanpa URL": {
			map[string]string{"JWT_SECRET": secret, "OLT_MODE": "websocket"},
			"OLT_WS_URL",
		},
		"template tanpa placeholder": {
			map[string]string{"JWT_SECRET": secret, "OLT_MODE": "websocket", "OLT_WS_URL": "wss://olt.example/ws",
				"OLT_WS_LOGIN_TEMPLATE": `{"token":"x"}`},
			"{{token}}",
		},
		"mode tidak dikenal": {
			map[string]string{"JWT_SECRET": secret, "OLT_MODE": "ldap"},
			"unknown OLT_MODE",
		},
		"produksi tanpa valkey": {
			map[string]string{"JWT_SECRET": secret, "APP_ENV": "production", "OLT_MODE": "websocket",
				"OLT_WS_URL": "wss://olt.example/ws"},
			"VALKEY_ADDR",
		},
		"valkey db negatif": {
			map[string]string{"JWT_SECRET": secret, "VALKEY_DB": "-1"},
			"VALKEY_DB",
		},
		"port ops bentrok": {
			map[string]string{"JWT_SECRET": secret, "OPS_PORT": "8080"},
			"OPS_PORT",
		},
		"heartbeat terlalu jarang": {
			map[string]string{"JWT_SECRET": secret, "HEARTBEAT_INTERVAL": "120"},
			"HEARTBEAT_INTERVAL",
		},
		"instance terlalu panjang": {
			map[string]string{"JWT_SECRET": secret, "INSTANCE_ID": strings.Repeat("a", 101)},
			"INSTANCE_ID",
		},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			for k, v := range c.env {
				t.Setenv(k, v)
			}
			_, err := Load()
			if err == nil || !strings.Contains(err.Error(), c.want) {
				t.Fatalf("err = %v, want mengandung %q", err, c.want)
			}
		})
	}
}

func TestLoadWebSocketValid(t *testing.T) {
	t.Setenv("JWT_SECRET", secret)
	t.Setenv("APP_ENV", "production")
	t.Setenv("OLT_MODE", "websocket")
	t.Setenv("OLT_WS_URL", "wss://olt.example.com/ws")
	t.Setenv("VALKEY_ADDR", "valkey:6379")
	if _, err := Load(); err != nil {
		t.Fatal(err)
	}
}

func TestLoadJWTMode(t *testing.T) {
	path := filepath.Join(t.TempDir(), "olt_jwks")
	if err := os.WriteFile(path, []byte(`{"keys":[]}`), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("JWT_SECRET", secret)
	t.Setenv("OLT_MODE", "jwt")
	t.Setenv("OLT_JWT_JWKS_FILE", path)
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	o := cfg.OLT
	if string(o.JWKS) != `{"keys":[]}` || o.JWTIssuer != "olt" || o.JWTAudience != "olt-social" ||
		o.JWTMaxTTL.Seconds() != 900 || o.JWTLeeway.Seconds() != 30 {
		t.Fatalf("konfigurasi jwt = %+v", o)
	}
}

func TestLoadRejectsIncompleteJWTMode(t *testing.T) {
	cases := map[string]struct {
		env  map[string]string
		want string
	}{
		"tanpa JWKS": {
			map[string]string{"OLT_MODE": "jwt"},
			"OLT_JWT_JWKS_FILE",
		},
		"file JWKS tidak ada": {
			map[string]string{"OLT_MODE": "jwt", "OLT_JWT_JWKS_FILE": filepath.Join(t.TempDir(), "tidak-ada")},
			"OLT_JWT_JWKS_FILE",
		},
		"umur maksimal tidak valid": {
			map[string]string{"OLT_MODE": "jwt", "OLT_JWT_MAX_TTL": "0"},
			"OLT_JWT_MAX_TTL",
		},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			t.Setenv("JWT_SECRET", secret)
			for k, v := range c.env {
				t.Setenv(k, v)
			}
			_, err := Load()
			if err == nil || !strings.Contains(err.Error(), c.want) {
				t.Fatalf("err = %v, want mengandung %q", err, c.want)
			}
		})
	}
}
