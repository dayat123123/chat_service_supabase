package store

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"olt-social/media/internal/heartbeat"
	"olt-social/media/internal/jwt"
)

const (
	maxResponse = 64 << 10
	maxError    = 500
)

type PostgREST struct {
	baseURL string
	secret  []byte
	issuer  string
	http    *http.Client
	now     func() time.Time
}

func NewPostgREST(baseURL string, jwtSecret []byte, issuer string) *PostgREST {
	return &PostgREST{
		baseURL: baseURL,
		secret:  jwtSecret,
		issuer:  issuer,
		http:    &http.Client{Timeout: 15 * time.Second},
		now:     time.Now,
	}
}

func (p *PostgREST) Heartbeat(ctx context.Context, beat heartbeat.Beat) error {
	detail := beat.Detail
	if detail == nil {
		detail = map[string]any{}
	}
	return p.rpc(ctx, "service_heartbeat", map[string]any{
		"p_service":    beat.Service,
		"p_instance":   beat.Instance,
		"p_version":    beat.Version,
		"p_started_at": beat.StartedAt.UTC().Format(time.RFC3339),
		"p_status":     beat.Status,
		"p_error":      nullable(clip(beat.Error, maxError)),
		"p_detail":     detail,
	})
}

func (p *PostgREST) rpc(ctx context.Context, fn string, args map[string]any) error {
	body, err := json.Marshal(args)
	if err != nil {
		return err
	}
	token, err := jwt.ServiceRole(p.secret, p.issuer, p.now())
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL+"/rpc/"+fn, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Profile", "public")
	req.Header.Set("Accept-Profile", "public")
	resp, err := p.http.Do(req)
	if err != nil {
		return fmt.Errorf("rpc %s: %w", fn, err)
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxResponse))
	if err != nil {
		return fmt.Errorf("rpc %s: read response: %w", fn, err)
	}
	if resp.StatusCode >= 300 {
		return fmt.Errorf("rpc %s: status %d%s", fn, resp.StatusCode, reason(data))
	}
	return nil
}

func reason(data []byte) string {
	var body struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	}
	if json.Unmarshal(data, &body) != nil || strings.TrimSpace(body.Message) == "" {
		return ""
	}
	if body.Code != "" {
		return ": " + body.Code + " " + strings.TrimSpace(body.Message)
	}
	return ": " + strings.TrimSpace(body.Message)
}

func clip(s string, n int) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}

func nullable(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
