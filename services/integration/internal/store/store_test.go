package store

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"olt-social/integration/internal/heartbeat"
)

var secret = []byte("an-integration-test-secret-of-32-chars-or-more")

func fakeREST(t *testing.T, handler func(fn string, body map[string]any) (int, string)) *PostgREST {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.Header.Get("Authorization"), "Bearer ") || r.Header.Get("Content-Profile") != "public" {
			t.Errorf("header salah: %v", r.Header)
		}
		var body map[string]any
		_ = json.NewDecoder(r.Body).Decode(&body)
		status, out := handler(strings.TrimPrefix(r.URL.Path, "/rpc/"), body)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_, _ = w.Write([]byte(out))
	}))
	t.Cleanup(srv.Close)
	return NewPostgREST(srv.URL, secret, "supabase", 5*time.Second)
}

func TestAuthenticate(t *testing.T) {
	p := fakeREST(t, func(fn string, body map[string]any) (int, string) {
		if fn != "integration_authenticate" {
			t.Errorf("fn = %s", fn)
		}
		if body["p_key_hash"] == "unknown" {
			return 200, "null"
		}
		if body["p_ip"] != "10.0.0.1" {
			t.Errorf("p_ip = %v", body["p_ip"])
		}
		return 200, `{"id":"k1","name":"OLT","prefix":"AbCdEfGh","scopes":["notify"],"rate_limit_per_minute":600,"ip_allowed":true}`
	})
	k, err := p.Authenticate(context.Background(), "hash", "10.0.0.1")
	if err != nil || k == nil || k.ID != "k1" || k.RateLimit != 600 || !k.IPAllowed || !k.Has("notify") {
		t.Fatalf("key = %+v err = %v", k, err)
	}
	if k, err := p.Authenticate(context.Background(), "unknown", "10.0.0.1"); k != nil || err != nil {
		t.Fatalf("key tidak dikenal: %+v %v", k, err)
	}
}

func TestCallMapsErrors(t *testing.T) {
	cases := map[string]struct {
		status int
		body   string
		api    *APIError
	}{
		"error API dari RPC": {403, `{"code":"PT403","message":"scope_forbidden","details":"API key ini tidak punya izin notify"}`,
			&APIError{Status: 403, Code: "scope_forbidden", Detail: "API key ini tidak punya izin notify"}},
		"fungsi belum ada": {404, `{"code":"PGRST202","message":"Could not find the function"}`, nil},
		"JWT ditolak":      {401, `{"code":"PGRST301","message":"JWT invalid"}`, nil},
		"database mati":    {503, `{"code":"PGRST001","message":"Database client error"}`, nil},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			p := fakeREST(t, func(string, map[string]any) (int, string) { return tc.status, tc.body })
			_, err := p.Notify(context.Background(), "k1", json.RawMessage(`[]`), "")
			var api *APIError
			if tc.api != nil {
				if !errors.As(err, &api) || *api != *tc.api {
					t.Fatalf("err = %#v, want %#v", err, tc.api)
				}
				return
			}
			if !errors.Is(err, ErrUnavailable) || errors.As(err, &api) {
				t.Fatalf("err = %v, want ErrUnavailable", err)
			}
		})
	}
}

func TestCallReportsUnreachableAPI(t *testing.T) {
	p := NewPostgREST("http://127.0.0.1:1", secret, "supabase", time.Second)
	if _, err := p.BotPosts(context.Background(), "k1", json.RawMessage(`[]`), ""); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("err = %v", err)
	}
}

func TestNotifyAndBotPostsSendArguments(t *testing.T) {
	var seen []string
	p := fakeREST(t, func(fn string, body map[string]any) (int, string) {
		seen = append(seen, fn)
		switch fn {
		case "integration_notify":
			if body["p_key_id"] != "k1" || body["p_ip"] != nil || len(body["p_messages"].([]any)) != 1 {
				t.Errorf("body = %v", body)
			}
		case "integration_bot_post":
			if len(body["p_posts"].([]any)) != 1 || body["p_ip"] != "198.51.100.7" {
				t.Errorf("body = %v", body)
			}
		case "service_heartbeat":
			if body["p_service"] != "integration" || body["p_error"] != nil {
				t.Errorf("body = %v", body)
			}
		}
		return 200, `{"results":[]}`
	})
	if out, err := p.Notify(context.Background(), "k1", json.RawMessage(`[{"id":"a"}]`), ""); err != nil || string(out) != `{"results":[]}` {
		t.Fatalf("out = %s err = %v", out, err)
	}
	if _, err := p.BotPosts(context.Background(), "k1", json.RawMessage(`[{"id":"a"}]`), "198.51.100.7"); err != nil {
		t.Fatal(err)
	}
	if err := p.Heartbeat(context.Background(), heartbeat.Beat{Service: "integration", Instance: "i", Version: "0.1.0",
		StartedAt: time.Now(), Status: heartbeat.StatusOK}); err != nil {
		t.Fatal(err)
	}
	if strings.Join(seen, ",") != "integration_notify,integration_bot_post,service_heartbeat" {
		t.Fatalf("seen = %v", seen)
	}
}
