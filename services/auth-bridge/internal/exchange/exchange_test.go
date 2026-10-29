package exchange

import (
	"context"
	"errors"
	"testing"
	"time"

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
	calls int
	last  ProfileInput
}

func (s *fakeStore) UpsertProfile(_ context.Context, in ProfileInput) (Profile, error) {
	s.calls++
	s.last = in
	return Profile{ID: in.ID, OLTUserID: in.OLTUserID, Username: in.Username}, nil
}

func TestResolveDerivesStableIDAndCaches(t *testing.T) {
	verifier, store := &countingVerifier{}, &fakeStore{}
	svc := NewService(verifier, store, time.Minute)
	now := time.Unix(1_800_000_000, 0)
	svc.now = func() time.Time { return now }

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
	svc := NewService(verifier, &fakeStore{}, time.Minute)
	for range 2 {
		if _, _, err := svc.Resolve(context.Background(), "mock:1:a"); !errors.Is(err, olt.ErrUnavailable) {
			t.Fatalf("err = %v", err)
		}
	}
	if verifier.calls != 2 {
		t.Fatalf("kegagalan tidak boleh di-cache, calls=%d", verifier.calls)
	}
}
