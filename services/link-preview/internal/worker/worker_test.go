package worker

import (
	"bytes"
	"context"
	"encoding/binary"
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
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/link-preview/internal/heartbeat"
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
	worker   *Worker
	uploader *fakeUploader
	base     string
	port     string
	logs     *bytes.Buffer
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
	logs := &bytes.Buffer{}
	w := New(Options{
		Fetcher:        client,
		Uploader:       uploader,
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
	return &env{worker: w, uploader: uploader, base: "http://site.olt-test.com:" + u.Port(), port: u.Port(), logs: logs}
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
	if r != want {
		t.Fatalf("result %+v\nwant   %+v", r, want)
	}
	if len(e.uploader.uploads) != 1 || e.uploader.uploads[0].mime != "image/png" ||
		bytes.Contains(e.uploader.uploads[0].body, []byte("GPS-SECRET")) {
		t.Fatalf("uploads = %d, metadata must be stripped", len(e.uploader.uploads))
	}
	if strings.Contains(e.logs.String(), "/artikel") {
		t.Fatal("log must not contain the link path")
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
