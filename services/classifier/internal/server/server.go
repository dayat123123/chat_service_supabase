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
	"sync"
	"time"

	"olt-social/classifier/internal/heartbeat"
	"olt-social/classifier/internal/imageprep"
	"olt-social/classifier/internal/metrics"
	"olt-social/classifier/internal/model"
)

const (
	MaxBytes      = 10 << 20
	failThreshold = 3

	codeOK             = "ok"
	codeNotFound       = "not_found"
	codeModelMissing   = "model_missing"
	codeBusy           = "busy"
	codeEmpty          = "empty_file"
	codeTooLarge       = "file_too_large"
	codeUnsupported    = "unsupported_type"
	codeImageTooLarge  = "image_too_large"
	codeInvalidImage   = "invalid_image"
	codeInferenceError = "inference_failed"
	codeRequestTimeout = "request_timeout"
	codeInvalidRequest = "invalid_request"
	codeCanceled       = "canceled"
)

var messages = map[string]string{
	codeNotFound:       "Not found.",
	codeModelMissing:   "Image classification model is not available.",
	codeBusy:           "Classifier is busy. Try again shortly.",
	codeEmpty:          "Empty file.",
	codeTooLarge:       "Image exceeds 10 MB.",
	codeUnsupported:    "Unsupported image type (JPEG, PNG, WebP, GIF).",
	codeImageTooLarge:  "Image dimensions are too large.",
	codeInvalidImage:   "Image is corrupt or unreadable.",
	codeInferenceError: "Model failed to process the image.",
	codeRequestTimeout: "Image upload took too long.",
	codeInvalidRequest: "Image data could not be read.",
	codeCanceled:       "Request canceled.",
}

type Engine struct {
	Manifest model.Manifest
	Model    model.Model
}

type Options struct {
	Log            *slog.Logger
	Engine         *Engine
	Missing        string
	MaxConcurrent  int
	QueueWait      time.Duration
	RequestTimeout time.Duration
	Notify         func()
}

type Server struct {
	opts  Options
	prep  imageprep.Prep
	slots chan struct{}

	mu         sync.Mutex
	requests   map[string]uint64
	classified uint64
	inferences uint64
	seconds    float64
	failures   int
}

type result struct {
	Model   string             `json:"model"`
	Labels  []string           `json:"labels"`
	Scores  map[string]float64 `json:"scores"`
	Kind    string             `json:"kind"`
	Width   int                `json:"width"`
	Height  int                `json:"height"`
	Frames  int                `json:"frames"`
	Sampled int                `json:"sampled"`
	Views   int                `json:"views"`
}

type failure struct {
	status int
	code   string
	detail string
}

func New(opts Options) *Server {
	s := &Server{opts: opts, slots: make(chan struct{}, opts.MaxConcurrent), requests: map[string]uint64{}}
	if e := opts.Engine; e != nil {
		s.prep = imageprep.Prep{Side: e.Manifest.Side(), CropPct: e.Manifest.CropPct}
		copy(s.prep.Mean[:], e.Manifest.Mean)
		copy(s.prep.Std[:], e.Manifest.Std)
	}
	return s
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	switch {
	case r.Method == http.MethodPost && r.URL.Path == "/classify":
		s.classify(w, r)
	case r.Method == http.MethodGet && r.URL.Path == "/status":
		s.status(w)
	default:
		writeError(w, http.StatusNotFound, codeNotFound)
	}
}

func (s *Server) status(w http.ResponseWriter) {
	e := s.opts.Engine
	if e == nil {
		writeError(w, http.StatusServiceUnavailable, codeModelMissing)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"model": e.Manifest.ID, "labels": e.Manifest.Labels, "sha256": e.Manifest.SHA256})
}

func (s *Server) classify(w http.ResponseWriter, r *http.Request) {
	began := time.Now()
	id := requestID(r.Header.Get("X-Request-Id"))
	w.Header().Set("X-Request-Id", id)
	out, fail := s.run(w, r, began)
	took := time.Since(began)
	code := codeOK
	if fail != nil {
		code = fail.code
	}
	s.mu.Lock()
	s.requests[code]++
	if fail == nil {
		s.classified++
		s.seconds += took.Seconds()
	}
	s.mu.Unlock()
	attrs := []any{"request_id", id, "code", code, "took_ms", took.Milliseconds()}
	if fail != nil {
		attrs = append(attrs, "status", fail.status)
		if fail.detail != "" {
			attrs = append(attrs, "reason", fail.detail)
		}
		if fail.status == http.StatusServiceUnavailable {
			w.Header().Set("Retry-After", "2")
		}
		writeError(w, fail.status, fail.code)
		if fail.status >= 500 {
			s.opts.Log.Warn("Classification failed", attrs...)
		} else {
			s.opts.Log.Info("Classification rejected", attrs...)
		}
		return
	}
	writeJSON(w, http.StatusOK, out)
	s.opts.Log.Info("Image classified", append(attrs, "kind", out.Kind, "frames", out.Frames, "views", out.Views)...)
}

func (s *Server) run(w http.ResponseWriter, r *http.Request, began time.Time) (result, *failure) {
	e := s.opts.Engine
	if e == nil {
		return result{}, &failure{http.StatusServiceUnavailable, codeModelMissing, s.opts.Missing}
	}
	if r.ContentLength > MaxBytes {
		return result{}, &failure{http.StatusRequestEntityTooLarge, codeTooLarge, ""}
	}
	deadline := began.Add(s.opts.RequestTimeout)
	ctx, cancel := context.WithDeadline(r.Context(), deadline)
	defer cancel()
	if !s.acquire(ctx) {
		if r.Context().Err() != nil {
			return result{}, &failure{499, codeCanceled, "client went away while queued"}
		}
		return result{}, &failure{http.StatusServiceUnavailable, codeBusy, "no free slot"}
	}
	defer s.release()
	_ = http.NewResponseController(w).SetReadDeadline(deadline)
	body, err := io.ReadAll(io.LimitReader(r.Body, MaxBytes+1))
	switch {
	case err != nil && isTimeout(err):
		return result{}, &failure{http.StatusRequestTimeout, codeRequestTimeout, err.Error()}
	case err != nil && r.Context().Err() != nil:
		return result{}, &failure{499, codeCanceled, "client went away"}
	case err != nil:
		return result{}, &failure{http.StatusBadRequest, codeInvalidRequest, err.Error()}
	case len(body) == 0:
		return result{}, &failure{http.StatusBadRequest, codeEmpty, ""}
	case len(body) > MaxBytes:
		return result{}, &failure{http.StatusRequestEntityTooLarge, codeTooLarge, ""}
	}
	decoded, err := imageprep.Decode(body)
	switch {
	case errors.Is(err, imageprep.ErrUnsupported):
		return result{}, &failure{http.StatusUnsupportedMediaType, codeUnsupported, ""}
	case errors.Is(err, imageprep.ErrTooLarge):
		return result{}, &failure{http.StatusUnprocessableEntity, codeImageTooLarge, err.Error()}
	case err != nil:
		return result{}, &failure{http.StatusUnprocessableEntity, codeInvalidImage, err.Error()}
	}
	scores := map[string]float64{}
	views := 0
	for _, frame := range decoded.Frames {
		for _, view := range s.prep.Tensors(frame) {
			raw, err := e.Model.Infer(view)
			s.noteInference(err == nil)
			if err != nil {
				return result{}, &failure{http.StatusInternalServerError, codeInferenceError, err.Error()}
			}
			model.Merge(scores, e.Manifest.Labels, model.Probabilities(raw, e.Manifest.Activation))
			views++
		}
		if ctx.Err() != nil {
			return result{}, &failure{http.StatusServiceUnavailable, codeBusy, "deadline reached while classifying"}
		}
	}
	for label, v := range scores {
		scores[label] = math.Round(v*1e4) / 1e4
	}
	return result{
		Model: e.Manifest.ID, Labels: e.Manifest.Labels, Scores: scores, Kind: string(decoded.Kind),
		Width: decoded.Width, Height: decoded.Height, Frames: decoded.TotalFrames, Sampled: len(decoded.Frames), Views: views,
	}, nil
}

func (s *Server) noteInference(ok bool) {
	s.mu.Lock()
	before := s.failures >= failThreshold
	s.inferences++
	if ok {
		s.failures = 0
	} else {
		s.failures++
	}
	after := s.failures >= failThreshold
	s.mu.Unlock()
	if before != after && s.opts.Notify != nil {
		s.opts.Notify()
	}
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

func (s *Server) Ready() bool {
	return s.opts.Engine != nil
}

func (s *Server) Report() heartbeat.Report {
	s.mu.Lock()
	defer s.mu.Unlock()
	detail := map[string]any{
		"model": nil, "classified": s.classified, "rejected": s.rejected(), "busy": s.requests[codeBusy],
		"failed": s.requests[codeInferenceError], "avg_ms": 0,
	}
	if s.classified > 0 {
		detail["avg_ms"] = math.Round(s.seconds / float64(s.classified) * 1000)
	}
	e := s.opts.Engine
	if e == nil {
		return heartbeat.Report{
			Status: heartbeat.StatusError,
			Error:  "Model klasifikasi gambar tidak tersedia: " + s.opts.Missing,
			Detail: detail,
		}
	}
	detail["model"] = e.Manifest.ID
	detail["model_sha256"] = e.Manifest.SHA256[:12]
	detail["labels"] = e.Manifest.Labels
	r := heartbeat.Report{Status: heartbeat.StatusOK, Detail: detail}
	if s.failures >= failThreshold {
		r.Status = heartbeat.StatusDegraded
		r.Error = fmt.Sprintf("Model gagal memproses gambar (%d kali berturut-turut)", s.failures)
	}
	return r
}

func (s *Server) rejected() uint64 {
	var n uint64
	for code, count := range s.requests {
		if code != codeOK && code != codeBusy && code != codeInferenceError && code != codeModelMissing {
			n += count
		}
	}
	return n
}

func (s *Server) Metrics() metrics.Snapshot {
	s.mu.Lock()
	defer s.mu.Unlock()
	return metrics.Snapshot{
		Requests:            maps.Clone(s.requests),
		Inferences:          s.inferences,
		DurationSeconds:     s.seconds,
		Classified:          s.classified,
		Inflight:            len(s.slots),
		Capacity:            cap(s.slots),
		ModelLoaded:         s.opts.Engine != nil,
		ConsecutiveFailures: s.failures,
	}
}

func isTimeout(err error) bool {
	var netErr net.Error
	return errors.Is(err, os.ErrDeadlineExceeded) || (errors.As(err, &netErr) && netErr.Timeout())
}

func requestID(given string) string {
	if len(given) >= 1 && len(given) <= 64 && safe(given) {
		return given
	}
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func safe(s string) bool {
	for i := 0; i < len(s); i++ {
		c := s[i]
		if (c < 'a' || c > 'z') && (c < 'A' || c > 'Z') && (c < '0' || c > '9') && c != '.' && c != '_' && c != '-' {
			return false
		}
	}
	return true
}

func writeError(w http.ResponseWriter, status int, code string) {
	writeJSON(w, status, map[string]string{"code": code, "message": messages[code]})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	h := w.Header()
	h.Set("Content-Type", "application/json; charset=utf-8")
	h.Set("Cache-Control", "no-store")
	h.Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
