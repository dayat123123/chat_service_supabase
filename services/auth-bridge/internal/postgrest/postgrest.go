package postgrest

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math/rand/v2"
	"net/http"
	"time"

	"olt-social/auth-bridge/internal/exchange"
	"olt-social/auth-bridge/internal/heartbeat"
)

type ServiceTokenSource interface {
	ServiceToken() (string, error)
}

type Client struct {
	baseURL  string
	tokens   ServiceTokenSource
	http     *http.Client
	attempts int
	backoff  time.Duration
}

func NewClient(baseURL string, tokens ServiceTokenSource) *Client {
	return &Client{
		baseURL:  baseURL,
		tokens:   tokens,
		http:     &http.Client{Timeout: 5 * time.Second},
		attempts: 3,
		backoff:  100 * time.Millisecond,
	}
}

func (c *Client) UpsertProfile(ctx context.Context, in exchange.ProfileInput) (exchange.Profile, error) {
	body, err := json.Marshal(map[string]any{
		"p_id":           in.ID,
		"p_olt_user_id":  in.OLTUserID,
		"p_username":     in.Username,
		"p_display_name": nullable(in.DisplayName),
		"p_email":        nullable(in.Email),
	})
	if err != nil {
		return exchange.Profile{}, err
	}

	var profile exchange.Profile
	if err := c.rpc(ctx, "upsert_olt_profile", body, &profile); err != nil {
		return exchange.Profile{}, err
	}
	return profile, nil
}

func (c *Client) ReplaceAccountLinks(ctx context.Context, profileID string, accounts []string) (int, error) {
	if accounts == nil {
		accounts = []string{}
	}
	body, err := json.Marshal(map[string]any{"p_profile_id": profileID, "p_accounts": accounts})
	if err != nil {
		return 0, err
	}
	var out struct {
		Linked int `json:"linked"`
	}
	if err := c.rpc(ctx, "set_olt_account_links", body, &out); err != nil {
		return 0, err
	}
	return out.Linked, nil
}

func (c *Client) Heartbeat(ctx context.Context, beat heartbeat.Beat) error {
	detail := beat.Detail
	if detail == nil {
		detail = map[string]any{}
	}
	body, err := json.Marshal(map[string]any{
		"p_service":    beat.Service,
		"p_instance":   beat.Instance,
		"p_version":    beat.Version,
		"p_started_at": beat.StartedAt.UTC().Format(time.RFC3339),
		"p_status":     beat.Status,
		"p_error":      nullable(beat.Error),
		"p_detail":     detail,
	})
	if err != nil {
		return err
	}
	return c.rpc(ctx, "service_heartbeat", body, nil)
}

func (c *Client) Ping(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodHead, c.baseURL+"/", nil)
	if err != nil {
		return err
	}
	tok, err := c.tokens.ServiceToken()
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	if resp.StatusCode >= 500 {
		return fmt.Errorf("postgrest status %d", resp.StatusCode)
	}
	return nil
}

func (c *Client) rpc(ctx context.Context, fn string, body []byte, out any) error {
	var err error
	for attempt := 0; attempt < c.attempts; attempt++ {
		if attempt > 0 {
			backoff := c.backoff << (attempt - 1)
			select {
			case <-ctx.Done():
				return fmt.Errorf("rpc %s: %w (last error: %v)", fn, ctx.Err(), err)
			case <-time.After(backoff + time.Duration(rand.Int64N(int64(backoff)/2+1))):
			}
		}
		var retry bool
		retry, err = c.rpcOnce(ctx, fn, body, out)
		if err == nil || !retry {
			return err
		}
	}
	return err
}

func (c *Client) rpcOnce(ctx context.Context, fn string, body []byte, out any) (retry bool, err error) {
	tok, err := c.tokens.ServiceToken()
	if err != nil {
		return false, fmt.Errorf("service token: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/rpc/"+fn, bytes.NewReader(body))
	if err != nil {
		return false, err
	}
	req.Header.Set("Authorization", "Bearer "+tok)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return ctx.Err() == nil, fmt.Errorf("rpc %s: %w", fn, err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return true, fmt.Errorf("rpc %s: read response: %w", fn, err)
	}
	if resp.StatusCode >= 300 {
		return resp.StatusCode >= 500, fmt.Errorf("rpc %s: status %d: %s", fn, resp.StatusCode, truncate(data, 300))
	}
	if out == nil {
		return false, nil
	}
	if err := json.Unmarshal(data, out); err != nil {
		return false, fmt.Errorf("rpc %s: decode response: %w", fn, err)
	}
	return false, nil
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func truncate(b []byte, n int) string {
	if len(b) > n {
		return string(b[:n]) + "…"
	}
	return string(b)
}
