package server

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/share-link/internal/store"
)

type fakeSource struct {
	mu          sync.Mutex
	settings    store.Settings
	settingsErr error
	previews    map[string]store.Preview
	previewErr  error
	calls       map[string]int
	imagePath   string
	avatarPath  string
	blobErr     error
}

func (f *fakeSource) hit(name string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.calls == nil {
		f.calls = map[string]int{}
	}
	f.calls[name]++
}

func (f *fakeSource) count(name string) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.calls[name]
}

func (f *fakeSource) Settings(context.Context) (store.Settings, error) {
	f.hit("settings")
	return f.settings, f.settingsErr
}

func (f *fakeSource) Preview(_ context.Context, code string) (store.Preview, error) {
	f.hit("preview")
	if f.previewErr != nil {
		return store.Preview{}, f.previewErr
	}
	if p, ok := f.previews[code]; ok {
		return p, nil
	}
	return store.Preview{Status: "not_found"}, nil
}

func (f *fakeSource) PostImage(_ context.Context, path string, _ int, _ int64) (store.Blob, error) {
	f.mu.Lock()
	f.imagePath = path
	f.mu.Unlock()
	if f.blobErr != nil {
		return store.Blob{}, f.blobErr
	}
	return store.Blob{Data: []byte("jpeg"), ContentType: "image/jpeg", ETag: `"abc"`}, nil
}

func (f *fakeSource) Avatar(_ context.Context, path string, _ int64) (store.Blob, error) {
	f.mu.Lock()
	f.avatarPath = path
	f.mu.Unlock()
	return store.Blob{Data: []byte("png"), ContentType: "image/png"}, nil
}

const code = "Ab12Cd34Ef"

func readySettings() store.Settings {
	return store.Settings{
		Ready: true, Enabled: true, BaseURL: "https://share.olt.test", Preview: true, AppName: "OLT", AppScheme: "olt",
		Android:         []store.AndroidApp{{Package: "co.olt.app", SHA256: []string{"AB:CD"}}},
		IOSAppIDs:       []string{"ABCDE12345.co.olt.app"},
		AndroidStoreURL: "https://play.google.com/store/apps/details?id=co.olt.app",
		IOSStoreURL:     "http://not-https.example",
		MacDownloadURL:  "https://unduh.olt.test/OLT.dmg",
	}
}

func publicPost() store.Preview {
	return store.Preview{
		Status: "ok", Code: code, Preview: true,
		Author:    store.Author{Username: "ani", DisplayName: "Ani <Saham>", Official: true, AvatarPath: "u/avatar.jpg"},
		Body:      `Beli $BBCA <script>alert(1)</script>`,
		Truncated: true,
		CreatedAt: time.Date(2026, 11, 27, 20, 0, 0, 0, time.UTC),
		LikeCount: 12, CommentCount: 3,
		Image:  &store.Image{Path: "posts/u/photo.png", Width: 2400, Height: 1200},
		Stocks: []store.Stock{{Code: "BBCA"}, {Code: "bad code"}, {Code: "COMPOSITE", Name: "IHSG"}},
	}
}

func newServer(src *fakeSource) *Server {
	return New(Options{
		Log:              slog.New(slog.NewTextHandler(io.Discard, nil)),
		Source:           src,
		ConfigTTL:        30 * time.Second,
		PreviewTTL:       30 * time.Second,
		PreviewCacheSize: 10,
		MaxImageBytes:    1 << 20,
		ImageWidth:       1200,
		RequestTimeout:   5 * time.Second,
	})
}

func get(t *testing.T, s *Server, method, path string) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, httptest.NewRequest(method, path, nil))
	return rec
}

func TestPublicPostPageCarriesPreviewAndEscapesContent(t *testing.T) {
	src := &fakeSource{settings: readySettings(), previews: map[string]store.Preview{code: publicPost()}}
	rec := get(t, newServer(src), http.MethodGet, "/p/"+code)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	body := rec.Body.String()
	for _, want := range []string{
		`<meta property="og:title" content="Ani &lt;Saham&gt; di OLT">`,
		`<meta property="og:image" content="https://share.olt.test/p/` + code + `/image">`,
		`<meta property="og:image:width" content="1200">`,
		`<meta property="og:image:height" content="600">`,
		`<meta property="og:url" content="https://share.olt.test/p/` + code + `">`,
		`href="olt://p/` + code + `"`,
		`Beli <span class="tag">$BBCA</span> &lt;script&gt;alert(1)&lt;/script&gt;…`,
		`Baca selengkapnya di aplikasi`,
		`<b>$BBCA</b>`,
		`<small>IHSG</small>`,
		`</svg>Resmi</span>`,
		`@ani · 28 Nov 2026`,
		`Suka <em>12</em>`,
		`Komentar <em>3</em>`,
		`src="/p/` + code + `/avatar"`,
		`Unduh di Google Play`,
		`<a class="btn dl" href="https://unduh.olt.test/OLT.dmg" rel="noopener" title="Unduh untuk Mac">`,
		`</svg>Mac</a>`,
	} {
		if !strings.Contains(body, want) {
			t.Errorf("page is missing %q", want)
		}
	}
	if strings.Contains(body, "<script>alert") {
		t.Error("post text must be escaped")
	}
	if strings.Contains(body, "bad code") {
		t.Error("malformed stock codes must be dropped")
	}
	if strings.Contains(body, "not-https.example") {
		t.Error("download links must be https")
	}
	if got := rec.Header().Get("Content-Security-Policy"); !strings.Contains(got, "script-src 'sha256-") || strings.Contains(got, "unsafe-inline") {
		t.Errorf("CSP = %q", got)
	}
	if got := rec.Header().Get("X-Robots-Tag"); !strings.Contains(got, "noindex") {
		t.Errorf("X-Robots-Tag = %q", got)
	}
}

func TestPreviewOffShowsNoPostContent(t *testing.T) {
	src := &fakeSource{settings: readySettings(), previews: map[string]store.Preview{code: {Status: "ok", Code: code}}}
	rec := get(t, newServer(src), http.MethodGet, "/p/"+code)
	body := rec.Body.String()
	if rec.Code != http.StatusOK || !strings.Contains(body, "Postingan di OLT") || !strings.Contains(body, "olt://p/"+code) {
		t.Fatalf("status = %d body = %s", rec.Code, body)
	}
	if strings.Contains(body, "og:image") {
		t.Error("no image without preview")
	}
}

func TestHiddenUnknownAndDisabledLinksAre404WithoutContent(t *testing.T) {
	src := &fakeSource{settings: readySettings(), previews: map[string]store.Preview{code: {Status: "unavailable", Code: code}}}
	s := newServer(src)
	for _, path := range []string{"/p/" + code, "/p/ZZZZZZZZZZ", "/p/short", "/p/" + code + "/image"} {
		rec := get(t, s, http.MethodGet, path)
		if rec.Code != http.StatusNotFound {
			t.Errorf("%s status = %d", path, rec.Code)
		}
		if strings.Contains(rec.Body.String(), "olt://") {
			t.Errorf("%s must not offer to open the app", path)
		}
	}
	off := readySettings()
	off.Ready = false
	src = &fakeSource{settings: off, previews: map[string]store.Preview{code: publicPost()}}
	rec := get(t, newServer(src), http.MethodGet, "/p/"+code)
	if rec.Code != http.StatusNotFound || !strings.Contains(rec.Body.String(), "Tautan tidak tersedia") {
		t.Fatalf("disabled status = %d", rec.Code)
	}
	if src.count("preview") != 0 {
		t.Error("a disabled site must not read posts")
	}
}

func TestBadAppSchemeIsNotLinked(t *testing.T) {
	settings := readySettings()
	settings.AppScheme = "javascript:alert(1)//"
	src := &fakeSource{settings: settings, previews: map[string]store.Preview{code: publicPost()}}
	body := get(t, newServer(src), http.MethodGet, "/p/"+code).Body.String()
	if strings.Contains(body, `id="open"`) || strings.Contains(body, "javascript:") {
		t.Fatal("an invalid scheme must not become a link")
	}
}

func TestDatabaseDownGives503AndStaleSettingsKeepServing(t *testing.T) {
	src := &fakeSource{settingsErr: store.ErrUnavailable}
	s := newServer(src)
	rec := get(t, s, http.MethodGet, "/p/"+code)
	if rec.Code != http.StatusServiceUnavailable || rec.Header().Get("Retry-After") == "" {
		t.Fatalf("status = %d", rec.Code)
	}

	now := time.Unix(1_800_000_000, 0)
	src = &fakeSource{settings: readySettings(), previews: map[string]store.Preview{code: publicPost()}}
	s = newServer(src)
	s.opts.Now = func() time.Time { return now }
	get(t, s, http.MethodGet, "/p/"+code)
	src.settingsErr = store.ErrUnavailable
	now = now.Add(time.Minute)
	if rec := get(t, s, http.MethodGet, "/.well-known/assetlinks.json"); rec.Code != http.StatusOK {
		t.Fatalf("stale settings status = %d", rec.Code)
	}
	for range 3 {
		now = now.Add(time.Minute)
		get(t, s, http.MethodGet, "/.well-known/assetlinks.json")
	}
	if s.Report().Status != "degraded" {
		t.Fatal("repeated failures must degrade the heartbeat")
	}
}

func TestPreviewsAreCachedPerCode(t *testing.T) {
	src := &fakeSource{settings: readySettings(), previews: map[string]store.Preview{code: publicPost()}}
	s := newServer(src)
	for range 3 {
		get(t, s, http.MethodGet, "/p/"+code)
	}
	get(t, s, http.MethodGet, "/p/"+code+"/image")
	if got := src.count("preview"); got != 1 {
		t.Fatalf("preview calls = %d", got)
	}
	if got := src.count("settings"); got != 1 {
		t.Fatalf("settings calls = %d", got)
	}
}

func TestImagesProxyOnlyTheSharedPostFiles(t *testing.T) {
	src := &fakeSource{settings: readySettings(), previews: map[string]store.Preview{code: publicPost()}}
	s := newServer(src)
	rec := get(t, s, http.MethodGet, "/p/"+code+"/image")
	if rec.Code != http.StatusOK || rec.Header().Get("Content-Type") != "image/jpeg" || rec.Body.String() != "jpeg" {
		t.Fatalf("image status = %d type = %q", rec.Code, rec.Header().Get("Content-Type"))
	}
	if src.imagePath != "posts/u/photo.png" || !strings.Contains(rec.Header().Get("Cache-Control"), "max-age=3600") {
		t.Fatalf("path = %q cache = %q", src.imagePath, rec.Header().Get("Cache-Control"))
	}
	if rec := get(t, s, http.MethodGet, "/p/"+code+"/avatar"); rec.Code != http.StatusOK || src.avatarPath != "u/avatar.jpg" {
		t.Fatalf("avatar status = %d path = %q", rec.Code, src.avatarPath)
	}
	if rec := get(t, s, http.MethodGet, "/p/"+code+"/other"); rec.Code != http.StatusNotFound {
		t.Fatalf("unknown sub path status = %d", rec.Code)
	}
	src.blobErr = store.ErrTooLarge
	s = newServer(src)
	if rec := get(t, s, http.MethodGet, "/p/"+code+"/image"); rec.Code != http.StatusNotFound {
		t.Fatalf("too large status = %d", rec.Code)
	}
}

func TestAssetLinksAndAppleAssociation(t *testing.T) {
	src := &fakeSource{settings: readySettings()}
	s := newServer(src)
	rec := get(t, s, http.MethodGet, "/.well-known/assetlinks.json")
	if rec.Code != http.StatusOK || rec.Header().Get("Content-Type") != "application/json" {
		t.Fatalf("assetlinks status = %d", rec.Code)
	}
	var links []struct {
		Relation []string `json:"relation"`
		Target   struct {
			Namespace string   `json:"namespace"`
			Package   string   `json:"package_name"`
			Prints    []string `json:"sha256_cert_fingerprints"`
		} `json:"target"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &links); err != nil || len(links) != 1 {
		t.Fatalf("assetlinks = %s", rec.Body.String())
	}
	if links[0].Relation[0] != "delegate_permission/common.handle_all_urls" || links[0].Target.Package != "co.olt.app" ||
		links[0].Target.Namespace != "android_app" || links[0].Target.Prints[0] != "AB:CD" {
		t.Fatalf("assetlinks = %+v", links[0])
	}

	rec = get(t, s, http.MethodGet, "/.well-known/apple-app-site-association")
	var aasa struct {
		Applinks struct {
			Details []struct {
				AppIDs     []string            `json:"appIDs"`
				Paths      []string            `json:"paths"`
				Components []map[string]string `json:"components"`
			} `json:"details"`
		} `json:"applinks"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &aasa); err != nil || rec.Code != http.StatusOK {
		t.Fatalf("aasa status = %d body = %s", rec.Code, rec.Body.String())
	}
	d := aasa.Applinks.Details[0]
	if d.AppIDs[0] != "ABCDE12345.co.olt.app" || d.Paths[0] != "/p/*" || d.Components[0]["/"] != "/p/*" {
		t.Fatalf("aasa = %+v", d)
	}

	empty := readySettings()
	empty.Android, empty.IOSAppIDs = nil, nil
	s = newServer(&fakeSource{settings: empty})
	for _, path := range []string{"/.well-known/assetlinks.json", "/.well-known/apple-app-site-association"} {
		if rec := get(t, s, http.MethodGet, path); rec.Code != http.StatusNotFound {
			t.Errorf("%s status = %d", path, rec.Code)
		}
	}
}

func TestOnlyGetAndHeadAndKnownPaths(t *testing.T) {
	s := newServer(&fakeSource{settings: readySettings()})
	if rec := get(t, s, http.MethodPost, "/p/"+code); rec.Code != http.StatusMethodNotAllowed || rec.Header().Get("Allow") != "GET, HEAD" {
		t.Fatalf("POST status = %d", rec.Code)
	}
	if rec := get(t, s, http.MethodGet, "/rest/v1/posts"); rec.Code != http.StatusNotFound {
		t.Fatalf("other path status = %d", rec.Code)
	}
	if rec := get(t, s, http.MethodHead, "/p/"+code); rec.Code != http.StatusNotFound {
		t.Fatalf("HEAD unknown status = %d", rec.Code)
	}
	metrics := httptest.NewRecorder()
	s.WriteMetrics(metrics, time.Time{})
	if !strings.Contains(metrics.Body.String(), `share_link_requests_total{route="page",status="404"} 1`) {
		t.Fatalf("metrics = %s", metrics.Body.String())
	}
}

func TestPreviewCacheStaysBounded(t *testing.T) {
	src := &fakeSource{settings: readySettings(), previews: map[string]store.Preview{}}
	s := newServer(src)
	for i := range 50 {
		get(t, s, http.MethodGet, "/p/"+strings.Repeat(string(rune('A'+i%26)), 9)+string(rune('a'+i/26)))
	}
	if n := len(s.previews); n > 10 {
		t.Fatalf("cache size = %d", n)
	}
}
