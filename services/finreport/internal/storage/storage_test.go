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
