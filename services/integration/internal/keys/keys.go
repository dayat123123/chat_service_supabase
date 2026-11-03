package keys

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"slices"
	"strings"
	"sync"
	"time"
)

const (
	ScopeNotify          = "notify"
	ScopeNotifyBroadcast = "notify_broadcast"
	ScopeBotPost         = "bot_post"

	maxKeyLength = 200
	maxEntries   = 10_000
)

type Key struct {
	ID        string   `json:"id"`
	Name      string   `json:"name"`
	Prefix    string   `json:"prefix"`
	Scopes    []string `json:"scopes"`
	RateLimit int      `json:"rate_limit_per_minute"`
	IPAllowed bool     `json:"ip_allowed"`
}

func (k *Key) Has(scope string) bool {
	return k != nil && slices.Contains(k.Scopes, scope)
}

type Lookup interface {
	Authenticate(ctx context.Context, keyHash, ip string) (*Key, error)
}

func Hash(key string) (string, bool) {
	if !wellFormed(key) {
		return "", false
	}
	sum := sha256.Sum256([]byte(key))
	return hex.EncodeToString(sum[:]), true
}

func wellFormed(key string) bool {
	if len(key) < 8 || len(key) > maxKeyLength || !strings.HasPrefix(key, "oik_") {
		return false
	}
	for i := 0; i < len(key); i++ {
		c := key[i]
		if !(c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '_' || c == '-') {
			return false
		}
	}
	return true
}

type entry struct {
	key     *Key
	expires time.Time
}

type Cache struct {
	lookup      Lookup
	ttl         time.Duration
	negativeTTL time.Duration
	now         func() time.Time

	mu    sync.Mutex
	items map[string]entry
}

func NewCache(lookup Lookup, ttl time.Duration) *Cache {
	return &Cache{
		lookup:      lookup,
		ttl:         ttl,
		negativeTTL: min(ttl, 10*time.Second),
		now:         time.Now,
		items:       make(map[string]entry),
	}
}

func (c *Cache) Authenticate(ctx context.Context, keyHash, ip string) (*Key, error) {
	id := keyHash + "|" + ip
	now := c.now()
	c.mu.Lock()
	hit, ok := c.items[id]
	c.mu.Unlock()
	if ok && now.Before(hit.expires) {
		return hit.key, nil
	}
	key, err := c.lookup.Authenticate(ctx, keyHash, ip)
	if err != nil {
		return nil, err
	}
	ttl := c.ttl
	if key == nil {
		ttl = c.negativeTTL
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(c.items) >= maxEntries {
		c.sweep(now)
		if len(c.items) >= maxEntries {
			clear(c.items)
		}
	}
	c.items[id] = entry{key: key, expires: now.Add(ttl)}
	return key, nil
}

func (c *Cache) Forget(keyHash string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	for id := range c.items {
		if strings.HasPrefix(id, keyHash+"|") {
			delete(c.items, id)
		}
	}
}

func (c *Cache) Len() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return len(c.items)
}

func (c *Cache) sweep(now time.Time) {
	for id, e := range c.items {
		if !now.Before(e.expires) {
			delete(c.items, id)
		}
	}
}
