package jwt

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
)

var b64 = base64.RawURLEncoding

var (
	ErrMalformed = errors.New("malformed token")
	ErrSignature = errors.New("invalid token signature")
	ErrExpired   = errors.New("token expired")
)

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
	return input + "." + b64.EncodeToString(mac(input, secret)), nil
}

func Verify(token string, secret []byte, now time.Time) (map[string]any, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil, ErrMalformed
	}
	head, err := b64.DecodeString(parts[0])
	if err != nil {
		return nil, ErrMalformed
	}
	var header struct {
		Alg string `json:"alg"`
	}
	if err := json.Unmarshal(head, &header); err != nil || header.Alg != "HS256" {
		return nil, ErrMalformed
	}
	sig, err := b64.DecodeString(parts[2])
	if err != nil || !hmac.Equal(sig, mac(parts[0]+"."+parts[1], secret)) {
		return nil, ErrSignature
	}
	raw, err := b64.DecodeString(parts[1])
	if err != nil {
		return nil, ErrMalformed
	}
	var claims map[string]any
	if err := json.Unmarshal(raw, &claims); err != nil {
		return nil, ErrMalformed
	}
	exp, ok := claims["exp"].(float64)
	if !ok || now.Unix() >= int64(exp) {
		return nil, ErrExpired
	}
	return claims, nil
}

func HasAudience(claims map[string]any, audience string) bool {
	switch aud := claims["aud"].(type) {
	case string:
		return aud == audience
	case []any:
		for _, item := range aud {
			if item == audience {
				return true
			}
		}
	}
	return false
}

func mac(input string, secret []byte) []byte {
	h := hmac.New(sha256.New, secret)
	h.Write([]byte(input))
	return h.Sum(nil)
}
