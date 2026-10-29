package postgrest

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

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
