// Package exchange menyatukan langkah tukar token: verifikasi token OLT,
// turunkan id user Supabase, lalu buat/perbarui profil. Hasilnya di-cache
// singkat (Valkey, dibagi semua replika) agar tidak membebani server OLT
// maupun database.
package exchange

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"time"

	"olt-social/auth-bridge/internal/identity"
	"olt-social/auth-bridge/internal/olt"
)

// ErrBanned: user diblokir dari fitur sosial (sanksi ban aktif).
var ErrBanned = errors.New("user diblokir dari fitur sosial")

// Profile adalah baris profiles hasil upsert (bentuk JSON dari RPC upsert_olt_profile).
// Banned/BanEndsAt hanya dibaca dari RPC; tidak pernah ikut terkirim ke client.
type Profile struct {
	ID          string     `json:"id"`
	OLTUserID   string     `json:"olt_user_id"`
	Username    string     `json:"username"`
	DisplayName *string    `json:"display_name"`
	AvatarURL   *string    `json:"avatar_url"`
	IsVerified  bool       `json:"is_verified"`
	Banned      bool       `json:"banned,omitempty"`
	BanEndsAt   *time.Time `json:"ban_ends_at,omitempty"`
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

// Identity adalah hasil exchange yang siap dijadikan JWT. Sengaja tanpa email:
// JWT berisi klaim minimal, dan cache tidak menyimpan data pribadi.
type Identity struct {
	Profile Profile `json:"profile"`
}

// Cache menyimpan Identity per hash token OLT selama ttl.
type Cache interface {
	Get(ctx context.Context, key [32]byte) (Identity, bool)
	Set(ctx context.Context, key [32]byte, id Identity, ttl time.Duration)
}

// Service menjalankan exchange token OLT dengan cache berbasis hash token.
type Service struct {
	verifier olt.Verifier
	store    ProfileStore
	cache    Cache
	ttl      time.Duration
}

// NewService membuat Service. ttl <= 0 atau cache nil mematikan cache.
func NewService(verifier olt.Verifier, store ProfileStore, cache Cache, ttl time.Duration) *Service {
	return &Service{verifier: verifier, store: store, cache: cache, ttl: ttl}
}

// Resolve memverifikasi token OLT dan memastikan profilnya ada.
// cached = true jika hasil diambil dari cache (tanpa menghubungi OLT).
func (s *Service) Resolve(ctx context.Context, oltToken string) (id Identity, cached bool, err error) {
	// Token tidak pernah disimpan apa adanya; hanya hash-nya yang jadi kunci cache.
	key := sha256.Sum256([]byte(oltToken))
	if s.enabled() {
		if hit, ok := s.cache.Get(ctx, key); ok {
			return hit, true, nil
		}
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
	if profile.Banned {
		return Identity{Profile: profile}, false, ErrBanned
	}

	id = Identity{Profile: profile}
	if s.enabled() {
		s.cache.Set(ctx, key, id, s.ttl)
	}
	return id, false, nil
}

func (s *Service) enabled() bool { return s.cache != nil && s.ttl > 0 }
