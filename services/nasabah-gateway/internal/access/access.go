package access

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"slices"
	"sync"
	"time"

	"olt-social/nasabah-gateway/internal/jwt"
)

type Grant struct {
	AgentID     string   `json:"agent_id"`
	AgentCode   string   `json:"agent_code"`
	DisplayName string   `json:"display_name"`
	Permissions []string `json:"permissions"`
}

func (g Grant) Allows(permissions []string) bool {
	for _, p := range permissions {
		if slices.Contains(g.Permissions, p) {
			return true
		}
	}
	return false
}

type Store interface {
	Grant(ctx context.Context, userID string) (*Grant, error)
	Audit(ctx context.Context, userID, action string, details map[string]any) error
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
		http:    &http.Client{Timeout: 5 * time.Second},
		now:     time.Now,
	}
}

func (p *PostgREST) Grant(ctx context.Context, userID string) (*Grant, error) {
	var grant *Grant
	if err := p.rpc(ctx, "nasabah_access", map[string]any{"p_user_id": userID}, &grant); err != nil {
		return nil, err
	}
	if grant == nil || len(grant.Permissions) == 0 {
		return nil, nil
	}
	return grant, nil
}

func (p *PostgREST) Audit(ctx context.Context, userID, action string, details map[string]any) error {
	var ignored any
	return p.rpc(ctx, "nasabah_audit", map[string]any{"p_user_id": userID, "p_action": action, "p_details": details}, &ignored)
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
	req.Header.Set("Content-Profile", "cs_api")
	req.Header.Set("Accept-Profile", "cs_api")
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
		return fmt.Errorf("rpc %s: status %d", fn, resp.StatusCode)
	}
	if len(data) == 0 {
		return nil
	}
	if err := json.Unmarshal(data, out); err != nil {
		return fmt.Errorf("rpc %s: decode response: %w", fn, err)
	}
	return nil
}

type entry struct {
	grant   *Grant
	expires time.Time
}

type Cache struct {
	store     Store
	ttl       time.Duration
	denialTTL time.Duration
	now       func() time.Time

	mu      sync.Mutex
	entries map[string]entry
}

func NewCache(store Store, ttl time.Duration) *Cache {
	return &Cache{store: store, ttl: ttl, denialTTL: min(ttl, 5*time.Second), now: time.Now, entries: map[string]entry{}}
}

func (c *Cache) Grant(ctx context.Context, userID string) (*Grant, error) {
	now := c.now()
	c.mu.Lock()
	if e, ok := c.entries[userID]; ok && now.Before(e.expires) {
		c.mu.Unlock()
		return e.grant, nil
	}
	c.mu.Unlock()

	grant, err := c.store.Grant(ctx, userID)
	if err != nil {
		return nil, err
	}
	ttl := c.ttl
	if grant == nil {
		ttl = c.denialTTL
	}
	c.mu.Lock()
	if len(c.entries) > 10_000 {
		clear(c.entries)
	}
	c.entries[userID] = entry{grant: grant, expires: now.Add(ttl)}
	c.mu.Unlock()
	return grant, nil
}

func (c *Cache) Audit(ctx context.Context, userID, action string, details map[string]any) error {
	return c.store.Audit(ctx, userID, action, details)
}
