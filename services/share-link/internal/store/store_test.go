package store

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

var secret = []byte("a-share-link-test-secret-of-32-chars-or-more")

func TestRPCsSendAServiceRoleTokenAndDecode(t *testing.T) {
	var calls []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls = append(calls, r.URL.Path)
		if !strings.HasPrefix(r.Header.Get("Authorization"), "Bearer ") || r.Header.Get("Content-Profile") != "public" {
			t.Errorf("headers = %v", r.Header)
		}
		body, _ := io.ReadAll(r.Body)
		switch r.URL.Path {
		case "/rpc/share_link_config":
			_, _ = w.Write([]byte(`{"ready":true,"base_url":"https://s.test","app_scheme":"olt","android":[{"package":"co.olt","sha256":["AB"]}]}`))
		case "/rpc/share_post_preview":
			var args map[string]string
			_ = json.Unmarshal(body, &args)
			if args["p_code"] != "Ab12Cd34Ef" {
				t.Errorf("args = %s", body)
			}
			_, _ = w.Write([]byte(`{"status":"ok","preview":true,"author":{"username":"ani"},"created_at":"2026-11-27T20:00:00Z","image":{"path":"posts/a/b.png","width":10,"height":5}}`))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer srv.Close()
	c := New(srv.URL, srv.URL, secret, "supabase", time.Second)
	settings, err := c.Settings(context.Background())
	if err != nil || !settings.Ready || settings.Android[0].Package != "co.olt" {
		t.Fatalf("settings = %+v err = %v", settings, err)
	}
	preview, err := c.Preview(context.Background(), "Ab12Cd34Ef")
	if err != nil || preview.Author.Username != "ani" || preview.Image.Width != 10 || preview.CreatedAt.IsZero() {
		t.Fatalf("preview = %+v err = %v", preview, err)
	}
	if len(calls) != 2 {
		t.Fatalf("calls = %v", calls)
	}
}

func TestRPCErrorsAreUnavailable(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"code":"XX000","message":"boom"}`))
	}))
	defer srv.Close()
	_, err := New(srv.URL, srv.URL, secret, "supabase", time.Second).Settings(context.Background())
	if !errors.Is(err, ErrUnavailable) {
		t.Fatalf("err = %v", err)
	}
}

func TestPostImageUsesAuthenticatedRenderAndEscapesPath(t *testing.T) {
	var seen *http.Request
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen = r
		w.Header().Set("Content-Type", "image/webp")
		w.Header().Set("ETag", `"e1"`)
		_, _ = w.Write([]byte("webp"))
	}))
	defer srv.Close()
	c := New(srv.URL, srv.URL, secret, "supabase", time.Second)
	blob, err := c.PostImage(context.Background(), "posts/a b/c.png", 1200, 1<<20)
	if err != nil || string(blob.Data) != "webp" || blob.ContentType != "image/webp" || blob.ETag != `"e1"` {
		t.Fatalf("blob = %+v err = %v", blob, err)
	}
	if seen.URL.EscapedPath() != "/render/image/authenticated/attachments/posts/a%20b/c.png" ||
		seen.URL.Query().Get("width") != "1200" || !strings.HasPrefix(seen.Header.Get("Authorization"), "Bearer ") {
		t.Fatalf("request = %s %v", seen.URL.String(), seen.Header)
	}
	if _, err := c.Avatar(context.Background(), "u/a.jpg", 1<<20); err != nil {
		t.Fatal(err)
	}
	if seen.URL.Path != "/render/image/public/avatars/u/a.jpg" || seen.Header.Get("Authorization") != "" {
		t.Fatalf("avatar request = %s auth = %q", seen.URL.Path, seen.Header.Get("Authorization"))
	}
}

func TestImageRejectsNonImagesMissingAndOversized(t *testing.T) {
	cases := []struct {
		name   string
		status int
		ctype  string
		body   string
		want   error
	}{
		{"html", http.StatusOK, "text/html", "<svg>", ErrNotFound},
		{"svg", http.StatusOK, "image/svg+xml", "<svg>", ErrNotFound},
		{"missing", http.StatusNotFound, "application/json", "{}", ErrNotFound},
		{"large", http.StatusOK, "image/png", strings.Repeat("x", 2048), ErrTooLarge},
		{"down", http.StatusBadGateway, "text/plain", "", ErrUnavailable},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				w.Header().Set("Content-Type", tc.ctype)
				w.WriteHeader(tc.status)
				_, _ = w.Write([]byte(tc.body))
			}))
			defer srv.Close()
			_, err := New(srv.URL, srv.URL, secret, "supabase", time.Second).PostImage(context.Background(), "posts/a/b.png", 100, 1024)
			if !errors.Is(err, tc.want) {
				t.Fatalf("err = %v, want %v", err, tc.want)
			}
		})
	}
}

func TestRedirectsAreNotFollowed(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "http://169.254.169.254/", http.StatusFound)
	}))
	defer srv.Close()
	_, err := New(srv.URL, srv.URL, secret, "supabase", time.Second).Avatar(context.Background(), "u/a.jpg", 1024)
	if !errors.Is(err, ErrUnavailable) {
		t.Fatalf("err = %v", err)
	}
}
