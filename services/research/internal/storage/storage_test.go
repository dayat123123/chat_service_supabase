package storage

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestUploadAndDownload(t *testing.T) {
	var gotPath, gotType, gotUpsert, gotAuth, gotBody string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPost:
			gotPath, gotType, gotUpsert, gotAuth = r.URL.Path, r.Header.Get("Content-Type"), r.Header.Get("x-upsert"),
				r.Header.Get("Authorization")
			body, _ := io.ReadAll(r.Body)
			gotBody = string(body)
			_, _ = w.Write([]byte(`{"Key":"x"}`))
		case http.MethodGet:
			switch r.URL.Path {
			case "/object/authenticated/financial-reports/api/abc/report.zip":
				_, _ = w.Write([]byte("zipdata"))
			case "/object/authenticated/financial-reports/api/big/report.zip":
				_, _ = w.Write([]byte(strings.Repeat("x", 100)))
			case "/object/authenticated/financial-reports/api/missing/report.zip":
				w.WriteHeader(http.StatusBadRequest)
				_, _ = w.Write([]byte(`{"statusCode":"404","error":"not_found","message":"Object not found"}`))
			default:
				w.WriteHeader(http.StatusInternalServerError)
				_, _ = w.Write([]byte(`{"message":"boom"}`))
			}
		}
	}))
	defer srv.Close()
	c := New(srv.URL, []byte(strings.Repeat("s", 40)), "supabase", 5*time.Second)
	ctx := context.Background()
	if err := c.Upload(ctx, "api/abc/report.zip", []byte("PK")); err != nil {
		t.Fatal(err)
	}
	if gotPath != "/object/financial-reports/api/abc/report.zip" || gotType != "application/zip" || gotUpsert != "true" ||
		!strings.HasPrefix(gotAuth, "Bearer ") || gotBody != "PK" {
		t.Fatalf("upload request %q %q %q %q %q", gotPath, gotType, gotUpsert, gotAuth, gotBody)
	}
	if data, err := c.Download(ctx, "api/abc/report.zip", 64); err != nil || string(data) != "zipdata" {
		t.Fatalf("download = %q, %v", data, err)
	}
	if _, err := c.Download(ctx, "api/big/report.zip", 64); !errors.Is(err, ErrTooLarge) {
		t.Fatalf("too large: %v", err)
	}
	if _, err := c.Download(ctx, "api/missing/report.zip", 64); !errors.Is(err, ErrNotFound) {
		t.Fatalf("missing: %v", err)
	}
	if _, err := c.Download(ctx, "api/other/report.zip", 64); !errors.Is(err, ErrUnavailable) || !strings.Contains(err.Error(), "boom") {
		t.Fatalf("server error: %v", err)
	}
	srv.Close()
	if err := c.Upload(ctx, "api/abc/report.zip", []byte("PK")); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("closed server: %v", err)
	}
}

func TestPutGetAndRemoveInOtherBuckets(t *testing.T) {
	var gotPath, gotType, gotUpsert string
	var gotLength int64
	var removed []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPost:
			gotPath, gotType, gotUpsert, gotLength = r.URL.Path, r.Header.Get("Content-Type"), r.Header.Get("x-upsert"),
				r.ContentLength
			_, _ = io.Copy(io.Discard, r.Body)
			_, _ = w.Write([]byte(`{"Key":"x"}`))
		case http.MethodGet:
			if r.URL.Path == "/object/authenticated/post-files/research/abc/file.pdf" {
				_, _ = w.Write([]byte("%PDF-"))
				return
			}
			w.WriteHeader(http.StatusNotFound)
		case http.MethodDelete:
			removed = append(removed, r.URL.Path)
			if strings.Contains(r.URL.Path, "gone") {
				w.WriteHeader(http.StatusBadRequest)
				_, _ = w.Write([]byte(`{"statusCode":"404","error":"not_found"}`))
				return
			}
			if strings.Contains(r.URL.Path, "broken") {
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
			_, _ = w.Write([]byte(`[]`))
		}
	}))
	defer srv.Close()
	c := New(srv.URL, []byte(strings.Repeat("s", 40)), "supabase", 5*time.Second)
	ctx := context.Background()
	body := strings.NewReader("%PDF-1.7 body")
	if err := c.Put(ctx, PostFiles, "research/abc/file.pdf", "application/pdf", io.NopCloser(body), 13); err != nil {
		t.Fatal(err)
	}
	if gotPath != "/object/post-files/research/abc/file.pdf" || gotType != "application/pdf" || gotUpsert != "false" ||
		gotLength != 13 {
		t.Fatalf("put request %q %q %q %d", gotPath, gotType, gotUpsert, gotLength)
	}
	if data, err := c.Get(ctx, PostFiles, "research/abc/file.pdf", 64); err != nil || string(data) != "%PDF-" {
		t.Fatalf("get = %q, %v", data, err)
	}
	if _, err := c.Get(ctx, PostFiles, "research/none/file.pdf", 64); !errors.Is(err, ErrNotFound) {
		t.Fatalf("missing: %v", err)
	}
	if err := c.Remove(ctx, PostFiles, "research/abc/file.pdf"); err != nil {
		t.Fatal(err)
	}
	if err := c.Remove(ctx, PostFiles, "research/gone/file.pdf"); err != nil {
		t.Fatalf("already gone: %v", err)
	}
	if err := c.Remove(ctx, PostFiles, "research/broken/file.pdf"); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("broken: %v", err)
	}
	if len(removed) != 3 || removed[0] != "/object/post-files/research/abc/file.pdf" {
		t.Fatalf("removed = %v", removed)
	}
}
