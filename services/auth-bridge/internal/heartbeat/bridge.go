package heartbeat

import (
	"time"

	"olt-social/auth-bridge/internal/olt"
)

const (
	maxKeys     = 20
	maxKidChars = 100
	jwtMode     = "jwt"
)

type Bridge struct {
	AppEnv   string
	OLTMode  string
	Issuer   string
	Audience string
	MaxTTL   time.Duration
	Keys     []olt.KeyInfo
}

func (b Bridge) Detail() map[string]any {
	shown := b.Keys[:min(len(b.Keys), maxKeys)]
	keys := make([]map[string]string, 0, len(shown))
	for _, k := range shown {
		keys = append(keys, map[string]string{"kid": clip(k.Kid, maxKidChars), "alg": k.Alg})
	}
	detail := map[string]any{
		"app_env":   b.AppEnv,
		"olt_mode":  b.OLTMode,
		"key_count": len(b.Keys),
		"keys":      keys,
	}
	if b.OLTMode == jwtMode {
		detail["issuer"] = b.Issuer
		detail["audience"] = b.Audience
		detail["max_ttl_seconds"] = int(b.MaxTTL / time.Second)
	}
	return detail
}

func clip(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n])
}
