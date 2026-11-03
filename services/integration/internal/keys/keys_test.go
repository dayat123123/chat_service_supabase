package keys

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"sync"
	"testing"
	"time"
)

type fakeLookup struct {
	mu    sync.Mutex
	calls int
	keys  map[string]*Key
	err   error
}

func (f *fakeLookup) Authenticate(_ context.Context, keyHash, ip string) (*Key, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls++
	if f.err != nil {
		return nil, f.err
	}
	k, ok := f.keys[keyHash]
	if !ok {
		return nil, nil
	}
	c := *k
	c.IPAllowed = ip != "192.0.2.66"
	return &c, nil
}

const sample = "oik_AbCdEfGh0123456789abcdefghijklmnopqrstuvw"

func TestHash(t *testing.T) {
	sum := sha256.Sum256([]byte(sample))
	if got, ok := Hash(sample); !ok || got != hex.EncodeToString(sum[:]) {
		t.Fatalf("Hash = %q %v", got, ok)
	}
	for _, bad := range []string{"", "oik_", "Bearer oik_abc", "olt_abcdefgh", "oik_abc def", "oik_" + string(make([]byte, 300))} {
		if _, ok := Hash(bad); ok {
			t.Errorf("%q harus ditolak tanpa ke database", bad)
		}
	}
}

func TestCacheReusesAnswersPerKeyAndIP(t *testing.T) {
	hash, _ := Hash(sample)
	lookup := &fakeLookup{keys: map[string]*Key{hash: {ID: "k1", Scopes: []string{ScopeNotify}, RateLimit: 600}}}
	cache := NewCache(lookup, 30*time.Second)
	now := time.Unix(1_800_000_000, 0)
	cache.now = func() time.Time { return now }

	for range 3 {
		k, err := cache.Authenticate(context.Background(), hash, "10.0.0.1")
		if err != nil || k == nil || !k.Has(ScopeNotify) || k.Has(ScopeBotPost) || !k.IPAllowed {
			t.Fatalf("key = %+v err = %v", k, err)
		}
	}
	if lookup.calls != 1 {
		t.Fatalf("calls = %d, want 1", lookup.calls)
	}
	if k, _ := cache.Authenticate(context.Background(), hash, "192.0.2.66"); k == nil || k.IPAllowed {
		t.Fatalf("IP lain harus diperiksa ulang ke database: %+v", k)
	}
	if lookup.calls != 2 {
		t.Fatalf("calls = %d, want 2", lookup.calls)
	}

	now = now.Add(31 * time.Second)
	if _, _ = cache.Authenticate(context.Background(), hash, "10.0.0.1"); lookup.calls != 3 {
		t.Fatalf("cache kedaluwarsa harus bertanya lagi, calls = %d", lookup.calls)
	}

	cache.Forget(hash)
	if cache.Len() != 0 {
		t.Fatalf("Forget harus menghapus semua entri key itu, len = %d", cache.Len())
	}
}

func TestCacheRemembersUnknownKeysBriefly(t *testing.T) {
	lookup := &fakeLookup{keys: map[string]*Key{}}
	cache := NewCache(lookup, time.Minute)
	now := time.Unix(1_800_000_000, 0)
	cache.now = func() time.Time { return now }
	for range 2 {
		if k, err := cache.Authenticate(context.Background(), "h", "ip"); k != nil || err != nil {
			t.Fatalf("key = %v err = %v", k, err)
		}
	}
	if lookup.calls != 1 {
		t.Fatalf("calls = %d", lookup.calls)
	}
	now = now.Add(11 * time.Second)
	_, _ = cache.Authenticate(context.Background(), "h", "ip")
	if lookup.calls != 2 {
		t.Fatalf("key tidak dikenal hanya diingat 10 detik, calls = %d", lookup.calls)
	}
}

func TestCacheDoesNotRememberErrors(t *testing.T) {
	lookup := &fakeLookup{err: errors.New("postgrest down")}
	cache := NewCache(lookup, time.Minute)
	for range 2 {
		if _, err := cache.Authenticate(context.Background(), "h", "ip"); err == nil {
			t.Fatal("error harus diteruskan")
		}
	}
	if lookup.calls != 2 || cache.Len() != 0 {
		t.Fatalf("error tidak boleh di-cache: calls=%d len=%d", lookup.calls, cache.Len())
	}
}
