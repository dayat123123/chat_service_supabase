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

	"olt-social/notifier/internal/jwt"
	"olt-social/notifier/internal/push"
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
		http:    &http.Client{Timeout: 10 * time.Second},
		now:     time.Now,
	}
}

type wireJob struct {
	ID          int64          `json:"id"`
	Token       string         `json:"token"`
	Platform    string         `json:"platform"`
	Kind        string         `json:"kind"`
	Title       string         `json:"title"`
	Body        string         `json:"body"`
	Data        map[string]any `json:"data"`
	CollapseKey *string        `json:"collapse_key"`
	Badge       *int           `json:"badge"`
	Priority    string         `json:"priority"`
	TTLSeconds  int            `json:"ttl_seconds"`
	Attempt     int            `json:"attempt"`
}

func (w wireJob) job() push.Job {
	data := make(map[string]string, len(w.Data))
	for key, value := range w.Data {
		switch v := value.(type) {
		case nil:
		case string:
			data[key] = v
		default:
			encoded, _ := json.Marshal(v)
			data[key] = string(encoded)
		}
	}
	job := push.Job{
		ID:         w.ID,
		Token:      w.Token,
		Platform:   w.Platform,
		Kind:       w.Kind,
		Title:      w.Title,
		Body:       w.Body,
		Data:       data,
		Badge:      w.Badge,
		Priority:   w.Priority,
		TTLSeconds: w.TTLSeconds,
		Attempt:    w.Attempt,
	}
	if w.CollapseKey != nil {
		job.CollapseKey = *w.CollapseKey
	}
	return job
}

type wireResult struct {
	ID         int64        `json:"id"`
	Outcome    push.Outcome `json:"outcome"`
	Error      *string      `json:"error"`
	RetryAfter *int         `json:"retry_after"`
}

func (p *PostgREST) Claim(ctx context.Context, instance string, limit int, lease time.Duration) ([]push.Job, error) {
	var rows []wireJob
	args := map[string]any{"p_instance": instance, "p_limit": limit, "p_lease_seconds": seconds(lease)}
	if err := p.rpc(ctx, "push_claim", args, &rows); err != nil {
		return nil, err
	}
	jobs := make([]push.Job, 0, len(rows))
	for _, row := range rows {
		jobs = append(jobs, row.job())
	}
	return jobs, nil
}

func (p *PostgREST) Report(ctx context.Context, instance string, results []push.Result) (int, error) {
	rows := make([]wireResult, 0, len(results))
	for _, r := range results {
		row := wireResult{ID: r.ID, Outcome: r.Outcome, Error: nullable(r.Error)}
		if r.RetryAfter > 0 {
			after := seconds(r.RetryAfter)
			row.RetryAfter = &after
		}
		rows = append(rows, row)
	}
	var updated int
	if err := p.rpc(ctx, "push_report", map[string]any{"p_instance": instance, "p_results": rows}, &updated); err != nil {
		return 0, err
	}
	return updated, nil
}

func (p *PostgREST) Heartbeat(ctx context.Context, beat push.Heartbeat) (int, error) {
	var reply struct {
		Queued int `json:"queued"`
	}
	args := map[string]any{
		"p_instance":   beat.Instance,
		"p_version":    beat.Version,
		"p_configured": beat.Configured,
		"p_project_id": nullable(beat.ProjectID),
		"p_error":      nullable(beat.Error),
		"p_started_at": beat.StartedAt.UTC().Format(time.RFC3339),
	}
	if err := p.rpc(ctx, "push_heartbeat", args, &reply); err != nil {
		return 0, err
	}
	return reply.Queued, nil
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
	now := p.now()
	token, err := jwt.Sign(map[string]any{"alg": "HS256", "typ": "JWT"},
		map[string]any{"iss": p.issuer, "role": "service_role", "iat": now.Unix(), "exp": now.Add(time.Minute).Unix()}, p.secret)
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
	data, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return fmt.Errorf("rpc %s: read response: %w", fn, err)
	}
	if resp.StatusCode >= 300 {
		return fmt.Errorf("rpc %s: status %d%s", fn, resp.StatusCode, reason(data))
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

func nullable(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func seconds(d time.Duration) int {
	return int((d + time.Second - 1) / time.Second)
}
