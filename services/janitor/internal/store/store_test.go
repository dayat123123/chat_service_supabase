package store

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"
)

type captured struct {
	method, path, contentProfile, acceptProfile, contentType, accept string
	claims                                                           map[string]any
	args                                                             map[string]any
}

func serviceClaims(t *testing.T, header string, secret []byte) map[string]any {
	t.Helper()
	parts := strings.Split(strings.TrimPrefix(header, "Bearer "), ".")
	if len(parts) != 3 {
		t.Fatalf("authorization = %q", header)
	}
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(parts[0] + "." + parts[1]))
	if base64.RawURLEncoding.EncodeToString(mac.Sum(nil)) != parts[2] {
		t.Fatal("service token signature mismatch")
	}
	payload, _ := base64.RawURLEncoding.DecodeString(parts[1])
	var claims map[string]any
	_ = json.Unmarshal(payload, &claims)
	return claims
}

func recordingServer(t *testing.T, reply string, seen *captured) *httptest.Server {
	t.Helper()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen.method = r.Method
		seen.path = r.URL.Path
		seen.contentProfile = r.Header.Get("Content-Profile")
		seen.acceptProfile = r.Header.Get("Accept-Profile")
		seen.contentType = r.Header.Get("Content-Type")
		seen.accept = r.Header.Get("Accept")
		seen.claims = serviceClaims(t, r.Header.Get("Authorization"), []byte("secret"))
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &seen.args)
		_, _ = w.Write([]byte(reply))
	}))
	t.Cleanup(server.Close)
	return server
}

func newStore(url string) *PostgREST {
	p := NewPostgREST(url, []byte("secret"), "supabase", 5*time.Second)
	p.now = func() time.Time { return time.Unix(1_800_000_000, 0) }
	return p
}

func TestClaimSendsServiceRoleRPCAndDecodesEntries(t *testing.T) {
	var seen captured
	reply := `[
	  {"id": 12, "bucket": "avatars", "prefix": "3f2a/", "objects": ["3f2a/a.jpg", "3f2a/b.png"]},
	  {"id": 13, "bucket": "care-documents", "prefix": "letters/9/", "objects": []},
	  {"id": 14, "bucket": "attachments", "prefix": "posts/3f2a/", "objects": null}
	]`
	server := recordingServer(t, reply, &seen)

	entries, err := newStore(server.URL).Claim(context.Background(), "janitor-1", 20, 1000, 5*time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	if seen.method != http.MethodPost || seen.path != "/rpc/storage_cleanup_claim" || seen.contentProfile != "public" ||
		seen.acceptProfile != "public" || seen.contentType != "application/json" || seen.accept != "application/json" {
		t.Fatalf("request = %+v", seen)
	}
	if seen.claims["role"] != "service_role" || seen.claims["iss"] != "supabase" ||
		seen.claims["exp"].(float64)-seen.claims["iat"].(float64) != 60 {
		t.Fatalf("claims = %v", seen.claims)
	}
	wantArgs := map[string]any{"p_instance": "janitor-1", "p_limit": float64(20), "p_objects": float64(1000), "p_lease_seconds": float64(300)}
	if !reflect.DeepEqual(seen.args, wantArgs) {
		t.Fatalf("args = %v", seen.args)
	}
	want := []Entry{
		{ID: 12, Bucket: "avatars", Prefix: "3f2a/", Objects: []string{"3f2a/a.jpg", "3f2a/b.png"}},
		{ID: 13, Bucket: "care-documents", Prefix: "letters/9/", Objects: []string{}},
		{ID: 14, Bucket: "attachments", Prefix: "posts/3f2a/"},
	}
	if !reflect.DeepEqual(entries, want) {
		t.Fatalf("entries = %+v", entries)
	}
}

func TestClaimWithAnEmptyQueue(t *testing.T) {
	var seen captured
	server := recordingServer(t, `[]`, &seen)
	entries, err := newStore(server.URL).Claim(context.Background(), "janitor-1", 5, 10, 30500*time.Millisecond)
	if err != nil || len(entries) != 0 {
		t.Fatalf("entries = %v, err = %v", entries, err)
	}
	if seen.args["p_lease_seconds"] != float64(31) {
		t.Fatalf("lease must round up to whole seconds: %v", seen.args)
	}
}

func TestReportSendsEveryFieldWithNullForAnEmptyError(t *testing.T) {
	var seen captured
	server := recordingServer(t, `3`, &seen)
	results := []Result{
		{ID: 1, Deleted: 2},
		{ID: 2, Deleted: 100, Error: "storage delete avatars: status 404: Bucket not found"},
		{ID: 3, Deleted: 5, Release: true},
		{ID: 4, Deleted: -1},
	}

	updated, err := newStore(server.URL).Report(context.Background(), "janitor-1", results)
	if err != nil || updated != 3 {
		t.Fatalf("updated = %d, err = %v", updated, err)
	}
	if seen.method != http.MethodPost || seen.path != "/rpc/storage_cleanup_report" || seen.claims["role"] != "service_role" ||
		seen.contentProfile != "public" || seen.acceptProfile != "public" {
		t.Fatalf("request = %+v", seen)
	}
	want := map[string]any{
		"p_instance": "janitor-1",
		"p_results": []any{
			map[string]any{"id": float64(1), "deleted": float64(2), "error": nil, "release": false},
			map[string]any{"id": float64(2), "deleted": float64(100), "error": "storage delete avatars: status 404: Bucket not found", "release": false},
			map[string]any{"id": float64(3), "deleted": float64(5), "error": nil, "release": true},
			map[string]any{"id": float64(4), "deleted": float64(0), "error": nil, "release": false},
		},
	}
	if !reflect.DeepEqual(seen.args, want) {
		t.Fatalf("args = %#v", seen.args)
	}
}

func TestReportClipsLongErrorsTo500Characters(t *testing.T) {
	var seen captured
	server := recordingServer(t, `1`, &seen)
	long := strings.Repeat("é", 600)

	if _, err := newStore(server.URL).Report(context.Background(), "janitor-1", []Result{{ID: 1, Error: long}}); err != nil {
		t.Fatal(err)
	}
	sent := seen.args["p_results"].([]any)[0].(map[string]any)["error"].(string)
	if sent != strings.Repeat("é", 500) {
		t.Fatalf("error has %d characters", len([]rune(sent)))
	}
}

func TestRPCErrorsNameTheFunctionAndStatus(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(`{"code":"PGRST202","message":"Could not find the function public.storage_cleanup_claim"}`))
	}))
	defer server.Close()

	_, err := newStore(server.URL).Claim(context.Background(), "j1", 1, 1, time.Minute)
	if err == nil || !strings.Contains(err.Error(), "rpc storage_cleanup_claim: status 404") || !strings.Contains(err.Error(), "Could not find") {
		t.Fatalf("err = %v", err)
	}
}

func TestRPCRejectsAnOversizedResponse(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`["` + strings.Repeat("x", maxResponse) + `"]`))
	}))
	defer server.Close()

	_, err := newStore(server.URL).Claim(context.Background(), "j1", 1, 1, time.Minute)
	if err == nil || !strings.Contains(err.Error(), "lower BATCH_SIZE or OBJECTS_PER_ENTRY") {
		t.Fatalf("err = %v", err)
	}
}

func TestPingReportsPostgRESTAvailability(t *testing.T) {
	status := http.StatusOK
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodHead || r.URL.Path != "/" {
			t.Errorf("ping = %s %s", r.Method, r.URL.Path)
		}
		w.WriteHeader(status)
	}))
	defer server.Close()
	store := newStore(server.URL)

	if err := store.Ping(context.Background()); err != nil {
		t.Fatal(err)
	}
	status = http.StatusBadGateway
	if err := store.Ping(context.Background()); err == nil {
		t.Fatal("expected an error for 502")
	}
}
