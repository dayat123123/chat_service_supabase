package server

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"strings"
	"testing"
	"time"

	"olt-social/auth-bridge/internal/exchange"
	"olt-social/auth-bridge/internal/olt"
	"olt-social/auth-bridge/internal/ratelimit"
	"olt-social/auth-bridge/internal/token"
)

const secret = "test-secret-yang-panjangnya-lebih-dari-32-karakter"

type fakeResolver struct{ err error }

func (f fakeResolver) Resolve(_ context.Context, oltToken string) (exchange.Identity, bool, error) {
	if f.err != nil {
		return exchange.Identity{}, false, f.err
	}
	u, err := olt.MockVerifier{}.Verify(context.Background(), oltToken)
	if err != nil {
		return exchange.Identity{}, false, err
	}
	return exchange.Identity{
		Profile: exchange.Profile{ID: "uuid-" + u.ID, OLTUserID: u.ID, Username: u.Username},
		Email:   "x@olt.id",
	}, false, nil
}

func newTestServer(resolver Resolver, limit int) http.Handler {
	return New(Options{
		Log:            slog.New(slog.NewTextHandler(io.Discard, nil)),
		Resolver:       resolver,
		Issuer:         token.NewIssuer(secret, 15*time.Minute, "olt-auth-bridge"),
		Limiter:        ratelimit.New(limit, time.Minute),
		TrustedProxies: []netip.Prefix{netip.MustParsePrefix("10.0.0.0/8")},
		OLTMode:        "mock",
	}).Handler()
}

func post(h http.Handler, body, remote, xff string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodPost, "/exchange", strings.NewReader(body))
	req.RemoteAddr = remote
	if xff != "" {
		req.Header.Set("X-Forwarded-For", xff)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestExchangeSuccess(t *testing.T) {
	rec := post(newTestServer(fakeResolver{}, 10), `{"token":"mock:1001:budi"}`, "10.0.0.5:1234", "203.0.113.9")
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body)
	}
	if rec.Header().Get("X-Request-Id") == "" || rec.Header().Get("Cache-Control") != "no-store" {
		t.Error("header X-Request-Id / Cache-Control hilang")
	}

	var resp exchangeResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp.TokenType != "bearer" || resp.ExpiresIn < 890 || resp.User.Username != "budi" {
		t.Fatalf("respons = %+v", resp)
	}
	claims, err := token.Verify(resp.AccessToken, []byte(secret), time.Now())
	if err != nil {
		t.Fatal(err)
	}
	if claims["sub"] != "uuid-1001" || claims["role"] != "authenticated" || claims["email"] != "x@olt.id" {
		t.Fatalf("claims = %v", claims)
	}
}

func TestExchangeErrors(t *testing.T) {
	cases := []struct {
		name     string
		resolver Resolver
		body     string
		status   int
		code     string
	}{
		{"body bukan JSON", fakeResolver{}, `token=abc`, 400, "invalid_request"},
		{"token kosong", fakeResolver{}, `{"token":"  "}`, 400, "invalid_request"},
		{"token ditolak OLT", fakeResolver{}, `{"token":"salah"}`, 401, "invalid_token"},
		{"OLT down", fakeResolver{err: fmt.Errorf("%w: timeout", olt.ErrUnavailable)}, `{"token":"t"}`, 503, "olt_unavailable"},
		{"DB gagal", fakeResolver{err: fmt.Errorf("upsert profil: boom")}, `{"token":"t"}`, 502, "exchange_failed"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			rec := post(newTestServer(c.resolver, 10), c.body, "192.0.2.1:1", "")
			var body map[string]string
			_ = json.Unmarshal(rec.Body.Bytes(), &body)
			if rec.Code != c.status || body["error"] != c.code {
				t.Fatalf("status=%d error=%q, want %d %q", rec.Code, body["error"], c.status, c.code)
			}
		})
	}
}

func TestExchangeRateLimitPerClientIP(t *testing.T) {
	h := newTestServer(fakeResolver{}, 2)
	for range 2 {
		if rec := post(h, `{"token":"mock:1:a"}`, "10.0.0.5:1", "198.51.100.7"); rec.Code != 200 {
			t.Fatalf("status = %d", rec.Code)
		}
	}
	rec := post(h, `{"token":"mock:1:a"}`, "10.0.0.5:1", "198.51.100.7")
	if rec.Code != http.StatusTooManyRequests || rec.Header().Get("Retry-After") == "" {
		t.Fatalf("status = %d, want 429 dengan Retry-After", rec.Code)
	}
	// Klien lain di balik proxy yang sama punya kuota sendiri.
	if rec := post(h, `{"token":"mock:1:a"}`, "10.0.0.5:1", "198.51.100.8"); rec.Code != 200 {
		t.Fatalf("klien lain ikut terblokir, status = %d", rec.Code)
	}
	// X-Forwarded-For dari klien yang tidak tepercaya diabaikan (tidak bisa memalsukan IP).
	for range 2 {
		post(h, `{"token":"mock:1:a"}`, "192.0.2.50:1", "1.1.1.1")
	}
	if rec := post(h, `{"token":"mock:1:a"}`, "192.0.2.50:1", "8.8.8.8"); rec.Code != http.StatusTooManyRequests {
		t.Fatalf("XFF palsu tidak boleh melewati rate limit, status = %d", rec.Code)
	}
}

func TestHealth(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestServer(fakeResolver{}, 1).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/health", nil))
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), `"status":"ok"`) {
		t.Fatalf("health = %d %s", rec.Code, rec.Body)
	}
}
