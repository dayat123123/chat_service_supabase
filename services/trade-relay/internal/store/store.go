package store

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const maxResponse = 64 << 20

type HTTPError struct {
	Status int
	Code   string
}

func (e *HTTPError) Error() string {
	if e.Code != "" {
		return fmt.Sprintf("status %d (%s)", e.Status, e.Code)
	}
	return fmt.Sprintf("status %d", e.Status)
}

func Rejected(err error) bool {
	var h *HTTPError
	return errors.As(err, &h) && h.Status >= 400 && h.Status < 500 && h.Status != 401 && h.Status != 408 && h.Status != 429
}

type AES struct {
	Mode string `json:"mode"`
	Key  string `json:"key"`
	IV   string `json:"iv"`
}

type Accounts struct {
	Sharers []string `json:"sharers"`
	Owners  []string `json:"owners"`
	Boards  []string `json:"boards"`
}

type Config struct {
	Enabled             bool
	Version             int64
	AccountsVersion     int64
	ReconnectGeneration int64
	RestartGeneration   int64
	HasConnection       bool
	IProxyAddr          string
	Identity            string
	HeartbeatSeconds    int
	AES                 *AES
	Accounts            *Accounts
}

type Result struct {
	Counts map[string]int64 `json:"counts"`
}

type Client struct {
	baseURL string
	secret  []byte
	issuer  string
	http    *http.Client
}

func New(baseURL string, secret []byte, issuer string, timeout time.Duration) *Client {
	return &Client{
		baseURL: strings.TrimRight(baseURL, "/"),
		secret:  secret,
		issuer:  issuer,
		http:    &http.Client{Timeout: timeout},
	}
}

var b64 = base64.RawURLEncoding

func (c *Client) token(now time.Time) (string, error) {
	head, _ := json.Marshal(map[string]any{"alg": "HS256", "typ": "JWT"})
	claims, err := json.Marshal(map[string]any{"iss": c.issuer, "role": "service_role", "iat": now.Unix(),
		"exp": now.Add(time.Minute).Unix()})
	if err != nil {
		return "", err
	}
	input := b64.EncodeToString(head) + "." + b64.EncodeToString(claims)
	h := hmac.New(sha256.New, c.secret)
	h.Write([]byte(input))
	return input + "." + b64.EncodeToString(h.Sum(nil)), nil
}

func (c *Client) rpc(ctx context.Context, fn string, args map[string]any, out any) error {
	body, err := json.Marshal(args)
	if err != nil {
		return fmt.Errorf("rpc %s: encode: %w", fn, err)
	}
	token, err := c.token(time.Now())
	if err != nil {
		return fmt.Errorf("rpc %s: token: %w", fn, err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/rpc/"+fn, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("rpc %s: %w", fn, err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Profile", "public")
	req.Header.Set("Accept-Profile", "public")
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("rpc %s: %w", fn, err)
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxResponse+1))
	if err != nil {
		return fmt.Errorf("rpc %s: read: %w", fn, err)
	}
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		var pg struct {
			Message string `json:"message"`
		}
		_ = json.Unmarshal(data, &pg)
		code := pg.Message
		if len(code) > 80 {
			code = code[:80]
		}
		return fmt.Errorf("rpc %s: %w", fn, &HTTPError{Status: resp.StatusCode, Code: code})
	}
	if len(data) > maxResponse {
		return fmt.Errorf("rpc %s: response too large", fn)
	}
	if out == nil || len(bytes.TrimSpace(data)) == 0 {
		return nil
	}
	if err := json.Unmarshal(data, out); err != nil {
		return fmt.Errorf("rpc %s: decode: %w", fn, err)
	}
	return nil
}

func (c *Client) Config(ctx context.Context, instance string, knownVersion, knownAccounts int64) (Config, error) {
	args := map[string]any{"p_instance": instance}
	if knownVersion > 0 {
		args["p_known_version"] = knownVersion
	}
	if knownAccounts > 0 {
		args["p_known_accounts"] = knownAccounts
	}
	var raw map[string]json.RawMessage
	if err := c.rpc(ctx, "trade_relay_config", args, &raw); err != nil {
		return Config{}, err
	}
	return ParseConfig(raw)
}

func ParseConfig(raw map[string]json.RawMessage) (Config, error) {
	var cfg Config
	fields := []struct {
		key string
		out any
	}{
		{"enabled", &cfg.Enabled},
		{"version", &cfg.Version},
		{"accounts_version", &cfg.AccountsVersion},
		{"reconnect_generation", &cfg.ReconnectGeneration},
		{"restart_generation", &cfg.RestartGeneration},
	}
	for _, f := range fields {
		v, ok := raw[f.key]
		if !ok {
			return Config{}, fmt.Errorf("config: missing %s", f.key)
		}
		if err := json.Unmarshal(v, f.out); err != nil {
			return Config{}, fmt.Errorf("config: %s: %w", f.key, err)
		}
	}
	if v, ok := raw["identity"]; ok {
		cfg.HasConnection = true
		var addr *string
		if err := json.Unmarshal(raw["iproxy_addr"], &addr); err != nil && raw["iproxy_addr"] != nil {
			return Config{}, fmt.Errorf("config: iproxy_addr: %w", err)
		}
		if addr != nil {
			cfg.IProxyAddr = *addr
		}
		if err := json.Unmarshal(v, &cfg.Identity); err != nil {
			return Config{}, fmt.Errorf("config: identity: %w", err)
		}
		if hb, ok := raw["heartbeat_seconds"]; ok {
			if err := json.Unmarshal(hb, &cfg.HeartbeatSeconds); err != nil {
				return Config{}, fmt.Errorf("config: heartbeat_seconds: %w", err)
			}
		}
		if a, ok := raw["aes"]; ok && string(a) != "null" {
			cfg.AES = &AES{}
			if err := json.Unmarshal(a, cfg.AES); err != nil {
				return Config{}, fmt.Errorf("config: aes: %w", err)
			}
		}
	}
	if a, ok := raw["accounts"]; ok {
		cfg.Accounts = &Accounts{}
		if err := json.Unmarshal(a, cfg.Accounts); err != nil {
			return Config{}, fmt.Errorf("config: accounts: %w", err)
		}
	}
	return cfg, nil
}

func (c *Client) Events(ctx context.Context, instance string, events any) (Result, error) {
	var res Result
	err := c.rpc(ctx, "trade_relay_events", map[string]any{"p_instance": instance, "p_events": events}, &res)
	return res, err
}

func (c *Client) Status(ctx context.Context, instance string, status map[string]any) error {
	return c.rpc(ctx, "trade_relay_status", map[string]any{"p_instance": instance, "p_status": status}, nil)
}

func (c *Client) Heartbeat(ctx context.Context, instance, version string, started time.Time, status, errText string,
	detail map[string]any) error {
	args := map[string]any{
		"p_service":    "trade-relay",
		"p_instance":   instance,
		"p_version":    version,
		"p_started_at": started.UTC().Format(time.RFC3339),
		"p_status":     status,
		"p_detail":     detail,
	}
	if errText != "" {
		args["p_error"] = errText
	}
	return c.rpc(ctx, "service_heartbeat", args, nil)
}
