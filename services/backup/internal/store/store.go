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

	"olt-social/backup/internal/jwt"
	"olt-social/backup/internal/settings"
	"olt-social/backup/internal/state"
)

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

type Beat struct {
	Instance       string
	Version        string
	StartedAt      time.Time
	ConfigRevision int64
	State          state.Report
}

func (p *PostgREST) Config(ctx context.Context, known int64) (settings.Settings, error) {
	var reply settings.Settings
	args := map[string]any{"p_revision": nil}
	if known != settings.UnknownRevision {
		args["p_revision"] = known
	}
	if err := p.rpc(ctx, "backup_config", args, &reply); err != nil {
		return settings.Settings{}, err
	}
	return reply, nil
}

func (p *PostgREST) Heartbeat(ctx context.Context, beat Beat) ([]string, error) {
	var reply struct {
		Requests []string `json:"requests"`
	}
	args := map[string]any{
		"p_instance":        beat.Instance,
		"p_version":         beat.Version,
		"p_started_at":      beat.StartedAt.UTC().Format(time.RFC3339),
		"p_config_revision": nil,
		"p_state":           beat.State,
	}
	if beat.ConfigRevision != settings.UnknownRevision {
		args["p_config_revision"] = beat.ConfigRevision
	}
	if err := p.rpc(ctx, "backup_heartbeat", args, &reply); err != nil {
		return nil, err
	}
	return reply.Requests, nil
}

func (p *PostgREST) Record(ctx context.Context, instance string, run state.Run) error {
	if run.Detail == nil {
		run.Detail = map[string]any{}
	}
	return p.rpc(ctx, "backup_record", map[string]any{"p_instance": instance, "p_run": run}, nil)
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
	data, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return fmt.Errorf("rpc %s: read response: %w", fn, err)
	}
	if resp.StatusCode >= 300 {
		return fmt.Errorf("rpc %s: status %d%s", fn, resp.StatusCode, reason(data))
	}
	if out == nil || len(bytes.TrimSpace(data)) == 0 {
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
		return fmt.Sprintf(": %s (%s)", strings.TrimSpace(body.Message), body.Code)
	}
	return ": " + strings.TrimSpace(body.Message)
}
