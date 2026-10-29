package exchange

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"

	"olt-social/auth-bridge/internal/identity"
	"olt-social/auth-bridge/internal/olt"
)

type countingVerifier struct {
	calls int
	err   error
}

func (v *countingVerifier) Verify(ctx context.Context, token string) (olt.User, error) {
	v.calls++
	if v.err != nil {
		return olt.User{}, v.err
	}
	return olt.MockVerifier{}.Verify(ctx, token)
}

type fakeStore struct {
	calls  int
	last   ProfileInput
	banned bool
}

func (s *fakeStore) UpsertProfile(_ context.Context, in ProfileInput) (Profile, error) {
	s.calls++
	s.last = in
	return Profile{ID: in.ID, OLTUserID: in.OLTUserID, Username: in.Username, Banned: s.banned}, nil
}

func TestResolveDerivesStableIDAndCaches(t *testing.T) {
	verifier, store := &countingVerifier{}, &fakeStore{}
	cache := NewMemoryCache()
	now := time.Unix(1_800_000_000, 0)
	cache.now = func() time.Time { return now }
	svc := NewService(verifier, store, cache, time.Minute)

	got, cached, err := svc.Resolve(context.Background(), "mock:1001:budi_santoso")
	if err != nil || cached {
		t.Fatalf("resolve pertama: cached=%v err=%v", cached, err)
	}
	if got.Profile.ID != identity.UserID("1001") || store.last.OLTUserID != "1001" {
		t.Fatalf("id tidak diturunkan dari olt_user_id: %+v", got)
	}

	if _, cached, _ := svc.Resolve(context.Background(), "mock:1001:budi_santoso"); !cached {
		t.Fatal("resolve kedua harus dari cache")
	}
	if verifier.calls != 1 || store.calls != 1 {
		t.Fatalf("OLT/DB dipanggil ulang: verifier=%d store=%d", verifier.calls, store.calls)
	}

	now = now.Add(61 * time.Second)
	if _, cached, _ := svc.Resolve(context.Background(), "mock:1001:budi_santoso"); cached {
		t.Fatal("cache kedaluwarsa harus memverifikasi ulang")
	}
}

func TestResolveDoesNotCacheFailures(t *testing.T) {
	verifier := &countingVerifier{err: olt.ErrUnavailable}
	svc := NewService(verifier, &fakeStore{}, NewMemoryCache(), time.Minute)
	for range 2 {
		if _, _, err := svc.Resolve(context.Background(), "mock:1:a"); !errors.Is(err, olt.ErrUnavailable) {
			t.Fatalf("err = %v", err)
		}
	}
	if verifier.calls != 2 {
		t.Fatalf("kegagalan tidak boleh di-cache, calls=%d", verifier.calls)
	}
}

func TestResolveRejectsBannedUserWithoutCaching(t *testing.T) {
	store := &fakeStore{banned: true}
	svc := NewService(&countingVerifier{}, store, NewMemoryCache(), time.Minute)
	for range 2 {
		if _, _, err := svc.Resolve(context.Background(), "mock:7:dibanned"); !errors.Is(err, ErrBanned) {
			t.Fatalf("err = %v, want ErrBanned", err)
		}
	}
	if store.calls != 2 {
		t.Fatalf("user yang di-ban tidak boleh di-cache, calls=%d", store.calls)
	}
}

func TestValkeyCacheSharedAndExpires(t *testing.T) {
	srv := miniredis.RunT(t)
	client := redis.NewClient(&redis.Options{Addr: srv.Addr()})
	verifier, store := &countingVerifier{}, &fakeStore{}
	a := NewService(verifier, store, NewValkeyCache(client, "olt:verify:"), time.Minute)
	b := NewService(verifier, store, NewValkeyCache(client, "olt:verify:"), time.Minute)

	if _, cached, err := a.Resolve(context.Background(), "mock:1002:sari_invest"); err != nil || cached {
		t.Fatalf("resolve pertama: cached=%v err=%v", cached, err)
	}
	if _, cached, _ := b.Resolve(context.Background(), "mock:1002:sari_invest"); !cached {
		t.Fatal("replika lain harus memakai cache Valkey yang sama")
	}
	for _, k := range srv.Keys() {
		if len(k) != len("olt:verify:")+64 {
			t.Fatalf("kunci cache harus hash token, bukan token: %q", k)
		}
	}
	srv.FastForward(61 * time.Second)
	if _, cached, _ := a.Resolve(context.Background(), "mock:1002:sari_invest"); cached {
		t.Fatal("cache Valkey harus kedaluwarsa sesuai TTL")
	}
}

func TestValkeyCacheSkippedWhenUnavailable(t *testing.T) {
	srv := miniredis.RunT(t)
	client := redis.NewClient(&redis.Options{Addr: srv.Addr()})
	srv.Close()
	var failures int
	cache := NewValkeyCache(client, "olt:verify:")
	cache.OnError = func(error) { failures++ }
	svc := NewService(&countingVerifier{}, &fakeStore{}, cache, time.Minute)
	if _, _, err := svc.Resolve(context.Background(), "mock:1:a"); err != nil {
		t.Fatalf("Valkey mati tidak boleh menggagalkan exchange: %v", err)
	}
	if failures == 0 {
		t.Fatal("error Valkey harus dilaporkan")
	}
}
