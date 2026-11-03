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

var ErrBanned = errors.New("user diblokir dari fitur sosial")

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

type ProfileInput struct {
	ID          string
	OLTUserID   string
	Username    string
	DisplayName string
	Email       string
}

type ProfileStore interface {
	UpsertProfile(ctx context.Context, in ProfileInput) (Profile, error)
}

type AccountLinker interface {
	ReplaceAccountLinks(ctx context.Context, profileID string, accounts []string) error
}

type AccountLinks struct {
	Present   bool
	Malformed bool
	Linked    int
	Ignored   int
	Err       error
}

type Identity struct {
	Profile  Profile      `json:"profile"`
	Accounts AccountLinks `json:"-"`
}

type Cache interface {
	Get(ctx context.Context, key [32]byte) (Identity, bool)
	Set(ctx context.Context, key [32]byte, id Identity, ttl time.Duration)
}

type Service struct {
	verifier olt.Verifier
	store    ProfileStore
	cache    Cache
	ttl      time.Duration
}

func NewService(verifier olt.Verifier, store ProfileStore, cache Cache, ttl time.Duration) *Service {
	return &Service{verifier: verifier, store: store, cache: cache, ttl: ttl}
}

func (s *Service) Resolve(ctx context.Context, oltToken string) (id Identity, cached bool, err error) {
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
	id = Identity{Profile: profile, Accounts: s.linkAccounts(ctx, profile.ID, user.Accounts)}
	if profile.Banned {
		return id, false, ErrBanned
	}

	if s.enabled() && id.Accounts.Err == nil {
		s.cache.Set(ctx, key, Identity{Profile: id.Profile}, s.ttl)
	}
	return id, false, nil
}

func (s *Service) enabled() bool { return s.cache != nil && s.ttl > 0 }

func (s *Service) linkAccounts(ctx context.Context, profileID string, claim *olt.AccountClaim) AccountLinks {
	if claim == nil {
		return AccountLinks{}
	}
	result := AccountLinks{Present: true, Malformed: claim.Malformed, Ignored: claim.Ignored}
	if claim.Malformed {
		return result
	}
	linker, ok := s.store.(AccountLinker)
	if !ok {
		result.Err = errors.New("penyimpan tautan rekening tidak tersedia")
		return result
	}
	if err := linker.ReplaceAccountLinks(ctx, profileID, claim.IDs); err != nil {
		result.Err = fmt.Errorf("tautan rekening: %w", err)
		return result
	}
	result.Linked = len(claim.IDs)
	return result
}
