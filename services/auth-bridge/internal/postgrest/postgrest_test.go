package postgrest

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"olt-social/auth-bridge/internal/exchange"
	"olt-social/auth-bridge/internal/heartbeat"
)

type staticToken string

func (s staticToken) ServiceToken() (string, error) { return string(s), nil }

func TestUpsertProfile(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rpc/upsert_olt_profile" || r.Method != http.MethodPost {
			t.Errorf("request %s %s", r.Method, r.URL.Path)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer svc-token" {
			t.Errorf("Authorization = %q", got)
		}
		var body map[string]any
		_ = json.NewDecoder(r.Body).Decode(&body)
		if body["p_olt_user_id"] != "1001" || body["p_email"] != nil {
			t.Errorf("body = %v", body)
		}
		_, _ = w.Write([]byte(`{"id":"u-1","olt_user_id":"1001","username":"budi","display_name":null,"avatar_url":null,"is_verified":true}`))
	}))
	defer srv.Close()

	c := NewClient(srv.URL, staticToken("svc-token"))
	p, err := c.UpsertProfile(context.Background(), exchange.ProfileInput{ID: "u-1", OLTUserID: "1001", Username: "budi"})
	if err != nil {
		t.Fatal(err)
	}
	if p.ID != "u-1" || p.Username != "budi" || !p.IsVerified || p.DisplayName != nil {
		t.Fatalf("profile = %+v", p)
	}
}

func TestUpsertProfileError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusConflict)
		_, _ = w.Write([]byte(`{"code":"PT409","message":"username_unavailable"}`))
	}))
	defer srv.Close()

	_, err := NewClient(srv.URL, staticToken("t")).UpsertProfile(context.Background(), exchange.ProfileInput{ID: "u"})
	if err == nil || !strings.Contains(err.Error(), "username_unavailable") {
		t.Fatalf("err = %v", err)
	}
}

func TestRPCRetriesTransientErrors(t *testing.T) {
	var calls atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		if calls.Add(1) < 3 {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte(`{"id":"u-1","olt_user_id":"1001","username":"budi","is_verified":false}`))
	}))
	defer srv.Close()

	c := NewClient(srv.URL, staticToken("t"))
	c.backoff = time.Millisecond
	p, err := c.UpsertProfile(context.Background(), exchange.ProfileInput{ID: "u-1", OLTUserID: "1001"})
	if err != nil || p.ID != "u-1" {
		t.Fatalf("profile=%+v err=%v", p, err)
	}
	if calls.Load() != 3 {
		t.Fatalf("calls = %d, want 3 (2x 503 lalu sukses)", calls.Load())
	}
}

func TestRPCDoesNotRetryClientErrorsAndGivesUp(t *testing.T) {
	cases := map[string]struct {
		status int
		want   int32
	}{
		"4xx tidak di-retry":          {http.StatusConflict, 1},
		"5xx berhenti setelah 3 kali": {http.StatusBadGateway, 3},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			var calls atomic.Int32
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				calls.Add(1)
				w.WriteHeader(c.status)
			}))
			defer srv.Close()

			client := NewClient(srv.URL, staticToken("t"))
			client.backoff = time.Millisecond
			if _, err := client.UpsertProfile(context.Background(), exchange.ProfileInput{ID: "u"}); err == nil {
				t.Fatal("harus gagal")
			}
			if calls.Load() != c.want {
				t.Fatalf("calls = %d, want %d", calls.Load(), c.want)
			}
		})
	}
}

func TestReplaceAccountLinks(t *testing.T) {
	var got map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rpc/set_olt_account_links" || r.Header.Get("Authorization") != "Bearer svc" {
			t.Errorf("request %s %s", r.URL.Path, r.Header.Get("Authorization"))
		}
		_ = json.NewDecoder(r.Body).Decode(&got)
		_, _ = w.Write([]byte(`{"linked":2,"ignored":0}`))
	}))
	defer srv.Close()

	c := NewClient(srv.URL, staticToken("svc"))
	if err := c.ReplaceAccountLinks(context.Background(), "u-1", []string{"W137", "C1626"}); err != nil {
		t.Fatal(err)
	}
	if got["p_profile_id"] != "u-1" || len(got["p_accounts"].([]any)) != 2 {
		t.Fatalf("body = %v", got)
	}
	if err := c.ReplaceAccountLinks(context.Background(), "u-1", nil); err != nil {
		t.Fatal(err)
	}
	if accounts, ok := got["p_accounts"].([]any); !ok || len(accounts) != 0 {
		t.Fatalf("nil harus dikirim sebagai array kosong, body = %v", got)
	}
}

func TestHeartbeatCallsServiceHeartbeatAndAcceptsEmptyResponse(t *testing.T) {
	var got map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rpc/service_heartbeat" || r.Header.Get("Authorization") != "Bearer svc" {
			t.Errorf("request %s %s", r.URL.Path, r.Header.Get("Authorization"))
		}
		_ = json.NewDecoder(r.Body).Decode(&got)
		w.WriteHeader(http.StatusNoContent)
	}))
	defer srv.Close()

	started := time.Date(2026, 11, 4, 8, 0, 0, 0, time.FixedZone("WIB", 7*3600))
	err := NewClient(srv.URL, staticToken("svc")).Heartbeat(context.Background(), heartbeat.Beat{
		Service:   "auth-bridge",
		Instance:  "bridge-1",
		Version:   "0.6.0",
		StartedAt: started,
		Status:    heartbeat.StatusOK,
		Detail:    map[string]any{"olt_mode": "jwt"},
	})
	if err != nil {
		t.Fatal(err)
	}
	detail, _ := got["p_detail"].(map[string]any)
	if got["p_service"] != "auth-bridge" || got["p_instance"] != "bridge-1" || got["p_version"] != "0.6.0" ||
		got["p_started_at"] != "2026-11-04T01:00:00Z" || got["p_status"] != "ok" || got["p_error"] != nil ||
		detail["olt_mode"] != "jwt" {
		t.Fatalf("body = %v", got)
	}
}

func TestHeartbeatReportsRejectedCalls(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusForbidden)
		_, _ = w.Write([]byte(`{"code":"42501","message":"permission denied"}`))
	}))
	defer srv.Close()

	err := NewClient(srv.URL, staticToken("t")).Heartbeat(context.Background(), heartbeat.Beat{Service: "auth-bridge"})
	if err == nil || !strings.Contains(err.Error(), "permission denied") {
		t.Fatalf("err = %v", err)
	}
}
