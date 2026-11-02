package olt

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/ed25519"
	"crypto/elliptic"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"strings"
	"time"
)

const (
	maxTokenBytes = 8 << 10
	devKeyPrefix  = "dev-"
)

var b64 = base64.RawURLEncoding.Strict()

type JWTOptions struct {
	Issuer        string
	Audience      string
	MaxTTL        time.Duration
	Leeway        time.Duration
	RejectDevKeys bool
}

type publicKey struct {
	alg string
	ed  ed25519.PublicKey
	ec  *ecdsa.PublicKey
}

type JWTVerifier struct {
	keys map[string]publicKey
	opts JWTOptions
	now  func() time.Time
}

func NewJWTVerifier(jwks []byte, opts JWTOptions) (*JWTVerifier, error) {
	keys, err := parseJWKS(jwks, opts.RejectDevKeys)
	if err != nil {
		return nil, fmt.Errorf("JWKS OLT: %w", err)
	}
	return &JWTVerifier{keys: keys, opts: opts, now: time.Now}, nil
}

type jwk struct {
	Kty string `json:"kty"`
	Crv string `json:"crv"`
	Kid string `json:"kid"`
	Alg string `json:"alg"`
	X   string `json:"x"`
	Y   string `json:"y"`
}

func parseJWKS(data []byte, rejectDev bool) (map[string]publicKey, error) {
	var doc struct {
		Keys []jwk `json:"keys"`
	}
	if err := json.Unmarshal(data, &doc); err != nil {
		return nil, fmt.Errorf("bukan JSON JWKS: %w", err)
	}
	if len(doc.Keys) == 0 {
		return nil, errors.New("tidak ada kunci")
	}
	keys := make(map[string]publicKey, len(doc.Keys))
	for _, k := range doc.Keys {
		if k.Kid == "" {
			return nil, errors.New("setiap kunci wajib punya kid")
		}
		if _, dup := keys[k.Kid]; dup {
			return nil, fmt.Errorf("kid %q ganda", k.Kid)
		}
		if rejectDev && strings.HasPrefix(k.Kid, devKeyPrefix) {
			return nil, fmt.Errorf("kunci dev %q tidak boleh dipakai di produksi; ganti dengan JWKS dari OLT", k.Kid)
		}
		key, err := parseKey(k)
		if err != nil {
			return nil, fmt.Errorf("kid %q: %w", k.Kid, err)
		}
		keys[k.Kid] = key
	}
	return keys, nil
}

func parseKey(k jwk) (publicKey, error) {
	switch {
	case k.Kty == "OKP" && k.Crv == "Ed25519":
		x, err := b64.DecodeString(k.X)
		if err != nil || len(x) != ed25519.PublicKeySize {
			return publicKey{}, errors.New("x Ed25519 tidak valid")
		}
		return publicKey{alg: "EdDSA", ed: ed25519.PublicKey(x)}, checkAlg(k.Alg, "EdDSA")
	case k.Kty == "EC" && k.Crv == "P-256":
		x, errX := b64.DecodeString(k.X)
		y, errY := b64.DecodeString(k.Y)
		if errX != nil || errY != nil || len(x) != 32 || len(y) != 32 {
			return publicKey{}, errors.New("koordinat P-256 tidak valid")
		}
		pub := &ecdsa.PublicKey{Curve: elliptic.P256(), X: new(big.Int).SetBytes(x), Y: new(big.Int).SetBytes(y)}
		if !pub.Curve.IsOnCurve(pub.X, pub.Y) {
			return publicKey{}, errors.New("titik tidak berada di kurva P-256")
		}
		return publicKey{alg: "ES256", ec: pub}, checkAlg(k.Alg, "ES256")
	default:
		return publicKey{}, fmt.Errorf("jenis kunci %s/%s tidak didukung (Ed25519 atau P-256)", k.Kty, k.Crv)
	}
}

func checkAlg(declared, expected string) error {
	if declared != "" && declared != expected {
		return fmt.Errorf("alg %q tidak cocok dengan jenis kunci (%s)", declared, expected)
	}
	return nil
}

type header struct {
	Alg string `json:"alg"`
	Kid string `json:"kid"`
}

type claims struct {
	Issuer            string          `json:"iss"`
	Audience          json.RawMessage `json:"aud"`
	Subject           json.RawMessage `json:"sub"`
	PreferredUsername string          `json:"preferred_username"`
	Name              string          `json:"name"`
	Email             string          `json:"email"`
	IssuedAt          *int64          `json:"iat"`
	ExpiresAt         *int64          `json:"exp"`
	NotBefore         *int64          `json:"nbf"`
}

func invalid(reason string) error {
	return fmt.Errorf("%w: %s", ErrInvalidToken, reason)
}

func (v *JWTVerifier) Verify(_ context.Context, token string) (User, error) {
	if token == "" || len(token) > maxTokenBytes {
		return User{}, invalid("ukuran token tidak wajar")
	}
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return User{}, invalid("bukan JWT")
	}
	var h header
	if err := decodeSegment(parts[0], &h); err != nil {
		return User{}, invalid("header tidak valid")
	}
	key, err := v.keyFor(h)
	if err != nil {
		return User{}, err
	}
	signature, err := b64.DecodeString(parts[2])
	if err != nil || !key.verify([]byte(parts[0]+"."+parts[1]), signature) {
		return User{}, invalid("tanda tangan tidak valid")
	}
	var c claims
	if err := decodeSegment(parts[1], &c); err != nil {
		return User{}, invalid("payload tidak valid")
	}
	return v.userFrom(c)
}

func (v *JWTVerifier) keyFor(h header) (publicKey, error) {
	if h.Alg != "EdDSA" && h.Alg != "ES256" {
		return publicKey{}, invalid("alg tidak diizinkan")
	}
	var key publicKey
	switch {
	case h.Kid != "":
		found, ok := v.keys[h.Kid]
		if !ok {
			return publicKey{}, invalid("kid tidak dikenal")
		}
		key = found
	case len(v.keys) == 1:
		for _, only := range v.keys {
			key = only
		}
	default:
		return publicKey{}, invalid("kid wajib diisi")
	}
	if key.alg != h.Alg {
		return publicKey{}, invalid("alg tidak cocok dengan kunci")
	}
	return key, nil
}

func (k publicKey) verify(input, signature []byte) bool {
	if k.ed != nil {
		return ed25519.Verify(k.ed, input, signature)
	}
	if len(signature) != 64 {
		return false
	}
	digest := sha256.Sum256(input)
	r := new(big.Int).SetBytes(signature[:32])
	s := new(big.Int).SetBytes(signature[32:])
	return ecdsa.Verify(k.ec, digest[:], r, s)
}

func (v *JWTVerifier) userFrom(c claims) (User, error) {
	now := v.now()
	leeway := int64(v.opts.Leeway / time.Second)
	switch {
	case c.Issuer != v.opts.Issuer:
		return User{}, invalid("issuer tidak dikenal")
	case !hasAudience(c.Audience, v.opts.Audience):
		return User{}, invalid("audience bukan untuk OLT Social")
	case c.ExpiresAt == nil || c.IssuedAt == nil:
		return User{}, invalid("exp dan iat wajib diisi")
	case now.Unix() >= *c.ExpiresAt+leeway:
		return User{}, invalid("token kedaluwarsa")
	case *c.IssuedAt > now.Unix()+leeway:
		return User{}, invalid("iat di masa depan")
	case c.NotBefore != nil && *c.NotBefore > now.Unix()+leeway:
		return User{}, invalid("token belum berlaku")
	case time.Duration(*c.ExpiresAt-*c.IssuedAt)*time.Second > v.opts.MaxTTL:
		return User{}, invalid("masa berlaku token melebihi batas")
	}
	var subject string
	if err := json.Unmarshal(c.Subject, &subject); err != nil || subject == "" {
		return User{}, invalid("sub wajib berupa string")
	}
	if c.PreferredUsername == "" {
		return User{}, invalid("preferred_username wajib diisi")
	}
	return User{ID: subject, Username: c.PreferredUsername, Email: c.Email, DisplayName: c.Name}, nil
}

func hasAudience(raw json.RawMessage, want string) bool {
	var single string
	if err := json.Unmarshal(raw, &single); err == nil {
		return single == want
	}
	var many []string
	if err := json.Unmarshal(raw, &many); err != nil {
		return false
	}
	for _, aud := range many {
		if aud == want {
			return true
		}
	}
	return false
}

func decodeSegment(segment string, out any) error {
	raw, err := b64.DecodeString(segment)
	if err != nil {
		return err
	}
	dec := json.NewDecoder(bytes.NewReader(raw))
	return dec.Decode(out)
}
