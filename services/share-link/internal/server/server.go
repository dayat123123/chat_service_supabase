package server

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"html/template"
	"log/slog"
	"net/http"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
	"unicode/utf8"

	"olt-social/share-link/internal/heartbeat"
	"olt-social/share-link/internal/page"
	"olt-social/share-link/internal/store"
)

const (
	routeAssetLinks = "assetlinks"
	routeAASA       = "apple_app_site_association"
	routePage       = "page"
	routeImage      = "image"
	routeAvatar     = "avatar"
	routeOther      = "other"

	staleSettings  = 10 * time.Minute
	imageSlots     = 16
	descriptionMax = 200
)

var (
	codePattern   = regexp.MustCompile(`^[A-Za-z0-9]{10}$`)
	schemePattern = regexp.MustCompile(`^[a-z][a-z0-9+.-]{1,30}$`)
	stockPattern  = regexp.MustCompile(`^[A-Z][A-Z0-9]{1,11}$`)
)

type Source interface {
	Settings(ctx context.Context) (store.Settings, error)
	Preview(ctx context.Context, code string) (store.Preview, error)
	PostImage(ctx context.Context, path string, width int, limit int64) (store.Blob, error)
	Avatar(ctx context.Context, path string, limit int64) (store.Blob, error)
}

type Options struct {
	Log              *slog.Logger
	Source           Source
	ConfigTTL        time.Duration
	PreviewTTL       time.Duration
	PreviewCacheSize int
	MaxImageBytes    int64
	ImageWidth       int
	RequestTimeout   time.Duration
	Now              func() time.Time
}

type previewEntry struct {
	preview store.Preview
	at      time.Time
}

type Server struct {
	opts Options
	csp  string

	settingsMu sync.Mutex
	settings   store.Settings
	settingsAt time.Time

	previewMu sync.Mutex
	previews  map[string]previewEntry

	images chan struct{}

	statsMu  sync.Mutex
	requests map[[2]string]uint64
	failures atomic.Int64
}

func New(opts Options) *Server {
	if opts.Now == nil {
		opts.Now = time.Now
	}
	return &Server{
		opts:     opts,
		csp:      page.ContentSecurityPolicy(),
		previews: map[string]previewEntry{},
		images:   make(chan struct{}, imageSlots),
		requests: map[[2]string]uint64{},
	}
}

type recorder struct {
	http.ResponseWriter
	status int
}

func (r *recorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	rec := &recorder{ResponseWriter: w, status: http.StatusOK}
	route := s.route(rec, r)
	s.count(route, rec.status)
}

func (s *Server) route(w *recorder, r *http.Request) string {
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Referrer-Policy", "no-referrer")
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		w.Header().Set("Allow", "GET, HEAD")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return routeOther
	}
	ctx, cancel := context.WithTimeout(r.Context(), s.opts.RequestTimeout)
	defer cancel()
	switch path := r.URL.Path; {
	case path == "/.well-known/assetlinks.json":
		s.assetLinks(ctx, w)
		return routeAssetLinks
	case path == "/.well-known/apple-app-site-association":
		s.appleAssociation(ctx, w)
		return routeAASA
	case strings.HasPrefix(path, "/p/"):
		code, sub, _ := strings.Cut(strings.TrimPrefix(path, "/p/"), "/")
		switch sub {
		case "":
			s.page(ctx, w, code)
			return routePage
		case "image":
			s.image(ctx, w, code, false)
			return routeImage
		case "avatar":
			s.image(ctx, w, code, true)
			return routeAvatar
		}
	}
	http.NotFound(w, r)
	return routeOther
}

func (s *Server) loadSettings(ctx context.Context) (store.Settings, error) {
	s.settingsMu.Lock()
	defer s.settingsMu.Unlock()
	now := s.opts.Now()
	if !s.settingsAt.IsZero() && now.Sub(s.settingsAt) < s.opts.ConfigTTL {
		return s.settings, nil
	}
	fresh, err := s.opts.Source.Settings(ctx)
	if err != nil {
		s.failed(err)
		if !s.settingsAt.IsZero() && now.Sub(s.settingsAt) < staleSettings {
			return s.settings, nil
		}
		return store.Settings{}, err
	}
	s.failures.Store(0)
	s.settings, s.settingsAt = fresh, now
	return fresh, nil
}

func (s *Server) loadPreview(ctx context.Context, code string) (store.Preview, error) {
	now := s.opts.Now()
	if s.opts.PreviewTTL > 0 {
		s.previewMu.Lock()
		entry, ok := s.previews[code]
		s.previewMu.Unlock()
		if ok && now.Sub(entry.at) < s.opts.PreviewTTL {
			return entry.preview, nil
		}
	}
	preview, err := s.opts.Source.Preview(ctx, code)
	if err != nil {
		s.failed(err)
		return preview, err
	}
	s.failures.Store(0)
	if s.opts.PreviewTTL > 0 && s.opts.PreviewCacheSize > 0 {
		s.previewMu.Lock()
		if len(s.previews) >= s.opts.PreviewCacheSize {
			s.prune(now)
		}
		s.previews[code] = previewEntry{preview: preview, at: now}
		s.previewMu.Unlock()
	}
	return preview, nil
}

func (s *Server) prune(now time.Time) {
	for code, entry := range s.previews {
		if now.Sub(entry.at) >= s.opts.PreviewTTL {
			delete(s.previews, code)
		}
	}
	for code := range s.previews {
		if len(s.previews) < s.opts.PreviewCacheSize/2+1 {
			break
		}
		delete(s.previews, code)
	}
}

func (s *Server) failed(err error) {
	if errors.Is(err, store.ErrUnavailable) {
		if s.failures.Add(1) == 3 {
			s.opts.Log.Warn("Database API keeps failing", "error", err)
		}
	}
}

func (s *Server) assetLinks(ctx context.Context, w http.ResponseWriter) {
	settings, err := s.loadSettings(ctx)
	if err != nil {
		unavailable(w)
		return
	}
	if len(settings.Android) == 0 {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	type target struct {
		Namespace   string   `json:"namespace"`
		PackageName string   `json:"package_name"`
		Prints      []string `json:"sha256_cert_fingerprints"`
	}
	type statement struct {
		Relation []string `json:"relation"`
		Target   target   `json:"target"`
	}
	out := make([]statement, 0, len(settings.Android))
	for _, app := range settings.Android {
		out = append(out, statement{
			Relation: []string{"delegate_permission/common.handle_all_urls"},
			Target:   target{Namespace: "android_app", PackageName: app.Package, Prints: app.SHA256},
		})
	}
	writeJSON(w, out)
}

func (s *Server) appleAssociation(ctx context.Context, w http.ResponseWriter) {
	settings, err := s.loadSettings(ctx)
	if err != nil {
		unavailable(w)
		return
	}
	if len(settings.IOSAppIDs) == 0 {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	type detail struct {
		AppID      string              `json:"appID"`
		AppIDs     []string            `json:"appIDs"`
		Paths      []string            `json:"paths"`
		Components []map[string]string `json:"components"`
	}
	details := make([]detail, 0, len(settings.IOSAppIDs))
	for _, id := range settings.IOSAppIDs {
		details = append(details, detail{
			AppID:      id,
			AppIDs:     []string{id},
			Paths:      []string{"/p/*"},
			Components: []map[string]string{{"/": "/p/*"}},
		})
	}
	writeJSON(w, map[string]any{"applinks": map[string]any{"apps": []string{}, "details": details}})
}

func writeJSON(w http.ResponseWriter, body any) {
	data, err := json.Marshal(body)
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "public, max-age=300")
	w.Header().Set("Content-Length", strconv.Itoa(len(data)))
	_, _ = w.Write(data)
}

func unavailable(w http.ResponseWriter) {
	w.Header().Set("Retry-After", "10")
	w.Header().Set("Cache-Control", "no-store")
	http.Error(w, "service unavailable", http.StatusServiceUnavailable)
}

func (s *Server) page(ctx context.Context, w http.ResponseWriter, code string) {
	settings, err := s.loadSettings(ctx)
	if err != nil {
		s.renderUnavailable(w)
		return
	}
	appName := settings.AppName
	if appName == "" {
		appName = "OLT"
	}
	base := page.Data{SiteName: appName, Downloads: downloads(settings)}
	if !settings.Ready || !codePattern.MatchString(code) {
		base.Title = "Tautan tidak tersedia"
		base.Description = base.Title
		base.Heading = base.Title
		base.Message = "Tautan ini tidak dikenal atau sudah tidak aktif."
		s.render(w, http.StatusNotFound, base)
		return
	}
	preview, err := s.loadPreview(ctx, code)
	if err != nil {
		s.renderUnavailable(w)
		return
	}
	if preview.Status != "ok" {
		base.Title = "Postingan tidak tersedia"
		base.Description = base.Title
		base.Heading = base.Title
		base.Message = "Postingan ini mungkin sudah dihapus, disembunyikan, atau tautannya salah."
		s.render(w, http.StatusNotFound, base)
		return
	}
	link := settings.BaseURL + "/p/" + code
	base.CanonicalURL = link
	if schemePattern.MatchString(settings.AppScheme) {
		base.AppURL = template.URL(settings.AppScheme + "://p/" + code)
	}
	if !preview.Preview {
		base.Title = "Postingan di " + appName
		base.Description = "Buka postingan ini di aplikasi " + appName + "."
		base.Heading = base.Title
		base.Message = "Buka di aplikasi untuk melihat isi postingan ini."
		s.render(w, http.StatusOK, base)
		return
	}
	author := preview.Author
	name := author.DisplayName
	if name == "" {
		name = author.Username
	}
	body := preview.Body
	if preview.Truncated && body != "" {
		body += "…"
	}
	post := &page.Post{
		DisplayName: name,
		Username:    author.Username,
		Initials:    page.Initials(name),
		Body:        page.Segments(body),
		More:        preview.Truncated && body != "",
		Date:        page.Date(preview.CreatedAt),
		Likes:       max(preview.LikeCount, 0),
		Comments:    max(preview.CommentCount, 0),
		Stocks:      stocks(preview.Stocks),
	}
	switch {
	case author.Official:
		post.Badge = "Resmi"
	case author.Verified:
		post.Badge = "Terverifikasi"
	}
	if author.AvatarPath != "" {
		post.AvatarURL = "/p/" + code + "/avatar"
	}
	if preview.Image != nil && preview.Image.Path != "" {
		post.ImageURL = "/p/" + code + "/image"
		post.ImageWidth, post.ImageHeight = scaled(preview.Image.Width, preview.Image.Height, s.opts.ImageWidth)
		base.OGImageURL = link + "/image"
		base.OGImageW, base.OGImageH = post.ImageWidth, post.ImageHeight
	} else if post.AvatarURL != "" {
		base.OGImageURL = link + "/avatar"
	}
	base.Post = post
	base.Title = name + " di " + appName
	base.Description = describe(preview.Body, author.Username)
	s.render(w, http.StatusOK, base)
}

func (s *Server) renderUnavailable(w http.ResponseWriter) {
	w.Header().Set("Retry-After", "10")
	s.render(w, http.StatusServiceUnavailable, page.Data{
		SiteName:    "Tautan berbagi",
		Title:       "Sedang ada gangguan",
		Description: "Sedang ada gangguan",
		Heading:     "Sedang ada gangguan",
		Message:     "Halaman ini belum bisa dibuka. Coba lagi beberapa saat lagi.",
	})
}

func (s *Server) render(w http.ResponseWriter, status int, data page.Data) {
	body, err := page.Render(data)
	if err != nil {
		s.opts.Log.Error("Failed to render the share page", "error", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	h := w.Header()
	h.Set("Content-Type", "text/html; charset=utf-8")
	h.Set("Content-Security-Policy", s.csp)
	h.Set("X-Frame-Options", "DENY")
	h.Set("X-Robots-Tag", "noindex, nofollow, noarchive")
	if status == http.StatusOK || status == http.StatusNotFound {
		h.Set("Cache-Control", "public, max-age=60")
	} else {
		h.Set("Cache-Control", "no-store")
	}
	h.Set("Content-Length", strconv.Itoa(len(body)))
	w.WriteHeader(status)
	_, _ = w.Write(body)
}

func (s *Server) image(ctx context.Context, w http.ResponseWriter, code string, avatar bool) {
	settings, err := s.loadSettings(ctx)
	if err != nil {
		unavailable(w)
		return
	}
	if !settings.Ready || !codePattern.MatchString(code) {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	preview, err := s.loadPreview(ctx, code)
	if err != nil {
		unavailable(w)
		return
	}
	if preview.Status != "ok" || !preview.Preview {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	path := preview.Author.AvatarPath
	if !avatar {
		path = ""
		if preview.Image != nil {
			path = preview.Image.Path
		}
	}
	if path == "" {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	select {
	case s.images <- struct{}{}:
		defer func() { <-s.images }()
	case <-ctx.Done():
		unavailable(w)
		return
	}
	var blob store.Blob
	if avatar {
		blob, err = s.opts.Source.Avatar(ctx, path, s.opts.MaxImageBytes)
	} else {
		blob, err = s.opts.Source.PostImage(ctx, path, s.opts.ImageWidth, s.opts.MaxImageBytes)
	}
	switch {
	case errors.Is(err, store.ErrNotFound), errors.Is(err, store.ErrTooLarge):
		http.Error(w, "not found", http.StatusNotFound)
		return
	case err != nil:
		s.opts.Log.Warn("Failed to fetch a share image", "error", err, "avatar", avatar)
		unavailable(w)
		return
	}
	h := w.Header()
	h.Set("Content-Type", blob.ContentType)
	h.Set("Cache-Control", "public, max-age=3600")
	h.Set("Content-Security-Policy", "default-src 'none'; sandbox")
	if blob.ETag != "" {
		h.Set("ETag", blob.ETag)
	}
	h.Set("Content-Length", strconv.Itoa(len(blob.Data)))
	_, _ = w.Write(blob.Data)
}

func downloads(settings store.Settings) []page.Link {
	var links []page.Link
	for _, item := range []page.Link{
		{Kind: "android", Name: "Android", Label: "Unduh di Google Play", URL: settings.AndroidStoreURL},
		{Kind: "ios", Name: "iPhone", Label: "Unduh di App Store", URL: settings.IOSStoreURL},
		{Kind: "windows", Name: "Windows", Label: "Unduh untuk Windows", URL: settings.WindowsDownloadURL},
		{Kind: "mac", Name: "Mac", Label: "Unduh untuk Mac", URL: settings.MacDownloadURL},
	} {
		if strings.HasPrefix(item.URL, "https://") {
			links = append(links, item)
		}
	}
	return links
}

func stocks(items []store.Stock) []page.Stock {
	var out []page.Stock
	for _, item := range items {
		if len(out) == 3 {
			break
		}
		if !stockPattern.MatchString(item.Code) {
			continue
		}
		out = append(out, page.Stock{Code: item.Code, Name: item.Name, Initials: item.Code[:2]})
	}
	return out
}

func describe(body, username string) string {
	body = strings.TrimSpace(body)
	if body == "" {
		return "Postingan dari @" + username
	}
	if utf8.RuneCountInString(body) <= descriptionMax {
		return body
	}
	return strings.TrimSpace(string([]rune(body)[:descriptionMax-1])) + "…"
}

func scaled(width, height, limit int) (int, int) {
	if width <= 0 || height <= 0 {
		return 0, 0
	}
	if width > limit {
		height = height * limit / width
		width = limit
	}
	return width, height
}

func (s *Server) count(route string, status int) {
	s.statsMu.Lock()
	s.requests[[2]string{route, strconv.Itoa(status)}]++
	s.statsMu.Unlock()
}

func (s *Server) Report() heartbeat.Report {
	failures := s.failures.Load()
	s.settingsMu.Lock()
	ready := s.settings.Ready
	s.settingsMu.Unlock()
	report := heartbeat.Report{Status: heartbeat.StatusOK, Detail: map[string]any{"ready": ready, "store_failures": failures}}
	if failures >= 3 {
		report.Status = heartbeat.StatusDegraded
		report.Error = "database API unavailable"
	}
	return report
}

func (s *Server) WriteMetrics(w http.ResponseWriter, lastHeartbeat time.Time) {
	s.statsMu.Lock()
	keys := make([][2]string, 0, len(s.requests))
	for k := range s.requests {
		keys = append(keys, k)
	}
	slices.SortFunc(keys, func(a, b [2]string) int {
		if c := strings.Compare(a[0], b[0]); c != 0 {
			return c
		}
		return strings.Compare(a[1], b[1])
	})
	var b strings.Builder
	b.WriteString("# HELP share_link_requests_total Requests by route and HTTP status.\n# TYPE share_link_requests_total counter\n")
	for _, k := range keys {
		fmt.Fprintf(&b, "share_link_requests_total{route=%q,status=%q} %d\n", k[0], k[1], s.requests[k])
	}
	s.statsMu.Unlock()
	s.previewMu.Lock()
	cached := len(s.previews)
	s.previewMu.Unlock()
	fmt.Fprintf(&b, "# HELP share_link_preview_cache_entries Cached post previews.\n# TYPE share_link_preview_cache_entries gauge\nshare_link_preview_cache_entries %d\n", cached)
	fmt.Fprintf(&b, "# HELP share_link_store_consecutive_failures Consecutive failed database API calls (3 or more = degraded).\n# TYPE share_link_store_consecutive_failures gauge\nshare_link_store_consecutive_failures %d\n", s.failures.Load())
	last := int64(0)
	if !lastHeartbeat.IsZero() {
		last = lastHeartbeat.Unix()
	}
	fmt.Fprintf(&b, "# HELP share_link_last_heartbeat_timestamp_seconds Unix time of the last successful heartbeat.\n# TYPE share_link_last_heartbeat_timestamp_seconds gauge\nshare_link_last_heartbeat_timestamp_seconds %d\n", last)
	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
	_, _ = w.Write([]byte(b.String()))
}
