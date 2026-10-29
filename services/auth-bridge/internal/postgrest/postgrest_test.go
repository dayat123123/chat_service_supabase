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
