package fcm

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"strings"
	"sync"
	"testing"
	"time"
)

var testKey = sync.OnceValue(func() *rsa.PrivateKey {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		panic(err)
	}
	return key
})

func pkcs8PEM(t *testing.T, key any) string {
	t.Helper()
	der, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatal(err)
	}
	return string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}))
}

func accountJSON(t *testing.T, overrides map[string]any) []byte {
	t.Helper()
	fields := map[string]any{
		"type":           "service_account",
		"project_id":     "demo-project",
		"private_key_id": "kid-1",
		"private_key":    pkcs8PEM(t, testKey()),
		"client_email":   "notifier@demo-project.iam.gserviceaccount.com",
		"client_id":      "1234567890",
	}
	for k, v := range overrides {
		if v == nil {
			delete(fields, k)
			continue
		}
		fields[k] = v
	}
	data, err := json.Marshal(fields)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func newTestClient(tokenURL, baseURL string) *Client {
	return New(Options{BaseURL: baseURL, TokenURL: tokenURL, SendTimeout: 2 * time.Second})
}

type decodedJWT struct {
	header, claims map[string]any
}

func verifyRS256(t *testing.T, token string, key *rsa.PublicKey) decodedJWT {
	t.Helper()
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Fatalf("assertion = %q", token)
	}
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		t.Fatal(err)
	}
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	if err := rsa.VerifyPKCS1v15(key, crypto.SHA256, digest[:], sig); err != nil {
		t.Fatalf("assertion signature: %v", err)
	}
	var out decodedJWT
	for i, target := range []*map[string]any{&out.header, &out.claims} {
		raw, err := base64.RawURLEncoding.DecodeString(parts[i])
		if err != nil {
			t.Fatal(err)
		}
		if err := json.Unmarshal(raw, target); err != nil {
			t.Fatal(err)
		}
	}
	return out
}
