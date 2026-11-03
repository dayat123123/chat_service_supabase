package server

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/integration/internal/clientip"
	"olt-social/integration/internal/heartbeat"
	"olt-social/integration/internal/keys"
	"olt-social/integration/internal/metrics"
	"olt-social/integration/internal/store"
)

const (
	notifyKey = "oik_NotifyKey000000000000000000000000000000000"
	botKey    = "oik_BotPostKey00000000000000000000000000000000"
	lanKey    = "oik_LanOnlyKey00000000000000000000000000000000"
)

type fakeKeys struct {
	mu      sync.Mutex
	known   map[string]keys.Key
	forgot  []string
	lookups int
	err     error
}

func newFakeKeys() *fakeKeys {
	hash := func(k string) string { h, _ := keys.Hash(k); return h }
	return &fakeKeys{known: map[string]keys.Key{
		hash(notifyKey): {ID: "k-notify", Prefix: "NotifyKe", Scopes: []string{keys.ScopeNotify}, RateLimit: 3},
		hash(botKey):    {ID: "k-bot", Prefix: "BotPostK", Scopes: []string{keys.ScopeBotPost}, RateLimit: 100},
		hash(lanKey):    {ID: "k-lan", Prefix: "LanOnlyK", Scopes: []string{keys.ScopeNotify}, RateLimit: 100},
	}}
}

func (f *fakeKeys) Authenticate(_ context.Context, keyHash, ip string) (*keys.Key, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.lookups++
	if f.err != nil {
		return nil, f.err
	}
	k, ok := f.known[keyHash]
	if !ok {
		return nil, nil
	}
	k.IPAllowed = k.ID != "k-lan" || strings.HasPrefix(ip, "192.168.")
	return &k, nil
}

func (f *fakeKeys) Forget(keyHash string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.forgot = append(f.forgot, keyHash)
}

func (f *fakeKeys) Len() int { return 0 }

type call struct {
	fn, keyID, ip string
	items         json.RawMessage
}

type fakeStore struct {
	mu    sync.Mutex
	calls []call
	err   error
	out   string
	block chan struct{}
}

func (f *fakeStore) do(fn, keyID string, items json.RawMessage, ip string) (json.RawMessage, error) {
	if f.block != nil {
		<-f.block
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, call{fn, keyID, ip, items})
	if f.err != nil {
		return nil, f.err
	}
	return json.RawMessage(f.out), nil
}

func (f *fakeStore) Notify(_ context.Context, keyID string, items json.RawMessage, ip string) (json.RawMessage, error) {
	return f.do("notify", keyID, items, ip)
}

func (f *fakeStore) BotPosts(_ context.Context, keyID string, items json.RawMessage, ip string) (json.RawMessage, error) {
	return f.do("bot_posts", keyID, items, ip)
}

type harness struct {
	srv   *Server
	keys  *fakeKeys
	store *fakeStore
	logs  *bytes.Buffer
	kicks int
}

func newHarness(t *testing.T, mutate func(*Options)) *harness {
	t.Helper()
	h := &harness{keys: newFakeKeys(), store: &fakeStore{out: `{"results":[{"index":0,"id":"t1","status":"queued","devices":2}],"queued":1,"devices":2,"no_recipient":0,"duplicate":0,"invalid":0}`}, logs: &bytes.Buffer{}}
	opts := Options{
		Log:                   slog.New(slog.NewJSONHandler(h.logs, nil)),
		Store:                 h.store,
		Keys:                  h.keys,
		ClientIP:              clientip.New([]netip.Prefix{netip.MustParsePrefix("172.16.0.0/12"), netip.MustParsePrefix("192.168.0.0/16")}).Of,
		MaxBodyBytes:          64 << 10,
		MaxConcurrent:         4,
		AuthFailuresPerMinute: 5,
		RequestTimeout:        5 * time.Second,
		Notify:                func() { h.kicks++ },
	}
	if mutate != nil {
		mutate(&opts)
	}
	h.srv = New(opts)
	return h
}

func (h *harness) do(method, path, key, body string, headers ...string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.RemoteAddr = "172.18.0.5:41000"
	req.Header.Set("X-Forwarded-For", "203.0.113.10, 172.18.0.3")
	if key != "" {
		req.Header.Set("Authorization", "Bearer "+key)
	}
	for i := 0; i+1 < len(headers); i += 2 {
		req.Header.Set(headers[i], headers[i+1])
	}
	rec := httptest.NewRecorder()
	h.srv.ServeHTTP(rec, req)
	return rec
}

func errorCode(t *testing.T, rec *httptest.ResponseRecorder) string {
	t.Helper()
	var body struct {
		Error   string `json:"error"`
		Message string `json:"message"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("body bukan JSON: %q", rec.Body.String())
	}
	if body.Message == "" {
		t.Fatalf("pesan error kosong: %q", rec.Body.String())
	}
	return body.Error
}

const oneMessage = `{"messages":[{"id":"t1","cust_id":"W137","title":"Order match"}]}`

func TestNotifyPassesTheBatchToTheDatabase(t *testing.T) {
	h := newHarness(t, nil)
	rec := h.do("POST", "/notify/messages", notifyKey, oneMessage, "X-Request-Id", "olt-req-1")
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body)
	}
	if rec.Body.String() != h.store.out || rec.Header().Get("X-Request-Id") != "olt-req-1" || rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("respons = %s header = %v", rec.Body, rec.Header())
	}
	if len(h.store.calls) != 1 {
		t.Fatalf("calls = %d", len(h.store.calls))
	}
	c := h.store.calls[0]
	var items []map[string]any
	_ = json.Unmarshal(c.items, &items)
	if c.fn != "notify" || c.keyID != "k-notify" || c.ip != "203.0.113.10" || len(items) != 1 || items[0]["cust_id"] != "W137" {
		t.Fatalf("call = %+v", c)
	}
	if strings.Contains(h.logs.String(), notifyKey) || strings.Contains(h.logs.String(), "W137") {
		t.Fatalf("log tidak boleh memuat key atau isi pesan:\n%s", h.logs)
	}
	if !strings.Contains(h.logs.String(), `"key_prefix":"NotifyKe"`) || !strings.Contains(h.logs.String(), `"queued":1`) {
		t.Fatalf("log harus memuat prefix key dan ringkasan:\n%s", h.logs)
	}
}

func TestBotPostsUseTheirOwnScope(t *testing.T) {
	h := newHarness(t, nil)
	h.store.out = `{"results":[],"published":1,"rejected":0,"duplicate":0,"invalid":0,"rate_limited":0}`
	if rec := h.do("POST", "/bot/posts", botKey, `{"posts":[{"id":"n1","body":"Dividen BBCA"}]}`); rec.Code != http.StatusOK {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body)
	}
	if rec := h.do("POST", "/bot/posts", notifyKey, `{"posts":[{"id":"n1","body":"x"}]}`); rec.Code != http.StatusForbidden || errorCode(t, rec) != codeScopeForbidden {
		t.Fatalf("key notify tidak boleh memposting: %d %s", rec.Code, rec.Body)
	}
	if rec := h.do("POST", "/notify/messages", botKey, oneMessage); rec.Code != http.StatusForbidden || errorCode(t, rec) != codeScopeForbidden {
		t.Fatalf("key bot tidak boleh mengirim notifikasi: %d %s", rec.Code, rec.Body)
	}
	if len(h.store.calls) != 1 || h.store.calls[0].fn != "bot_posts" {
		t.Fatalf("calls = %+v", h.store.calls)
	}
	snap := h.srv.Metrics()
	if snap.Posts["published"] != 1 || snap.Requests[metrics.Request{Endpoint: "bot_posts", Code: "ok"}] != 1 ||
		snap.Requests[metrics.Request{Endpoint: "notify", Code: codeScopeForbidden}] != 1 {
		t.Fatalf("metrics = %+v", snap)
	}
}

func TestRequestErrors(t *testing.T) {
	big := `{"messages":[` + strings.Repeat(`{"id":"x","cust_id":"W137","title":"`+strings.Repeat("a", 100)+`"},`, 700) + `{"id":"y"}]}`
	cases := []struct {
		name, method, path, key, body string
		status                        int
		code                          string
	}{
		{"path lain", "POST", "/notify", notifyKey, oneMessage, 404, codeNotFound},
		{"metode GET", "GET", "/notify/messages", notifyKey, "", 405, codeMethodNotAllowed},
		{"tanpa key", "POST", "/notify/messages", "", oneMessage, 401, codeMissingKey},
		{"key salah format", "POST", "/notify/messages", "bukan-key", oneMessage, 401, codeInvalidKey},
		{"key tidak dikenal", "POST", "/notify/messages", "oik_Unknown0000000000000000000000000000000000", oneMessage, 401, codeInvalidKey},
		{"IP di luar CIDR", "POST", "/notify/messages", lanKey, oneMessage, 403, codeIPNotAllowed},
		{"bukan JSON", "POST", "/notify/messages", notifyKey, `messages=1`, 400, codeInvalidJSON},
		{"JSON berlebih", "POST", "/notify/messages", notifyKey, oneMessage + `{}`, 400, codeInvalidJSON},
		{"tanpa messages", "POST", "/notify/messages", notifyKey, `{"posts":[{}]}`, 400, codeInvalidBatch},
		{"messages bukan array", "POST", "/notify/messages", notifyKey, `{"messages":{"id":"x"}}`, 400, codeInvalidBatch},
		{"batch kosong", "POST", "/notify/messages", notifyKey, `{"messages":[]}`, 400, codeInvalidBatch},
		{"body terlalu besar", "POST", "/notify/messages", notifyKey, big, 413, codeBodyTooLarge},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			h := newHarness(t, func(o *Options) { o.AuthFailuresPerMinute = 100 })
			rec := h.do(tc.method, tc.path, tc.key, tc.body)
			if rec.Code != tc.status || errorCode(t, rec) != tc.code {
				t.Fatalf("status = %d body = %s, want %d %s", rec.Code, rec.Body, tc.status, tc.code)
			}
			if len(h.store.calls) != 0 {
				t.Fatal("request yang ditolak tidak boleh sampai ke database")
			}
		})
	}
}

func TestBatchLimits(t *testing.T) {
	h := newHarness(t, func(o *Options) { o.MaxBodyBytes = 4 << 20 })
	h.keys.known[func() string { s, _ := keys.Hash(notifyKey); return s }()] = keys.Key{ID: "k-notify", Scopes: []string{keys.ScopeNotify}, RateLimit: 100}
	batch := func(field string, n int) string {
		items := make([]string, n)
		for i := range items {
			items[i] = fmt.Sprintf(`{"id":"m%d","cust_id":"W137","title":"x","body":"y"}`, i)
		}
		return `{"` + field + `":[` + strings.Join(items, ",") + `]}`
	}
	if rec := h.do("POST", "/notify/messages", notifyKey, batch("messages", MaxMessages)); rec.Code != http.StatusOK {
		t.Fatalf("500 pesan harus diterima: %d %s", rec.Code, rec.Body)
	}
	if rec := h.do("POST", "/notify/messages", notifyKey, batch("messages", MaxMessages+1)); rec.Code != http.StatusBadRequest {
		t.Fatalf("501 pesan harus ditolak: %d", rec.Code)
	}
	if rec := h.do("POST", "/bot/posts", botKey, batch("posts", MaxPosts+1)); rec.Code != http.StatusBadRequest {
		t.Fatalf("51 postingan harus ditolak: %d", rec.Code)
	}
}

func TestRateLimitPerKey(t *testing.T) {
	h := newHarness(t, nil)
	for i := range 3 {
		if rec := h.do("POST", "/notify/messages", notifyKey, oneMessage); rec.Code != http.StatusOK {
			t.Fatalf("request %d: %d", i+1, rec.Code)
		}
	}
	rec := h.do("POST", "/notify/messages", notifyKey, oneMessage)
	if rec.Code != http.StatusTooManyRequests || errorCode(t, rec) != codeRateLimited || rec.Header().Get("Retry-After") == "" {
		t.Fatalf("status = %d header = %v", rec.Code, rec.Header())
	}
	if rec := h.do("POST", "/bot/posts", botKey, `{"posts":[{"id":"n","body":"x"}]}`); rec.Code != http.StatusOK {
		t.Fatalf("key lain tidak terpengaruh: %d", rec.Code)
	}
}

func TestRepeatedAuthFailuresAreThrottledPerIP(t *testing.T) {
	h := newHarness(t, nil)
	for range 5 {
		if rec := h.do("POST", "/notify/messages", "oik_Wrong00000000000000000000000000000000000000", oneMessage); rec.Code != http.StatusUnauthorized {
			t.Fatalf("status = %d", rec.Code)
		}
	}
	lookups := h.keys.lookups
	rec := h.do("POST", "/notify/messages", notifyKey, oneMessage)
	if rec.Code != http.StatusTooManyRequests || errorCode(t, rec) != codeTooManyAuthFailures {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body)
	}
	if h.keys.lookups != lookups {
		t.Fatal("IP yang diblokir tidak boleh membebani database")
	}
}

func TestDatabaseErrors(t *testing.T) {
	h := newHarness(t, func(o *Options) { o.AuthFailuresPerMinute = 100 })
	h.store.err = &store.APIError{Status: 401, Code: "invalid_key", Detail: "API key tidak dikenal, nonaktif, atau sudah dicabut"}
	rec := h.do("POST", "/notify/messages", notifyKey, oneMessage)
	if rec.Code != http.StatusUnauthorized || errorCode(t, rec) != "invalid_key" || len(h.keys.forgot) != 1 {
		t.Fatalf("key yang dicabut di database harus dilupakan dari cache: %d %s forgot=%v", rec.Code, rec.Body, h.keys.forgot)
	}

	h.store.err = &store.APIError{Status: 403, Code: "ip_not_allowed", Detail: "Alamat IP pengirim tidak diizinkan"}
	if rec := h.do("POST", "/notify/messages", notifyKey, oneMessage); rec.Code != http.StatusForbidden || errorCode(t, rec) != "ip_not_allowed" {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body)
	}

	h.store.err = &store.APIError{Status: 418, Code: "odd", Detail: "x"}
	if rec := h.do("POST", "/notify/messages", notifyKey, oneMessage); rec.Code != http.StatusBadGateway {
		t.Fatalf("status = %d", rec.Code)
	}
}

func TestUnavailableDatabaseDegradesHeartbeat(t *testing.T) {
	h := newHarness(t, func(o *Options) { o.AuthFailuresPerMinute = 100 })
	h.keys.err = fmt.Errorf("%w: dial tcp: connection refused", store.ErrUnavailable)
	for range 2 {
		rec := h.do("POST", "/notify/messages", notifyKey, oneMessage)
		if rec.Code != http.StatusServiceUnavailable || rec.Header().Get("Retry-After") != "5" {
			t.Fatalf("status = %d header = %v", rec.Code, rec.Header())
		}
	}
	if h.srv.Report().Status != heartbeat.StatusOK {
		t.Fatal("dua kegagalan belum degraded")
	}
	h.keys.err = nil
	h.store.err = errors.New("context deadline exceeded")
	_ = h.do("POST", "/bot/posts", botKey, `{"posts":[{"id":"n","body":"x"}]}`)
	report := h.srv.Report()
	if report.Status != heartbeat.StatusDegraded || !strings.Contains(report.Error, "3 consecutive") || h.kicks != 1 {
		t.Fatalf("report = %+v kicks = %d", report, h.kicks)
	}
	h.store.err = nil
	if rec := h.do("POST", "/bot/posts", botKey, `{"posts":[{"id":"n","body":"x"}]}`); rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	if h.srv.Report().Status != heartbeat.StatusOK || h.kicks != 2 {
		t.Fatalf("pulih harus kembali ok dan memicu heartbeat, kicks = %d", h.kicks)
	}
}

func TestBusyWhenAllSlotsAreTaken(t *testing.T) {
	h := newHarness(t, func(o *Options) { o.MaxConcurrent = 1; o.QueueWait = 50 * time.Millisecond })
	h.store.block = make(chan struct{})
	done := make(chan int)
	go func() { done <- h.do("POST", "/notify/messages", notifyKey, oneMessage).Code }()
	deadline := time.Now().Add(2 * time.Second)
	for h.srv.Metrics().Inflight == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	rec := h.do("POST", "/bot/posts", botKey, `{"posts":[{"id":"n","body":"x"}]}`)
	if rec.Code != http.StatusServiceUnavailable || errorCode(t, rec) != codeBusy || rec.Header().Get("Retry-After") != "2" {
		t.Fatalf("status = %d body = %s", rec.Code, rec.Body)
	}
	close(h.store.block)
	if code := <-done; code != http.StatusOK {
		t.Fatalf("request pertama = %d", code)
	}
}

func TestReportIncludesCounts(t *testing.T) {
	h := newHarness(t, nil)
	_ = h.do("POST", "/notify/messages", notifyKey, oneMessage)
	report := h.srv.Report()
	if report.Status != heartbeat.StatusOK || report.Detail["notify_messages"] != uint64(1) {
		t.Fatalf("report = %+v", report)
	}
	if snap := h.srv.Metrics(); snap.Devices != 2 || snap.Messages["queued"] != 1 || snap.Handled != 1 {
		t.Fatalf("metrics = %+v", snap)
	}
}

func TestBearer(t *testing.T) {
	for header, want := range map[string]string{"Bearer abc": "abc", "bearer  abc ": "abc", "Basic abc": "", "Bearer": "", "": ""} {
		got, ok := bearer(header)
		if got != want || ok != (want != "") {
			t.Errorf("bearer(%q) = %q %v", header, got, ok)
		}
	}
}
