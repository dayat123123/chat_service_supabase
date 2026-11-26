package api

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"olt-social/research/internal/keys"
	"olt-social/research/internal/store"
	"olt-social/research/internal/xbrl"
	"olt-social/research/internal/xbrltest"
)

const secret = "oik_testkey_123456"

type fakeKeys struct {
	key *keys.Key
	err error
}

func (k fakeKeys) Authenticate(_ context.Context, hash, _ string) (*keys.Key, error) {
	want, _ := keys.Hash(secret)
	if k.err != nil {
		return nil, k.err
	}
	if hash != want {
		return nil, nil
	}
	return k.key, nil
}

func (fakeKeys) Forget(string) {}
func (fakeKeys) Len() int      { return 1 }

type fakeStore struct {
	mu        sync.Mutex
	submitOut string
	submitErr error
	fileOut   string
	fileErr   error
	submitted []string
}

func (s *fakeStore) Submit(_ context.Context, keyID, sha string, size int64, _ string) (json.RawMessage, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.submitted = append(s.submitted, keyID+"|"+sha)
	if s.submitErr != nil {
		return nil, s.submitErr
	}
	return json.RawMessage(s.submitOut), nil
}

func (s *fakeStore) File(_ context.Context, _, id, _ string) (json.RawMessage, error) {
	if s.fileErr != nil {
		return nil, s.fileErr
	}
	return json.RawMessage(strings.ReplaceAll(s.fileOut, "ID", id)), nil
}

type fakeObjects struct {
	mu    sync.Mutex
	names []string
	block chan struct{}
	err   error
}

func (o *fakeObjects) Upload(_ context.Context, name string, _ []byte) error {
	if o.block != nil {
		<-o.block
	}
	o.mu.Lock()
	defer o.mu.Unlock()
	o.names = append(o.names, name)
	return o.err
}

func validKey() *keys.Key {
	return &keys.Key{ID: "k1", Prefix: "testkey", Scopes: []string{keys.ScopeResearch}, RateLimit: 600, IPAllowed: true}
}

func newServer(k fakeKeys, st *fakeStore, objects *fakeObjects, accepted *atomic.Int32) *Server {
	return New(Options{
		Log:   slog.New(slog.NewTextHandler(io.Discard, nil)),
		Store: st, Objects: objects, Keys: k,
		ClientIP:     func(*http.Request) string { return "10.0.0.5" },
		MaxFileBytes: 1 << 20, MaxUploads: 1, AuthFailuresPerMinute: 5, RequestTimeout: 5 * time.Second,
		QueueWait: 50 * time.Millisecond, Limits: xbrl.DefaultLimits(),
		Accepted: func() { accepted.Add(1) },
	})
}

func post(s *Server, body []byte, contentType, auth string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodPost, "/research", bytes.NewReader(body))
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	if auth != "" {
		req.Header.Set("Authorization", auth)
	}
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, req)
	return rec
}

func errorCode(t *testing.T, rec *httptest.ResponseRecorder) string {
	t.Helper()
	var body struct {
		Error string `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("error body %q: %v", rec.Body.String(), err)
	}
	return body.Error
}

func TestSubmitAcceptsAReport(t *testing.T) {
	var accepted atomic.Int32
	st := &fakeStore{submitOut: `{"id":"f1","status":"queued","resubmitted":false}`}
	objects := &fakeObjects{}
	s := newServer(fakeKeys{key: validKey()}, st, objects, &accepted)
	data := xbrltest.Archive(xbrltest.BankQ3())
	rec := post(s, data, "application/zip", "Bearer "+secret)
	if rec.Code != http.StatusAccepted || accepted.Load() != 1 {
		t.Fatalf("status %d accepted %d body %s", rec.Code, accepted.Load(), rec.Body)
	}
	if len(objects.names) != 1 || !strings.HasPrefix(objects.names[0], "api/") || !strings.HasSuffix(objects.names[0], "/report.zip") {
		t.Fatalf("uploads = %v", objects.names)
	}
	sha := strings.TrimSuffix(strings.TrimPrefix(objects.names[0], "api/"), "/report.zip")
	if len(st.submitted) != 1 || st.submitted[0] != "k1|"+sha || rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("submitted %v headers %v", st.submitted, rec.Header())
	}
	snap := s.Snapshot()
	if snap.Requests[Request{Endpoint: EndpointPost, Code: "ok"}] != 1 || snap.Bytes != uint64(len(data)) {
		t.Fatalf("snapshot = %+v", snap)
	}
}

func TestResubmittedReportsAnswerOK(t *testing.T) {
	var accepted atomic.Int32
	for _, out := range []string{`{"status":"queued","resubmitted":true}`, `{"status":"duplicate","resubmitted":false}`} {
		s := newServer(fakeKeys{key: validKey()}, &fakeStore{submitOut: out}, &fakeObjects{}, &accepted)
		if rec := post(s, xbrltest.Archive(xbrltest.BankQ3()), "application/x-zip-compressed", "Bearer "+secret); rec.Code != http.StatusOK {
			t.Fatalf("%s: status %d", out, rec.Code)
		}
	}
	if accepted.Load() != 0 {
		t.Fatal("worker woken for a known file")
	}
}

func TestSubmitRejectsBadRequests(t *testing.T) {
	var accepted atomic.Int32
	report := xbrltest.Archive(xbrltest.BankQ3())
	noScope := validKey()
	noScope.Scopes = []string{"notify"}
	blockedIP := validKey()
	blockedIP.IPAllowed = false
	cases := []struct {
		name   string
		keys   fakeKeys
		body   []byte
		ctype  string
		auth   string
		status int
		code   string
	}{
		{"no key", fakeKeys{key: validKey()}, report, "application/zip", "", 401, codeMissingKey},
		{"wrong key", fakeKeys{key: validKey()}, report, "application/zip", "Bearer oik_wrong_key_000", 401, codeInvalidKey},
		{"malformed key", fakeKeys{key: validKey()}, report, "application/zip", "Bearer nope", 401, codeInvalidKey},
		{"key lookup down", fakeKeys{err: errors.New("down")}, report, "application/zip", "Bearer " + secret, 503, codeUnavailable},
		{"scope", fakeKeys{key: noScope}, report, "application/zip", "Bearer " + secret, 403, codeScopeForbidden},
		{"ip", fakeKeys{key: blockedIP}, report, "application/zip", "Bearer " + secret, 403, codeIPNotAllowed},
		{"json", fakeKeys{key: validKey()}, report, "application/json", "Bearer " + secret, 415, codeUnsupportedType},
		{"form", fakeKeys{key: validKey()}, report, "", "Bearer " + secret, 415, codeUnsupportedType},
		{"empty", fakeKeys{key: validKey()}, nil, "application/zip", "Bearer " + secret, 400, codeEmptyBody},
		{"too large", fakeKeys{key: validKey()}, make([]byte, 2<<20), "application/zip", "Bearer " + secret, 413, codeBodyTooLarge},
		{"not zip", fakeKeys{key: validKey()}, []byte("hello"), "application/zip", "Bearer " + secret, 400, codeNotZip},
		{"no instance", fakeKeys{key: validKey()}, xbrltest.Zip(xbrltest.Entry{Name: "a.pdf", Body: []byte("x")}),
			"application/zip", "Bearer " + secret, 400, codeNoInstance},
	}
	for _, c := range cases {
		objects := &fakeObjects{}
		s := newServer(c.keys, &fakeStore{submitOut: `{}`}, objects, &accepted)
		rec := post(s, c.body, c.ctype, c.auth)
		if rec.Code != c.status || errorCode(t, rec) != c.code {
			t.Errorf("%s: %d %s, want %d %s", c.name, rec.Code, rec.Body, c.status, c.code)
		}
		if len(objects.names) != 0 {
			t.Errorf("%s: file uploaded before validation", c.name)
		}
	}
}

func TestSubmitPassesDatabaseDecisions(t *testing.T) {
	var accepted atomic.Int32
	st := &fakeStore{submitErr: &store.APIError{Status: 429, Code: "rate_limited", Detail: "Maksimal 120 file laporan per jam"}}
	s := newServer(fakeKeys{key: validKey()}, st, &fakeObjects{}, &accepted)
	rec := post(s, xbrltest.Archive(xbrltest.BankQ3()), "application/zip", "Bearer "+secret)
	if rec.Code != 429 || errorCode(t, rec) != "rate_limited" || rec.Header().Get("Retry-After") != "60" ||
		!strings.Contains(rec.Body.String(), "120 file") {
		t.Fatalf("status %d headers %v body %s", rec.Code, rec.Header(), rec.Body)
	}
	st = &fakeStore{submitErr: store.ErrUnavailable}
	s = newServer(fakeKeys{key: validKey()}, st, &fakeObjects{}, &accepted)
	if rec := post(s, xbrltest.Archive(xbrltest.BankQ3()), "application/zip", "Bearer "+secret); rec.Code != 503 {
		t.Fatalf("store down: %d", rec.Code)
	}
	s = newServer(fakeKeys{key: validKey()}, &fakeStore{}, &fakeObjects{err: errors.New("storage down")}, &accepted)
	if rec := post(s, xbrltest.Archive(xbrltest.BankQ3()), "application/zip", "Bearer "+secret); rec.Code != 503 ||
		rec.Header().Get("Retry-After") != "5" {
		t.Fatalf("storage down: %d %v", rec.Code, rec.Header())
	}
}

func TestUploadSlotsAreLimited(t *testing.T) {
	var accepted atomic.Int32
	objects := &fakeObjects{block: make(chan struct{})}
	s := newServer(fakeKeys{key: validKey()}, &fakeStore{submitOut: `{"status":"queued"}`}, objects, &accepted)
	data := xbrltest.Archive(xbrltest.BankQ3())
	first := make(chan int)
	go func() { first <- post(s, data, "application/zip", "Bearer "+secret).Code }()
	deadline := time.Now().Add(2 * time.Second)
	for s.Snapshot().Inflight == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	rec := post(s, data, "application/zip", "Bearer "+secret)
	close(objects.block)
	if rec.Code != 503 || errorCode(t, rec) != codeBusy || <-first != http.StatusAccepted {
		t.Fatalf("second upload %d %s", rec.Code, rec.Body)
	}
}

func TestAuthFailuresAreThrottledPerIP(t *testing.T) {
	var accepted atomic.Int32
	s := newServer(fakeKeys{key: validKey()}, &fakeStore{}, &fakeObjects{}, &accepted)
	for range 5 {
		post(s, nil, "application/zip", "Bearer oik_wrong_key_000")
	}
	if rec := post(s, nil, "application/zip", "Bearer "+secret); rec.Code != 429 || errorCode(t, rec) != codeTooManyAuthFailures {
		t.Fatalf("status %d", rec.Code)
	}
}

func TestStatusEndpoint(t *testing.T) {
	var accepted atomic.Int32
	st := &fakeStore{fileOut: `{"id":"ID","status":"done"}`}
	s := newServer(fakeKeys{key: validKey()}, st, &fakeObjects{}, &accepted)
	get := func(path string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		req.Header.Set("Authorization", "Bearer "+secret)
		rec := httptest.NewRecorder()
		s.ServeHTTP(rec, req)
		return rec
	}
	id := "0b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b"
	if rec := get("/research/" + id); rec.Code != 200 || !strings.Contains(rec.Body.String(), id) {
		t.Fatalf("status %d body %s", rec.Code, rec.Body)
	}
	if rec := get("/research/not-a-uuid"); rec.Code != 400 || errorCode(t, rec) != codeInvalidID {
		t.Fatalf("invalid id %d", rec.Code)
	}
	if rec := get("/research/a/b"); rec.Code != 404 {
		t.Fatalf("nested path %d", rec.Code)
	}
	st.fileErr = &store.APIError{Status: 404, Code: "file_not_found"}
	if rec := get("/research/" + id); rec.Code != 404 || errorCode(t, rec) != "file_not_found" {
		t.Fatalf("missing file %d", rec.Code)
	}
	req := httptest.NewRequest(http.MethodDelete, "/research/"+id, nil)
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, req)
	if rec.Code != 405 || rec.Header().Get("Allow") != http.MethodGet {
		t.Fatalf("method %d %v", rec.Code, rec.Header())
	}
	req = httptest.NewRequest(http.MethodGet, "/research", nil)
	rec = httptest.NewRecorder()
	s.ServeHTTP(rec, req)
	if rec.Code != 405 || rec.Header().Get("Allow") != http.MethodPost {
		t.Fatalf("list %d %v", rec.Code, rec.Header())
	}
}
