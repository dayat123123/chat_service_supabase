package csadmin

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"
)

var ErrLoginFailed = errors.New("customer admin login failed")

type Session struct {
	baseURL  string
	username string
	password string
	http     *http.Client
	now      func() time.Time

	mu      sync.Mutex
	token   string
	expires time.Time
}

func NewSession(baseURL, username, password string, client *http.Client) *Session {
	if client == nil {
		client = &http.Client{Timeout: 15 * time.Second}
	}
	return &Session{baseURL: strings.TrimSuffix(baseURL, "/"), username: username, password: password, http: client, now: time.Now}
}

func (s *Session) Configured() bool {
	return s.baseURL != "" && s.username != "" && s.password != ""
}

func (s *Session) BaseURL() string { return s.baseURL }

func (s *Session) LoginID() string { return s.username }

func (s *Session) Token(ctx context.Context) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.token != "" && s.now().Before(s.expires) {
		return s.token, nil
	}
	token, expires, err := s.login(ctx)
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

func (s *Session) login(ctx context.Context) (string, time.Time, error) {
	body, err := json.Marshal(map[string]string{"LoginId": s.username, "Password": s.password})
	if err != nil {
		return "", time.Time{}, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.baseURL+"/cs/login", bytes.NewReader(body))
	if err != nil {
		return "", time.Time{}, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	resp, err := s.http.Do(req)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("login request: %w", err)
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return "", time.Time{}, fmt.Errorf("login response: %w", err)
	}
	var envelope struct {
		Message string `json:"message"`
		Data    struct {
			Token string `json:"Token"`
		} `json:"data"`
	}
	_ = json.Unmarshal(raw, &envelope)
	if resp.StatusCode != http.StatusOK || envelope.Data.Token == "" {
		return "", time.Time{}, fmt.Errorf("%w: status %d", ErrLoginFailed, resp.StatusCode)
	}
	return envelope.Data.Token, s.refreshAt(envelope.Data.Token), nil
}

func (s *Session) refreshAt(token string) time.Time {
	fallback := s.now().Add(30 * time.Minute)
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
