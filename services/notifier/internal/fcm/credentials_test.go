package fcm

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/pem"
	"strings"
	"testing"

	"olt-social/notifier/internal/push"
)

func TestParseServiceAccount(t *testing.T) {
	ecKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	pkcs1 := string(pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(testKey())}))
	cases := []struct {
		name      string
		data      []byte
		wantError string
	}{
		{name: "pkcs8 key", data: accountJSON(t, nil)},
		{name: "pkcs1 key", data: accountJSON(t, map[string]any{"private_key": pkcs1})},
		{name: "escaped newlines", data: accountJSON(t, map[string]any{"private_key": strings.ReplaceAll(pkcs8PEM(t, testKey()), "\n", `\n`)})},
		{name: "token uri is ignored", data: accountJSON(t, map[string]any{"token_uri": "http://attacker.example/token"})},
		{name: "not json", data: []byte("project_id=demo"), wantError: "bukan JSON"},
		{name: "empty", data: nil, wantError: "bukan JSON"},
		{name: "google-services.json", data: []byte(`{"project_info":{"project_id":"demo"},"client":[]}`), wantError: `type harus "service_account"`},
		{name: "wrong type", data: accountJSON(t, map[string]any{"type": "authorized_user"}), wantError: `type harus "service_account"`},
		{name: "missing project", data: accountJSON(t, map[string]any{"project_id": nil}), wantError: "project_id kosong"},
		{name: "missing email", data: accountJSON(t, map[string]any{"client_email": " "}), wantError: "client_email kosong"},
		{name: "missing key", data: accountJSON(t, map[string]any{"private_key": nil}), wantError: "private_key kosong"},
		{name: "key not pem", data: accountJSON(t, map[string]any{"private_key": "MIIEvQIBADANBg"}), wantError: "private_key bukan PEM"},
		{name: "corrupt key", data: accountJSON(t, map[string]any{"private_key": "-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----\n"}), wantError: "tidak bisa dibaca sebagai kunci RSA"},
		{name: "ecdsa key", data: accountJSON(t, map[string]any{"private_key": pkcs8PEM(t, ecKey)}), wantError: "bukan kunci RSA"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			account, err := ParseServiceAccount(tc.data)
			if tc.wantError != "" {
				if err == nil || !strings.Contains(err.Error(), tc.wantError) {
					t.Fatalf("err = %v, want %q", err, tc.wantError)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			if account.ProjectID != "demo-project" || account.ClientEmail != "notifier@demo-project.iam.gserviceaccount.com" ||
				account.PrivateKeyID != "kid-1" || !account.Key.Equal(testKey()) {
				t.Fatalf("account = %+v", account)
			}
		})
	}
}

func TestLoadSwitchesCredentialsInPlace(t *testing.T) {
	client := newTestClient("http://google.invalid/token", "http://fcm.invalid")
	step := func(name string, data []byte, want push.Status, usable bool) *tokenSource {
		t.Helper()
		if status := client.Load(data); status != want {
			t.Fatalf("%s: status = %+v, want %+v", name, status, want)
		}
		account, tokens := client.current()
		if (account != nil) != usable || (tokens != nil) != usable {
			t.Fatalf("%s: account present = %v, token source present = %v", name, account != nil, tokens != nil)
		}
		return tokens
	}

	step("nothing yet", nil, push.Status{}, false)
	first := step("uploaded", accountJSON(t, nil), push.Status{Configured: true, ProjectID: "demo-project"}, true)
	second := step("replaced", accountJSON(t, map[string]any{"project_id": "other-project"}),
		push.Status{Configured: true, ProjectID: "other-project"}, true)
	if first == second {
		t.Fatal("new credentials must start a fresh token source")
	}
	step("broken", accountJSON(t, map[string]any{"private_key": "garbage"}),
		push.Status{Configured: true, Problem: "Kredensial Firebase tidak valid: private_key bukan PEM"}, false)
	step("uploaded again", accountJSON(t, nil), push.Status{Configured: true, ProjectID: "demo-project"}, true)
	step("removed", nil, push.Status{}, false)
}
