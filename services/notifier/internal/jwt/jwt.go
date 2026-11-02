package jwt

import (
	"crypto"
	"crypto/hmac"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
)

var b64 = base64.RawURLEncoding

func Sign(header, claims map[string]any, secret []byte) (string, error) {
	input, err := signingInput(header, claims)
	if err != nil {
		return "", err
	}
	h := hmac.New(sha256.New, secret)
	h.Write([]byte(input))
	return input + "." + b64.EncodeToString(h.Sum(nil)), nil
}

func SignRS256(header, claims map[string]any, key *rsa.PrivateKey) (string, error) {
	input, err := signingInput(header, claims)
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256([]byte(input))
	sig, err := rsa.SignPKCS1v15(nil, key, crypto.SHA256, digest[:])
	if err != nil {
		return "", fmt.Errorf("sign: %w", err)
	}
	return input + "." + b64.EncodeToString(sig), nil
}

func signingInput(header, claims map[string]any) (string, error) {
	head, err := json.Marshal(header)
	if err != nil {
		return "", fmt.Errorf("encode header: %w", err)
	}
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", fmt.Errorf("encode claims: %w", err)
	}
	return b64.EncodeToString(head) + "." + b64.EncodeToString(payload), nil
}
