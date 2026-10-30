package postgrest

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

type staticToken string

func (s staticToken) Token() (string, error) { return string(s), nil }

func TestCallSendsSchemaAndDecodes(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rpc/agent_customer_access" || r.Header.Get("Content-Profile") != "cs_api" ||
			r.Header.Get("Authorization") != "Bearer svc" {
			t.Errorf("request salah: %s %v", r.URL.Path, r.Header)
		}
		var args map[string]string
		_ = json.NewDecoder(r.Body).Decode(&args)
		_ = json.NewEncoder(w).Encode(map[string]string{"id": args["p_letter_id"]})
	}))
	defer srv.Close()

	c := New(srv.URL, staticToken("svc"), time.Second)
	var out struct {
		ID string `json:"id"`
	}
	if err := c.Call(context.Background(), "agent_customer_access", map[string]string{"p_letter_id": "L1"}, &out); err != nil {
		t.Fatal(err)
	}
	if out.ID != "L1" {
		t.Fatalf("hasil salah: %+v", out)
	}
}

func TestCallAsForwardsCallerToken(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer staff-jwt" {
			t.Errorf("token pemanggil tidak diteruskan: %q", r.Header.Get("Authorization"))
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer srv.Close()
	if err := New(srv.URL, staticToken("svc"), time.Second).CallAs(context.Background(), "staff-jwt", "x", nil, nil); err != nil {
		t.Fatal(err)
	}
}

func TestErrorsMapToCodes(t *testing.T) {
	cases := []struct {
		status     int
		body       string
		retryAfter string
		want       Error
	}{
		{403, `{"code":"PT403","message":"staff_required","details":"Butuh akun staf aktif dengan 2FA"}`, "",
			Error{Status: 403, Code: "staff_required", Message: "Butuh akun staf aktif dengan 2FA"}},
		{429, `{"code":"PT429","message":"rate_limited","details":"Batas terlampaui"}`, "300",
			Error{Status: 429, Code: "rate_limited", Message: "Batas terlampaui", RetryAfter: "300"}},
		{401, `{"code":"PGRST301","message":"JWT expired"}`, "",
			Error{Status: 401, Code: "PGRST301", Message: "JWT expired"}},
		{502, `bukan json`, "", Error{Status: 502, Code: "Bad Gateway"}},
	}
	for _, c := range cases {
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			if c.retryAfter != "" {
				w.Header().Set("Retry-After", c.retryAfter)
			}
			w.WriteHeader(c.status)
			_, _ = w.Write([]byte(c.body))
		}))
		err := New(srv.URL, staticToken("svc"), time.Second).Call(context.Background(), "x", nil, nil)
		srv.Close()
		got, ok := AsError(err)
		if !ok || *got != c.want {
			t.Errorf("status %d: dapat %#v, ingin %#v", c.status, got, c.want)
		}
	}
}
