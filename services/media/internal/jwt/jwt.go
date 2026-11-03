package jwt

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"maps"
	"math"
	"regexp"
	"strings"
	"time"
)

const (
	maxTokenLength = 16 << 10
	maxTimestamp   = 1 << 40
)

var (
	b64  = base64.RawURLEncoding
	uuid = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

	ErrInvalid = errors.New("invalid token")
)

type User struct {
	Subject string
	Expires int64
	Claims  map[string]any
}

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

func ServiceRole(secret []byte, issuer string, now time.Time) (string, error) {
	return Sign(map[string]any{"alg": "HS256", "typ": "JWT"},
		map[string]any{"iss": issuer, "role": "service_role", "iat": now.Unix(), "exp": now.Add(time.Minute).Unix()}, secret)
}

func VerifyUser(token string, secret []byte, now time.Time, leeway time.Duration) (User, error) {
	if token == "" || len(token) > maxTokenLength {
		return User{}, fmt.Errorf("%w: length", ErrInvalid)
	}
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return User{}, fmt.Errorf("%w: format", ErrInvalid)
	}
	var header struct {
		Alg string `json:"alg"`
	}
	if err := decodePart(parts[0], &header); err != nil || header.Alg != "HS256" {
		return User{}, fmt.Errorf("%w: header", ErrInvalid)
	}
	sig, err := b64.DecodeString(parts[2])
	if err != nil || !hmac.Equal(sig, mac(parts[0]+"."+parts[1], secret)) {
		return User{}, fmt.Errorf("%w: signature", ErrInvalid)
	}
	var claims map[string]any
	if err := decodePart(parts[1], &claims); err != nil || claims == nil {
		return User{}, fmt.Errorf("%w: payload", ErrInvalid)
	}
	if role, _ := claims["role"].(string); role != "authenticated" {
		return User{}, fmt.Errorf("%w: role", ErrInvalid)
	}
	sub, _ := claims["sub"].(string)
	if !uuid.MatchString(sub) {
		return User{}, fmt.Errorf("%w: sub", ErrInvalid)
	}
	exp, ok := seconds(claims["exp"])
	if !ok || !now.Before(time.Unix(exp, 0).Add(leeway)) {
		return User{}, fmt.Errorf("%w: expired", ErrInvalid)
	}
	if raw, present := claims["nbf"]; present {
		nbf, ok := seconds(raw)
		if !ok || now.Add(leeway).Before(time.Unix(nbf, 0)) {
			return User{}, fmt.Errorf("%w: not yet valid", ErrInvalid)
		}
	}
	return User{Subject: sub, Expires: exp, Claims: claims}, nil
}

func Verified(user User, secret []byte, now time.Time, ttl time.Duration) (string, error) {
	claims := maps.Clone(user.Claims)
	claims["media_verified"] = true
	claims["iat"] = now.Unix()
	claims["exp"] = min(user.Expires, now.Add(ttl).Unix())
	return Sign(map[string]any{"alg": "HS256", "typ": "JWT"}, claims, secret)
}

func decodePart(part string, out any) error {
	raw, err := b64.DecodeString(part)
	if err != nil {
		return err
	}
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	if err := dec.Decode(out); err != nil {
		return err
	}
	if dec.More() {
		return errors.New("trailing data")
	}
	return nil
}

func seconds(v any) (int64, bool) {
	n, ok := v.(json.Number)
	if !ok {
		return 0, false
	}
	f, err := n.Float64()
	if err != nil || math.IsNaN(f) || f < 0 || f > maxTimestamp {
		return 0, false
	}
	if i, err := n.Int64(); err == nil {
		return i, true
	}
	return int64(math.Floor(f)), true
}

func mac(input string, secret []byte) []byte {
	h := hmac.New(sha256.New, secret)
	h.Write([]byte(input))
	return h.Sum(nil)
}
