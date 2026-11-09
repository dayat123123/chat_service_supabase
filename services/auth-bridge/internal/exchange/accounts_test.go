package exchange

import (
	"context"
	"errors"
	"reflect"
	"testing"
	"time"

	"olt-social/auth-bridge/internal/olt"
)

type accountVerifier struct{ claim *olt.AccountClaim }

func (v accountVerifier) Verify(_ context.Context, _ string) (olt.User, error) {
	return olt.User{ID: "1001", Username: "budi_santoso", Accounts: v.claim}, nil
}

type linkingStore struct {
	fakeStore
	calls   int
	profile string
	ids     []string
	limit   int
	err     error
}

func (s *linkingStore) ReplaceAccountLinks(_ context.Context, profileID string, accounts []string) (int, error) {
	s.calls++
	s.profile, s.ids = profileID, accounts
	if s.err != nil {
		return 0, s.err
	}
	if s.limit > 0 {
		return min(len(accounts), s.limit), nil
	}
	return len(accounts), nil
}

func TestResolveCountsAccountsBeyondTheServerLimitAsIgnored(t *testing.T) {
	store := &linkingStore{limit: 2}
	claim := &olt.AccountClaim{IDs: []string{"W137", "C1626", "S2001"}, Ignored: 1}
	id, _, err := NewService(accountVerifier{claim}, store, nil, 0).Resolve(context.Background(), "t")
	if err != nil {
		t.Fatal(err)
	}
	want := AccountLinks{Present: true, Linked: 2, Ignored: 2}
	if id.Accounts != want {
		t.Fatalf("accounts = %+v, want %+v", id.Accounts, want)
	}
}

func TestResolveReplacesAccountLinksWhenClaimPresent(t *testing.T) {
	store := &linkingStore{}
	claim := &olt.AccountClaim{IDs: []string{"W137", "C1626"}, Ignored: 1}
	svc := NewService(accountVerifier{claim}, store, NewMemoryCache(), time.Minute)

	id, _, err := svc.Resolve(context.Background(), "token-1")
	if err != nil {
		t.Fatal(err)
	}
	if store.calls != 1 || store.profile != id.Profile.ID || !reflect.DeepEqual(store.ids, claim.IDs) {
		t.Fatalf("ReplaceAccountLinks calls=%d profile=%q ids=%v", store.calls, store.profile, store.ids)
	}
	want := AccountLinks{Present: true, Linked: 2, Ignored: 1}
	if id.Accounts != want {
		t.Fatalf("accounts = %+v, want %+v", id.Accounts, want)
	}

	hit, cached, _ := svc.Resolve(context.Background(), "token-1")
	if !cached || store.calls != 1 {
		t.Fatalf("token yang sama dari cache tidak perlu menyimpan ulang: cached=%v calls=%d", cached, store.calls)
	}
	if hit.Accounts.Present {
		t.Fatal("hasil cache tidak membawa status tautan rekening")
	}
}

func TestResolveLeavesLinksAloneWithoutClaim(t *testing.T) {
	for name, claim := range map[string]*olt.AccountClaim{
		"klaim tidak ada":    nil,
		"klaim salah bentuk": {Malformed: true},
	} {
		t.Run(name, func(t *testing.T) {
			store := &linkingStore{}
			id, _, err := NewService(accountVerifier{claim}, store, nil, 0).Resolve(context.Background(), "t")
			if err != nil {
				t.Fatal(err)
			}
			if store.calls != 0 {
				t.Fatalf("tautan rekening tidak boleh diubah, calls=%d", store.calls)
			}
			if id.Accounts.Present != (claim != nil) || id.Accounts.Malformed != (claim != nil) {
				t.Fatalf("accounts = %+v", id.Accounts)
			}
		})
	}
}

func TestResolveEmptyClaimClearsLinks(t *testing.T) {
	store := &linkingStore{}
	if _, _, err := NewService(accountVerifier{&olt.AccountClaim{IDs: []string{}}}, store, nil, 0).Resolve(context.Background(), "t"); err != nil {
		t.Fatal(err)
	}
	if store.calls != 1 || store.ids == nil || len(store.ids) != 0 {
		t.Fatalf("klaim [] harus melepas semua rekening: calls=%d ids=%v", store.calls, store.ids)
	}
}

func TestResolveSucceedsWhenLinkingFailsButSkipsCache(t *testing.T) {
	store := &linkingStore{err: errors.New("postgrest 503")}
	svc := NewService(accountVerifier{&olt.AccountClaim{IDs: []string{"W137"}}}, store, NewMemoryCache(), time.Minute)
	id, _, err := svc.Resolve(context.Background(), "t")
	if err != nil {
		t.Fatalf("gagal menyimpan tautan tidak boleh menggagalkan login: %v", err)
	}
	if id.Accounts.Err == nil || id.Accounts.Linked != 0 {
		t.Fatalf("accounts = %+v", id.Accounts)
	}
	if _, cached, _ := svc.Resolve(context.Background(), "t"); cached || store.calls != 2 {
		t.Fatalf("exchange berikutnya harus mencoba lagi: cached=%v calls=%d", cached, store.calls)
	}
}

func TestResolveLinksAccountsOfBannedUsers(t *testing.T) {
	store := &linkingStore{fakeStore: fakeStore{banned: true}}
	id, _, err := NewService(accountVerifier{&olt.AccountClaim{IDs: []string{"W137"}}}, store, nil, 0).Resolve(context.Background(), "t")
	if !errors.Is(err, ErrBanned) {
		t.Fatalf("err = %v", err)
	}
	if store.calls != 1 || id.Accounts.Linked != 1 {
		t.Fatalf("rekening nasabah yang di-ban tetap tertaut untuk notifikasi transaksi: calls=%d", store.calls)
	}
}
