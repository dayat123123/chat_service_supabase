package jwt

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"time"
)

var b64 = base64.RawURLEncoding

func Sign(header, claims map[string]any, secret []byte) (string, error) {
	head, err := json.Marshal(header)
	if err != nil {
		return "", fmt.Errorf("encode header: %w", err)
	}
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", fmt.Errorf("encode claims: %w", err)
	}
	input := b64.EncodeToString(head) + "." + b64.EncodeToString(payload)
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(input))
	return input + "." + b64.EncodeToString(mac.Sum(nil)), nil
}

func ServiceRole(secret []byte, issuer string, now time.Time) (string, error) {
	return Sign(map[string]any{"alg": "HS256", "typ": "JWT"},
		map[string]any{"iss": issuer, "role": "service_role", "iat": now.Unix(), "exp": now.Add(time.Minute).Unix()}, secret)
}
