package csadmin

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"olt-social/nasabah-gateway/internal/jwt"
)

const (
	Audience          = "csAdminEL"
	assertionLifetime = time.Minute
)

var ErrRefused = errors.New("customer admin refused the integration assertion")

type Session struct {
	baseURL  string
	clientID string
	key      ed25519.PrivateKey
	http     *http.Client
	now      func() time.Time

	mu      sync.Mutex
	token   string
	expires time.Time
}

func NewSession(baseURL, clientID string, key ed25519.PrivateKey, client *http.Client) *Session {
	if client == nil {
		client = &http.Client{Timeout: 15 * time.Second}
	}
	return &Session{baseURL: strings.TrimSuffix(baseURL, "/"), clientID: clientID, key: key, http: client, now: time.Now}
}

func (s *Session) Configured() bool {
	return s.baseURL != "" && s.clientID != "" && len(s.key) == ed25519.PrivateKeySize
}

func (s *Session) BaseURL() string { return s.baseURL }

func (s *Session) Token(ctx context.Context) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.token != "" && s.now().Before(s.expires) {
		return s.token, nil
	}
	token, expires, err := s.exchange(ctx)
	if err != nil {
		return "", err
	}
	s.token, s.expires = token, expires
	return token, nil
}

func (s *Session) Invalidate(token string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.token == token {
		s.token = ""
	}
}

func (s *Session) assertion() (string, error) {
	nonce := make([]byte, 16)
	if _, err := rand.Read(nonce); err != nil {
		return "", err
	}
	now := s.now()
	return jwt.SignEdDSA(map[string]any{
		"iss": s.clientID,
		"sub": s.clientID,
		"aud": Audience,
		"iat": now.Unix(),
		"exp": now.Add(assertionLifetime).Unix(),
		"jti": hex.EncodeToString(nonce),
	}, s.key)
}

func (s *Session) exchange(ctx context.Context) (string, time.Time, error) {
	assertion, err := s.assertion()
	if err != nil {
		return "", time.Time{}, fmt.Errorf("sign assertion: %w", err)
	}
	body, err := json.Marshal(map[string]string{"Assertion": assertion})
	if err != nil {
		return "", time.Time{}, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.baseURL+"/integration/token", bytes.NewReader(body))
	if err != nil {
		return "", time.Time{}, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	resp, err := s.http.Do(req)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("integration token request: %w", err)
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return "", time.Time{}, fmt.Errorf("integration token response: %w", err)
	}
	var envelope struct {
		Data struct {
			Token string `json:"Token"`
		} `json:"data"`
	}
	_ = json.Unmarshal(raw, &envelope)
	if resp.StatusCode != http.StatusOK || envelope.Data.Token == "" {
		return "", time.Time{}, fmt.Errorf("%w: status %d", ErrRefused, resp.StatusCode)
	}
	return envelope.Data.Token, s.refreshAt(envelope.Data.Token), nil
}

func (s *Session) refreshAt(token string) time.Time {
	fallback := s.now().Add(5 * time.Minute)
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return fallback
	}
	raw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return fallback
	}
	var claims struct {
		Exp int64 `json:"exp"`
	}
	if json.Unmarshal(raw, &claims) != nil || claims.Exp == 0 {
		return fallback
	}
	return time.Unix(claims.Exp, 0).Add(-time.Minute)
}

func ParsePrivateKey(data []byte) (ed25519.PrivateKey, error) {
	block, _ := pem.Decode(bytes.TrimSpace(data))
	if block == nil {
		return nil, errors.New("signing key is not PEM encoded")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("signing key: %w", err)
	}
	key, ok := parsed.(ed25519.PrivateKey)
	if !ok {
		return nil, errors.New("signing key is not an Ed25519 key")
	}
	return key, nil
}

func PublicKeyLine(key ed25519.PrivateKey) string {
	der, err := x509.MarshalPKIXPublicKey(key.Public())
	if err != nil {
		return ""
	}
	return base64.RawStdEncoding.EncodeToString(der)
}
