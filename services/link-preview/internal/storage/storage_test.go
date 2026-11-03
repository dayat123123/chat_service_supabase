package storage

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestUploadPostsToLinkPreviewBucket(t *testing.T) {
	var got struct {
		method, path, auth, mime, cache, upsert string
		body                                    []byte
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got.method, got.path = r.Method, r.URL.EscapedPath()
		got.auth, got.mime = r.Header.Get("Authorization"), r.Header.Get("Content-Type")
		got.cache, got.upsert = r.Header.Get("Cache-Control"), r.Header.Get("x-upsert")
		got.body, _ = io.ReadAll(r.Body)
		_, _ = w.Write([]byte(`{"Key":"link-previews/x"}`))
	}))
	defer srv.Close()
	c := New(srv.URL, []byte(strings.Repeat("s", 40)), "supabase", 5*time.Second)
	if err := c.Upload(context.Background(), "abc/0123456789abcdef/preview.png", "image/png", []byte("png")); err != nil {
		t.Fatal(err)
	}
	if got.method != http.MethodPost || got.path != "/object/link-previews/abc/0123456789abcdef/preview.png" ||
		!strings.HasPrefix(got.auth, "Bearer ") || got.mime != "image/png" || got.cache != "max-age=604800" ||
		got.upsert != "" || string(got.body) != "png" {
		t.Fatalf("request = %+v", got)
	}
}

func TestUploadReportsStorageErrors(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"statusCode":"413","error":"Payload too large","message":"The object exceeded the maximum allowed size"}`))
	}))
	defer srv.Close()
	c := New(srv.URL, []byte(strings.Repeat("s", 40)), "supabase", 5*time.Second)
	err := c.Upload(context.Background(), "a/b/preview.jpg", "image/jpeg", []byte("x"))
	if err == nil || !strings.Contains(err.Error(), "status 400: Payload too large") {
		t.Fatalf("err = %v", err)
	}
}

func TestPing(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/status" {
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer srv.Close()
	if err := New(srv.URL, []byte(strings.Repeat("s", 40)), "supabase", time.Second).Ping(context.Background()); err != nil {
		t.Fatal(err)
	}
}
