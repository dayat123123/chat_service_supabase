package store

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"olt-social/link-preview/internal/heartbeat"
	"olt-social/link-preview/internal/jwt"
	"olt-social/link-preview/internal/moderation"
)

const (
	maxResponse = 4 << 20
	maxError    = 300

	StatusOK      = "ok"
	StatusEmpty   = "empty"
	StatusBlocked = "blocked"
	StatusFailed  = "failed"
	StatusRetry   = "retry"
	StatusRelease = "release"

	VerdictAllow       = "allow"
	VerdictHold        = "hold"
	VerdictBlock       = "block"
	VerdictUnreadable  = "unreadable"
	VerdictUnavailable = "unavailable"
)

type Entry struct {
	URLHash string `json:"url_hash"`
	URL     string `json:"url"`
	Attempt int    `json:"attempt"`
}

type Result struct {
	URLHash     string `json:"url_hash"`
	Status      string `json:"status"`
	FinalURL    string `json:"final_url,omitempty"`
	Title       string `json:"title,omitempty"`
	Description string `json:"description,omitempty"`
	SiteName    string `json:"site_name,omitempty"`
	ImagePath   string `json:"image_path,omitempty"`
	ImageWidth  int    `json:"image_width,omitempty"`
	ImageHeight int    `json:"image_height,omitempty"`
	Error       string `json:"error,omitempty"`
	ImageCheck
}

type ImageCheck struct {
	ImageSHA256        string             `json:"image_sha256,omitempty"`
	ImageVerdict       string             `json:"image_verdict,omitempty"`
	ImageCategory      string             `json:"image_category,omitempty"`
	ImageScore         *float64           `json:"image_score,omitempty"`
	ImageModel         string             `json:"image_model,omitempty"`
	ImageScores        map[string]float64 `json:"image_scores,omitempty"`
	ThresholdsRevision int64              `json:"thresholds_revision,omitempty"`
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

func (p *PostgREST) Claim(ctx context.Context, instance string, limit int, lease time.Duration) ([]Entry, error) {
	var entries []Entry
	args := map[string]any{"p_instance": instance, "p_limit": limit, "p_lease_seconds": seconds(lease)}
	if err := p.rpc(ctx, "link_preview_claim", args, &entries); err != nil {
		return nil, err
	}
	return entries, nil
}

func (p *PostgREST) Report(ctx context.Context, instance string, results []Result) (int, error) {
	rows := make([]Result, 0, len(results))
	for _, r := range results {
		r.Error = clip(r.Error, maxError)
		rows = append(rows, r)
	}
	var updated int
	if err := p.rpc(ctx, "link_preview_report", map[string]any{"p_instance": instance, "p_results": rows}, &updated); err != nil {
		return 0, err
	}
	return updated, nil
}

func (p *PostgREST) ModerationConfig(ctx context.Context, known int64) (moderation.Config, error) {
	args := map[string]any{"p_revision": nil}
	if known != moderation.UnknownRevision {
		args["p_revision"] = known
	}
	var reply struct {
		Revision   int64                       `json:"revision"`
		Unchanged  bool                        `json:"unchanged"`
		Thresholds map[string]moderation.Limit `json:"thresholds"`
	}
	if err := p.rpc(ctx, "media_moderation_config", args, &reply); err != nil {
		return moderation.Config{}, err
	}
	if !reply.Unchanged && reply.Thresholds == nil {
		return moderation.Config{}, errors.New("rpc media_moderation_config: reply without thresholds")
	}
	return moderation.Config{Revision: reply.Revision, Unchanged: reply.Unchanged, Limits: reply.Thresholds}, nil
}

func (p *PostgREST) CachedScores(ctx context.Context, sha256 string) (moderation.Result, bool, error) {
	var reply *moderation.Result
	if err := p.rpc(ctx, "link_preview_image_scores", map[string]any{"p_sha256": sha256}, &reply); err != nil {
		return moderation.Result{}, false, err
	}
	if reply == nil || reply.Model == "" || len(reply.Scores) == 0 {
		return moderation.Result{}, false, nil
	}
	return *reply, true, nil
}

func (p *PostgREST) Heartbeat(ctx context.Context, beat heartbeat.Beat) error {
	detail := beat.Detail
	if detail == nil {
		detail = map[string]any{}
	}
	var discard json.RawMessage
	return p.rpc(ctx, "service_heartbeat", map[string]any{
		"p_service":    beat.Service,
		"p_instance":   beat.Instance,
		"p_version":    beat.Version,
		"p_started_at": beat.StartedAt.UTC().Format(time.RFC3339),
		"p_status":     beat.Status,
		"p_error":      nullable(clip(beat.Error, 500)),
		"p_detail":     detail,
	}, &discard)
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
		return fmt.Errorf("rpc %s: response larger than %d MiB", fn, maxResponse>>20)
	}
	if len(bytes.TrimSpace(data)) == 0 {
		return nil
	}
	if err := json.Unmarshal(data, out); err != nil {
		return fmt.Errorf("rpc %s: decode response: %w", fn, err)
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

func seconds(d time.Duration) int {
	return int((d + time.Second - 1) / time.Second)
}
