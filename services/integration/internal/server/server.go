package server

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"olt-social/integration/internal/heartbeat"
	"olt-social/integration/internal/keys"
	"olt-social/integration/internal/metrics"
	"olt-social/integration/internal/ratelimit"
	"olt-social/integration/internal/store"
)

const (
	MaxMessages = 500
	MaxPosts    = 50

	degradedAfter = 3
)

type Store interface {
	Notify(ctx context.Context, keyID string, messages json.RawMessage, ip string) (json.RawMessage, error)
	BotPosts(ctx context.Context, keyID string, posts json.RawMessage, ip string) (json.RawMessage, error)
}

type Keys interface {
	Authenticate(ctx context.Context, keyHash, ip string) (*keys.Key, error)
	Forget(keyHash string)
	Len() int
}

type Options struct {
	Log                   *slog.Logger
	Store                 Store
	Keys                  Keys
	ClientIP              func(*http.Request) string
	MaxBodyBytes          int64
	MaxConcurrent         int
	AuthFailuresPerMinute int
	RequestTimeout        time.Duration
	QueueWait             time.Duration
	Notify                func()
}

type endpoint struct {
	name  string
	scope string
	field string
	max   int
	call  func(ctx context.Context, keyID string, items json.RawMessage, ip string) (json.RawMessage, error)
}

type Server struct {
	opts      Options
	notify    endpoint
	botPosts  endpoint
	slots     chan struct{}
	perKey    *ratelimit.Limiter
	failures  *ratelimit.Limiter
	failing   atomic.Int32
	lastError atomic.Value

	mu       sync.Mutex
	requests map[metrics.Request]uint64
	messages map[string]uint64
	posts    map[string]uint64
	devices  uint64
	duration float64
	handled  uint64
}

func New(opts Options) *Server {
	if opts.QueueWait <= 0 {
		opts.QueueWait = 5 * time.Second
	}
	if opts.Notify == nil {
		opts.Notify = func() {}
	}
	s := &Server{
		opts:     opts,
		slots:    make(chan struct{}, opts.MaxConcurrent),
		perKey:   ratelimit.New(time.Minute),
		failures: ratelimit.New(time.Minute),
		requests: map[metrics.Request]uint64{},
		messages: map[string]uint64{},
		posts:    map[string]uint64{},
	}
	s.notify = endpoint{name: "notify", scope: keys.ScopeNotify, field: "messages", max: MaxMessages, call: opts.Store.Notify}
	s.botPosts = endpoint{name: "bot_posts", scope: keys.ScopeBotPost, field: "posts", max: MaxPosts, call: opts.Store.BotPosts}
	s.lastError.Store("")
	return s
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	id := r.Header.Get("X-Request-Id")
	if !safeRequestID(id) {
		var b [8]byte
		_, _ = rand.Read(b[:])
		id = hex.EncodeToString(b[:])
	}
	w.Header().Set("X-Request-Id", id)
	log := s.opts.Log.With("request_id", id)
	defer func() {
		if rec := recover(); rec != nil {
			log.Error("Panic while handling request", "panic", fmt.Sprint(rec))
			writeError(w, http.StatusInternalServerError, codeInternal, "")
		}
	}()

	var ep *endpoint
	switch r.URL.Path {
	case "/notify/messages":
		ep = &s.notify
	case "/bot/posts":
		ep = &s.botPosts
	default:
		writeError(w, http.StatusNotFound, codeNotFound, "")
		return
	}
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		writeError(w, http.StatusMethodNotAllowed, codeMethodNotAllowed, "")
		return
	}
	s.handle(ep, w, r, log)
}

type outcome struct {
	status int
	code   string
	key    *keys.Key
	items  int
	counts map[string]int
}

func (s *Server) handle(ep *endpoint, w http.ResponseWriter, r *http.Request, log *slog.Logger) {
	start := time.Now()
	ip := s.opts.ClientIP(r)
	res := s.process(ep, w, r, ip)
	elapsed := time.Since(start)
	s.record(ep.name, res, elapsed)

	attrs := []any{"endpoint", ep.name, "status", res.status, "code", res.code, "client_ip", ip,
		"items", res.items, "duration_ms", elapsed.Milliseconds()}
	if res.key != nil {
		attrs = append(attrs, "key_id", res.key.ID, "key_prefix", res.key.Prefix)
	}
	for k, v := range res.counts {
		attrs = append(attrs, k, v)
	}
	level := slog.LevelInfo
	switch {
	case res.status >= 500:
		level = slog.LevelError
	case res.status == http.StatusUnauthorized || res.status == http.StatusForbidden || res.status == http.StatusTooManyRequests:
		level = slog.LevelWarn
	}
	log.Log(r.Context(), level, "Integration request", attrs...)
}

func (s *Server) process(ep *endpoint, w http.ResponseWriter, r *http.Request, ip string) outcome {
	failKey := "ip:" + ip
	if blocked, retry := s.failures.Exceeded(failKey, s.opts.AuthFailuresPerMinute); blocked {
		return s.fail(w, http.StatusTooManyRequests, codeTooManyAuthFailures, "", retry, nil)
	}
	token, ok := bearer(r.Header.Get("Authorization"))
	if !ok {
		s.failures.Hit(failKey)
		return s.fail(w, http.StatusUnauthorized, codeMissingKey, "", 0, nil)
	}
	hash, ok := keys.Hash(token)
	if !ok {
		s.failures.Hit(failKey)
		return s.fail(w, http.StatusUnauthorized, codeInvalidKey, "", 0, nil)
	}
	key, err := s.opts.Keys.Authenticate(r.Context(), hash, ip)
	if err != nil {
		s.storeFailed(err)
		return s.fail(w, http.StatusServiceUnavailable, codeUnavailable, "", 5*time.Second, nil)
	}
	if key == nil {
		s.failures.Hit(failKey)
		return s.fail(w, http.StatusUnauthorized, codeInvalidKey, "", 0, nil)
	}
	if !key.IPAllowed {
		return s.fail(w, http.StatusForbidden, codeIPNotAllowed, "", 0, key)
	}
	if !key.Has(ep.scope) {
		return s.fail(w, http.StatusForbidden, codeScopeForbidden, "", 0, key)
	}
	if ok, retry := s.perKey.Allow("key:"+key.ID, max(1, key.RateLimit)); !ok {
		return s.fail(w, http.StatusTooManyRequests, codeRateLimited, "", retry, key)
	}

	items, count, status, code := s.readBatch(ep, w, r)
	if status != 0 {
		res := s.fail(w, status, code, "", 0, key)
		res.items = count
		return res
	}

	select {
	case s.slots <- struct{}{}:
	case <-time.After(s.opts.QueueWait):
		res := s.fail(w, http.StatusServiceUnavailable, codeBusy, "", 2*time.Second, key)
		res.items = count
		return res
	case <-r.Context().Done():
		return outcome{status: 499, code: codeCanceled, key: key, items: count}
	}
	defer func() { <-s.slots }()

	ctx, cancel := context.WithTimeout(r.Context(), s.opts.RequestTimeout)
	defer cancel()
	out, err := ep.call(ctx, key.ID, items, ip)
	var api *store.APIError
	switch {
	case errors.As(err, &api):
		s.storeOK()
		if api.Status == http.StatusUnauthorized {
			s.opts.Keys.Forget(hash)
		}
		res := s.fail(w, apiStatus(api.Status), api.Code, api.Detail, 0, key)
		res.items = count
		return res
	case err != nil:
		if r.Context().Err() != nil {
			return outcome{status: 499, code: codeCanceled, key: key, items: count}
		}
		s.storeFailed(err)
		res := s.fail(w, http.StatusServiceUnavailable, codeUnavailable, "", 5*time.Second, key)
		res.items = count
		return res
	}
	s.storeOK()
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(out)
	return outcome{status: http.StatusOK, code: "ok", key: key, items: count, counts: summary(out)}
}

func (s *Server) readBatch(ep *endpoint, w http.ResponseWriter, r *http.Request) (json.RawMessage, int, int, string) {
	body := http.MaxBytesReader(w, r.Body, s.opts.MaxBodyBytes)
	dec := json.NewDecoder(body)
	var payload map[string]json.RawMessage
	if err := dec.Decode(&payload); err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			return nil, 0, http.StatusRequestEntityTooLarge, codeBodyTooLarge
		}
		return nil, 0, http.StatusBadRequest, codeInvalidJSON
	}
	if _, err := dec.Token(); !errors.Is(err, io.EOF) {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			return nil, 0, http.StatusRequestEntityTooLarge, codeBodyTooLarge
		}
		return nil, 0, http.StatusBadRequest, codeInvalidJSON
	}
	raw, ok := payload[ep.field]
	var items []json.RawMessage
	if !ok || json.Unmarshal(raw, &items) != nil {
		return nil, 0, http.StatusBadRequest, codeInvalidBatch
	}
	if len(items) == 0 || len(items) > ep.max {
		return nil, len(items), http.StatusBadRequest, codeInvalidBatch
	}
	return raw, len(items), 0, ""
}

func (s *Server) fail(w http.ResponseWriter, status int, code, detail string, retry time.Duration, key *keys.Key) outcome {
	if retry > 0 {
		w.Header().Set("Retry-After", strconv.Itoa(int((retry+time.Second-1)/time.Second)))
	}
	writeError(w, status, code, detail)
	return outcome{status: status, code: code, key: key}
}

func (s *Server) record(endpoint string, res outcome, elapsed time.Duration) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.requests[metrics.Request{Endpoint: endpoint, Code: res.code}]++
	if res.key != nil {
		s.handled++
		s.duration += elapsed.Seconds()
	}
	target := s.messages
	if endpoint == s.botPosts.name {
		target = s.posts
	}
	for k, v := range res.counts {
		if k == "devices" {
			s.devices += uint64(v)
			continue
		}
		target[k] += uint64(v)
	}
}

func (s *Server) storeFailed(err error) {
	s.lastError.Store(err.Error())
	if s.failing.Add(1) == degradedAfter {
		s.opts.Notify()
	}
}

func (s *Server) storeOK() {
	if s.failing.Swap(0) >= degradedAfter {
		s.opts.Notify()
	}
}

func (s *Server) Report() heartbeat.Report {
	s.mu.Lock()
	var messages, posts uint64
	for _, v := range s.messages {
		messages += v
	}
	for _, v := range s.posts {
		posts += v
	}
	s.mu.Unlock()
	detail := map[string]any{
		"notify_messages": messages,
		"bot_posts":       posts,
		"keys_cached":     s.opts.Keys.Len(),
		"inflight":        len(s.slots),
	}
	if n := s.failing.Load(); n >= degradedAfter {
		return heartbeat.Report{Status: heartbeat.StatusDegraded,
			Error:  fmt.Sprintf("Database API unreachable (%d consecutive failures): %s", n, s.lastError.Load()),
			Detail: detail}
	}
	return heartbeat.Report{Status: heartbeat.StatusOK, Detail: detail}
}

func (s *Server) Metrics() metrics.Snapshot {
	s.mu.Lock()
	defer s.mu.Unlock()
	snap := metrics.Snapshot{
		Requests:        make(map[metrics.Request]uint64, len(s.requests)),
		Messages:        make(map[string]uint64, len(s.messages)),
		Posts:           make(map[string]uint64, len(s.posts)),
		Devices:         s.devices,
		DurationSeconds: s.duration,
		Handled:         s.handled,
		Inflight:        len(s.slots),
		Capacity:        cap(s.slots),
		KeysCached:      s.opts.Keys.Len(),
		StoreFailures:   int(s.failing.Load()),
	}
	for k, v := range s.requests {
		snap.Requests[k] = v
	}
	for k, v := range s.messages {
		snap.Messages[k] = v
	}
	for k, v := range s.posts {
		snap.Posts[k] = v
	}
	return snap
}

func summary(out json.RawMessage) map[string]int {
	var body map[string]json.RawMessage
	if json.Unmarshal(out, &body) != nil {
		return nil
	}
	counts := map[string]int{}
	for _, k := range []string{"queued", "devices", "no_recipient", "duplicate", "invalid", "published", "rejected", "rate_limited"} {
		var n int
		if raw, ok := body[k]; ok && json.Unmarshal(raw, &n) == nil {
			counts[k] = n
		}
	}
	return counts
}

func apiStatus(status int) int {
	switch status {
	case http.StatusBadRequest, http.StatusUnauthorized, http.StatusForbidden, http.StatusNotFound, http.StatusConflict,
		http.StatusUnprocessableEntity, http.StatusTooManyRequests:
		return status
	}
	return http.StatusBadGateway
}

func bearer(header string) (string, bool) {
	scheme, token, ok := strings.Cut(strings.TrimSpace(header), " ")
	if !ok || !strings.EqualFold(scheme, "Bearer") {
		return "", false
	}
	token = strings.TrimSpace(token)
	return token, token != ""
}

func safeRequestID(id string) bool {
	if id == "" || len(id) > 64 {
		return false
	}
	for i := 0; i < len(id); i++ {
		c := id[i]
		if !(c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '.' || c == '_' || c == '-') {
			return false
		}
	}
	return true
}
