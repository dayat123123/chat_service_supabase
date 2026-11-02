package storage

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"
)

type captured struct {
	method, path, contentType, apikey string
	claims                            map[string]any
	body                              map[string]any
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

func recordingServer(t *testing.T, status int, reply string, seen *captured) *httptest.Server {
	t.Helper()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen.method = r.Method
		seen.path = r.URL.EscapedPath()
		seen.contentType = r.Header.Get("Content-Type")
		seen.apikey = r.Header.Get("apikey")
		seen.claims = serviceClaims(t, r.Header.Get("Authorization"), []byte("secret"))
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &seen.body)
		w.WriteHeader(status)
		_, _ = w.Write([]byte(reply))
	}))
	t.Cleanup(server.Close)
	return server
}

func newClient(url string) *Client {
	c := New(url, []byte("secret"), "supabase", 5*time.Second)
	c.now = func() time.Time { return time.Unix(1_800_000_000, 0) }
	return c
}

func TestDeleteSendsTheNamesAndCountsDeletedObjects(t *testing.T) {
	var seen captured
	reply := `[{"name":"3f2a/a.jpg","bucket_id":"avatars"},{"name":"3f2a/b.png","bucket_id":"avatars"}]`
	server := recordingServer(t, http.StatusOK, reply, &seen)

	deleted, err := newClient(server.URL).Delete(context.Background(), "avatars", []string{"3f2a/a.jpg", "3f2a/b.png", "3f2a/gone.jpg"})
	if err != nil || deleted != 2 {
		t.Fatalf("deleted = %d, err = %v", deleted, err)
	}
	if seen.method != http.MethodDelete || seen.path != "/object/avatars" || seen.contentType != "application/json" || seen.apikey != "" {
		t.Fatalf("request = %+v", seen)
	}
	want := map[string]any{"iss": "supabase", "role": "service_role", "iat": float64(1_800_000_000), "exp": float64(1_800_000_060)}
	if !reflect.DeepEqual(seen.claims, want) {
		t.Fatalf("claims = %v", seen.claims)
	}
	if !reflect.DeepEqual(seen.body, map[string]any{"prefixes": []any{"3f2a/a.jpg", "3f2a/b.png", "3f2a/gone.jpg"}}) {
		t.Fatalf("body = %v", seen.body)
	}
}

func TestDeleteEscapesTheBucket(t *testing.T) {
	var seen captured
	server := recordingServer(t, http.StatusOK, `[]`, &seen)

	deleted, err := newClient(server.URL).Delete(context.Background(), "odd/bucket name", []string{"x"})
	if err != nil || deleted != 0 {
		t.Fatalf("deleted = %d, err = %v", deleted, err)
	}
	if seen.path != "/object/odd%2Fbucket%20name" {
		t.Fatalf("path = %q", seen.path)
	}
}

func TestDeleteWithoutNamesMakesNoRequest(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Errorf("unexpected request %s %s", r.Method, r.URL.Path)
	}))
	defer server.Close()

	if deleted, err := newClient(server.URL).Delete(context.Background(), "avatars", nil); err != nil || deleted != 0 {
		t.Fatalf("deleted = %d, err = %v", deleted, err)
	}
}

func TestDeleteErrorsCarryTheStorageReason(t *testing.T) {
	cases := []struct {
		name   string
		status int
		reply  string
		want   string
	}{
		{"message", http.StatusBadRequest, `{"statusCode":"404","error":"not_found","message":"Bucket not found"}`, "storage delete avatars: status 400: Bucket not found"},
		{"error only", http.StatusForbidden, `{"statusCode":"403","error":"Unauthorized"}`, "storage delete avatars: status 403: Unauthorized"},
		{"plain body", http.StatusBadGateway, `upstream down`, "storage delete avatars: status 502"},
		{"bad success body", http.StatusOK, `{"deleted":2}`, "storage delete avatars: decode response"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var seen captured
			server := recordingServer(t, tc.status, tc.reply, &seen)
			deleted, err := newClient(server.URL).Delete(context.Background(), "avatars", []string{"a"})
			if deleted != 0 || err == nil || !strings.HasPrefix(err.Error(), tc.want) {
				t.Fatalf("deleted = %d, err = %v, want %q", deleted, err, tc.want)
			}
		})
	}
}

func TestDeleteReportsUnreachableStorage(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	server.Close()

	_, err := newClient(server.URL).Delete(context.Background(), "avatars", []string{"a"})
	if err == nil || !strings.HasPrefix(err.Error(), "storage delete avatars: ") {
		t.Fatalf("err = %v", err)
	}
}

func TestDeleteStopsWithTheContext(t *testing.T) {
	stop := make(chan struct{})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.ReadAll(r.Body)
		select {
		case <-r.Context().Done():
		case <-stop:
		}
	}))
	defer server.Close()
	defer close(stop)
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()

	_, err := newClient(server.URL).Delete(ctx, "avatars", []string{"a"})
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("err = %v", err)
	}
}

func TestPingReportsStorageAvailability(t *testing.T) {
	status := http.StatusOK
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/status" {
			t.Errorf("ping = %s %s", r.Method, r.URL.Path)
		}
		w.WriteHeader(status)
	}))
	defer server.Close()
	client := newClient(server.URL)

	if err := client.Ping(context.Background()); err != nil {
		t.Fatal(err)
	}
	status = http.StatusServiceUnavailable
	if err := client.Ping(context.Background()); err == nil {
		t.Fatal("expected an error for 503")
	}
}
