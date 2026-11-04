package storage

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestUploadSendsTheVerifiedRequest(t *testing.T) {
	for _, upsert := range []bool{false, true} {
		var got *http.Request
		var body []byte
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			got = r
			body, _ = io.ReadAll(r.Body)
			_, _ = w.Write([]byte(`{"Key":"avatars/u/a.jpg","Id":"x"}`))
		}))
		c := New(srv.URL, 4)
		err := c.Upload(context.Background(), Upload{
			Bucket: "avatars", Path: "u/a.jpg", ContentType: "image/jpeg", Body: []byte("jpeg"), Upsert: upsert, Token: "tok",
		})
		srv.Close()
		if err != nil {
			t.Fatal(err)
		}
		if got.Method != http.MethodPost || got.URL.Path != "/object/avatars/u/a.jpg" || string(body) != "jpeg" ||
			got.Header.Get("Authorization") != "Bearer tok" || got.Header.Get("Content-Type") != "image/jpeg" ||
			got.Header.Get("Cache-Control") != "max-age=3600" || got.ContentLength != 4 {
			t.Fatalf("request = %s %s %v", got.Method, got.URL, got.Header)
		}
		if want := map[bool]string{true: "true", false: ""}[upsert]; got.Header.Get("x-upsert") != want {
			t.Fatalf("x-upsert = %q", got.Header.Get("x-upsert"))
		}
	}
}

func TestUploadForwardsTheEdgeMarker(t *testing.T) {
	for _, edge := range []string{"", "public"} {
		var got http.Header
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			got = r.Header.Clone()
			_, _ = w.Write([]byte(`{"Key":"avatars/u/a.jpg","Id":"x"}`))
		}))
		err := New(srv.URL, 4).Upload(context.Background(), Upload{
			Bucket: "avatars", Path: "u/a.jpg", ContentType: "image/jpeg", Body: []byte("jpeg"), Token: "tok", Edge: edge,
		})
		srv.Close()
		if err != nil {
			t.Fatal(err)
		}
		if values := got.Values(EdgeHeader); (edge == "" && len(values) != 0) || (edge != "" && (len(values) != 1 || values[0] != edge)) {
			t.Fatalf("edge %q -> %v", edge, values)
		}
	}
}

func TestClassifyMapsStorageErrors(t *testing.T) {
	cases := map[string]struct {
		status int
		body   string
		code   string
		http   int
	}{
		"rls (storage-api v1.81 shape)": {400, `{"statusCode":"403","error":"Unauthorized","message":"new row violates row-level security policy","code":"AccessDenied"}`, CodeForbidden, 403},
		"rls with a real 403":           {403, `{"statusCode":403,"error":"Unauthorized","message":"new row violates row-level security policy for table \"objects\""}`, CodeForbidden, 403},
		"duplicate":                     {400, `{"statusCode":"409","error":"Duplicate","message":"The resource already exists","code":"KeyAlreadyExists"}`, CodeExists, 409},
		"duplicate as 409":              {409, `{"error":"Duplicate"}`, CodeExists, 409},
		"too large":                     {400, `{"statusCode":"413","error":"Payload too large","message":"The object exceeded the maximum allowed size","code":"EntityTooLarge"}`, CodeTooLarge, 413},
		"too large from proxy":          {413, `<html>413</html>`, CodeTooLarge, 413},
		"daily limit message":           {400, `{"statusCode":"400","error":"too_many_uploads","message":"Batas upload harian tercapai"}`, CodeTooMany, 429},
		"database rate limit":           {500, `{"statusCode":"500","error":"internal","message":"{\"code\":\"PT429\",\"message\":\"rate_limited\"}"}`, CodeTooMany, 429},
		"http 429":                      {429, ``, CodeTooMany, 429},
		"statusCode 429":                {400, `{"statusCode":"429","error":"Too Many Requests","message":"slow down"}`, CodeTooMany, 429},
		"expired minted token":          {400, `{"statusCode":"403","error":"Unauthorized","message":"\"exp\" claim timestamp check failed","code":"AccessDenied"}`, CodeInvalidToken, 401},
		"wrong secret":                  {400, `{"statusCode":"403","error":"Unauthorized","message":"signature verification failed","code":"AccessDenied"}`, CodeError, 502},
		"other access denied":           {400, `{"statusCode":"403","error":"Unauthorized","message":"access denied","code":"AccessDenied"}`, CodeForbidden, 403},
		"bucket missing":                {400, `{"statusCode":"404","error":"Bucket not found","message":"Bucket not found","code":"NoSuchBucket"}`, CodeError, 502},
		"mime rejected":                 {400, `{"statusCode":"415","error":"invalid_mime_type","message":"mime type text/plain is not supported","code":"InvalidMimeType"}`, CodeError, 502},
		"internal error":                {500, `{"statusCode":"500","error":"internal","message":"Internal Server Error"}`, CodeError, 502},
		"gateway html":                  {502, `<html>bad gateway</html>`, CodeError, 502},
		"weird statusCode":              {400, `{"statusCode":"abc","message":"?"}`, CodeError, 502},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			f := Classify(tc.status, []byte(tc.body))
			if f.Code != tc.code || f.Status != tc.http || f.Unreachable || f.Reason == "" {
				t.Fatalf("failure = %+v", f)
			}
		})
	}
}

func TestUploadReportsStorageErrors(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"statusCode":"409","error":"Duplicate","message":"The resource already exists"}`))
	}))
	defer srv.Close()
	err := New(srv.URL, 1).Upload(context.Background(), Upload{Bucket: "b", Path: "p.png", Token: "t"})
	var f *Failure
	if !errors.As(err, &f) || f.Code != CodeExists || f.Status != http.StatusConflict {
		t.Fatalf("err = %v", err)
	}
}

func TestUploadReportsUnreachableStorage(t *testing.T) {
	srv := httptest.NewServer(http.NotFoundHandler())
	url := srv.URL
	srv.Close()
	err := New(url, 1).Upload(context.Background(), Upload{Bucket: "b", Path: "p.png", Token: "secret-token"})
	var f *Failure
	if !errors.As(err, &f) || f.Code != CodeUnavailable || !f.Unreachable || f.Status != http.StatusBadGateway {
		t.Fatalf("err = %v", err)
	}
	if want := "/object/b/p.png"; strings.Contains(f.Reason, want) || strings.Contains(f.Reason, "secret-token") {
		t.Fatalf("reason leaks the request: %q", f.Reason)
	}
}

func TestUploadHonoursTheDeadline(t *testing.T) {
	release := make(chan struct{})
	srv := httptest.NewServer(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		select {
		case <-release:
		case <-r.Context().Done():
		}
	}))
	defer srv.Close()
	defer close(release)
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	err := New(srv.URL, 1).Upload(ctx, Upload{Bucket: "b", Path: "p.png"})
	var f *Failure
	if !errors.As(err, &f) || f.Code != CodeUnavailable || !f.Unreachable {
		t.Fatalf("err = %v", err)
	}
}

func TestPing(t *testing.T) {
	var status atomic.Int32
	status.Store(http.StatusOK)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/status" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.WriteHeader(int(status.Load()))
	}))
	defer srv.Close()
	c := New(srv.URL, 1)
	if err := c.Ping(context.Background()); err != nil {
		t.Fatal(err)
	}
	status.Store(http.StatusServiceUnavailable)
	if err := c.Ping(context.Background()); err == nil {
		t.Fatal("expected an error for 503")
	}
	srv.Close()
	if err := c.Ping(context.Background()); err == nil {
		t.Fatal("expected an error when storage is down")
	}
}
