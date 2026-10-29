package server

import (
	"context"
	"encoding/json"
	"errors"
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
	"olt-social/auth-bridge/internal/metrics"
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
	}, false, nil
}

func testOptions(resolver Resolver, limit int) Options {
	return Options{
		Log:            slog.New(slog.NewTextHandler(io.Discard, nil)),
		Resolver:       resolver,
		Issuer:         token.NewIssuer(secret, 15*time.Minute, "olt-auth-bridge"),
		Limiter:        ratelimit.New(limit, time.Minute),
		TrustedProxies: []netip.Prefix{netip.MustParsePrefix("10.0.0.0/8")},
		OLTMode:        "mock",
	}
}

func newTestServer(resolver Resolver, limit int) http.Handler {
	return New(testOptions(resolver, limit)).Handler()
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

func get(h http.Handler, path string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
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
	if claims["sub"] != "uuid-1001" || claims["role"] != "authenticated" {
		t.Fatalf("claims = %v", claims)
	}
	if _, ok := claims["email"]; ok {
		t.Fatalf("JWT tidak boleh memuat email: %v", claims)
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
		{"user di-ban", fakeResolver{err: exchange.ErrBanned}, `{"token":"t"}`, 403, "user_banned"},
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

func TestClientIP(t *testing.T) {
	s := New(testOptions(fakeResolver{}, 1))
	cases := []struct{ remote, xff, want string }{
		{"10.0.0.5:1", "203.0.113.9", "203.0.113.9"},                         // klien publik di balik proxy
		{"10.0.0.5:1", "198.51.100.1, 203.0.113.9, 10.0.0.7", "203.0.113.9"}, // paling kanan yang tidak tepercaya
		{"10.0.0.5:1", "10.1.1.1, 10.2.2.2", "10.1.1.1"},                     // semua privat: hop paling kiri
		{"10.0.0.5:1", "", "10.0.0.5"},                                       // tanpa XFF: IP proxy
		{"10.0.0.5:1", "bukan-ip, 10.2.2.2", "10.2.2.2"},                     // entri rusak: berhenti di situ
		{"192.0.2.50:1", "10.1.1.1", "192.0.2.50"},                           // klien tidak tepercaya: XFF diabaikan
	}
	for _, c := range cases {
		req := httptest.NewRequest(http.MethodPost, "/exchange", nil)
		req.RemoteAddr = c.remote
		if c.xff != "" {
			req.Header.Set("X-Forwarded-For", c.xff)
		}
		if got := s.clientIP(req); got != c.want {
			t.Errorf("clientIP(remote=%s, xff=%q) = %s, want %s", c.remote, c.xff, got, c.want)
		}
	}
}

func TestExchangeRateLimitPerUser(t *testing.T) {
	opts := testOptions(fakeResolver{}, 100)
	opts.UserLimiter = ratelimit.New(2, time.Minute)
	h := New(opts).Handler()

	// User yang sama dari IP berbeda tetap berbagi kuota.
	for i := range 2 {
		if rec := post(h, `{"token":"mock:1001:budi"}`, fmt.Sprintf("192.0.2.%d:1", i+1), ""); rec.Code != 200 {
			t.Fatalf("status = %d", rec.Code)
		}
	}
	rec := post(h, `{"token":"mock:1001:budi"}`, "192.0.2.9:1", "")
	if rec.Code != http.StatusTooManyRequests || rec.Header().Get("Retry-After") == "" {
		t.Fatalf("status = %d, want 429 dengan Retry-After", rec.Code)
	}
	if rec := post(h, `{"token":"mock:1002:sari"}`, "192.0.2.9:1", ""); rec.Code != 200 {
		t.Fatalf("user lain ikut terblokir, status = %d", rec.Code)
	}
}

func TestHealth(t *testing.T) {
	rec := get(newTestServer(fakeResolver{}, 1), "/health")
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), `"status":"ok"`) {
		t.Fatalf("health = %d %s", rec.Code, rec.Body)
	}
}

func TestOpsEndpointsNotOnPublicPort(t *testing.T) {
	h := newTestServer(fakeResolver{}, 1)
	for _, path := range []string{"/metrics", "/livez", "/readyz"} {
		if rec := get(h, path); rec.Code != http.StatusNotFound {
			t.Errorf("%s di port publik = %d, want 404", path, rec.Code)
		}
	}
}

func TestReadiness(t *testing.T) {
	failing := func(context.Context) error { return errors.New("connection refused") }
	ok := func(context.Context) error { return nil }
	cases := []struct {
		name   string
		checks []ReadyCheck
		status int
		state  string
	}{
		{"semua sehat", []ReadyCheck{{Name: "postgrest", Check: ok}, {Name: "valkey", Optional: true, Check: ok}}, 200, "ready"},
		{"opsional gagal", []ReadyCheck{{Name: "postgrest", Check: ok}, {Name: "valkey", Optional: true, Check: failing}}, 200, "degraded"},
		{"wajib gagal", []ReadyCheck{{Name: "postgrest", Check: failing}, {Name: "valkey", Optional: true, Check: ok}}, 503, "not_ready"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			opts := testOptions(fakeResolver{}, 1)
			opts.ReadyChecks = c.checks
			rec := get(New(opts).OpsHandler(http.NotFoundHandler()), "/readyz")
			var body struct {
				Status string            `json:"status"`
				Checks map[string]string `json:"checks"`
			}
			_ = json.Unmarshal(rec.Body.Bytes(), &body)
			if rec.Code != c.status || body.Status != c.state {
				t.Fatalf("readyz = %d %s, want %d %s", rec.Code, rec.Body, c.status, c.state)
			}
			if strings.Contains(rec.Body.String(), "connection refused") {
				t.Fatal("detail error tidak boleh ada di respons")
			}
		})
	}
	if rec := get(New(testOptions(fakeResolver{}, 1)).OpsHandler(http.NotFoundHandler()), "/livez"); rec.Code != 200 {
		t.Fatalf("livez = %d", rec.Code)
	}
}

func TestMetricsRecorded(t *testing.T) {
	reg := metrics.NewRegistry()
	opts := testOptions(fakeResolver{}, 100)
	opts.Metrics = NewMetrics(reg)
	s := New(opts)
	h := s.Handler()
	post(h, `{"token":"mock:1001:budi"}`, "192.0.2.1:1", "")
	post(h, `{"token":"salah"}`, "192.0.2.1:1", "")
	get(h, "/tidak-ada")

	out := get(s.OpsHandler(reg.Handler()), "/metrics").Body.String()
	for _, want := range []string{
		`olt_auth_bridge_exchanges_total{result="ok"} 1`,
		`olt_auth_bridge_exchanges_total{result="invalid_token"} 1`,
		`olt_auth_bridge_http_requests_total{path="/exchange",status="200"} 1`,
		`olt_auth_bridge_http_requests_total{path="/exchange",status="401"} 1`,
		`olt_auth_bridge_http_requests_total{path="other",status="404"} 1`,
		`olt_auth_bridge_http_request_duration_seconds_count{path="/exchange"} 2`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("metrik tidak memuat %q:\n%s", want, out)
		}
	}
	if strings.Contains(out, "mock:1001") {
		t.Fatal("token tidak boleh muncul di metrik")
	}
}
