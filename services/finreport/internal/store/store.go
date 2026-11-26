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

	"olt-social/finreport/internal/heartbeat"
	"olt-social/finreport/internal/jwt"
	"olt-social/finreport/internal/keys"
	"olt-social/finreport/internal/xbrl"
)

const (
	maxResponse = 8 << 20
	maxError    = 500
	dateLayout  = "2006-01-02"
)

var ErrUnavailable = errors.New("database API unavailable")

type APIError struct {
	Status int
	Code   string
	Detail string
}

func (e *APIError) Error() string {
	return fmt.Sprintf("status %d: %s", e.Status, e.Code)
}

type Job struct {
	ID         string `json:"id"`
	ObjectName string `json:"object_name"`
	SHA256     string `json:"sha256"`
	SizeBytes  int64  `json:"size_bytes"`
	Attempts   int    `json:"attempts"`
}

type Version struct {
	ID          string     `json:"id"`
	Period      string     `json:"period"`
	PeriodStart string     `json:"period_start"`
	PeriodEnd   string     `json:"period_end"`
	Facts       xbrl.Facts `json:"facts"`
}

func (v *Version) Dates() (time.Time, time.Time, error) {
	start, err := time.Parse(dateLayout, v.PeriodStart)
	if err != nil {
		return time.Time{}, time.Time{}, err
	}
	end, err := time.Parse(dateLayout, v.PeriodEnd)
	return start, end, err
}

type Related struct {
	Previous  *Version `json:"previous"`
	PriorYear *Version `json:"prior_year"`
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

func (p *PostgREST) Authenticate(ctx context.Context, keyHash, ip string) (*keys.Key, error) {
	data, err := p.call(ctx, "integration_authenticate", map[string]any{"p_key_hash": keyHash, "p_ip": nullable(ip)})
	if err != nil {
		return nil, err
	}
	if trimmed := bytes.TrimSpace(data); len(trimmed) == 0 || bytes.Equal(trimmed, []byte("null")) {
		return nil, nil
	}
	var key keys.Key
	if err := json.Unmarshal(data, &key); err != nil {
		return nil, fmt.Errorf("%w: decode integration_authenticate: %v", ErrUnavailable, err)
	}
	if key.ID == "" {
		return nil, nil
	}
	return &key, nil
}

func (p *PostgREST) Submit(ctx context.Context, keyID, sha string, size int64, ip string) (json.RawMessage, error) {
	return p.call(ctx, "finreport_submit", map[string]any{"p_key_id": keyID, "p_sha256": sha, "p_size": size,
		"p_ip": nullable(ip)})
}

func (p *PostgREST) File(ctx context.Context, keyID, id, ip string) (json.RawMessage, error) {
	return p.call(ctx, "finreport_file", map[string]any{"p_key_id": keyID, "p_id": id, "p_ip": nullable(ip)})
}

func (p *PostgREST) Claim(ctx context.Context, instance string, lease time.Duration) (*Job, error) {
	data, err := p.call(ctx, "finreport_claim", map[string]any{"p_instance": instance,
		"p_lease_seconds": int(lease / time.Second)})
	if err != nil {
		return nil, err
	}
	if trimmed := bytes.TrimSpace(data); len(trimmed) == 0 || bytes.Equal(trimmed, []byte("null")) {
		return nil, nil
	}
	var job Job
	if err := json.Unmarshal(data, &job); err != nil {
		return nil, fmt.Errorf("%w: decode finreport_claim: %v", ErrUnavailable, err)
	}
	return &job, nil
}

func (p *PostgREST) Related(ctx context.Context, entity string, start, end time.Time) (*Related, error) {
	data, err := p.call(ctx, "finreport_related", map[string]any{"p_entity": entity,
		"p_period_start": start.Format(dateLayout), "p_period_end": end.Format(dateLayout)})
	if err != nil {
		return nil, err
	}
	var related Related
	if err := json.Unmarshal(data, &related); err != nil {
		return nil, fmt.Errorf("%w: decode finreport_related: %v", ErrUnavailable, err)
	}
	return &related, nil
}

func (p *PostgREST) Complete(ctx context.Context, fileID, instance string, report any) (json.RawMessage, error) {
	return p.call(ctx, "finreport_complete", map[string]any{"p_file": fileID, "p_instance": instance, "p_report": report})
}

func (p *PostgREST) Fail(ctx context.Context, fileID, instance, code, detail string, retry bool) error {
	_, err := p.call(ctx, "finreport_fail", map[string]any{"p_file": fileID, "p_instance": instance, "p_code": code,
		"p_detail": nullable(clip(detail, maxError)), "p_retry": retry})
	return err
}

func (p *PostgREST) Heartbeat(ctx context.Context, beat heartbeat.Beat) error {
	detail := beat.Detail
	if detail == nil {
		detail = map[string]any{}
	}
	_, err := p.call(ctx, "service_heartbeat", map[string]any{
		"p_service":    beat.Service,
		"p_instance":   beat.Instance,
		"p_version":    beat.Version,
		"p_started_at": beat.StartedAt.UTC().Format(time.RFC3339),
		"p_status":     beat.Status,
		"p_error":      nullable(clip(beat.Error, maxError)),
		"p_detail":     detail,
	})
	return err
}

func (p *PostgREST) call(ctx context.Context, fn string, args map[string]any) (json.RawMessage, error) {
	body, err := json.Marshal(args)
	if err != nil {
		return nil, err
	}
	token, err := jwt.ServiceRole(p.secret, p.issuer, p.now())
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL+"/rpc/"+fn, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Profile", "public")
	req.Header.Set("Accept-Profile", "public")
	resp, err := p.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: rpc %s: %v", ErrUnavailable, fn, err)
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxResponse))
	if err != nil {
		return nil, fmt.Errorf("%w: rpc %s: read response: %v", ErrUnavailable, fn, err)
	}
	if resp.StatusCode < 300 {
		return data, nil
	}
	var e struct {
		Code    string `json:"code"`
		Message string `json:"message"`
		Details string `json:"details"`
	}
	_ = json.Unmarshal(data, &e)
	if resp.StatusCode < 500 && strings.HasPrefix(e.Code, "PT") && e.Message != "" {
		return nil, &APIError{Status: resp.StatusCode, Code: e.Message, Detail: clip(e.Details, maxError)}
	}
	return nil, fmt.Errorf("%w: rpc %s: status %d %s", ErrUnavailable, fn, resp.StatusCode, clip(e.Code+" "+e.Message, 200))
}

func clip(s string, n int) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}
