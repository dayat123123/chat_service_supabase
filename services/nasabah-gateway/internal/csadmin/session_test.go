package csadmin

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"olt-social/nasabah-gateway/internal/jwt"
)

func legacyServer(t *testing.T, logins *atomic.Int32, exp time.Time, status int) *httptest.Server {
	t.Helper()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/csAdmin/cs/login" || r.Method != http.MethodPost || r.Header.Get("Content-Type") != "application/json" {
			http.NotFound(w, r)
			return
		}
		var body map[string]string
		_ = json.NewDecoder(r.Body).Decode(&body)
		logins.Add(1)
		if status != http.StatusOK || body["LoginId"] != "svc" || body["Password"] != "pw" {
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte(`{"message":"Login failed","data":{}}`))
			return
		}
		token, _ := jwt.Sign(map[string]any{"alg": "HS256", "typ": "JWS"}, map[string]any{"iss": "auth0", "loginId": "svc", "exp": exp.Unix()}, []byte("legacy"))
		_ = json.NewEncoder(w).Encode(map[string]any{"message": "Login successfully.", "data": map[string]any{"LoginId": "svc", "Token": token}})
	}))
	t.Cleanup(server.Close)
	return server
}

func TestSessionLogsInOnceAndRefreshesBeforeExpiry(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	var logins atomic.Int32
	server := legacyServer(t, &logins, now.Add(5*time.Hour), http.StatusOK)
	s := NewSession(server.URL+"/csAdmin/", "svc", "pw", nil)
	s.now = func() time.Time { return now }

	first, err := s.Token(context.Background())
	if err != nil || first == "" {
		t.Fatalf("token %q err %v", first, err)
	}
	second, _ := s.Token(context.Background())
	if second != first || logins.Load() != 1 {
		t.Fatalf("token must be reused, logins = %d", logins.Load())
	}
	now = now.Add(5*time.Hour - 30*time.Second)
	_, _ = s.Token(context.Background())
	if logins.Load() != 2 {
		t.Fatalf("token must be refreshed a minute before expiry, logins = %d", logins.Load())
	}
}

func TestSessionInvalidateForcesANewLogin(t *testing.T) {
	var logins atomic.Int32
	server := legacyServer(t, &logins, time.Now().Add(time.Hour), http.StatusOK)
	s := NewSession(server.URL+"/csAdmin", "svc", "pw", nil)
	token, _ := s.Token(context.Background())
	s.Invalidate("some-other-token")
	_, _ = s.Token(context.Background())
	if logins.Load() != 1 {
		t.Fatal("invalidating a stale token must keep the current one")
	}
	s.Invalidate(token)
	_, _ = s.Token(context.Background())
	if logins.Load() != 2 {
		t.Fatal("invalidating the current token must log in again")
	}
}

func TestSessionReportsRejectedCredentials(t *testing.T) {
	var logins atomic.Int32
	server := legacyServer(t, &logins, time.Now().Add(time.Hour), http.StatusUnauthorized)
	s := NewSession(server.URL+"/csAdmin", "svc", "wrong", nil)
	if _, err := s.Token(context.Background()); !errors.Is(err, ErrLoginFailed) {
		t.Fatalf("err = %v", err)
	}
}

func TestSessionIsNotConfiguredWithoutCredentials(t *testing.T) {
	if NewSession("http://csadmin", "svc", "", nil).Configured() || NewSession("", "svc", "pw", nil).Configured() {
		t.Fatal("missing url or password must not count as configured")
	}
	if !NewSession("http://csadmin", "svc", "pw", nil).Configured() {
		t.Fatal("complete settings must count as configured")
	}
}
