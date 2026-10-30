package tokens

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"strings"
	"sync"
	"time"
)

const Prefix = "olt_"

var b64 = base64.RawURLEncoding

type Claims struct {
	UserID    string `json:"uid"`
	IssuedAt  int64  `json:"iat"`
	ExpiresAt int64  `json:"exp"`
	ID        string `json:"jti"`
}

var (
	ErrMalformed = errors.New("format token tidak valid")
	ErrSignature = errors.New("tanda tangan token tidak valid")
	ErrExpired   = errors.New("token kedaluwarsa")
	ErrRevoked   = errors.New("token sudah logout")
)

type Issuer struct {
	secret []byte
	now    func() time.Time

	mu      sync.Mutex
	revoked map[string]int64
}

func NewIssuer(secret string) *Issuer {
	return &Issuer{secret: []byte(secret), now: time.Now, revoked: make(map[string]int64)}
}

func (i *Issuer) Issue(userID string, ttl time.Duration) (string, time.Time, error) {
	var id [12]byte
	if _, err := rand.Read(id[:]); err != nil {
		return "", time.Time{}, err
	}
	now := i.now()
	exp := now.Add(ttl)
	payload, err := json.Marshal(Claims{UserID: userID, IssuedAt: now.Unix(), ExpiresAt: exp.Unix(), ID: hex.EncodeToString(id[:])})
	if err != nil {
		return "", time.Time{}, err
	}
	body := b64.EncodeToString(payload)
	return Prefix + body + "." + b64.EncodeToString(i.sign(body)), exp, nil
}

func (i *Issuer) Verify(token string) (Claims, error) {
	claims, err := i.parse(token)
	if err != nil {
		return Claims{}, err
	}
	if i.now().Unix() >= claims.ExpiresAt {
		return Claims{}, ErrExpired
	}
	i.mu.Lock()
	defer i.mu.Unlock()
	if _, ok := i.revoked[claims.ID]; ok {
		return Claims{}, ErrRevoked
	}
	return claims, nil
}

func (i *Issuer) Revoke(token string) error {
	claims, err := i.parse(token)
	if err != nil {
		return err
	}
	i.mu.Lock()
	defer i.mu.Unlock()
	now := i.now().Unix()
	for jti, exp := range i.revoked {
		if exp <= now {
			delete(i.revoked, jti)
		}
	}
	i.revoked[claims.ID] = claims.ExpiresAt
	return nil
}

func (i *Issuer) parse(token string) (Claims, error) {
	rest, ok := strings.CutPrefix(token, Prefix)
	if !ok {
		return Claims{}, ErrMalformed
	}
	body, sig, ok := strings.Cut(rest, ".")
	if !ok {
		return Claims{}, ErrMalformed
	}
	gotSig, err := b64.DecodeString(sig)
	if err != nil {
		return Claims{}, ErrMalformed
	}
	if !hmac.Equal(gotSig, i.sign(body)) {
		return Claims{}, ErrSignature
	}
	raw, err := b64.DecodeString(body)
	if err != nil {
		return Claims{}, ErrMalformed
	}
	var claims Claims
	if err := json.Unmarshal(raw, &claims); err != nil || claims.UserID == "" || claims.ID == "" {
		return Claims{}, ErrMalformed
	}
	return claims, nil
}

func (i *Issuer) sign(body string) []byte {
	h := hmac.New(sha256.New, i.secret)
	h.Write([]byte(body))
	return h.Sum(nil)
}
