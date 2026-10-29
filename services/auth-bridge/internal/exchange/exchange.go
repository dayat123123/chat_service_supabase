// Package exchange menyatukan langkah tukar token: verifikasi token OLT,
// turunkan id user Supabase, lalu buat/perbarui profil. Hasilnya di-cache
// singkat agar tidak membebani server OLT maupun database.
package exchange

import (
	"context"
	"crypto/sha256"
	"fmt"
	"sync"
	"time"

	"olt-social/auth-bridge/internal/identity"
	"olt-social/auth-bridge/internal/olt"
)

// Profile adalah baris profiles hasil upsert (bentuk JSON dari RPC upsert_olt_profile).
type Profile struct {
	ID          string  `json:"id"`
	OLTUserID   string  `json:"olt_user_id"`
	Username    string  `json:"username"`
	DisplayName *string `json:"display_name"`
	AvatarURL   *string `json:"avatar_url"`
	IsVerified  bool    `json:"is_verified"`
}

// ProfileInput adalah data untuk upsert profil.
type ProfileInput struct {
	ID          string
	OLTUserID   string
	Username    string
	DisplayName string
	Email       string
}

// ProfileStore membuat atau memperbarui profil user.
type ProfileStore interface {
	UpsertProfile(ctx context.Context, in ProfileInput) (Profile, error)
}

// Identity adalah hasil exchange yang siap dijadikan JWT.
type Identity struct {
	Profile Profile
	Email   string
}

// Service menjalankan exchange token OLT dengan cache berbasis hash token.
type Service struct {
	verifier olt.Verifier
	store    ProfileStore
	ttl      time.Duration
	maxItems int
	now      func() time.Time

	mu    sync.Mutex
	cache map[[32]byte]cacheEntry
}

type cacheEntry struct {
	identity Identity
	expires  time.Time
}

// NewService membuat Service. ttl <= 0 mematikan cache.
func NewService(verifier olt.Verifier, store ProfileStore, ttl time.Duration) *Service {
	return &Service{
		verifier: verifier,
		store:    store,
		ttl:      ttl,
		maxItems: 10_000,
		now:      time.Now,
		cache:    make(map[[32]byte]cacheEntry),
	}
}

// Resolve memverifikasi token OLT dan memastikan profilnya ada.
// cached = true jika hasil diambil dari cache (tanpa menghubungi OLT).
func (s *Service) Resolve(ctx context.Context, oltToken string) (id Identity, cached bool, err error) {
	// Token tidak pernah disimpan apa adanya; hanya hash-nya yang jadi kunci cache.
	key := sha256.Sum256([]byte(oltToken))
	if hit, ok := s.lookup(key); ok {
		return hit, true, nil
	}

	user, err := s.verifier.Verify(ctx, oltToken)
	if err != nil {
		return Identity{}, false, err
	}

	profile, err := s.store.UpsertProfile(ctx, ProfileInput{
		ID:          identity.UserID(user.ID),
		OLTUserID:   user.ID,
		Username:    user.Username,
		DisplayName: user.DisplayName,
		Email:       user.Email,
	})
	if err != nil {
		return Identity{}, false, fmt.Errorf("upsert profil: %w", err)
	}

	id = Identity{Profile: profile, Email: user.Email}
	s.remember(key, id)
	return id, false, nil
}

func (s *Service) lookup(key [32]byte) (Identity, bool) {
	if s.ttl <= 0 {
		return Identity{}, false
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	e, ok := s.cache[key]
	if !ok || !s.now().Before(e.expires) {
		return Identity{}, false
	}
	return e.identity, true
}

func (s *Service) remember(key [32]byte, id Identity) {
	if s.ttl <= 0 {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	now := s.now()
	if len(s.cache) >= s.maxItems {
		for k, e := range s.cache {
			if !now.Before(e.expires) {
				delete(s.cache, k)
			}
		}
		if len(s.cache) >= s.maxItems {
			clear(s.cache) // jarang terjadi; cache hanya optimasi
		}
	}
	s.cache[key] = cacheEntry{identity: id, expires: now.Add(s.ttl)}
}
