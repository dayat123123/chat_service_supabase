package exchange

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
)

type MemoryCache struct {
	maxItems int
	now      func() time.Time

	mu    sync.Mutex
	items map[[32]byte]memoryEntry
}

type memoryEntry struct {
	identity Identity
	expires  time.Time
}

func NewMemoryCache() *MemoryCache {
	return &MemoryCache{maxItems: 10_000, now: time.Now, items: make(map[[32]byte]memoryEntry)}
}

func (c *MemoryCache) Get(_ context.Context, key [32]byte) (Identity, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	e, ok := c.items[key]
	if !ok || !c.now().Before(e.expires) {
		return Identity{}, false
	}
	return e.identity, true
}

func (c *MemoryCache) Set(_ context.Context, key [32]byte, id Identity, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	now := c.now()
	if len(c.items) >= c.maxItems {
		for k, e := range c.items {
			if !now.Before(e.expires) {
				delete(c.items, k)
			}
		}
		if len(c.items) >= c.maxItems {
			clear(c.items)
		}
	}
	c.items[key] = memoryEntry{identity: id, expires: now.Add(ttl)}
}

type ValkeyCache struct {
	client  redis.UniversalClient
	prefix  string
	timeout time.Duration

	OnError func(error)
}

func NewValkeyCache(client redis.UniversalClient, prefix string) *ValkeyCache {
	return &ValkeyCache{client: client, prefix: prefix, timeout: 300 * time.Millisecond}
}

func (c *ValkeyCache) Get(ctx context.Context, key [32]byte) (Identity, bool) {
	ctx, cancel := context.WithTimeout(ctx, c.timeout)
	defer cancel()
	raw, err := c.client.Get(ctx, c.key(key)).Bytes()
	if err != nil {
		if err != redis.Nil {
			c.report(err)
		}
		return Identity{}, false
	}
	var id Identity
	if err := json.Unmarshal(raw, &id); err != nil {
		return Identity{}, false
	}
	return id, true
}

func (c *ValkeyCache) Set(ctx context.Context, key [32]byte, id Identity, ttl time.Duration) {
	raw, err := json.Marshal(id)
	if err != nil {
		return
	}
	ctx, cancel := context.WithTimeout(ctx, c.timeout)
	defer cancel()
	if err := c.client.Set(ctx, c.key(key), raw, ttl).Err(); err != nil {
		c.report(err)
	}
}

func (c *ValkeyCache) key(k [32]byte) string { return c.prefix + hex.EncodeToString(k[:]) }

func (c *ValkeyCache) report(err error) {
	if c.OnError != nil {
		c.OnError(err)
	}
}
