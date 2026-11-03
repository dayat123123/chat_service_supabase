package server

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"testing"

	"olt-social/media/internal/heartbeat"
	"olt-social/media/internal/moderation"
	"olt-social/media/internal/store"
)

type fakeClassifier struct {
	mu      sync.Mutex
	calls   []string
	scores  map[string]float64
	err     error
	pingErr error
}

func (f *fakeClassifier) Classify(_ context.Context, mime string, _ []byte, requestID string) (moderation.Result, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, mime+" "+requestID)
	if f.err != nil {
		return moderation.Result{}, f.err
	}
	scores := f.scores
	if scores == nil {
		scores = map[string]float64{"neutral": 0.97, "porn": 0.01, "sexy": 0.02}
	}
	return moderation.Result{Model: "nsfw-test@1", Scores: scores}, nil
}

func (f *fakeClassifier) Ping(context.Context) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.pingErr
}

func (f *fakeClassifier) set(scores map[string]float64, err error) {
	f.mu.Lock()
	f.scores, f.err = scores, err
	f.mu.Unlock()
}

func (f *fakeClassifier) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.calls)
}

type fakePolicy struct {
	mu     sync.Mutex
	loaded bool
	t      moderation.Thresholds
}

func (f *fakePolicy) Current() (moderation.Thresholds, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.t, f.loaded
}

type fakeHolds struct {
	mu        sync.Mutex
	holds     []moderation.HoldRequest
	cancelled []int64
	err       error
}

func (f *fakeHolds) RecordHold(_ context.Context, h moderation.HoldRequest) (int64, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return 0, f.err
	}
	f.holds = append(f.holds, h)
	return int64(40 + len(f.holds)), nil
}

func (f *fakeHolds) CancelHold(_ context.Context, id int64) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.cancelled = append(f.cancelled, id)
	return nil
}

func limit(v float64) *float64 {
	return &v
}

func defaultThresholds() moderation.Thresholds {
	return moderation.Thresholds{Revision: 7, Limits: map[string]moderation.Limit{
		"porn": {Hold: limit(0.45), Block: limit(0.9)},
		"sexy": {Hold: limit(0.75)},
	}}
}

func TestEveryImageIsClassifiedBeforeItIsStored(t *testing.T) {
	h := newHarness(t, nil)
	rec := h.post(t, "/object/attachments/posts/"+sub+"/a.png", token(t, nil, secret), pngBytes(t, 2, 2),
		map[string]string{"X-Request-Id": "req-9"})
	if rec.Code != http.StatusOK || decode(t, rec)["held"] != nil {
		t.Fatalf("status = %d %s", rec.Code, rec.Body.String())
	}
	if h.classifier.count() != 1 || h.classifier.calls[0] != "image/png req-9" || h.storage.count() != 1 {
		t.Fatalf("classifier calls = %v storage = %d", h.classifier.calls, h.storage.count())
	}
	if !strings.Contains(h.logs.String(), `"decision":"allow"`) {
		t.Fatalf("logs = %s", h.logs.String())
	}
	pdf := h.post(t, "/object/cs-documents/"+sub+"/surat.pdf", token(t, nil, secret), []byte(plainPDF), nil)
	if pdf.Code != http.StatusOK || h.classifier.count() != 1 {
		t.Fatal("PDF documents are not images and are not classified")
	}
}

func TestBlockedImagesAreNotStored(t *testing.T) {
	h := newHarness(t, nil)
	h.classifier.set(map[string]float64{"porn": 0.95, "neutral": 0.05}, nil)
	rec := h.post(t, "/object/attachments/posts/"+sub+"/a.jpg", token(t, nil, secret), phoneJPEG(t), nil)
	expectError(t, rec, http.StatusUnprocessableEntity, codeImageBlocked)
	if h.storage.count() != 0 || len(h.holds.holds) != 0 {
		t.Fatal("blocked image reached storage")
	}
	r := h.srv.Report()
	if r.Detail["blocked"] != uint64(1) || r.Detail["rejected"] != uint64(1) {
		t.Fatalf("report = %+v", r)
	}
	if logs := h.logs.String(); !strings.Contains(logs, `"decision":"block"`) || !strings.Contains(logs, `"category":"porn"`) {
		t.Fatalf("logs = %s", logs)
	}
}

func TestBorderlineImagesAreHeldForReview(t *testing.T) {
	h := newHarness(t, nil)
	h.classifier.set(map[string]float64{"porn": 0.5, "sexy": 0.8, "neutral": 0.1}, nil)
	rec := h.post(t, "/object/attachments/posts/"+sub+"/a.png", token(t, nil, secret), pngBytes(t, 2, 2), nil)
	if rec.Code != http.StatusOK || decode(t, rec)["held"] != true {
		t.Fatalf("status = %d %s", rec.Code, rec.Body.String())
	}
	if h.storage.count() != 1 || len(h.holds.holds) != 1 {
		t.Fatalf("storage = %d holds = %d", h.storage.count(), len(h.holds.holds))
	}
	got := h.holds.holds[0]
	if got.Bucket != "attachments" || got.Path != "posts/"+sub+"/a.png" || got.Uploader != sub || got.Category != "sexy" ||
		got.Score != 0.8 || got.Revision != 7 || got.Model != "nsfw-test@1" || got.Scores["porn"] != 0.5 {
		t.Fatalf("hold = %+v", got)
	}
	if r := h.srv.Report(); r.Detail["held"] != uint64(1) || r.Detail["accepted"] != uint64(1) ||
		r.Detail["thresholds_revision"] != int64(7) {
		t.Fatalf("report = %+v", r)
	}
	if strings.Contains(h.logs.String(), sub) {
		t.Fatal("logs leak the uploader")
	}
}

func TestHeldUploadThatStorageRefusesIsCancelled(t *testing.T) {
	h := newHarness(t, nil)
	h.classifier.set(map[string]float64{"porn": 0.6}, nil)
	h.storage.setReply(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(400)
		_, _ = w.Write([]byte(`{"statusCode":"409","error":"Duplicate","message":"The resource already exists"}`))
	})
	rec := h.post(t, "/object/attachments/posts/"+sub+"/a.png", token(t, nil, secret), pngBytes(t, 2, 2), nil)
	expectError(t, rec, http.StatusConflict, "already_exists")
	if len(h.holds.cancelled) != 1 || h.holds.cancelled[0] != 41 {
		t.Fatalf("cancelled = %v", h.holds.cancelled)
	}
}

func TestPublicAvatarsCannotBeHeld(t *testing.T) {
	h := newHarness(t, nil)
	h.classifier.set(map[string]float64{"sexy": 0.8}, nil)
	rec := h.post(t, "/object/avatars/"+sub+"/me.png", token(t, nil, secret), pngBytes(t, 2, 2), nil)
	expectError(t, rec, http.StatusUnprocessableEntity, codeImageBlocked)
	if h.storage.count() != 0 || len(h.holds.holds) != 0 {
		t.Fatal("avatar under review must not be stored in a public bucket")
	}
}

func TestHoldErrorsFailClosed(t *testing.T) {
	cases := map[string]struct {
		err    error
		status int
		code   string
	}{
		"exists":    {fmt.Errorf("rpc media_hold: %w", &store.RPCError{Status: 409, Code: "PT409", Message: "already_exists"}), 409, "already_exists"},
		"not owner": {fmt.Errorf("rpc media_hold: %w", &store.RPCError{Status: 403, Code: "PT403", Message: "not_owner"}), 403, "upload_forbidden"},
		"database":  {errors.New("rpc media_hold: connection refused"), 503, codeModerationUnavailable},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			h := newHarness(t, nil)
			h.classifier.set(map[string]float64{"porn": 0.6}, nil)
			h.holds.err = tc.err
			expectError(t, h.post(t, "/object/attachments/posts/"+sub+"/a.png", token(t, nil, secret), pngBytes(t, 2, 2), nil),
				tc.status, tc.code)
			if h.storage.count() != 0 {
				t.Fatal("nothing may be stored without a recorded hold")
			}
		})
	}
}

func TestClassifierProblemsFailClosed(t *testing.T) {
	cases := map[string]struct {
		err      error
		allow    bool
		status   int
		code     string
		degraded bool
	}{
		"unreachable":           {fmt.Errorf("%w: connection refused", moderation.ErrUnavailable), false, 503, codeClassifierUnavailable, true},
		"model missing":         {moderation.ErrModelMissing, false, 503, codeClassifierUnavailable, true},
		"model missing allowed": {moderation.ErrModelMissing, true, 200, "", true},
		"unreadable":            {fmt.Errorf("%w: invalid_image", moderation.ErrUnreadable), false, 422, codeInvalidImage, false},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			h := newHarness(t, func(o *Options) { o.AllowUnclassified = tc.allow })
			h.classifier.set(nil, tc.err)
			for i := 0; i < 3; i++ {
				rec := h.post(t, "/object/attachments/posts/"+sub+"/a.png", token(t, nil, secret), pngBytes(t, 2, 2), nil)
				if tc.status == http.StatusOK {
					if rec.Code != http.StatusOK {
						t.Fatalf("status = %d", rec.Code)
					}
					continue
				}
				expectError(t, rec, tc.status, tc.code)
				if tc.status == http.StatusServiceUnavailable && rec.Header().Get("Retry-After") == "" {
					t.Fatal("missing Retry-After")
				}
			}
			r := h.srv.Report()
			if (r.Status == heartbeat.StatusDegraded) != tc.degraded {
				t.Fatalf("report = %+v", r)
			}
			if tc.allow && (r.Detail["unclassified"] != uint64(3) || h.storage.count() != 3) {
				t.Fatalf("report = %+v storage = %d", r, h.storage.count())
			}
			if !tc.allow && tc.status != http.StatusOK && h.storage.count() != 0 {
				t.Fatal("storage must not be called")
			}
		})
	}
}

func TestClassifierProbeRestoresTheHeartbeat(t *testing.T) {
	h := newHarness(t, nil)
	h.classifier.set(nil, moderation.ErrUnavailable)
	h.classifier.pingErr = moderation.ErrUnavailable
	for i := 0; i < 3; i++ {
		h.srv.Probe(context.Background())
	}
	r := h.srv.Report()
	if r.Status != heartbeat.StatusDegraded || !strings.Contains(r.Error, "Classifier tidak bisa dihubungi (3 kali") {
		t.Fatalf("report = %+v", r)
	}
	h.classifier.mu.Lock()
	h.classifier.pingErr = moderation.ErrModelMissing
	h.classifier.mu.Unlock()
	h.srv.Probe(context.Background())
	if r := h.srv.Report(); !strings.Contains(r.Error, "Model classifier belum tersedia (4 kali") {
		t.Fatalf("report = %+v", r)
	}
	h.classifier.mu.Lock()
	h.classifier.pingErr = nil
	h.classifier.mu.Unlock()
	h.srv.Probe(context.Background())
	if r := h.srv.Report(); r.Status != heartbeat.StatusOK || r.Detail["classifier_failures"] != 0 {
		t.Fatalf("report = %+v", r)
	}
	if h.notify.Load() != 2 {
		t.Fatalf("notify = %d", h.notify.Load())
	}
}

func TestImagesWaitForThresholds(t *testing.T) {
	h := newHarness(t, nil)
	h.policy.mu.Lock()
	h.policy.loaded = false
	h.policy.mu.Unlock()
	expectError(t, h.post(t, "/object/attachments/posts/"+sub+"/a.png", token(t, nil, secret), pngBytes(t, 2, 2), nil),
		http.StatusServiceUnavailable, codeModerationUnavailable)
	if h.classifier.count() != 0 || h.storage.count() != 0 {
		t.Fatal("nothing may happen without thresholds")
	}
	r := h.srv.Report()
	if r.Status != heartbeat.StatusDegraded || !strings.Contains(r.Error, "Ambang moderasi") || r.Detail["thresholds_revision"] != nil {
		t.Fatalf("report = %+v", r)
	}
	if m := h.srv.Metrics(); m.Revision != -1 {
		t.Fatalf("revision = %d", m.Revision)
	}
}

func TestModerationMetrics(t *testing.T) {
	h := newHarness(t, nil)
	tok := token(t, nil, secret)
	h.post(t, "/object/attachments/posts/"+sub+"/a.png", tok, pngBytes(t, 2, 2), nil)
	h.classifier.set(map[string]float64{"porn": 0.99}, nil)
	h.post(t, "/object/attachments/posts/"+sub+"/b.png", tok, pngBytes(t, 2, 2), nil)
	m := h.srv.Metrics()
	if m.Verdicts["allow"] != 1 || m.Verdicts["block"] != 1 || m.Classifications != 2 || m.Revision != 7 {
		t.Fatalf("metrics = %+v", m)
	}
}
