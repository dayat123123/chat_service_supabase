package social

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"time"
)

var b64 = base64.RawURLEncoding

type Identity struct {
	ID       string
	Username string
	Name     string
	Email    string
	Accounts []string
}

type Signer struct {
	key      ed25519.PrivateKey
	kid      string
	issuer   string
	audience string
	now      func() time.Time
}

func NewSigner(key ed25519.PrivateKey, kid, issuer, audience string) *Signer {
	return &Signer{key: key, kid: kid, issuer: issuer, audience: audience, now: time.Now}
}

func ParsePrivateKey(pemBytes []byte) (ed25519.PrivateKey, error) {
	block, _ := pem.Decode(pemBytes)
	if block == nil {
		return nil, errors.New("kunci penanda tangan harus PEM PKCS#8")
	}
	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	ed, ok := key.(ed25519.PrivateKey)
	if !ok {
		return nil, errors.New("kunci penanda tangan harus Ed25519")
	}
	return ed, nil
}

func (s *Signer) Sign(id Identity, ttl time.Duration) (string, time.Time, error) {
	return s.SignFor(id, ttl, s.audience)
}

func (s *Signer) SignFor(id Identity, ttl time.Duration, audience string) (string, time.Time, error) {
	var jti [12]byte
	if _, err := rand.Read(jti[:]); err != nil {
		return "", time.Time{}, err
	}
	now := s.now()
	exp := now.Add(ttl)
	issuedAt := now
	if ttl <= 0 {
		issuedAt = exp.Add(-time.Minute)
	}
	header, err := json.Marshal(map[string]string{"alg": "EdDSA", "typ": "JWT", "kid": s.kid})
	if err != nil {
		return "", time.Time{}, err
	}
	claims := map[string]any{
		"iss":                s.issuer,
		"aud":                audience,
		"sub":                id.ID,
		"preferred_username": id.Username,
		"iat":                issuedAt.Unix(),
		"exp":                exp.Unix(),
		"jti":                hex.EncodeToString(jti[:]),
	}
	if id.Name != "" {
		claims["name"] = id.Name
	}
	if id.Email != "" {
		claims["email"] = id.Email
	}
	if id.Accounts != nil {
		claims["accounts"] = id.Accounts
	}
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", time.Time{}, err
	}
	input := b64.EncodeToString(header) + "." + b64.EncodeToString(payload)
	return input + "." + b64.EncodeToString(ed25519.Sign(s.key, []byte(input))), exp, nil
}
