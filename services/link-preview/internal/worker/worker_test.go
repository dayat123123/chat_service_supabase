package worker

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"hash/crc32"
	"image"
	"image/color"
	"image/gif"
	"image/png"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"net/url"
	"reflect"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/link-preview/internal/heartbeat"
	"olt-social/link-preview/internal/moderation"
	"olt-social/link-preview/internal/safehttp"
	"olt-social/link-preview/internal/store"
)

const hash = "0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f"

type upload struct {
	path, mime string
	body       []byte
}

type fakeUploader struct {
	mu      sync.Mutex
	uploads []upload
	fail    error
}

func (f *fakeUploader) Upload(_ context.Context, path, contentType string, body []byte) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.fail != nil {
		return f.fail
	}
	f.uploads = append(f.uploads, upload{path, contentType, append([]byte(nil), body...)})
	return nil
}

type fakeClassifier struct {
	mu    sync.Mutex
	calls int
	mimes []string
	reply func(body []byte) (moderation.Result, error)
}

func (f *fakeClassifier) Classify(_ context.Context, mime string, body []byte, _ string) (moderation.Result, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls++
	f.mimes = append(f.mimes, mime)
	if f.reply == nil {
		return moderation.Result{Model: "fake@1", Scores: map[string]float64{"neutral": 0.98, "porn": 0.01}}, nil
	}
	return f.reply(body)
}

func (f *fakeClassifier) Ping(context.Context) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.reply == nil {
		return nil
	}
	_, err := f.reply(nil)
	return err
}

func (f *fakeClassifier) set(reply func(body []byte) (moderation.Result, error)) {
	f.mu.Lock()
	f.reply = reply
	f.mu.Unlock()
}

func (f *fakeClassifier) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.calls
}

func scores(model string, s map[string]float64) func([]byte) (moderation.Result, error) {
	return func([]byte) (moderation.Result, error) { return moderation.Result{Model: model, Scores: s}, nil }
}

func failing(err error) func([]byte) (moderation.Result, error) {
	return func([]byte) (moderation.Result, error) { return moderation.Result{}, err }
}

type fakePolicy struct {
	mu         sync.Mutex
	thresholds moderation.Thresholds
	loaded     bool
}

func (f *fakePolicy) Current() (moderation.Thresholds, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.thresholds, f.loaded
}

func limit(v float64) *float64 {
	return &v
}

func mediaThresholds(revision int64) moderation.Thresholds {
	return moderation.Thresholds{Revision: revision, Limits: map[string]moderation.Limit{
		"porn":   {Hold: limit(0.5), Block: limit(0.9)},
		"hentai": {Hold: limit(0.6), Block: limit(0.95)},
		"sexy":   {Hold: limit(0.85)},
	}}
}

type fakeScores struct {
	mu      sync.Mutex
	entries map[string]moderation.Result
	err     error
	lookups int
}

func (f *fakeScores) CachedScores(_ context.Context, sha string) (moderation.Result, bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.lookups++
	if f.err != nil {
		return moderation.Result{}, false, f.err
	}
	r, ok := f.entries[sha]
	return r, ok, nil
}

type fakeResolver map[string][]netip.Addr

func (f fakeResolver) LookupNetIP(_ context.Context, _, host string) ([]netip.Addr, error) {
	if a, ok := f[host]; ok {
		return a, nil
	}
	return nil, &net.DNSError{Err: "no such host", Name: host, IsNotFound: true}
}

func pngWithText(t *testing.T, w, h int, secret string) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.Set(x, y, color.RGBA{uint8(x), uint8(y), 99, 255})
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatal(err)
	}
	data := buf.Bytes()
	payload := append([]byte("Comment\x00"), secret...)
	chunk := binary.BigEndian.AppendUint32(nil, uint32(len(payload)))
	chunk = append(chunk, "tEXt"...)
	chunk = append(chunk, payload...)
	chunk = binary.BigEndian.AppendUint32(chunk, crc32.ChecksumIEEE(append([]byte("tEXt"), payload...)))
	at := 8 + 25
	return append(append(append([]byte(nil), data[:at]...), chunk...), data[at:]...)
}

func tinyGIF(t *testing.T) []byte {
	t.Helper()
	var buf bytes.Buffer
	img := image.NewPaletted(image.Rect(0, 0, 1, 1), color.Palette{color.Black, color.White})
	if err := gif.Encode(&buf, img, nil); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

type env struct {
	worker     *Worker
	uploader   *fakeUploader
	classifier *fakeClassifier
	policy     *fakePolicy
	base       string
	port       string
	logs       *bytes.Buffer
}

func newEnv(t *testing.T, handler http.Handler) *env {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	u, _ := url.Parse(srv.URL)
	port, _ := strconv.Atoi(u.Port())
	client := safehttp.New(safehttp.Options{
		Policy:   safehttp.Policy{Ports: []uint16{uint16(port), 80}, Allow: []netip.Prefix{netip.MustParsePrefix("127.0.0.1/32")}},
		Resolver: fakeResolver{"site.olt-test.com": {netip.MustParseAddr("127.0.0.1")}, "cdn.olt-test.com": {netip.MustParseAddr("127.0.0.1")}},
		Timeout:  500 * time.Millisecond,
	})
	uploader := &fakeUploader{}
	classifier := &fakeClassifier{}
	policy := &fakePolicy{thresholds: mediaThresholds(1), loaded: true}
	logs := &bytes.Buffer{}
	w := New(Options{
		Fetcher:        client,
		Uploader:       uploader,
		Classifier:     classifier,
		Policy:         policy,
		Log:            slog.New(slog.NewJSONHandler(logs, &slog.HandlerOptions{Level: slog.LevelDebug})),
		Instance:       "lp-test",
		BatchSize:      4,
		Concurrency:    2,
		Lease:          2 * time.Minute,
		PollInterval:   10 * time.Millisecond,
		FetchTimeout:   500 * time.Millisecond,
		RequestTimeout: time.Second,
		MaxHTMLBytes:   1 << 20,
		MaxImageBytes:  5 << 20,
		Nonce:          func() string { return "0123456789abcdef" },
	})
	return &env{worker: w, uploader: uploader, classifier: classifier, policy: policy, base: "http://site.olt-test.com:" + u.Port(), port: u.Port(), logs: logs}
}

func site(t *testing.T, imageBody []byte) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/artikel", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprintf(w, `<html><head><title>Cadangan</title>
<meta property="og:title" content="BBCA cetak rekor">
<meta property="og:description" content="Laba naik 12%%">
<meta property="og:site_name" content="Kabar Pasar">
<meta property="og:image" content="%s"></head><body></body></html>`, r.URL.Query().Get("img"))
	})
	mux.HandleFunc("/img.png", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "image/png")
		_, _ = w.Write(imageBody)
	})
	mux.HandleFunc("/tiny.gif", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "image/gif")
		_, _ = w.Write(tinyGIF(t))
	})
	mux.HandleFunc("/logo.svg", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "image/svg+xml")
		_, _ = w.Write([]byte(`<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>`))
	})
	mux.HandleFunc("/laporan.pdf", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/pdf")
		_, _ = w.Write([]byte("%PDF-1.7"))
	})
	mux.HandleFunc("/to-metadata", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "http://169.254.169.254/latest/meta-data/", http.StatusFound)
	})
	mux.HandleFunc("/status/", func(w http.ResponseWriter, r *http.Request) {
		code, _ := strconv.Atoi(strings.TrimPrefix(r.URL.Path, "/status/"))
		w.WriteHeader(code)
	})
	mux.HandleFunc("/slow", func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-time.After(3 * time.Second):
		case <-r.Context().Done():
		}
	})
	return mux
}

func TestProcessBuildsPreviewWithSanitizedImage(t *testing.T) {
	img := pngWithText(t, 120, 63, "GPS-SECRET")
	e := newEnv(t, site(t, img))
	r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=/img.png"})
	want := store.Result{URLHash: hash, Status: store.StatusOK, FinalURL: e.base + "/artikel?img=/img.png",
		Title: "BBCA cetak rekor", Description: "Laba naik 12%", SiteName: "Kabar Pasar",
		ImagePath: hash + "/0123456789abcdef/preview.png", ImageWidth: 120, ImageHeight: 63}
	check := r.ImageCheck
	r.ImageCheck = store.ImageCheck{}
	if !reflect.DeepEqual(r, want) {
		t.Fatalf("result %+v\nwant   %+v", r, want)
	}
	if len(e.uploader.uploads) != 1 || e.uploader.uploads[0].mime != "image/png" ||
		bytes.Contains(e.uploader.uploads[0].body, []byte("GPS-SECRET")) {
		t.Fatalf("uploads = %d, metadata must be stripped", len(e.uploader.uploads))
	}
	if strings.Contains(e.logs.String(), "/artikel") {
		t.Fatal("log must not contain the link path")
	}
	sum := sha256.Sum256(e.uploader.uploads[0].body)
	if check.ImageVerdict != store.VerdictAllow || check.ImageSHA256 != hex.EncodeToString(sum[:]) ||
		check.ImageModel != "fake@1" || check.ImageScores["neutral"] != 0.98 || check.ThresholdsRevision != 1 ||
		e.classifier.mimes[0] != "image/png" {
		t.Fatalf("check = %+v mimes = %v", check, e.classifier.mimes)
	}
}

func TestImageOnOtherHostAndRelativePaths(t *testing.T) {
	img := pngWithText(t, 64, 64, "x")
	e := newEnv(t, site(t, img))
	r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=" + url.QueryEscape("http://cdn.olt-test.com:"+e.port+"/img.png")})
	if r.ImagePath == "" || r.ImageWidth != 64 {
		t.Fatalf("cross-host image: %+v", r)
	}
}

func TestPrivateImageIsDroppedButPreviewKept(t *testing.T) {
	e := newEnv(t, site(t, nil))
	for _, img := range []string{"http://10.0.0.1/a.png", "http://169.254.169.254/latest/meta-data/x.png", "http://localhost/a.png",
		"http://[::1]/a.png", "http://2130706433/a.png"} {
		r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=" + url.QueryEscape(img)})
		if r.Status != store.StatusOK || r.Title != "BBCA cetak rekor" || r.ImagePath != "" {
			t.Fatalf("%s: %+v", img, r)
		}
	}
	if m := e.worker.Metrics(); m.Images["blocked"] != 5 || len(e.uploader.uploads) != 0 {
		t.Fatalf("images = %v uploads = %d", m.Images, len(e.uploader.uploads))
	}
}

func TestRejectedImages(t *testing.T) {
	e := newEnv(t, site(t, []byte("not an image")))
	for img, event := range map[string]string{"/tiny.gif": "skipped", "/logo.svg": "rejected", "/img.png": "rejected"} {
		r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=" + img})
		if r.Status != store.StatusOK || r.ImagePath != "" {
			t.Fatalf("%s: %+v", img, r)
		}
		if e.worker.Metrics().Images[event] == 0 {
			t.Fatalf("%s should count as %s", img, event)
		}
	}
}

func TestUploadFailureKeepsTextPreview(t *testing.T) {
	e := newEnv(t, site(t, pngWithText(t, 64, 64, "x")))
	e.uploader.fail = errors.New("storage down")
	r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=/img.png"})
	if r.Status != store.StatusOK || r.ImagePath != "" || e.worker.Metrics().Images["failed"] != 1 {
		t.Fatalf("result %+v", r)
	}
}

func TestDirectImageLinkAndOtherTypes(t *testing.T) {
	e := newEnv(t, site(t, pngWithText(t, 80, 40, "x")))
	r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/img.png"})
	if r.Status != store.StatusOK || r.ImagePath == "" || r.SiteName != "site.olt-test.com" || r.Title != "" {
		t.Fatalf("image link: %+v", r)
	}
	r = e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/laporan.pdf"})
	if r.Status != store.StatusEmpty {
		t.Fatalf("pdf: %+v", r)
	}
}

func TestClassification(t *testing.T) {
	e := newEnv(t, site(t, nil))
	cases := map[string][2]string{
		e.base + "/to-metadata":                 {store.StatusBlocked, safehttp.ReasonAddress},
		"http://169.254.169.254/latest/":        {store.StatusBlocked, safehttp.ReasonAddress},
		"http://storage:5000/status":            {store.StatusBlocked, safehttp.ReasonPort},
		"http://evil@127.0.0.1:" + e.port + "/": {store.StatusBlocked, safehttp.ReasonUserinfo},
		"http://0x7f.1:" + e.port + "/":         {store.StatusBlocked, safehttp.ReasonNumericHost},
		e.base + "/status/404":                  {store.StatusFailed, "http_404"},
		e.base + "/status/410":                  {store.StatusFailed, "http_410"},
		e.base + "/status/503":                  {store.StatusRetry, "http_503"},
		e.base + "/status/429":                  {store.StatusRetry, "http_429"},
		e.base + "/slow":                        {store.StatusRetry, "timeout"},
		"http://unknown.olt-test.com:" + e.port: {store.StatusFailed, "dns_not_found"},
	}
	for target, want := range cases {
		r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: target})
		if r.Status != want[0] || r.Error != want[1] {
			t.Fatalf("%s = %s/%s, want %s/%s", target, r.Status, r.Error, want[0], want[1])
		}
	}
	if m := e.worker.Metrics(); m.Blocked[safehttp.ReasonAddress] != 2 || m.Blocked[safehttp.ReasonPort] != 1 || m.Results[store.StatusBlocked] != 5 {
		t.Fatalf("metrics = %+v", m)
	}
}

func TestCancelledWorkIsReleased(t *testing.T) {
	e := newEnv(t, site(t, nil))
	ctx, cancel := context.WithCancel(context.Background())
	go func() {
		time.Sleep(50 * time.Millisecond)
		cancel()
	}()
	r := e.worker.Process(ctx, store.Entry{URLHash: hash, URL: e.base + "/slow"})
	if r.Status != store.StatusRelease {
		t.Fatalf("result = %+v", r)
	}
}

type fakeStore struct {
	mu       sync.Mutex
	batches  [][]store.Entry
	claimErr error
	claims   int
	reports  [][]store.Result
}

func (s *fakeStore) Claim(_ context.Context, instance string, limit int, _ time.Duration) ([]store.Entry, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.claims++
	if instance != "lp-test" || limit != 4 {
		return nil, fmt.Errorf("unexpected claim %s %d", instance, limit)
	}
	if s.claimErr != nil {
		return nil, s.claimErr
	}
	if len(s.batches) == 0 {
		return nil, nil
	}
	b := s.batches[0]
	s.batches = s.batches[1:]
	return b, nil
}

func (s *fakeStore) Report(_ context.Context, _ string, results []store.Result) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.reports = append(s.reports, results)
	return len(results), nil
}

func (s *fakeStore) reported() map[string]string {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := map[string]string{}
	for _, batch := range s.reports {
		for _, r := range batch {
			out[r.URLHash] = r.Status
		}
	}
	return out
}

func TestRunClaimsProcessesAndReportsEachLink(t *testing.T) {
	e := newEnv(t, site(t, pngWithText(t, 64, 64, "x")))
	fs := &fakeStore{batches: [][]store.Entry{{
		{URLHash: "a", URL: e.base + "/artikel?img=/img.png"},
		{URLHash: "b", URL: "http://10.0.0.1/"},
		{URLHash: "c", URL: e.base + "/status/404"},
	}}}
	e.worker.opts.Store = fs
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		e.worker.Run(ctx)
		close(done)
	}()
	deadline := time.Now().Add(5 * time.Second)
	for len(fs.reported()) < 3 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	cancel()
	<-done
	got := fs.reported()
	if got["a"] != store.StatusOK || got["b"] != store.StatusBlocked || got["c"] != store.StatusFailed {
		t.Fatalf("reported = %v", got)
	}
	for _, batch := range fs.reports {
		if len(batch) != 1 {
			t.Fatalf("each processed link is reported on its own: %v", fs.reports)
		}
	}
}

func TestLinksThatCannotStartBeforeTheLeaseEndsAreReleased(t *testing.T) {
	e := newEnv(t, site(t, nil))
	fs := &fakeStore{batches: [][]store.Entry{{{URLHash: "a", URL: e.base + "/slow"}, {URLHash: "b", URL: e.base + "/slow"}}}}
	e.worker.opts.Store = fs
	e.worker.opts.Lease = 2*e.worker.opts.FetchTimeout + e.worker.opts.RequestTimeout + leaseMargin
	if _, err := e.worker.round(context.Background(), context.Background()); err != nil {
		t.Fatal(err)
	}
	if got := fs.reported(); got["a"] != store.StatusRelease || got["b"] != store.StatusRelease {
		t.Fatalf("reported = %v", got)
	}
}

func TestHeartbeatDegradesAfterRepeatedClaimFailures(t *testing.T) {
	e := newEnv(t, site(t, nil))
	e.worker.opts.Store = &fakeStore{claimErr: errors.New("postgrest down")}
	for i := 0; i < degradedAfter; i++ {
		if r := e.worker.Report(); r.Status != heartbeat.StatusOK {
			t.Fatalf("degraded too early after %d failures", i)
		}
		_, _ = e.worker.round(context.Background(), context.Background())
	}
	r := e.worker.Report()
	if r.Status != heartbeat.StatusDegraded || !strings.Contains(r.Error, "postgrest down") || r.Detail["claim_errors"] != uint64(3) {
		t.Fatalf("report = %+v", r)
	}
	e.worker.opts.Store = &fakeStore{}
	_, _ = e.worker.round(context.Background(), context.Background())
	if e.worker.Report().Status != heartbeat.StatusOK {
		t.Fatal("a good claim clears the degraded state")
	}
}

func TestExplicitThumbnailIsDroppedAndVerdictRecorded(t *testing.T) {
	e := newEnv(t, site(t, pngWithText(t, 64, 64, "x")))
	e.classifier.set(scores("fake@1", map[string]float64{"porn": 0.97, "neutral": 0.01}))
	r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=/img.png"})
	if r.Status != store.StatusOK || r.Title != "BBCA cetak rekor" || r.Description != "Laba naik 12%" || r.ImagePath != "" ||
		r.ImageWidth != 0 || len(e.uploader.uploads) != 0 {
		t.Fatalf("result %+v uploads %d", r, len(e.uploader.uploads))
	}
	if r.ImageVerdict != store.VerdictBlock || r.ImageCategory != "porn" || r.ImageScore == nil || *r.ImageScore != 0.97 ||
		r.ImageModel != "fake@1" || r.ImageScores["porn"] != 0.97 || len(r.ImageSHA256) != 64 || r.ThresholdsRevision != 1 {
		t.Fatalf("check %+v", r.ImageCheck)
	}
	m := e.worker.Metrics()
	if m.Images["unsafe"] != 1 || m.Images["stored"] != 0 || m.Verdicts[store.VerdictBlock] != 1 {
		t.Fatalf("metrics images=%v verdicts=%v", m.Images, m.Verdicts)
	}
}

func TestBorderlineThumbnailIsNotShown(t *testing.T) {
	e := newEnv(t, site(t, pngWithText(t, 64, 64, "x")))
	e.classifier.set(scores("fake@1", map[string]float64{"porn": 0.3, "sexy": 0.88, "neutral": 0.1}))
	r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=/img.png"})
	if r.Status != store.StatusOK || r.Title == "" || r.ImagePath != "" || len(e.uploader.uploads) != 0 {
		t.Fatalf("result %+v", r)
	}
	if r.ImageVerdict != store.VerdictHold || r.ImageCategory != "sexy" || *r.ImageScore != 0.88 {
		t.Fatalf("check %+v", r.ImageCheck)
	}
}

func TestDirectImageLinkIsScreenedToo(t *testing.T) {
	e := newEnv(t, site(t, pngWithText(t, 80, 40, "x")))
	e.classifier.set(scores("fake@1", map[string]float64{"hentai": 0.99}))
	r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/img.png"})
	if r.Status != store.StatusOK || r.ImagePath != "" || r.ImageVerdict != store.VerdictBlock || len(e.uploader.uploads) != 0 {
		t.Fatalf("result %+v", r)
	}
}

func TestClassifierUnavailableFailsClosed(t *testing.T) {
	e := newEnv(t, site(t, pngWithText(t, 64, 64, "x")))
	for _, err := range []error{moderation.ErrUnavailable, moderation.ErrModelMissing, context.DeadlineExceeded} {
		e.classifier.set(failing(err))
		r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=/img.png"})
		if r.Status != store.StatusOK || r.Title == "" || r.ImagePath != "" || r.ImageVerdict != store.VerdictUnavailable ||
			r.ImageScores != nil || r.ImageScore != nil || len(r.ImageSHA256) != 64 {
			t.Fatalf("%v: result %+v", err, r)
		}
	}
	if len(e.uploader.uploads) != 0 {
		t.Fatal("nothing may be stored while the classifier is down")
	}
	rep := e.worker.Report()
	if rep.Status != heartbeat.StatusDegraded || !strings.HasPrefix(rep.Error, "classifier: ") ||
		rep.Detail["classifier_failures"] != 3 || rep.Detail["images_unchecked"] != uint64(3) {
		t.Fatalf("report = %+v", rep)
	}
	if !strings.Contains(e.logs.String(), "Classifier cannot be used") {
		t.Fatal("the outage is logged once it is persistent")
	}
	e.worker.opts.Store = &fakeStore{}
	_, _ = e.worker.round(context.Background(), context.Background())
	if e.worker.Report().Status != heartbeat.StatusDegraded {
		t.Fatal("a failing probe keeps the degraded state")
	}
	e.classifier.set(nil)
	_, _ = e.worker.round(context.Background(), context.Background())
	if rep := e.worker.Report(); rep.Status != heartbeat.StatusOK || rep.Detail["classifier_failures"] != 0 {
		t.Fatalf("a good probe clears the degraded state: %+v", rep)
	}
	r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=/img.png"})
	if r.ImagePath == "" || r.ImageVerdict != store.VerdictAllow || e.worker.Report().Status != heartbeat.StatusOK {
		t.Fatalf("after recovery: %+v", r)
	}
}

func TestUnreadableImageIsDropped(t *testing.T) {
	e := newEnv(t, site(t, pngWithText(t, 64, 64, "x")))
	e.classifier.set(failing(fmt.Errorf("%w: invalid_image", moderation.ErrUnreadable)))
	r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=/img.png"})
	if r.ImagePath != "" || r.ImageVerdict != store.VerdictUnreadable || len(e.uploader.uploads) != 0 {
		t.Fatalf("result %+v", r)
	}
	if e.worker.Report().Detail["classifier_failures"] != 0 {
		t.Fatal("an unreadable image is an answer, not an outage")
	}
}

func TestThresholdsNotLoadedFailClosed(t *testing.T) {
	e := newEnv(t, site(t, pngWithText(t, 64, 64, "x")))
	e.policy.loaded = false
	r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=/img.png"})
	if r.ImagePath != "" || r.ImageVerdict != store.VerdictUnavailable || e.classifier.count() != 0 {
		t.Fatalf("result %+v calls %d", r, e.classifier.count())
	}
	if e.worker.Metrics().ThresholdsSet {
		t.Fatal("metrics must show the thresholds are missing")
	}
}

func TestSameThumbnailIsClassifiedOnce(t *testing.T) {
	e := newEnv(t, site(t, pngWithText(t, 64, 64, "x")))
	e.classifier.set(scores("fake@1", map[string]float64{"porn": 0.6}))
	first := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=/img.png"})
	second := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/img.png"})
	if e.classifier.count() != 1 || first.ImageSHA256 != second.ImageSHA256 {
		t.Fatalf("calls = %d", e.classifier.count())
	}
	if first.ImageScores == nil || second.ImageScores != nil || second.ImageModel != "" || second.ImageVerdict != store.VerdictHold {
		t.Fatalf("only fresh scores are reported: %+v / %+v", first.ImageCheck, second.ImageCheck)
	}
	e.policy.mu.Lock()
	e.policy.thresholds = moderation.Thresholds{Revision: 2, Limits: map[string]moderation.Limit{"porn": {Hold: limit(0.7)}}}
	e.policy.mu.Unlock()
	third := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/img.png"})
	if e.classifier.count() != 1 || third.ImageVerdict != store.VerdictAllow || third.ImagePath == "" || third.ThresholdsRevision != 2 {
		t.Fatalf("cached scores follow the current thresholds: %+v", third)
	}
	if e.worker.Metrics().CacheHits != 2 {
		t.Fatalf("cache hits = %d", e.worker.Metrics().CacheHits)
	}
}

func TestScoresCachedInTheDatabaseAreReused(t *testing.T) {
	img := pngWithText(t, 64, 64, "x")
	first := newEnv(t, site(t, img))
	clean := first.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: first.base + "/img.png"}).ImageSHA256
	e := newEnv(t, site(t, img))
	cache := &fakeScores{entries: map[string]moderation.Result{clean: {Model: "fake@0", Scores: map[string]float64{"porn": 0.95}}}}
	e.worker.opts.Scores = cache
	r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=/img.png"})
	if e.classifier.count() != 0 || r.ImageVerdict != store.VerdictBlock || r.ImagePath != "" || r.ImageScores != nil {
		t.Fatalf("calls = %d result = %+v", e.classifier.count(), r)
	}
	_ = e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/img.png"})
	if cache.lookups != 1 {
		t.Fatalf("the database is asked once per image, lookups = %d", cache.lookups)
	}
	down := newEnv(t, site(t, img))
	down.worker.opts.Scores = &fakeScores{err: errors.New("postgrest down")}
	r = down.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: down.base + "/img.png"})
	if down.classifier.count() != 1 || r.ImageVerdict != store.VerdictAllow || r.ImagePath == "" {
		t.Fatalf("a cache error falls back to the classifier: %+v", r)
	}
}

func TestRejectedImagesAreNotClassified(t *testing.T) {
	e := newEnv(t, site(t, []byte("not an image")))
	for _, img := range []string{"/tiny.gif", "/logo.svg", "/img.png"} {
		r := e.worker.Process(context.Background(), store.Entry{URLHash: hash, URL: e.base + "/artikel?img=" + img})
		if r.ImageVerdict != "" || r.ImageSHA256 != "" {
			t.Fatalf("%s: %+v", img, r)
		}
	}
	if e.classifier.count() != 0 {
		t.Fatalf("calls = %d", e.classifier.count())
	}
}
