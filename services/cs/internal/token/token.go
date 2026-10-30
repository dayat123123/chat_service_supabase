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

var (
	b64          = base64.RawURLEncoding
	ErrMalformed = errors.New("format JWT tidak valid")
	ErrSignature = errors.New("tanda tangan JWT tidak valid")
	ErrExpired   = errors.New("JWT kedaluwarsa")
)

const header = `{"alg":"HS256","typ":"JWT"}`

func Sign(claims map[string]any, secret []byte) (string, error) {
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", fmt.Errorf("encode claims: %w", err)
	}
	input := b64.EncodeToString([]byte(header)) + "." + b64.EncodeToString(payload)
	return input + "." + b64.EncodeToString(mac(input, secret)), nil
}

func Verify(tok string, secret []byte, now time.Time) (map[string]any, error) {
	parts := strings.Split(tok, ".")
	if len(parts) != 3 {
		return nil, ErrMalformed
	}
	var head struct {
		Alg string `json:"alg"`
	}
	rawHeader, err := b64.DecodeString(parts[0])
	if err != nil || json.Unmarshal(rawHeader, &head) != nil || head.Alg != "HS256" {
		return nil, ErrMalformed
	}
	sig, err := b64.DecodeString(parts[2])
	if err != nil || !hmac.Equal(sig, mac(parts[0]+"."+parts[1], secret)) {
		return nil, ErrSignature
	}
	rawClaims, err := b64.DecodeString(parts[1])
	if err != nil {
		return nil, ErrMalformed
	}
	var claims map[string]any
	if err := json.Unmarshal(rawClaims, &claims); err != nil {
		return nil, ErrMalformed
	}
	exp, ok := claims["exp"].(float64)
	if !ok || now.Unix() >= int64(exp) {
		return nil, ErrExpired
	}
	return claims, nil
}

func mac(input string, secret []byte) []byte {
	h := hmac.New(sha256.New, secret)
	h.Write([]byte(input))
	return h.Sum(nil)
}

type Service struct {
	secret []byte
	issuer string
	now    func() time.Time

	mu      sync.Mutex
	current string
	expires time.Time
}

func NewService(secret, issuer string) *Service {
	return &Service{secret: []byte(secret), issuer: issuer, now: time.Now}
}

func (s *Service) Token() (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := s.now()
	if s.current != "" && now.Add(10*time.Second).Before(s.expires) {
		return s.current, nil
	}
	exp := now.Add(60 * time.Second)
	tok, err := Sign(map[string]any{"iss": s.issuer, "role": "service_role", "iat": now.Unix(), "exp": exp.Unix()}, s.secret)
	if err != nil {
		return "", err
	}
	s.current, s.expires = tok, exp
	return tok, nil
}
