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
	"math"
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
	"olt-social/media/internal/moderation"
	"olt-social/media/internal/sanitize"
	"olt-social/media/internal/sniff"
	"olt-social/media/internal/storage"
	"olt-social/media/internal/store"
)

const (
	defaultQueueWait = 5 * time.Second
	tokenTTL         = 120 * time.Second
	clockLeeway      = 30 * time.Second
	failThreshold    = 3
	probeTimeout     = 5 * time.Second
	otherBucket      = "other"

	holdCancelTimeout   = 5 * time.Second
	verdictUnclassified = "unclassified"
)

type bucket struct {
	limit    int64
	kinds    []sniff.Kind
	upsert   bool
	holdable bool
}

var buckets = map[string]bucket{
	"avatars":      {limit: 2 << 20, kinds: []sniff.Kind{sniff.JPEG, sniff.PNG, sniff.WebP}, upsert: true},
	"attachments":  {limit: 5 << 20, kinds: []sniff.Kind{sniff.JPEG, sniff.PNG, sniff.WebP, sniff.GIF}, holdable: true},
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

type Classifier interface {
	Classify(ctx context.Context, mime string, body []byte, requestID string) (moderation.Result, error)
	Ping(ctx context.Context) error
}

type Policy interface {
	Current() (moderation.Thresholds, bool)
}

type Holds interface {
	RecordHold(ctx context.Context, h moderation.HoldRequest) (int64, error)
	CancelHold(ctx context.Context, id int64) error
}

type Options struct {
	Log               *slog.Logger
	Secret            []byte
	Storage           Storage
	Classifier        Classifier
	Policy            Policy
	Holds             Holds
	AllowUnclassified bool
	MaxConcurrent     int
	RequestTimeout    time.Duration
	QueueWait         time.Duration
	Notify            func()
	Now               func() time.Time
}

type Server struct {
	opts  Options
	slots chan struct{}

	mu                sync.Mutex
	uploads           map[metrics.Upload]uint64
	verdicts          map[string]uint64
	accepted          uint64
	rejected          uint64
	cleaned           uint64
	received          uint64
	stored            uint64
	seconds           float64
	requests          uint64
	failures          int
	classifierFails   int
	classifierProblem string
	classifierSeconds float64
	classifications   uint64
}

type outcome struct {
	bucket   string
	kind     sniff.Kind
	path     string
	received int
	stored   int
	info     sanitize.Info
	verdict  string
	decision moderation.Decision
	err      *apiError
}

type uploaded struct {
	Bucket string `json:"bucket"`
	Path   string `json:"path"`
	MIME   string `json:"mime"`
	Size   int    `json:"size"`
	Width  *int   `json:"width,omitempty"`
	Height *int   `json:"height,omitempty"`
	Held   bool   `json:"held,omitempty"`
}

func New(opts Options) *Server {
	if opts.QueueWait <= 0 {
		opts.QueueWait = defaultQueueWait
	}
	if opts.Now == nil {
		opts.Now = time.Now
	}
	return &Server{
		opts:     opts,
		slots:    make(chan struct{}, opts.MaxConcurrent),
		uploads:  map[metrics.Upload]uint64{},
		verdicts: map[string]uint64{},
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
	o := s.upload(w, r, began, id)
	took := time.Since(began)
	s.record(o, took)
	attrs := []any{"request_id", id, "bucket", o.bucket, "size_in", o.received, "took_ms", took.Milliseconds()}
	if o.verdict != "" {
		attrs = append(attrs, "decision", o.verdict)
		if o.decision.Category != "" {
			attrs = append(attrs, "category", o.decision.Category, "score", math.Round(o.decision.Score*1e4)/1e4)
		}
	}
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
	reply := uploaded{Bucket: o.bucket, Path: o.path, MIME: o.kind.MIME(), Size: o.stored, Held: o.verdict == string(moderation.Hold)}
	if o.kind.Image() {
		reply.Width, reply.Height = &o.info.Width, &o.info.Height
	}
	writeJSON(w, http.StatusOK, reply)
	s.opts.Log.Info("Upload stored", append(attrs, "code", "ok", "mime", reply.MIME, "size_out", o.stored,
		"metadata_removed", o.info.Removed)...)
}

func (s *Server) upload(w http.ResponseWriter, r *http.Request, began time.Time, requestID string) outcome {
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

	var holdID int64
	if o.kind.Image() {
		holdID, o.err = s.moderate(ctx, r, &o, name, b, user, clean, requestID)
		if o.err != nil {
			return o
		}
	}

	token, err := jwt.Verified(user, s.opts.Secret, s.opts.Now(), tokenTTL)
	if err != nil {
		s.cancelHold(holdID, requestID)
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
	s.cancelHold(holdID, requestID)
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

func (s *Server) moderate(ctx context.Context, r *http.Request, o *outcome, name string, b bucket, user jwt.User,
	clean []byte, requestID string) (int64, *apiError) {
	thresholds, loaded := s.opts.Policy.Current()
	if !loaded {
		return 0, fail(http.StatusServiceUnavailable, codeModerationUnavailable, "image thresholds are not loaded")
	}
	started := time.Now()
	result, err := s.opts.Classifier.Classify(ctx, o.kind.MIME(), clean, requestID)
	s.noteClassifier(err, time.Since(started))
	switch {
	case err == nil:
	case errors.Is(err, moderation.ErrModelMissing) && s.opts.AllowUnclassified:
		o.verdict = verdictUnclassified
		return 0, nil
	case errors.Is(err, moderation.ErrUnreadable):
		return 0, fail(http.StatusUnprocessableEntity, codeInvalidImage, err.Error())
	case r.Context().Err() != nil:
		return 0, fail(499, codeCanceled, "client went away while classifying")
	default:
		return 0, fail(http.StatusServiceUnavailable, codeClassifierUnavailable, err.Error())
	}
	o.decision = moderation.Decide(result.Scores, thresholds)
	o.verdict = string(o.decision.Verdict)
	switch o.decision.Verdict {
	case moderation.Block:
		return 0, fail(http.StatusUnprocessableEntity, codeImageBlocked, "")
	case moderation.Allow:
		return 0, nil
	}
	if !b.holdable {
		o.verdict = string(moderation.Block)
		return 0, fail(http.StatusUnprocessableEntity, codeImageBlocked, "review needed but the bucket is public")
	}
	id, err := s.opts.Holds.RecordHold(ctx, moderation.HoldRequest{
		Bucket: name, Path: o.path, Uploader: user.Subject, Model: result.Model, Scores: result.Scores,
		Category: o.decision.Category, Score: o.decision.Score, Revision: thresholds.Revision,
	})
	var rpcErr *store.RPCError
	switch {
	case err == nil:
		return id, nil
	case errors.As(err, &rpcErr) && rpcErr.Status == http.StatusConflict:
		return 0, fail(http.StatusConflict, storage.CodeExists, "hold: "+rpcErr.Message)
	case errors.As(err, &rpcErr) && rpcErr.Status == http.StatusForbidden:
		return 0, fail(http.StatusForbidden, storage.CodeForbidden, "hold: "+rpcErr.Message)
	}
	return 0, fail(http.StatusServiceUnavailable, codeModerationUnavailable, "record hold: "+err.Error())
}

func (s *Server) cancelHold(id int64, requestID string) {
	if id == 0 {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), holdCancelTimeout)
	defer cancel()
	if err := s.opts.Holds.CancelHold(ctx, id); err != nil {
		s.opts.Log.Warn("Could not cancel the review of an upload that was not stored", "request_id", requestID,
			"review_id", id, "error", err)
	}
}

func (s *Server) noteClassifier(err error, took time.Duration) {
	answered := err == nil || errors.Is(err, moderation.ErrUnreadable)
	problem := ""
	if errors.Is(err, moderation.ErrModelMissing) {
		problem = "Model classifier belum tersedia"
	}
	s.mu.Lock()
	before := s.classifierFails >= failThreshold
	if answered {
		s.classifierFails = 0
		s.classifierProblem = ""
		s.classifierSeconds += took.Seconds()
		s.classifications++
	} else {
		s.classifierFails++
		s.classifierProblem = problem
	}
	after := s.classifierFails >= failThreshold
	fails := s.classifierFails
	s.mu.Unlock()
	if before == after {
		return
	}
	if after {
		s.opts.Log.Warn("Classifier cannot be used; image uploads are refused", "consecutive_failures", fails, "error", err)
	} else {
		s.opts.Log.Info("Classifier works again")
	}
	if s.opts.Notify != nil {
		s.opts.Notify()
	}
}

func (s *Server) Probe(ctx context.Context) {
	s.ProbeStorage(ctx)
	probe, cancel := context.WithTimeout(ctx, probeTimeout)
	err := s.opts.Classifier.Ping(probe)
	cancel()
	if ctx.Err() != nil {
		return
	}
	if err != nil {
		s.opts.Log.Debug("Classifier probe failed", "error", err)
	}
	s.noteClassifierProbe(err)
}

func (s *Server) noteClassifierProbe(err error) {
	if err == nil {
		s.mu.Lock()
		was := s.classifierFails >= failThreshold
		s.classifierFails, s.classifierProblem = 0, ""
		s.mu.Unlock()
		if was {
			s.opts.Log.Info("Classifier works again")
			if s.opts.Notify != nil {
				s.opts.Notify()
			}
		}
		return
	}
	s.noteClassifier(err, 0)
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
	if o.verdict != "" {
		s.verdicts[o.verdict]++
	}
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
	thresholds, loaded := s.opts.Policy.Current()
	r := heartbeat.Report{
		Status: heartbeat.StatusOK,
		Detail: map[string]any{
			"accepted": s.accepted, "rejected": s.rejected, "metadata_removed": s.cleaned,
			"allowed": s.verdicts[string(moderation.Allow)], "held": s.verdicts[string(moderation.Hold)],
			"blocked": s.verdicts[string(moderation.Block)], "unclassified": s.verdicts[verdictUnclassified],
			"classifier_failures": s.classifierFails, "thresholds_revision": nil,
		},
	}
	if loaded {
		r.Detail["thresholds_revision"] = thresholds.Revision
	}
	var problems []string
	if s.failures >= failThreshold {
		problems = append(problems, fmt.Sprintf("Storage tidak bisa dihubungi (%d kali berturut-turut)", s.failures))
	}
	if s.classifierFails >= failThreshold {
		what := s.classifierProblem
		if what == "" {
			what = "Classifier tidak bisa dihubungi"
		}
		problems = append(problems, fmt.Sprintf("%s (%d kali berturut-turut); upload gambar ditolak", what, s.classifierFails))
	}
	if !loaded {
		problems = append(problems, "Ambang moderasi gambar belum termuat; upload gambar ditolak")
	}
	if len(problems) > 0 {
		r.Status = heartbeat.StatusDegraded
		r.Error = strings.Join(problems, "; ")
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
		Verdicts:        maps.Clone(s.verdicts),
		ClassifierFails: s.classifierFails,
		ClassifySeconds: s.classifierSeconds,
		Classifications: s.classifications,
		Revision:        s.revision(),
	}
}

func (s *Server) revision() int64 {
	t, loaded := s.opts.Policy.Current()
	if !loaded {
		return -1
	}
	return t.Revision
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
