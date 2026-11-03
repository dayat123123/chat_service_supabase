package server

import (
	"bytes"
	"encoding/json"
	"errors"
	"image"
	"image/color"
	"image/gif"
	"image/png"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"olt-social/classifier/internal/heartbeat"
	"olt-social/classifier/internal/model"
)

var labels = []string{"drawings", "hentai", "neutral", "porn", "sexy"}

type fakeModel struct {
	mu      sync.Mutex
	calls   int
	infer   func(input []float32) ([]float32, error)
	entered chan struct{}
	release chan struct{}
}

func (f *fakeModel) Infer(input []float32) ([]float32, error) {
	f.mu.Lock()
	f.calls++
	f.mu.Unlock()
	if f.entered != nil {
		f.entered <- struct{}{}
		<-f.release
	}
	if f.infer != nil {
		return f.infer(input)
	}
	return []float32{0, 0, 5, 0, 0}, nil
}

func (f *fakeModel) Close() error { return nil }

func (f *fakeModel) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.calls
}

type syncBuffer struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (b *syncBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.Write(p)
}

func (b *syncBuffer) String() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.String()
}

func manifest() model.Manifest {
	return model.Manifest{
		ID: "nsfw-test@1", File: "model.onnx", SHA256: strings.Repeat("ab", 32), Input: "input", Output: "output",
		Shape: []int64{3, 16, 16}, CropPct: 0.875, Mean: []float32{0, 0, 0}, Std: []float32{1, 1, 1},
		Activation: "softmax", Labels: labels,
	}
}

func newServer(t *testing.T, m model.Model, tweak func(*Options)) (*Server, *syncBuffer) {
	t.Helper()
	logs := &syncBuffer{}
	opts := Options{
		Log:            slog.New(slog.NewJSONHandler(logs, nil)),
		Engine:         &Engine{Manifest: manifest(), Model: m},
		MaxConcurrent:  2,
		QueueWait:      50 * time.Millisecond,
		RequestTimeout: 5 * time.Second,
	}
	if tweak != nil {
		tweak(&opts)
	}
	return New(opts), logs
}

func pngOf(t *testing.T, w, h int, c color.Color) []byte {
	t.Helper()
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.Set(x, y, c)
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func post(s *Server, body []byte, headers map[string]string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodPost, "/classify", bytes.NewReader(body))
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, req)
	return rec
}

func decode(t *testing.T, rec *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var out map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatalf("body %q: %v", rec.Body.String(), err)
	}
	return out
}

func expectError(t *testing.T, rec *httptest.ResponseRecorder, status int, code string) {
	t.Helper()
	if rec.Code != status {
		t.Fatalf("status = %d, want %d: %s", rec.Code, status, rec.Body.String())
	}
	body := decode(t, rec)
	if body["code"] != code || body["message"] == "" {
		t.Fatalf("body = %v", body)
	}
}

func redIsExplicit(input []float32) ([]float32, error) {
	plane := len(input) / 3
	if input[0] > 0.9 && input[plane] < 0.1 {
		return []float32{0, 0, 0, 6, 0}, nil
	}
	return []float32{0, 0, 6, 0, 0}, nil
}

func TestClassifyReturnsTheHighestScorePerLabel(t *testing.T) {
	fake := &fakeModel{infer: redIsExplicit}
	s, logs := newServer(t, fake, nil)
	img := image.NewNRGBA(image.Rect(0, 0, 40, 20))
	for y := 0; y < 20; y++ {
		for x := 0; x < 40; x++ {
			c := color.NRGBA{R: 255, G: 255, B: 255, A: 255}
			if x < 4 {
				c = color.NRGBA{R: 255, A: 255}
			}
			img.Set(x, y, c)
		}
	}
	var buf bytes.Buffer
	_ = png.Encode(&buf, img)
	rec := post(s, buf.Bytes(), map[string]string{"X-Request-Id": "req-1"})
	if rec.Code != http.StatusOK || rec.Header().Get("X-Request-Id") != "req-1" {
		t.Fatalf("status = %d %s", rec.Code, rec.Body.String())
	}
	body := decode(t, rec)
	scores := body["scores"].(map[string]any)
	if body["model"] != "nsfw-test@1" || body["views"] != float64(2) || body["frames"] != float64(1) ||
		body["width"] != float64(40) || body["height"] != float64(20) || body["kind"] != "png" ||
		scores["porn"].(float64) < 0.99 || scores["neutral"].(float64) < 0.99 || len(scores) != 5 {
		t.Fatalf("body = %v", body)
	}
	if fake.count() != 2 {
		t.Fatalf("calls = %d", fake.count())
	}
	if strings.Contains(logs.String(), "scores") || !strings.Contains(logs.String(), `"code":"ok"`) {
		t.Fatalf("logs = %s", logs.String())
	}
	r := s.Report()
	if r.Status != heartbeat.StatusOK || r.Detail["classified"] != uint64(1) || r.Detail["model"] != "nsfw-test@1" ||
		r.Detail["model_sha256"] != "abababababab" {
		t.Fatalf("report = %+v", r)
	}
}

func TestClassifySamplesAnimatedGIFFrames(t *testing.T) {
	fake := &fakeModel{infer: redIsExplicit}
	s, _ := newServer(t, fake, nil)
	palette := color.Palette{color.White, color.RGBA{R: 255, A: 255}}
	var frames []*image.Paletted
	for i := 0; i < 7; i++ {
		f := image.NewPaletted(image.Rect(0, 0, 16, 16), palette)
		if i == 6 {
			for j := range f.Pix {
				f.Pix[j] = 1
			}
		}
		frames = append(frames, f)
	}
	var buf bytes.Buffer
	if err := gif.EncodeAll(&buf, &gif.GIF{Image: frames, Delay: make([]int, 7)}); err != nil {
		t.Fatal(err)
	}
	rec := post(s, buf.Bytes(), nil)
	body := decode(t, rec)
	if rec.Code != http.StatusOK || body["frames"] != float64(7) || body["sampled"] != float64(4) ||
		body["scores"].(map[string]any)["porn"].(float64) < 0.99 {
		t.Fatalf("body = %v", body)
	}
}

func TestClassifyRejects(t *testing.T) {
	cases := map[string]struct {
		body   []byte
		status int
		code   string
	}{
		"empty":      {nil, 400, codeEmpty},
		"text":       {[]byte("hello"), 415, codeUnsupported},
		"pdf":        {[]byte("%PDF-1.7\n"), 415, codeUnsupported},
		"broken png": {pngOf(t, 4, 4, color.White)[:40], 422, codeInvalidImage},
		"too wide":   {pngOf(t, 10001, 1, color.White), 422, codeImageTooLarge},
		"too big":    {append(pngOf(t, 2, 2, color.White), make([]byte, MaxBytes)...), 413, codeTooLarge},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			fake := &fakeModel{}
			s, _ := newServer(t, fake, nil)
			expectError(t, post(s, tc.body, nil), tc.status, tc.code)
			if fake.count() != 0 {
				t.Fatal("model must not run")
			}
			if r := s.Report(); r.Detail["rejected"] != uint64(1) || r.Status != heartbeat.StatusOK {
				t.Fatalf("report = %+v", r)
			}
		})
	}
}

func TestBodyLimitWithoutContentLength(t *testing.T) {
	s, _ := newServer(t, &fakeModel{}, nil)
	req := httptest.NewRequest(http.MethodPost, "/classify", io.MultiReader(bytes.NewReader(pngOf(t, 2, 2, color.White)),
		bytes.NewReader(make([]byte, MaxBytes))))
	req.ContentLength = -1
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, req)
	expectError(t, rec, http.StatusRequestEntityTooLarge, codeTooLarge)
}

func TestModelMissingFailsClosed(t *testing.T) {
	s, _ := newServer(t, nil, func(o *Options) {
		o.Engine = nil
		o.Missing = "manifest.json not found"
	})
	rec := post(s, pngOf(t, 2, 2, color.White), nil)
	expectError(t, rec, http.StatusServiceUnavailable, codeModelMissing)
	if rec.Header().Get("Retry-After") == "" {
		t.Fatal("missing Retry-After")
	}
	status := httptest.NewRecorder()
	s.ServeHTTP(status, httptest.NewRequest(http.MethodGet, "/status", nil))
	expectError(t, status, http.StatusServiceUnavailable, codeModelMissing)
	r := s.Report()
	if r.Status != heartbeat.StatusError || !strings.Contains(r.Error, "manifest.json not found") || r.Detail["model"] != nil || s.Ready() {
		t.Fatalf("report = %+v", r)
	}
	if m := s.Metrics(); m.ModelLoaded || m.Requests[codeModelMissing] != 1 {
		t.Fatalf("metrics = %+v", m)
	}
}

func TestStatusDescribesTheModel(t *testing.T) {
	s, _ := newServer(t, &fakeModel{}, nil)
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/status", nil))
	body := decode(t, rec)
	if rec.Code != http.StatusOK || body["model"] != "nsfw-test@1" || len(body["labels"].([]any)) != 5 || !s.Ready() {
		t.Fatalf("status = %d %v", rec.Code, body)
	}
	for _, r := range []struct{ method, path string }{{"GET", "/classify"}, {"POST", "/status"}, {"GET", "/"}} {
		rec := httptest.NewRecorder()
		s.ServeHTTP(rec, httptest.NewRequest(r.method, r.path, nil))
		expectError(t, rec, http.StatusNotFound, codeNotFound)
	}
}

func TestInferenceFailuresDegradeTheHeartbeat(t *testing.T) {
	fake := &fakeModel{infer: func([]float32) ([]float32, error) { return nil, errors.New("ort exploded") }}
	var notified atomic.Int32
	s, _ := newServer(t, fake, func(o *Options) { o.Notify = func() { notified.Add(1) } })
	for i := 0; i < 3; i++ {
		expectError(t, post(s, pngOf(t, 4, 4, color.White), nil), http.StatusInternalServerError, codeInferenceError)
	}
	r := s.Report()
	if r.Status != heartbeat.StatusDegraded || !strings.Contains(r.Error, "3 kali") || notified.Load() != 1 ||
		r.Detail["failed"] != uint64(3) {
		t.Fatalf("report = %+v notified = %d", r, notified.Load())
	}
	fake.mu.Lock()
	fake.infer = nil
	fake.mu.Unlock()
	if rec := post(s, pngOf(t, 4, 4, color.White), nil); rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	if r := s.Report(); r.Status != heartbeat.StatusOK || notified.Load() != 2 {
		t.Fatalf("report = %+v", r)
	}
}

func TestBusyWhenAllSlotsAreTaken(t *testing.T) {
	fake := &fakeModel{entered: make(chan struct{}, 4), release: make(chan struct{})}
	s, _ := newServer(t, fake, func(o *Options) { o.MaxConcurrent = 1 })
	square := pngOf(t, 16, 16, color.White)
	done := make(chan int)
	go func() { done <- post(s, square, nil).Code }()
	<-fake.entered
	if m := s.Metrics(); m.Inflight != 1 || m.Capacity != 1 {
		t.Fatalf("metrics = %+v", m)
	}
	expectError(t, post(s, square, nil), http.StatusServiceUnavailable, codeBusy)
	close(fake.release)
	if code := <-done; code != http.StatusOK {
		t.Fatalf("first = %d", code)
	}
	if m := s.Metrics(); m.Inflight != 0 || m.Requests[codeBusy] != 1 || m.Requests[codeOK] != 1 {
		t.Fatalf("metrics = %+v", m)
	}
}

func TestSlowUploadTimesOut(t *testing.T) {
	s, _ := newServer(t, &fakeModel{}, func(o *Options) { o.RequestTimeout = 300 * time.Millisecond })
	srv := httptest.NewServer(s)
	defer srv.Close()
	pr, pw := io.Pipe()
	defer pw.Close()
	go func() { _, _ = pw.Write(pngOf(t, 2, 2, color.White)[:10]) }()
	resp, err := srv.Client().Post(srv.URL+"/classify", "image/png", pr)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var body map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&body)
	if resp.StatusCode != http.StatusRequestTimeout || body["code"] != codeRequestTimeout {
		t.Fatalf("status = %d body = %v", resp.StatusCode, body)
	}
}

func TestRequestIDIsGeneratedWhenUnsafe(t *testing.T) {
	s, _ := newServer(t, &fakeModel{}, nil)
	for _, given := range []string{"", "has space", strings.Repeat("a", 65)} {
		rec := post(s, nil, map[string]string{"X-Request-Id": given})
		if id := rec.Header().Get("X-Request-Id"); id == given || len(id) != 16 {
			t.Fatalf("given %q got %q", given, id)
		}
	}
}
