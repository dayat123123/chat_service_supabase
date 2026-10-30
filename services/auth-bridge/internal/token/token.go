package token

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"
)

var b64 = base64.RawURLEncoding

const header = `{"alg":"HS256","typ":"JWT"}`

func Sign(claims map[string]any, secret []byte) (string, error) {
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", fmt.Errorf("encode claims: %w", err)
	}
	signingInput := b64.EncodeToString([]byte(header)) + "." + b64.EncodeToString(payload)
	return signingInput + "." + b64.EncodeToString(mac(signingInput, secret)), nil
}

func Verify(tok string, secret []byte, now time.Time) (map[string]any, error) {
	parts := strings.Split(tok, ".")
	if len(parts) != 3 {
		return nil, errors.New("format JWT tidak valid")
	}
	sig, err := b64.DecodeString(parts[2])
	if err != nil || !hmac.Equal(sig, mac(parts[0]+"."+parts[1], secret)) {
		return nil, errors.New("tanda tangan JWT tidak valid")
	}
	raw, err := b64.DecodeString(parts[1])
	if err != nil {
		return nil, fmt.Errorf("payload JWT: %w", err)
	}
	var claims map[string]any
	if err := json.Unmarshal(raw, &claims); err != nil {
		return nil, fmt.Errorf("payload JWT: %w", err)
	}
	if exp, ok := claims["exp"].(float64); !ok || now.Unix() >= int64(exp) {
		return nil, errors.New("JWT kedaluwarsa")
	}
	return claims, nil
}

func mac(input string, secret []byte) []byte {
	h := hmac.New(sha256.New, secret)
	h.Write([]byte(input))
	return h.Sum(nil)
}

type User struct {
	ID string
}

type Issuer struct {
	secret []byte
	ttl    time.Duration
	issuer string
	now    func() time.Time

	mu           sync.Mutex
	serviceToken string
	serviceExp   time.Time
}

func NewIssuer(secret string, ttl time.Duration, issuer string) *Issuer {
	return &Issuer{secret: []byte(secret), ttl: ttl, issuer: issuer, now: time.Now}
}

func (i *Issuer) UserToken(u User) (string, time.Time, error) {
	now := i.now()
	exp := now.Add(i.ttl)
	claims := map[string]any{
		"iss":          i.issuer,
		"sub":          u.ID,
		"aud":          "authenticated",
		"role":         "authenticated",
		"iat":          now.Unix(),
		"exp":          exp.Unix(),
		"app_metadata": map[string]any{"provider": "olt"},
	}
	tok, err := Sign(claims, i.secret)
	return tok, exp, err
}

func (i *Issuer) ServiceToken() (string, error) {
	i.mu.Lock()
	defer i.mu.Unlock()

	now := i.now()
	if i.serviceToken != "" && now.Add(10*time.Second).Before(i.serviceExp) {
		return i.serviceToken, nil
	}
	exp := now.Add(60 * time.Second)
	tok, err := Sign(map[string]any{
		"iss":  i.issuer,
		"role": "service_role",
		"iat":  now.Unix(),
		"exp":  exp.Unix(),
	}, i.secret)
	if err != nil {
		return "", err
	}
	i.serviceToken, i.serviceExp = tok, exp
	return tok, nil
}
