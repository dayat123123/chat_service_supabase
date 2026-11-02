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

	"olt-social/janitor/internal/jwt"
)

const (
	maxResponse = 64 << 20
	maxError    = 500
)

type Entry struct {
	ID      int64    `json:"id"`
	Bucket  string   `json:"bucket"`
	Prefix  string   `json:"prefix"`
	Objects []string `json:"objects"`
}

type Result struct {
	ID      int64
	Deleted int
	Error   string
	Release bool
}

type wireResult struct {
	ID      int64   `json:"id"`
	Deleted int     `json:"deleted"`
	Error   *string `json:"error"`
	Release bool    `json:"release"`
}

type PostgREST struct {
	baseURL string
	secret  []byte
	issuer  string
	http    *http.Client
	now     func() time.Time
}

func NewPostgREST(baseURL string, jwtSecret []byte, issuer string, timeout time.Duration) *PostgREST {
	return &PostgREST{
		baseURL: baseURL,
		secret:  jwtSecret,
		issuer:  issuer,
		http:    &http.Client{Timeout: timeout},
		now:     time.Now,
	}
}

func (p *PostgREST) Claim(ctx context.Context, instance string, limit, objects int, lease time.Duration) ([]Entry, error) {
	var entries []Entry
	args := map[string]any{"p_instance": instance, "p_limit": limit, "p_objects": objects, "p_lease_seconds": seconds(lease)}
	if err := p.rpc(ctx, "storage_cleanup_claim", args, &entries); err != nil {
		return nil, err
	}
	return entries, nil
}

func (p *PostgREST) Report(ctx context.Context, instance string, results []Result) (int, error) {
	rows := make([]wireResult, 0, len(results))
	for _, r := range results {
		rows = append(rows, wireResult{ID: r.ID, Deleted: max(r.Deleted, 0), Error: nullable(clip(r.Error, maxError)), Release: r.Release})
	}
	var updated int
	if err := p.rpc(ctx, "storage_cleanup_report", map[string]any{"p_instance": instance, "p_results": rows}, &updated); err != nil {
		return 0, err
	}
	return updated, nil
}

func (p *PostgREST) Ping(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodHead, p.baseURL+"/", nil)
	if err != nil {
		return err
	}
	resp, err := p.http.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	if resp.StatusCode >= 500 {
		return fmt.Errorf("postgrest status %d", resp.StatusCode)
	}
	return nil
}

func (p *PostgREST) rpc(ctx context.Context, fn string, args map[string]any, out any) error {
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
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxResponse+1))
	if err != nil {
		return fmt.Errorf("rpc %s: read response: %w", fn, err)
	}
	if resp.StatusCode >= 300 {
		return fmt.Errorf("rpc %s: status %d%s", fn, resp.StatusCode, reason(data))
	}
	if len(data) > maxResponse {
		return fmt.Errorf("rpc %s: response larger than %d MiB; lower BATCH_SIZE or OBJECTS_PER_ENTRY", fn, maxResponse>>20)
	}
	if len(data) == 0 {
		return nil
	}
	if err := json.Unmarshal(data, out); err != nil {
		return fmt.Errorf("rpc %s: decode response: %w", fn, err)
	}
	return nil
}

func reason(data []byte) string {
	var body struct {
		Message string `json:"message"`
	}
	if json.Unmarshal(data, &body) != nil || strings.TrimSpace(body.Message) == "" {
		return ""
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

func seconds(d time.Duration) int {
	return int((d + time.Second - 1) / time.Second)
}
