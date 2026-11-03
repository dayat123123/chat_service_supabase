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
	"maps"
	"net"
	"net/http"
	"os"
	"slices"
	"strings"
	"sync"
	"time"

	"olt-social/media/internal/heartbeat"
	"olt-social/media/internal/jwt"
	"olt-social/media/internal/metrics"
	"olt-social/media/internal/sanitize"
	"olt-social/media/internal/sniff"
	"olt-social/media/internal/storage"
)

const (
	defaultQueueWait = 5 * time.Second
	tokenTTL         = 120 * time.Second
	clockLeeway      = 30 * time.Second
	failThreshold    = 3
	probeTimeout     = 5 * time.Second
	otherBucket      = "other"
)

type bucket struct {
	limit  int64
	kinds  []sniff.Kind
	upsert bool
}

var buckets = map[string]bucket{
	"avatars":      {limit: 2 << 20, kinds: []sniff.Kind{sniff.JPEG, sniff.PNG, sniff.WebP}, upsert: true},
	"attachments":  {limit: 5 << 20, kinds: []sniff.Kind{sniff.JPEG, sniff.PNG, sniff.WebP, sniff.GIF}},
	"cs-documents": {limit: 10 << 20, kinds: []sniff.Kind{sniff.PDF}},
}

var sanitizers = map[sniff.Kind]func([]byte) ([]byte, sanitize.Info, error){
	sniff.JPEG: sanitize.JPEG,
	sniff.PNG:  sanitize.PNG,
	sniff.WebP: sanitize.WebP,
	sniff.GIF:  sanitize.GIF,
	sniff.PDF:  sanitize.PDF,
}

type Storage interface {
	Upload(ctx context.Context, u storage.Upload) error
	Ping(ctx context.Context) error
}

type Options struct {
	Log            *slog.Logger
	Secret         []byte
	Storage        Storage
	MaxConcurrent  int
	RequestTimeout time.Duration
	QueueWait      time.Duration
	Notify         func()
	Now            func() time.Time
}

type Server struct {
	opts  Options
	slots chan struct{}

	mu       sync.Mutex
	uploads  map[metrics.Upload]uint64
	accepted uint64
	rejected uint64
	cleaned  uint64
	received uint64
	stored   uint64
	seconds  float64
	requests uint64
	failures int
}

type outcome struct {
	bucket   string
	kind     sniff.Kind
	path     string
	received int
	stored   int
	info     sanitize.Info
	err      *apiError
}

type uploaded struct {
	Bucket string `json:"bucket"`
	Path   string `json:"path"`
	MIME   string `json:"mime"`
	Size   int    `json:"size"`
	Width  *int   `json:"width,omitempty"`
	Height *int   `json:"height,omitempty"`
}

func New(opts Options) *Server {
	if opts.QueueWait <= 0 {
		opts.QueueWait = defaultQueueWait
	}
	if opts.Now == nil {
		opts.Now = time.Now
	}
	return &Server{
		opts:    opts,
		slots:   make(chan struct{}, opts.MaxConcurrent),
		uploads: map[metrics.Upload]uint64{},
	}
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost || !strings.HasPrefix(r.URL.Path, "/object/") {
		writeJSON(w, http.StatusNotFound, errorBody{Code: codeNotFound, Message: messages[codeNotFound]})
		return
	}
	began := time.Now()
	id := requestID(r.Header.Get("X-Request-Id"))
	w.Header().Set("X-Request-Id", id)
	o := s.upload(w, r, began)
	took := time.Since(began)
	s.record(o, took)
	attrs := []any{"request_id", id, "bucket", o.bucket, "size_in", o.received, "took_ms", took.Milliseconds()}
	if o.err != nil {
		attrs = append(attrs, "code", o.err.code, "status", o.err.status)
		if o.err.detail != "" {
			attrs = append(attrs, "reason", o.err.detail)
		}
		switch o.err.status {
		case http.StatusUnauthorized:
			w.Header().Set("WWW-Authenticate", `Bearer error="invalid_token"`)
		case http.StatusServiceUnavailable:
			w.Header().Set("Retry-After", "2")
		}
		writeJSON(w, o.err.status, errorBody{Code: o.err.code, Message: o.err.message})
		if o.err.status >= 500 {
			s.opts.Log.Warn("Upload failed", attrs...)
		} else {
			s.opts.Log.Info("Upload rejected", attrs...)
		}
		return
	}
	reply := uploaded{Bucket: o.bucket, Path: o.path, MIME: o.kind.MIME(), Size: o.stored}
	if o.kind.Image() {
		reply.Width, reply.Height = &o.info.Width, &o.info.Height
	}
	writeJSON(w, http.StatusOK, reply)
	s.opts.Log.Info("Upload stored", append(attrs, "code", "ok", "mime", reply.MIME, "size_out", o.stored,
		"metadata_removed", o.info.Removed)...)
}

func (s *Server) upload(w http.ResponseWriter, r *http.Request, began time.Time) outcome {
	name, segments, pathOK := splitPath(r.URL.EscapedPath())
	b, allowed := buckets[name]
	o := outcome{bucket: otherBucket}
	if allowed {
		o.bucket = name
	}
	user, err := jwt.VerifyUser(bearer(r), s.opts.Secret, s.opts.Now(), clockLeeway)
	if err != nil {
		o.err = fail(http.StatusUnauthorized, codeInvalidToken, err.Error())
		return o
	}
	if !allowed {
		o.err = fail(http.StatusBadRequest, codeBucketNotAllowed, "")
		return o
	}
	if !pathOK {
		o.err = fail(http.StatusBadRequest, codeInvalidPath, "")
		return o
	}
	if r.ContentLength > b.limit {
		o.err = tooLarge(b.limit, fmt.Sprintf("content-length %d", r.ContentLength))
		return o
	}
	deadline := began.Add(s.opts.RequestTimeout)
	ctx, cancel := context.WithDeadline(r.Context(), deadline)
	defer cancel()
	if !s.acquire(ctx) {
		o.err = fail(http.StatusServiceUnavailable, codeBusy, "no free slot")
		if r.Context().Err() != nil {
			o.err = fail(499, codeCanceled, "client went away while queued")
		}
		return o
	}
	defer s.release()

	body, err := readBody(w, r, b.limit, deadline)
	o.received = len(body)
	switch {
	case err != nil && timeout(err):
		o.err = fail(http.StatusRequestTimeout, codeRequestTimeout, err.Error())
		return o
	case err != nil && r.Context().Err() != nil:
		o.err = fail(499, codeCanceled, "client went away during upload")
		return o
	case err != nil:
		o.err = fail(http.StatusBadRequest, codeInvalidRequest, err.Error())
		return o
	case len(body) == 0:
		o.err = fail(http.StatusBadRequest, codeEmptyFile, "")
		return o
	case int64(len(body)) > b.limit:
		o.err = tooLarge(b.limit, "body exceeds the bucket limit")
		return o
	}

	o.kind = sniff.Detect(body)
	if !slices.Contains(b.kinds, o.kind) {
		o.err = fail(http.StatusUnsupportedMediaType, codeUnsupportedType, "detected "+o.kind.String())
		return o
	}
	clean, info, err := sanitizers[o.kind](body)
	if err != nil {
		o.err = sanitizeError(err)
		return o
	}
	o.info = info
	o.path = finalPath(segments, o.kind.Ext())

	token, err := jwt.Verified(user, s.opts.Secret, s.opts.Now(), tokenTTL)
	if err != nil {
		o.err = fail(http.StatusInternalServerError, codeInternal, "mint token: "+err.Error())
		return o
	}
	err = s.opts.Storage.Upload(ctx, storage.Upload{
		Bucket:      name,
		Path:        o.path,
		ContentType: o.kind.MIME(),
		Body:        clean,
		Upsert:      b.upsert && strings.EqualFold(strings.TrimSpace(r.Header.Get("x-upsert")), "true"),
		Token:       token,
	})
	if err == nil {
		s.noteStorage(true)
		o.stored = len(clean)
		return o
	}
	var f *storage.Failure
	if !errors.As(err, &f) {
		o.err = fail(http.StatusBadGateway, storage.CodeError, err.Error())
		return o
	}
	if f.Unreachable && r.Context().Err() != nil {
		o.err = fail(499, codeCanceled, "client went away while storing")
		return o
	}
	s.noteStorage(!f.Unreachable)
	o.err = fail(f.Status, f.Code, f.Reason)
	if f.Code == storage.CodeTooLarge {
		o.err = tooLarge(b.limit, f.Reason)
	}
	return o
}

func (s *Server) acquire(ctx context.Context) bool {
	select {
	case s.slots <- struct{}{}:
		return true
	default:
	}
	timer := time.NewTimer(s.opts.QueueWait)
	defer timer.Stop()
	select {
	case s.slots <- struct{}{}:
		return true
	case <-timer.C:
	case <-ctx.Done():
	}
	return false
}

func (s *Server) release() {
	<-s.slots
}

func readBody(w http.ResponseWriter, r *http.Request, limit int64, deadline time.Time) ([]byte, error) {
	_ = http.NewResponseController(w).SetReadDeadline(deadline)
	return io.ReadAll(io.LimitReader(r.Body, limit+1))
}

func timeout(err error) bool {
	var netErr net.Error
	return errors.Is(err, os.ErrDeadlineExceeded) || (errors.As(err, &netErr) && netErr.Timeout())
}

func (s *Server) record(o outcome, took time.Duration) {
	code := "ok"
	if o.err != nil {
		code = o.err.code
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.uploads[metrics.Upload{Bucket: o.bucket, Code: code}]++
	s.requests++
	s.seconds += took.Seconds()
	s.received += uint64(o.received)
	if o.err != nil {
		s.rejected++
		return
	}
	s.accepted++
	s.stored += uint64(o.stored)
	if o.info.Removed > 0 {
		s.cleaned++
	}
}

func (s *Server) noteStorage(reachable bool) {
	s.mu.Lock()
	before := s.failures >= failThreshold
	if reachable {
		s.failures = 0
	} else {
		s.failures++
	}
	after := s.failures >= failThreshold
	failures := s.failures
	s.mu.Unlock()
	if before == after {
		return
	}
	if after {
		s.opts.Log.Warn("Storage cannot be reached; reporting degraded", "consecutive_failures", failures)
	} else {
		s.opts.Log.Info("Storage reachable again; reporting ok")
	}
	if s.opts.Notify != nil {
		s.opts.Notify()
	}
}

func (s *Server) ProbeStorage(ctx context.Context) {
	probe, cancel := context.WithTimeout(ctx, probeTimeout)
	err := s.opts.Storage.Ping(probe)
	cancel()
	if ctx.Err() != nil {
		return
	}
	if err != nil {
		s.opts.Log.Debug("Storage probe failed", "error", err)
	}
	s.noteStorage(err == nil)
}

func (s *Server) Report() heartbeat.Report {
	s.mu.Lock()
	defer s.mu.Unlock()
	r := heartbeat.Report{
		Status: heartbeat.StatusOK,
		Detail: map[string]any{"accepted": s.accepted, "rejected": s.rejected, "metadata_removed": s.cleaned},
	}
	if s.failures >= failThreshold {
		r.Status = heartbeat.StatusDegraded
		r.Error = fmt.Sprintf("Storage tidak bisa dihubungi (%d kali berturut-turut)", s.failures)
	}
	return r
}

func (s *Server) Metrics() metrics.Snapshot {
	s.mu.Lock()
	defer s.mu.Unlock()
	return metrics.Snapshot{
		Uploads:         maps.Clone(s.uploads),
		MetadataRemoved: s.cleaned,
		ReceivedBytes:   s.received,
		StoredBytes:     s.stored,
		DurationSeconds: s.seconds,
		Requests:        s.requests,
		Inflight:        len(s.slots),
		Capacity:        cap(s.slots),
		StorageFailures: s.failures,
	}
}

func bearer(r *http.Request) string {
	scheme, token, ok := strings.Cut(strings.TrimSpace(r.Header.Get("Authorization")), " ")
	if !ok || !strings.EqualFold(scheme, "Bearer") {
		return ""
	}
	return strings.TrimSpace(token)
}

func requestID(given string) string {
	if len(given) >= 1 && len(given) <= 64 && validChars(given) {
		return given
	}
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	h := w.Header()
	h.Set("Content-Type", "application/json; charset=utf-8")
	h.Set("Cache-Control", "no-store")
	h.Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
