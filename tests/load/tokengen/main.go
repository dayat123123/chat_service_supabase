package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"flag"
	"fmt"
	"os"
	"strconv"
	"time"
)

type user struct {
	Username  string `json:"username"`
	OLTUserID string `json:"olt_user_id"`
	IP        string `json:"ip"`
	Token     string `json:"token"`
}

var b64 = base64.RawURLEncoding

func main() {
	keyFile := flag.String("key", "/olt/secrets/olt_dev_signing_key", "kunci Ed25519 PEM PKCS#8")
	prefix := flag.String("prefix", "lt_", "awalan username")
	start := flag.Int("start", 1, "nomor user pertama")
	count := flag.Int("count", 100, "jumlah user")
	base := flag.Int64("base", 9100000, "olt_user_id = base + nomor")
	ttl := flag.Duration("ttl", 14*time.Minute, "masa berlaku token sosial")
	kid := flag.String("kid", "dev-olt-1", "kid header")
	issuer := flag.String("iss", "olt", "issuer")
	audience := flag.String("aud", "olt-social", "audience")
	flag.Parse()

	if len(*prefix) < 3 || (*prefix)[:2] != "lt" {
		fail(errors.New("awalan harus diawali lt dan minimal 3 karakter"))
	}
	raw, err := os.ReadFile(*keyFile)
	if err != nil {
		fail(err)
	}
	key, err := parseKey(raw)
	if err != nil {
		fail(err)
	}
	users := make([]user, 0, *count)
	for i := *start; i < *start+*count; i++ {
		id := strconv.FormatInt(*base+int64(i), 10)
		name := fmt.Sprintf("%s%05d", *prefix, i)
		token, err := sign(key, *kid, map[string]any{
			"iss":                *issuer,
			"aud":                *audience,
			"sub":                id,
			"preferred_username": name,
			"name":               "Load Test " + strconv.Itoa(i),
			"iat":                time.Now().Unix(),
			"exp":                time.Now().Add(*ttl).Unix(),
			"jti":                jti(),
		})
		if err != nil {
			fail(err)
		}
		users = append(users, user{Username: name, OLTUserID: id, IP: syntheticIP(i), Token: token})
	}
	enc := json.NewEncoder(os.Stdout)
	if err := enc.Encode(users); err != nil {
		fail(err)
	}
}

func syntheticIP(i int) string {
	n := 0xC6120000 + uint32(i)
	return fmt.Sprintf("%d.%d.%d.%d", n>>24, (n>>16)&0xff, (n>>8)&0xff, n&0xff)
}

func parseKey(raw []byte) (ed25519.PrivateKey, error) {
	block, _ := pem.Decode(raw)
	if block == nil {
		return nil, errors.New("kunci harus PEM PKCS#8")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	key, ok := parsed.(ed25519.PrivateKey)
	if !ok {
		return nil, errors.New("kunci harus Ed25519")
	}
	return key, nil
}

func sign(key ed25519.PrivateKey, kid string, claims map[string]any) (string, error) {
	header, err := json.Marshal(map[string]string{"alg": "EdDSA", "typ": "JWT", "kid": kid})
	if err != nil {
		return "", err
	}
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}
	input := b64.EncodeToString(header) + "." + b64.EncodeToString(payload)
	return input + "." + b64.EncodeToString(ed25519.Sign(key, []byte(input))), nil
}

func jti() string {
	var b [12]byte
	_, _ = rand.Read(b[:])
	return hex.EncodeToString(b[:])
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "tokengen:", err)
	os.Exit(1)
}
