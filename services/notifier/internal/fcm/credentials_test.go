package fcm

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/pem"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"olt-social/notifier/internal/push"
)

func TestParseServiceAccount(t *testing.T) {
	ecKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	pkcs1 := string(pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(testKey())}))
	cases := []struct {
		name      string
		data      []byte
		wantError string
		tokenURI  string
	}{
		{name: "pkcs8 key", data: accountJSON(t, nil), tokenURI: "https://oauth2.googleapis.com/token"},
		{name: "pkcs1 key", data: accountJSON(t, map[string]any{"private_key": pkcs1}), tokenURI: "https://oauth2.googleapis.com/token"},
		{name: "escaped newlines", data: accountJSON(t, map[string]any{"private_key": strings.ReplaceAll(pkcs8PEM(t, testKey()), "\n", `\n`)}), tokenURI: "https://oauth2.googleapis.com/token"},
		{name: "default token uri", data: accountJSON(t, map[string]any{"token_uri": nil}), tokenURI: defaultTokenURI},
		{name: "not json", data: []byte("project_id=demo"), wantError: "bukan JSON"},
		{name: "empty file", data: nil, wantError: "bukan JSON"},
		{name: "google-services.json", data: []byte(`{"project_info":{"project_id":"demo"},"client":[]}`), wantError: `type harus "service_account"`},
		{name: "wrong type", data: accountJSON(t, map[string]any{"type": "authorized_user"}), wantError: `type harus "service_account"`},
		{name: "missing project", data: accountJSON(t, map[string]any{"project_id": nil}), wantError: "project_id kosong"},
		{name: "missing email", data: accountJSON(t, map[string]any{"client_email": " "}), wantError: "client_email kosong"},
		{name: "missing key", data: accountJSON(t, map[string]any{"private_key": nil}), wantError: "private_key kosong"},
		{name: "key not pem", data: accountJSON(t, map[string]any{"private_key": "MIIEvQIBADANBg"}), wantError: "private_key bukan PEM"},
		{name: "corrupt key", data: accountJSON(t, map[string]any{"private_key": "-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----\n"}), wantError: "tidak bisa dibaca sebagai kunci RSA"},
		{name: "ecdsa key", data: accountJSON(t, map[string]any{"private_key": pkcs8PEM(t, ecKey)}), wantError: "bukan kunci RSA"},
		{name: "bad token uri", data: accountJSON(t, map[string]any{"token_uri": "oauth2.googleapis.com/token"}), wantError: "token_uri"},
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
				account.PrivateKeyID != "kid-1" || account.TokenURI != tc.tokenURI || !account.Key.Equal(testKey()) {
				t.Fatalf("account = %+v", account)
			}
		})
	}
}

func write(t *testing.T, path string, data []byte, modified time.Time) {
	t.Helper()
	if err := os.WriteFile(path, data, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(path, modified, modified); err != nil {
		t.Fatal(err)
	}
}

func TestReloadPicksUpCredentials(t *testing.T) {
	stamp := time.Date(2026, 11, 2, 8, 0, 0, 0, time.UTC)
	valid := push.Status{Configured: true, ProjectID: "demo-project"}
	cases := []struct {
		name  string
		setup func(t *testing.T, dir string) string
		want  push.Status
	}{
		{
			name: "single file path",
			setup: func(t *testing.T, dir string) string {
				path := filepath.Join(dir, "firebase.json")
				write(t, path, accountJSON(t, nil), stamp)
				return path
			},
			want: valid,
		},
		{
			name: "folder with one json",
			setup: func(t *testing.T, dir string) string {
				write(t, filepath.Join(dir, "demo-project-firebase-adminsdk.json"), accountJSON(t, nil), stamp)
				write(t, filepath.Join(dir, ".backup.json"), []byte("{}"), stamp)
				write(t, filepath.Join(dir, "README.txt"), []byte("taruh file di sini"), stamp)
				_ = os.Mkdir(filepath.Join(dir, "old.json"), 0o700)
				return dir
			},
			want: valid,
		},
		{
			name: "folder with uppercase extension",
			setup: func(t *testing.T, dir string) string {
				write(t, filepath.Join(dir, "KEY.JSON"), accountJSON(t, nil), stamp)
				return dir
			},
			want: valid,
		},
		{
			name: "empty folder",
			setup: func(t *testing.T, dir string) string {
				write(t, filepath.Join(dir, ".gitkeep"), nil, stamp)
				return dir
			},
			want: push.Status{},
		},
		{
			name: "folder with two json files",
			setup: func(t *testing.T, dir string) string {
				write(t, filepath.Join(dir, "a.json"), accountJSON(t, nil), stamp)
				write(t, filepath.Join(dir, "b.json"), accountJSON(t, nil), stamp)
				return dir
			},
			want: push.Status{Configured: true, Problem: problemMultipleFiles},
		},
		{
			name:  "missing path",
			setup: func(t *testing.T, dir string) string { return filepath.Join(dir, "absent") },
			want:  push.Status{},
		},
		{
			name: "empty placeholder file",
			setup: func(t *testing.T, dir string) string {
				path := filepath.Join(dir, "firebase")
				write(t, path, nil, stamp)
				return path
			},
			want: push.Status{},
		},
		{
			name: "whitespace-only placeholder file",
			setup: func(t *testing.T, dir string) string {
				path := filepath.Join(dir, "firebase")
				write(t, path, []byte(" \r\n\t\n"), stamp)
				return path
			},
			want: push.Status{},
		},
		{
			name: "folder with only an empty json",
			setup: func(t *testing.T, dir string) string {
				write(t, filepath.Join(dir, "firebase.json"), []byte("\n"), stamp)
				return dir
			},
			want: push.Status{},
		},
		{
			name: "folder ignores an empty json next to the real one",
			setup: func(t *testing.T, dir string) string {
				write(t, filepath.Join(dir, "placeholder.json"), nil, stamp)
				write(t, filepath.Join(dir, "key.json"), accountJSON(t, nil), stamp)
				return dir
			},
			want: valid,
		},
		{
			name: "invalid json",
			setup: func(t *testing.T, dir string) string {
				write(t, filepath.Join(dir, "key.json"), []byte("{not json"), stamp)
				return dir
			},
			want: push.Status{Configured: true, Problem: "File kredensial Firebase tidak valid: isi file bukan JSON akun layanan"},
		},
		{
			name: "wrong type",
			setup: func(t *testing.T, dir string) string {
				write(t, filepath.Join(dir, "key.json"), accountJSON(t, map[string]any{"type": "external_account"}), stamp)
				return dir
			},
			want: push.Status{Configured: true, Problem: `File kredensial Firebase tidak valid: bukan kunci akun layanan (type harus "service_account")`},
		},
		{
			name: "bad key",
			setup: func(t *testing.T, dir string) string {
				write(t, filepath.Join(dir, "key.json"), accountJSON(t, map[string]any{"private_key": "garbage"}), stamp)
				return dir
			},
			want: push.Status{Configured: true, Problem: "File kredensial Firebase tidak valid: private_key bukan PEM"},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			client := newTestClient(tc.setup(t, t.TempDir()), "http://fcm.invalid")
			status, changed := client.Reload()
			if !changed || status != tc.want {
				t.Fatalf("status = %+v changed = %v, want %+v", status, changed, tc.want)
			}
			if _, tokens := client.current(); (tokens != nil) != (tc.want == valid) {
				t.Fatalf("token source present = %v", tokens != nil)
			}
		})
	}
}

func TestReloadReportsUnreadableFiles(t *testing.T) {
	dir := t.TempDir()
	write(t, filepath.Join(dir, "key.json"), accountJSON(t, nil), time.Now())
	client := newTestClient(dir, "http://fcm.invalid")
	client.readFile = func(string) ([]byte, error) { return nil, fs.ErrPermission }

	status, changed := client.Reload()
	if !changed || status != (push.Status{Configured: true, Problem: problemUnreadableFile}) {
		t.Fatalf("status = %+v changed = %v", status, changed)
	}
	if _, changed := client.Reload(); changed {
		t.Fatal("an unchanged unreadable file must not count as a change")
	}
	client.readFile = os.ReadFile
	status, changed = client.Reload()
	if !changed || status != (push.Status{Configured: true, ProjectID: "demo-project"}) {
		t.Fatalf("after fixing permissions: status = %+v changed = %v", status, changed)
	}
}

func TestReloadWaitsForAnEmptySecretToBeFilled(t *testing.T) {
	path := filepath.Join(t.TempDir(), "firebase")
	stamp := time.Date(2026, 11, 2, 8, 0, 0, 0, time.UTC)
	write(t, path, nil, stamp)
	client := newTestClient(path, "http://fcm.invalid")

	if status, changed := client.Reload(); !changed || status != (push.Status{}) {
		t.Fatalf("placeholder: status = %+v changed = %v", status, changed)
	}
	if _, changed := client.Reload(); changed {
		t.Fatal("an unchanged placeholder must not count as a change")
	}
	write(t, path, accountJSON(t, nil), stamp.Add(time.Minute))
	if status, changed := client.Reload(); !changed || status != (push.Status{Configured: true, ProjectID: "demo-project"}) {
		t.Fatalf("filled: status = %+v changed = %v", status, changed)
	}
	write(t, path, []byte("  \n"), stamp.Add(2*time.Minute))
	if status, changed := client.Reload(); !changed || status != (push.Status{}) {
		t.Fatalf("emptied again: status = %+v changed = %v", status, changed)
	}
	if account, tokens := client.current(); account != nil || tokens != nil {
		t.Fatal("credentials must be dropped when the secret is emptied")
	}
}

func TestReloadFollowsTheFolderWithoutRestart(t *testing.T) {
	dir := t.TempDir()
	client := newTestClient(dir, "http://fcm.invalid")
	stamp := time.Date(2026, 11, 2, 8, 0, 0, 0, time.UTC)
	step := func(name string, wantChanged bool, want push.Status) {
		t.Helper()
		status, changed := client.Reload()
		if changed != wantChanged || status != want {
			t.Fatalf("%s: status = %+v changed = %v, want %+v changed = %v", name, status, changed, want, wantChanged)
		}
	}

	step("empty", true, push.Status{})
	step("still empty", false, push.Status{})

	first := filepath.Join(dir, "first.json")
	write(t, first, accountJSON(t, nil), stamp)
	step("file dropped in", true, push.Status{Configured: true, ProjectID: "demo-project"})
	_, before := client.current()
	step("unchanged", false, push.Status{Configured: true, ProjectID: "demo-project"})

	write(t, first, accountJSON(t, map[string]any{"project_id": "other-project"}), stamp.Add(time.Minute))
	step("file replaced", true, push.Status{Configured: true, ProjectID: "other-project"})
	if _, after := client.current(); after == before {
		t.Fatal("a changed file must start a fresh token source")
	}

	write(t, filepath.Join(dir, "second.json"), accountJSON(t, nil), stamp)
	step("second file", true, push.Status{Configured: true, Problem: problemMultipleFiles})

	_ = os.Remove(first)
	step("first removed", true, push.Status{Configured: true, ProjectID: "demo-project"})

	_ = os.Remove(filepath.Join(dir, "second.json"))
	step("all removed", true, push.Status{})
	if account, tokens := client.current(); account != nil || tokens != nil {
		t.Fatal("credentials must be dropped when the file disappears")
	}
}
