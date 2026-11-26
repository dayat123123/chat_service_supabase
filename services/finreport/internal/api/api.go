package api

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"mime"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"olt-social/finreport/internal/keys"
	"olt-social/finreport/internal/ratelimit"
	"olt-social/finreport/internal/store"
	"olt-social/finreport/internal/xbrl"
)

const (
	basePath      = "/financial-reports"
	EndpointPost  = "submit"
	EndpointGet   = "status"
	degradedAfter = 3
)

var fileID = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

type Store interface {
	Submit(ctx context.Context, keyID, sha string, size int64, ip string) (json.RawMessage, error)
	File(ctx context.Context, keyID, id, ip string) (json.RawMessage, error)
}

type Objects interface {
	Upload(ctx context.Context, name string, body []byte) error
}

type Keys interface {
	Authenticate(ctx context.Context, keyHash, ip string) (*keys.Key, error)
	Forget(keyHash string)
	Len() int
}

type Options struct {
	Log                   *slog.Logger
	Store                 Store
	Objects               Objects
	Keys                  Keys
	ClientIP              func(*http.Request) string
	MaxFileBytes          int64
	MaxUploads            int
	AuthFailuresPerMinute int
	RequestTimeout        time.Duration
	QueueWait             time.Duration
	Limits                xbrl.Limits
	Accepted              func()
	Notify                func()
}

type Request struct {
	Endpoint string
	Code     string
}

type Server struct {
	opts      Options
	slots     chan struct{}
	perKey    *ratelimit.Limiter
	failures  *ratelimit.Limiter
	failing   atomic.Int32
	lastError atomic.Value

	mu       sync.Mutex
	requests map[Request]uint64
	bytes    uint64
}

func New(opts Options) *Server {
	if opts.QueueWait <= 0 {
		opts.QueueWait = 3 * time.Second
	}
	if opts.Accepted == nil {
		opts.Accepted = func() {}
	}
	if opts.Notify == nil {
		opts.Notify = func() {}
	}
	s := &Server{
		opts:     opts,
		slots:    make(chan struct{}, opts.MaxUploads),
		perKey:   ratelimit.New(time.Minute),
		failures: ratelimit.New(time.Minute),
		requests: map[Request]uint64{},
	}
	s.lastError.Store("")
	return s
}

type outcome struct {
	status int
	code   string
	key    *keys.Key
	bytes  int
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

	endpoint, method, target := route(r.URL.Path)
	if endpoint == "" {
		writeError(w, http.StatusNotFound, codeNotFound, "")
		return
	}
	if r.Method != method {
		w.Header().Set("Allow", method)
		writeError(w, http.StatusMethodNotAllowed, codeMethodNotAllowed, "Gunakan metode "+method+".")
		return
	}
	start := time.Now()
	ip := s.opts.ClientIP(r)
	res := s.process(endpoint, target, w, r, ip)
	elapsed := time.Since(start)
	s.record(endpoint, res)

	attrs := []any{"endpoint", endpoint, "status", res.status, "code", res.code, "client_ip", ip,
		"bytes", res.bytes, "duration_ms", elapsed.Milliseconds()}
	if res.key != nil {
		attrs = append(attrs, "key_id", res.key.ID, "key_prefix", res.key.Prefix)
	}
	level := slog.LevelInfo
	switch {
	case res.status >= 500:
		level = slog.LevelError
	case res.status == http.StatusUnauthorized || res.status == http.StatusForbidden || res.status == http.StatusTooManyRequests:
		level = slog.LevelWarn
	}
	log.Log(r.Context(), level, "Financial report request", attrs...)
}

func route(path string) (endpoint, method, target string) {
	if path == basePath || path == basePath+"/" {
		return EndpointPost, http.MethodPost, ""
	}
	if rest, ok := strings.CutPrefix(path, basePath+"/"); ok && rest != "" && !strings.Contains(rest, "/") {
		return EndpointGet, http.MethodGet, rest
	}
	return "", "", ""
}

func (s *Server) process(endpoint, target string, w http.ResponseWriter, r *http.Request, ip string) outcome {
	key, hash, res := s.authenticate(w, r, ip)
	if key == nil {
		return res
	}
	if endpoint == EndpointGet {
		return s.status(w, r, key, hash, target, ip)
	}
	return s.submit(w, r, key, hash, ip)
}

func (s *Server) authenticate(w http.ResponseWriter, r *http.Request, ip string) (*keys.Key, string, outcome) {
	failKey := "ip:" + ip
	if blocked, retry := s.failures.Exceeded(failKey, s.opts.AuthFailuresPerMinute); blocked {
		return nil, "", s.fail(w, http.StatusTooManyRequests, codeTooManyAuthFailures, "", retry, nil)
	}
	token, ok := bearer(r.Header.Get("Authorization"))
	if !ok {
		s.failures.Hit(failKey)
		return nil, "", s.fail(w, http.StatusUnauthorized, codeMissingKey, "", 0, nil)
	}
	hash, ok := keys.Hash(token)
	if !ok {
		s.failures.Hit(failKey)
		return nil, "", s.fail(w, http.StatusUnauthorized, codeInvalidKey, "", 0, nil)
	}
	key, err := s.opts.Keys.Authenticate(r.Context(), hash, ip)
	if err != nil {
		s.storeFailed(err)
		return nil, "", s.fail(w, http.StatusServiceUnavailable, codeUnavailable, "", 5*time.Second, nil)
	}
	if key == nil {
		s.failures.Hit(failKey)
		return nil, "", s.fail(w, http.StatusUnauthorized, codeInvalidKey, "", 0, nil)
	}
	if !key.IPAllowed {
		return nil, "", s.fail(w, http.StatusForbidden, codeIPNotAllowed, "", 0, key)
	}
	if !key.Has(keys.ScopeFinancialReport) {
		return nil, "", s.fail(w, http.StatusForbidden, codeScopeForbidden, "", 0, key)
	}
	if ok, retry := s.perKey.Allow("key:"+key.ID, max(1, key.RateLimit)); !ok {
		return nil, "", s.fail(w, http.StatusTooManyRequests, codeRateLimited, "", retry, key)
	}
	return key, hash, outcome{}
}

func (s *Server) status(w http.ResponseWriter, r *http.Request, key *keys.Key, hash, id, ip string) outcome {
	if !fileID.MatchString(id) {
		return s.fail(w, http.StatusBadRequest, codeInvalidID, "", 0, key)
	}
	ctx, cancel := context.WithTimeout(r.Context(), s.opts.RequestTimeout)
	defer cancel()
	out, err := s.opts.Store.File(ctx, key.ID, id, ip)
	if res, failed := s.storeResult(w, r, err, key, hash); failed {
		return res
	}
	return s.reply(w, http.StatusOK, out, key, 0)
}

func (s *Server) submit(w http.ResponseWriter, r *http.Request, key *keys.Key, hash, ip string) outcome {
	if !zipType(r.Header.Get("Content-Type")) {
		return s.fail(w, http.StatusUnsupportedMediaType, codeUnsupportedType, "", 0, key)
	}
	if r.ContentLength > s.opts.MaxFileBytes {
		return s.fail(w, http.StatusRequestEntityTooLarge, codeBodyTooLarge, "", 0, key)
	}
	select {
	case s.slots <- struct{}{}:
	case <-time.After(s.opts.QueueWait):
		return s.fail(w, http.StatusServiceUnavailable, codeBusy, "", 5*time.Second, key)
	case <-r.Context().Done():
		return outcome{status: 499, code: codeCanceled, key: key}
	}
	defer func() { <-s.slots }()

	data, res, ok := s.readBody(w, r, key)
	if !ok {
		return res
	}
	if _, err := xbrl.Inspect(data, s.opts.Limits); err != nil {
		code := codeNotZip
		switch {
		case errors.Is(err, xbrl.ErrUnsafeZip):
			code = codeZipUnsafe
		case errors.Is(err, xbrl.ErrNoInstance):
			code = codeNoInstance
		}
		res := s.fail(w, http.StatusBadRequest, code, "", 0, key)
		res.bytes = len(data)
		return res
	}
	sum := sha256.Sum256(data)
	sha := hex.EncodeToString(sum[:])

	ctx, cancel := context.WithTimeout(r.Context(), s.opts.RequestTimeout)
	defer cancel()
	if err := s.opts.Objects.Upload(ctx, "api/"+sha+"/report.zip", data); err != nil {
		if r.Context().Err() != nil {
			return outcome{status: 499, code: codeCanceled, key: key, bytes: len(data)}
		}
		s.storeFailed(err)
		res := s.fail(w, http.StatusServiceUnavailable, codeUnavailable, "", 5*time.Second, key)
		res.bytes = len(data)
		return res
	}
	out, err := s.opts.Store.Submit(ctx, key.ID, sha, int64(len(data)), ip)
	if res, failed := s.storeResult(w, r, err, key, hash); failed {
		res.bytes = len(data)
		return res
	}
	var body struct {
		Status      string `json:"status"`
		Resubmitted bool   `json:"resubmitted"`
	}
	_ = json.Unmarshal(out, &body)
	status := http.StatusOK
	if body.Status == "queued" && !body.Resubmitted {
		status = http.StatusAccepted
		s.opts.Accepted()
	}
	return s.reply(w, status, out, key, len(data))
}

func (s *Server) readBody(w http.ResponseWriter, r *http.Request, key *keys.Key) ([]byte, outcome, bool) {
	var buf bytes.Buffer
	if r.ContentLength > 0 {
		buf.Grow(int(r.ContentLength))
	}
	_, err := buf.ReadFrom(http.MaxBytesReader(w, r.Body, s.opts.MaxFileBytes))
	var tooLarge *http.MaxBytesError
	switch {
	case errors.As(err, &tooLarge):
		return nil, s.fail(w, http.StatusRequestEntityTooLarge, codeBodyTooLarge, "", 0, key), false
	case err != nil && r.Context().Err() != nil:
		return nil, outcome{status: 499, code: codeCanceled, key: key}, false
	case err != nil:
		return nil, s.fail(w, http.StatusBadRequest, codeEmptyBody, "Body tidak terbaca sampai selesai.", 0, key), false
	case buf.Len() == 0:
		return nil, s.fail(w, http.StatusBadRequest, codeEmptyBody, "", 0, key), false
	}
	return buf.Bytes(), outcome{}, true
}

func (s *Server) storeResult(w http.ResponseWriter, r *http.Request, err error, key *keys.Key, hash string) (outcome, bool) {
	var api *store.APIError
	switch {
	case err == nil:
		s.storeOK()
		return outcome{}, false
	case errors.As(err, &api):
		s.storeOK()
		if api.Status == http.StatusUnauthorized {
			s.opts.Keys.Forget(hash)
		}
		retry := time.Duration(0)
		if api.Status == http.StatusTooManyRequests {
			retry = time.Minute
		}
		return s.fail(w, apiStatus(api.Status), api.Code, api.Detail, retry, key), true
	case r.Context().Err() != nil:
		return outcome{status: 499, code: codeCanceled, key: key}, true
	}
	s.storeFailed(err)
	return s.fail(w, http.StatusServiceUnavailable, codeUnavailable, "", 5*time.Second, key), true
}

func (s *Server) reply(w http.ResponseWriter, status int, out json.RawMessage, key *keys.Key, n int) outcome {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_, _ = w.Write(out)
	return outcome{status: status, code: "ok", key: key, bytes: n}
}

func (s *Server) fail(w http.ResponseWriter, status int, code, detail string, retry time.Duration, key *keys.Key) outcome {
	if retry > 0 {
		w.Header().Set("Retry-After", strconv.Itoa(int((retry+time.Second-1)/time.Second)))
	}
	writeError(w, status, code, detail)
	return outcome{status: status, code: code, key: key}
}

func (s *Server) record(endpoint string, res outcome) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.requests[Request{Endpoint: endpoint, Code: res.code}]++
	if res.code == "ok" {
		s.bytes += uint64(res.bytes)
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

type Snapshot struct {
	Requests      map[Request]uint64
	Bytes         uint64
	Inflight      int
	Capacity      int
	KeysCached    int
	StoreFailures int
	LastError     string
}

func (s *Server) Snapshot() Snapshot {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := Snapshot{
		Requests:      make(map[Request]uint64, len(s.requests)),
		Bytes:         s.bytes,
		Inflight:      len(s.slots),
		Capacity:      cap(s.slots),
		KeysCached:    s.opts.Keys.Len(),
		StoreFailures: int(s.failing.Load()),
		LastError:     s.lastError.Load().(string),
	}
	for k, v := range s.requests {
		out.Requests[k] = v
	}
	return out
}

func zipType(header string) bool {
	media, _, err := mime.ParseMediaType(header)
	if err != nil {
		return false
	}
	switch media {
	case "application/zip", "application/x-zip-compressed", "application/octet-stream":
		return true
	}
	return false
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
