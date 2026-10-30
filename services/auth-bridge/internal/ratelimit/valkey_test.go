package ratelimit

import (
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
)

func newValkey(t *testing.T) (*miniredis.Miniredis, redis.UniversalClient) {
	t.Helper()
	srv := miniredis.RunT(t)
	return srv, redis.NewClient(&redis.Options{Addr: srv.Addr()})
}

func TestValkeySlidingWindow(t *testing.T) {
	_, client := newValkey(t)
	now := time.Unix(1_000, 0)
	l := NewValkey(client, "rl:test:", 2, time.Minute)
	l.now = func() time.Time { return now }

	for i := 0; i < 2; i++ {
		if ok, _ := l.Allow("1.2.3.4"); !ok {
			t.Fatalf("request %d harus diizinkan", i+1)
		}
		now = now.Add(10 * time.Second)
	}
	ok, retry := l.Allow("1.2.3.4")
	if ok {
		t.Fatal("request ke-3 dalam semenit harus ditolak")
	}
	if retry != 40*time.Second {
		t.Fatalf("retry = %v, want 40s", retry)
	}
	if ok, _ := l.Allow("5.6.7.8"); !ok {
		t.Fatal("kunci lain punya jendela sendiri")
	}

	now = now.Add(41 * time.Second)
	if ok, _ := l.Allow("1.2.3.4"); !ok {
		t.Fatal("setelah request tertua keluar dari jendela, request harus diizinkan lagi")
	}
}

func TestValkeySharedAcrossInstances(t *testing.T) {
	_, client := newValkey(t)
	a := NewValkey(client, "rl:shared:", 1, time.Minute)
	b := NewValkey(client, "rl:shared:", 1, time.Minute)
	if ok, _ := a.Allow("user:1"); !ok {
		t.Fatal("request pertama harus diizinkan")
	}
	if ok, _ := b.Allow("user:1"); ok {
		t.Fatal("replika lain harus melihat hitungan yang sama")
	}
}

func TestValkeyFallsBackWhenUnavailable(t *testing.T) {
	srv, client := newValkey(t)
	srv.Close()

	var reported error
	l := NewValkey(client, "rl:down:", 1, time.Minute)
	l.OnError = func(err error) { reported = err }

	if ok, _ := l.Allow("k"); !ok {
		t.Fatal("saat Valkey mati, limiter in-memory tetap mengizinkan request pertama")
	}
	if ok, _ := l.Allow("k"); ok {
		t.Fatal("limiter in-memory tetap membatasi")
	}
	if reported == nil {
		t.Fatal("error Valkey harus dilaporkan")
	}
}
