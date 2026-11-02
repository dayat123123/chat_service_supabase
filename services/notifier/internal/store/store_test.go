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

	"olt-social/notifier/internal/push"
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
	p := NewPostgREST(url, []byte("secret"), "supabase")
	p.now = func() time.Time { return time.Unix(1_800_000_000, 0) }
	return p
}

func TestClaimSendsServiceRoleRPCAndDecodesJobs(t *testing.T) {
	var seen captured
	reply := `[
	  {"id": 7, "token": "tok-android-123456", "platform": "android", "kind": "chat.message", "title": "Rina",
	   "body": "Halo", "data": {"room_id": "r1", "count": 3, "seen": true, "gone": null},
	   "collapse_key": "room:r1", "badge": 4, "priority": "high", "ttl_seconds": 86000, "attempt": 2},
	  {"id": 8, "token": "tok-ios-abcdef", "platform": "ios", "kind": "like", "title": "Suka", "body": "",
	   "data": {}, "collapse_key": null, "badge": null, "priority": "normal", "ttl_seconds": 0, "attempt": 1}
	]`
	server := recordingServer(t, reply, &seen)

	jobs, err := newStore(server.URL).Claim(context.Background(), "notifier-1", 100, 60*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	if seen.method != http.MethodPost || seen.path != "/rpc/push_claim" || seen.contentProfile != "public" ||
		seen.acceptProfile != "public" || seen.contentType != "application/json" || seen.accept != "application/json" {
		t.Fatalf("request = %+v", seen)
	}
	if seen.claims["role"] != "service_role" || seen.claims["iss"] != "supabase" ||
		seen.claims["exp"].(float64)-seen.claims["iat"].(float64) != 60 {
		t.Fatalf("claims = %v", seen.claims)
	}
	wantArgs := map[string]any{"p_instance": "notifier-1", "p_limit": float64(100), "p_lease_seconds": float64(60)}
	if !reflect.DeepEqual(seen.args, wantArgs) {
		t.Fatalf("args = %v", seen.args)
	}
	badge := 4
	want := []push.Job{
		{ID: 7, Token: "tok-android-123456", Platform: "android", Kind: "chat.message", Title: "Rina", Body: "Halo",
			Data: map[string]string{"room_id": "r1", "count": "3", "seen": "true"}, CollapseKey: "room:r1",
			Badge: &badge, Priority: "high", TTLSeconds: 86000, Attempt: 2},
		{ID: 8, Token: "tok-ios-abcdef", Platform: "ios", Kind: "like", Title: "Suka", Data: map[string]string{},
			Priority: "normal", Attempt: 1},
	}
	if !reflect.DeepEqual(jobs, want) {
		t.Fatalf("jobs = %+v", jobs)
	}
}

func TestClaimWithAnEmptyQueue(t *testing.T) {
	var seen captured
	server := recordingServer(t, `[]`, &seen)
	jobs, err := newStore(server.URL).Claim(context.Background(), "notifier-1", 5, 1500*time.Millisecond)
	if err != nil || len(jobs) != 0 {
		t.Fatalf("jobs = %v, err = %v", jobs, err)
	}
	if seen.args["p_lease_seconds"] != float64(2) {
		t.Fatalf("lease must round up to whole seconds: %v", seen.args)
	}
}

func TestReportSendsOutcomesWithNullsForEmptyFields(t *testing.T) {
	var seen captured
	server := recordingServer(t, `3`, &seen)
	results := []push.Result{
		{ID: 1, Outcome: push.Sent},
		{ID: 2, Outcome: push.Retry, Error: "Firebase sementara gagal (UNAVAILABLE)", RetryAfter: 90 * time.Second},
		{ID: 3, Outcome: push.Release, Error: "Tidak bisa menghubungi Firebase", RetryAfter: 1500 * time.Millisecond},
	}

	updated, err := newStore(server.URL).Report(context.Background(), "notifier-1", results)
	if err != nil || updated != 3 {
		t.Fatalf("updated = %d, err = %v", updated, err)
	}
	if seen.path != "/rpc/push_report" || seen.claims["role"] != "service_role" {
		t.Fatalf("request = %+v", seen)
	}
	want := map[string]any{
		"p_instance": "notifier-1",
		"p_results": []any{
			map[string]any{"id": float64(1), "outcome": "sent", "error": nil, "retry_after": nil},
			map[string]any{"id": float64(2), "outcome": "retry", "error": "Firebase sementara gagal (UNAVAILABLE)", "retry_after": float64(90)},
			map[string]any{"id": float64(3), "outcome": "release", "error": "Tidak bisa menghubungi Firebase", "retry_after": float64(2)},
		},
	}
	if !reflect.DeepEqual(seen.args, want) {
		t.Fatalf("args = %#v", seen.args)
	}
}

func TestHeartbeatSendsStateAndReturnsQueueDepth(t *testing.T) {
	cases := []struct {
		name string
		beat push.Heartbeat
		want map[string]any
	}{
		{
			name: "not configured",
			beat: push.Heartbeat{Instance: "n1", Version: "0.1.0", StartedAt: time.Date(2026, 11, 2, 3, 4, 5, 0, time.FixedZone("WIB", 7*3600))},
			want: map[string]any{"p_instance": "n1", "p_version": "0.1.0", "p_configured": false, "p_project_id": nil,
				"p_error": nil, "p_started_at": "2026-11-01T20:04:05Z"},
		},
		{
			name: "configured with an error",
			beat: push.Heartbeat{Instance: "n1", Version: "0.1.0", Configured: true, ProjectID: "demo",
				Error: "Firebase menolak akses: denied", StartedAt: time.Date(2026, 11, 2, 0, 0, 0, 0, time.UTC)},
			want: map[string]any{"p_instance": "n1", "p_version": "0.1.0", "p_configured": true, "p_project_id": "demo",
				"p_error": "Firebase menolak akses: denied", "p_started_at": "2026-11-02T00:00:00Z"},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var seen captured
			server := recordingServer(t, `{"queued": 42}`, &seen)
			queued, err := newStore(server.URL).Heartbeat(context.Background(), tc.beat)
			if err != nil || queued != 42 {
				t.Fatalf("queued = %d, err = %v", queued, err)
			}
			if seen.path != "/rpc/push_heartbeat" || !reflect.DeepEqual(seen.args, tc.want) {
				t.Fatalf("path = %s args = %#v", seen.path, seen.args)
			}
		})
	}
}

func TestRPCErrorsNameTheFunctionAndStatus(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(`{"code":"PGRST202","message":"Could not find the function public.push_claim"}`))
	}))
	defer server.Close()

	_, err := newStore(server.URL).Claim(context.Background(), "n1", 1, 10*time.Second)
	if err == nil || !strings.Contains(err.Error(), "rpc push_claim: status 404") || !strings.Contains(err.Error(), "Could not find") {
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
