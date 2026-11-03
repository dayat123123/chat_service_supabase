package storage

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
)

func TestCopySendsACrossBucketUpsert(t *testing.T) {
	var seen captured
	var upsert string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		upsert = r.Header.Get("x-upsert")
		seen.method, seen.path, seen.contentType = r.Method, r.URL.EscapedPath(), r.Header.Get("Content-Type")
		seen.claims = serviceClaims(t, r.Header.Get("Authorization"), []byte("secret"))
		_ = json.NewDecoder(r.Body).Decode(&seen.body)
		_, _ = w.Write([]byte(`{"Key":"evidence/e1/01-a.png"}`))
	}))
	t.Cleanup(server.Close)

	err := newClient(server.URL).Copy(context.Background(), "attachments", "posts/u1/a.png", "evidence", "e1/01-a.png")
	if err != nil {
		t.Fatal(err)
	}
	if seen.method != http.MethodPost || seen.path != "/object/copy" || seen.contentType != "application/json" || upsert != "true" {
		t.Fatalf("request = %+v upsert=%q", seen, upsert)
	}
	want := map[string]any{"bucketId": "attachments", "sourceKey": "posts/u1/a.png",
		"destinationBucket": "evidence", "destinationKey": "e1/01-a.png"}
	if !reflect.DeepEqual(seen.body, want) {
		t.Fatalf("body = %v", seen.body)
	}
	if seen.claims["role"] != "service_role" {
		t.Fatalf("claims = %v", seen.claims)
	}
}

func TestCopyReportsAMissingSource(t *testing.T) {
	for _, tc := range []struct {
		status int
		reply  string
	}{
		{http.StatusBadRequest, `{"statusCode":"404","error":"not_found","message":"Object not found","code":"NoSuchKey"}`},
		{http.StatusNotFound, `not found`},
	} {
		var seen captured
		server := recordingServer(t, tc.status, tc.reply, &seen)
		err := newClient(server.URL).Copy(context.Background(), "attachments", "x", "evidence", "y")
		if !errors.Is(err, ErrNotFound) {
			t.Fatalf("status %d: err = %v", tc.status, err)
		}
	}
}

func TestCopyErrorsCarryTheStorageReason(t *testing.T) {
	var seen captured
	server := recordingServer(t, http.StatusBadRequest, `{"statusCode":"400","error":"invalid","message":"Bucket not found"}`, &seen)
	err := newClient(server.URL).Copy(context.Background(), "attachments", "x", "evidence", "y")
	if err == nil || errors.Is(err, ErrNotFound) || err.Error() != "storage copy attachments: status 400: Bucket not found" {
		t.Fatalf("err = %v", err)
	}
}

func TestHashStreamsTheObjectAndEscapesEachSegment(t *testing.T) {
	content := strings.Repeat("evidence", 1000)
	var path string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path = r.URL.EscapedPath()
		if r.Method != http.MethodGet || serviceClaims(t, r.Header.Get("Authorization"), []byte("secret"))["role"] != "service_role" {
			t.Errorf("request = %s %v", r.Method, r.Header)
		}
		_, _ = w.Write([]byte(content))
	}))
	t.Cleanup(server.Close)

	sum, size, err := newClient(server.URL).Hash(context.Background(), "attachments", "rooms/r 1/u#1/a b.png")
	if err != nil {
		t.Fatal(err)
	}
	digest := sha256.Sum256([]byte(content))
	if sum != hex.EncodeToString(digest[:]) || size != int64(len(content)) {
		t.Fatalf("sum = %s size = %d", sum, size)
	}
	if path != "/object/authenticated/attachments/rooms/r%201/u%231/a%20b.png" {
		t.Fatalf("path = %q", path)
	}
}

func TestHashReportsMissingObjectsAndOtherErrors(t *testing.T) {
	var seen captured
	server := recordingServer(t, http.StatusBadRequest, `{"statusCode":"404","code":"NoSuchKey","message":"Object not found"}`, &seen)
	if _, _, err := newClient(server.URL).Hash(context.Background(), "evidence", "a"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("err = %v", err)
	}
	broken := recordingServer(t, http.StatusInternalServerError, `{"message":"disk full"}`, &seen)
	_, _, err := newClient(broken.URL).Hash(context.Background(), "evidence", "a")
	if err == nil || err.Error() != "storage read evidence: status 500: disk full" {
		t.Fatalf("err = %v", err)
	}
}
