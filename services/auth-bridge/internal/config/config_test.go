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
		"match path tanpa value": {
			map[string]string{"JWT_SECRET": secret, "OLT_MODE": "websocket", "OLT_WS_URL": "wss://olt.example/ws",
				"OLT_WS_RESPONSE_MATCH_PATH": "type"},
			"OLT_WS_RESPONSE_MATCH_PATH",
		},
		"mode tidak dikenal": {
			map[string]string{"JWT_SECRET": secret, "OLT_MODE": "ldap"},
			"OLT_MODE tidak dikenal",
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
	if _, err := Load(); err != nil {
		t.Fatal(err)
	}
}
