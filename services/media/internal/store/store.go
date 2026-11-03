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

	"olt-social/media/internal/heartbeat"
	"olt-social/media/internal/jwt"
	"olt-social/media/internal/moderation"
)

const (
	maxResponse = 64 << 10
	maxError    = 500
)

type RPCError struct {
	Status  int
	Code    string
	Message string
}

func (e *RPCError) Error() string {
	return fmt.Sprintf("status %d%s", e.Status, reasonText(e.Code, e.Message))
}

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
	}, nil)
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

func (p *PostgREST) RecordHold(ctx context.Context, h moderation.HoldRequest) (int64, error) {
	var id int64
	err := p.rpc(ctx, "media_hold", map[string]any{
		"p_bucket":   h.Bucket,
		"p_name":     h.Path,
		"p_uploader": h.Uploader,
		"p_model":    h.Model,
		"p_scores":   h.Scores,
		"p_category": h.Category,
		"p_score":    h.Score,
		"p_revision": h.Revision,
	}, &id)
	return id, err
}

func (p *PostgREST) CancelHold(ctx context.Context, id int64) error {
	return p.rpc(ctx, "media_hold_cancel", map[string]any{"p_id": id}, nil)
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
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxResponse))
	if err != nil {
		return fmt.Errorf("rpc %s: read response: %w", fn, err)
	}
	if resp.StatusCode >= 300 {
		var reply struct {
			Code    string `json:"code"`
			Message string `json:"message"`
		}
		_ = json.Unmarshal(data, &reply)
		return fmt.Errorf("rpc %s: %w", fn, &RPCError{Status: resp.StatusCode, Code: reply.Code, Message: strings.TrimSpace(reply.Message)})
	}
	if out != nil {
		if err := json.Unmarshal(data, out); err != nil {
			return fmt.Errorf("rpc %s: decode reply: %w", fn, err)
		}
	}
	return nil
}

func reasonText(code, message string) string {
	switch {
	case message == "":
		return ""
	case code != "":
		return ": " + code + " " + message
	}
	return ": " + message
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
