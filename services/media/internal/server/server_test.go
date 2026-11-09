package server

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"image"
	"image/color"
	"image/gif"
	"image/jpeg"
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

	"olt-social/media/internal/heartbeat"
	"olt-social/media/internal/jwt"
	"olt-social/media/internal/metrics"
	"olt-social/media/internal/storage"
)

const sub = "6f1d2c3b-4a59-4e7f-8a1b-2c3d4e5f6a7b"

var secret = []byte(strings.Repeat("s", 40))

type received struct {
	method  string
	path    string
	headers http.Header
	body    []byte
}

type fakeStorage struct {
	mu       sync.Mutex
	requests []received
	reply    func(w http.ResponseWriter, r *http.Request)
	srv      *httptest.Server
}

func newFakeStorage(t *testing.T) *fakeStorage {
	t.Helper()
	f := &fakeStorage{}
	f.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		f.mu.Lock()
		f.requests = append(f.requests, received{method: r.Method, path: r.URL.Path, headers: r.Header.Clone(), body: body})
		reply := f.reply
		f.mu.Unlock()
		if reply != nil {
			reply(w, r)
			return
		}
		_, _ = w.Write([]byte(`{"Key":"x","Id":"y"}`))
	}))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fakeStorage) setReply(reply func(w http.ResponseWriter, r *http.Request)) {
	f.mu.Lock()
	f.reply = reply
	f.mu.Unlock()
}

func (f *fakeStorage) last(t *testing.T) received {
	t.Helper()
	f.mu.Lock()
	defer f.mu.Unlock()
	if len(f.requests) == 0 {
		t.Fatal("storage was not called")
	}
	return f.requests[len(f.requests)-1]
}

func (f *fakeStorage) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.requests)
}

type harness struct {
	srv        *Server
	storage    *fakeStorage
	logs       *syncBuffer
	notify     *atomic.Int32
	classifier *fakeClassifier
	policy     *fakePolicy
	holds      *fakeHolds
	rules      *fakeAttachments
	scanner    *fakeScanner
	video      *fakeVideo
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

func newHarness(t *testing.T, tweak func(*Options)) *harness {
	t.Helper()
	h := &harness{storage: newFakeStorage(t), logs: &syncBuffer{}, notify: &atomic.Int32{},
		classifier: &fakeClassifier{}, policy: &fakePolicy{loaded: true, t: defaultThresholds()}, holds: &fakeHolds{},
		rules: &fakeAttachments{loaded: true, policy: defaultAttachments()}, scanner: &fakeScanner{version: freshVersion},
		video: &fakeVideo{}}
	opts := Options{
		Log:            slog.New(slog.NewJSONHandler(h.logs, &slog.HandlerOptions{Level: slog.LevelDebug})),
		Secret:         secret,
		Storage:        storage.New(h.storage.srv.URL, 4),
		Classifier:     h.classifier,
		Policy:         h.policy,
		Holds:          h.holds,
		Attachments:    h.rules,
		Scanner:        h.scanner,
		Video:          h.video,
		MaxConcurrent:  4,
		RequestTimeout: 5 * time.Second,
		Notify:         func() { h.notify.Add(1) },
	}
	if tweak != nil {
		tweak(&opts)
	}
	h.srv = New(opts)
	return h
}

func token(t *testing.T, change func(map[string]any), key []byte) string {
	t.Helper()
	now := time.Now()
	claims := map[string]any{
		"iss": "olt-auth-bridge", "sub": sub, "aud": "authenticated", "role": "authenticated",
		"iat": now.Unix(), "exp": now.Add(time.Hour).Unix(), "app_metadata": map[string]any{"provider": "olt"},
	}
	if change != nil {
		change(claims)
	}
	tok, err := jwt.Sign(map[string]any{"alg": "HS256", "typ": "JWT"}, claims, key)
	if err != nil {
		t.Fatal(err)
	}
	return tok
}

func (h *harness) post(t *testing.T, path, tok string, body []byte, headers map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(body))
	if tok != "" {
		req.Header.Set("Authorization", "Bearer "+tok)
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	h.srv.ServeHTTP(rec, req)
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
		t.Fatalf("status = %d, want %d (%s)", rec.Code, status, rec.Body.String())
	}
	body := decode(t, rec)
	if body["code"] != code || body["message"] == "" || len(body) != 2 {
		t.Fatalf("body = %v, want code %q", body, code)
	}
	if rec.Header().Get("Content-Type") != "application/json; charset=utf-8" || rec.Header().Get("X-Request-Id") == "" && status != http.StatusNotFound {
		t.Fatalf("headers = %v", rec.Header())
	}
}

func gradient(w, h int) *image.RGBA {
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.Set(x, y, color.RGBA{R: uint8(x * 20), G: uint8(y * 20), B: 99, A: 255})
		}
	}
	return img
}

func phoneJPEG(t *testing.T) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, gradient(17, 9), nil); err != nil {
		t.Fatal(err)
	}
	tiff := []byte("MM\x00*\x00\x00\x00\x08\x00\x02")
	tiff = append(tiff, 0x01, 0x0F, 0x00, 0x02, 0x00, 0x00, 0x00, 0x0B, 0x00, 0x00, 0x00, 0x26)
	tiff = append(tiff, 0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x06, 0x00, 0x00)
	tiff = append(tiff, 0x00, 0x00, 0x00, 0x00)
	tiff = append(tiff, "GPS-SECRET\x00"...)
	app1 := append([]byte("Exif\x00\x00"), tiff...)
	seg := binary.BigEndian.AppendUint16([]byte{0xFF, 0xE1}, uint16(len(app1)+2))
	seg = append(seg, app1...)
	jpg := buf.Bytes()
	out := append(append(append([]byte(nil), jpg[:2]...), seg...), jpg[2:]...)
	return append(out, "TRAILER-SECRET"...)
}

func pngBytes(t *testing.T, w, h int) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := png.Encode(&buf, gradient(w, h)); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func gifBytes(t *testing.T) []byte {
	t.Helper()
	var buf bytes.Buffer
	img := image.NewPaletted(image.Rect(0, 0, 3, 2), color.Palette{color.Black, color.White})
	if err := gif.Encode(&buf, img, nil); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

const plainPDF = "%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n"

func verifyMinted(t *testing.T, header http.Header) map[string]any {
	t.Helper()
	tok, ok := strings.CutPrefix(header.Get("Authorization"), "Bearer ")
	if !ok {
		t.Fatalf("authorization = %q", header.Get("Authorization"))
	}
	parts := strings.Split(tok, ".")
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(parts[0] + "." + parts[1]))
	if base64.RawURLEncoding.EncodeToString(mac.Sum(nil)) != parts[2] {
		t.Fatal("minted token is not signed with the JWT secret")
	}
	raw, _ := base64.RawURLEncoding.DecodeString(parts[1])
	var claims map[string]any
	if err := json.Unmarshal(raw, &claims); err != nil {
		t.Fatal(err)
	}
	return claims
}

func TestUploadForwardsTheEdgeMarkerToStorage(t *testing.T) {
	h := newHarness(t, nil)
	tok := token(t, nil, secret)
	rec := h.post(t, "/object/attachments/posts/"+sub+"/photo.jpg", tok, phoneJPEG(t), map[string]string{"X-Olt-Edge": "public"})
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d %s", rec.Code, rec.Body.String())
	}
	if got := h.storage.last(t).headers.Get("X-Olt-Edge"); got != "public" {
		t.Fatalf("edge = %q", got)
	}
	rec = h.post(t, "/object/attachments/posts/"+sub+"/other.jpg", tok, phoneJPEG(t), nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d %s", rec.Code, rec.Body.String())
	}
	if got := h.storage.last(t).headers.Values("X-Olt-Edge"); len(got) != 0 {
		t.Fatalf("edge without marker = %v", got)
	}
}

func TestUploadStoresASanitizedPhoto(t *testing.T) {
	h := newHarness(t, nil)
	tok := token(t, nil, secret)
	before := time.Now().Unix()
	rec := h.post(t, "/object/attachments/posts/"+sub+"/photo.jpeg", tok, phoneJPEG(t),
		map[string]string{"Content-Type": "text/plain", "x-upsert": "true", "X-Request-Id": "req-123"})
	if rec.Code != http.StatusOK || rec.Header().Get("X-Request-Id") != "req-123" {
		t.Fatalf("status = %d %s", rec.Code, rec.Body.String())
	}
	got := h.storage.last(t)
	body := decode(t, rec)
	want := map[string]any{
		"bucket": "attachments", "path": "posts/" + sub + "/photo.jpg", "mime": "image/jpeg",
		"size": float64(len(got.body)), "width": float64(9), "height": float64(17),
	}
	for k, v := range want {
		if body[k] != v {
			t.Fatalf("response %s = %v, want %v (%v)", k, body[k], v, body)
		}
	}
	if len(body) != len(want) {
		t.Fatalf("response = %v", body)
	}
	if got.path != "/object/attachments/posts/"+sub+"/photo.jpg" || got.headers.Get("Content-Type") != "image/jpeg" ||
		got.headers.Get("Cache-Control") != "max-age=3600" || got.headers.Get("x-upsert") != "" {
		t.Fatalf("storage request = %s %v", got.path, got.headers)
	}
	if bytes.Contains(got.body, []byte("SECRET")) {
		t.Fatal("metadata reached storage")
	}
	if _, err := jpeg.DecodeConfig(bytes.NewReader(got.body)); err != nil {
		t.Fatal(err)
	}
	claims := verifyMinted(t, got.headers)
	if claims["media_verified"] != true || claims["sub"] != sub || claims["role"] != "authenticated" ||
		claims["aud"] != "authenticated" || claims["iss"] != "olt-auth-bridge" ||
		claims["app_metadata"].(map[string]any)["provider"] != "olt" {
		t.Fatalf("claims = %v", claims)
	}
	iat, exp := int64(claims["iat"].(float64)), int64(claims["exp"].(float64))
	if iat < before || exp-iat != 120 {
		t.Fatalf("iat = %d exp = %d", iat, exp)
	}
	logs := h.logs.String()
	if strings.Contains(logs, tok) || strings.Contains(logs, strings.Split(tok, ".")[1]) ||
		strings.Contains(logs, got.headers.Get("Authorization")[7:]) || strings.Contains(logs, "SECRET") ||
		strings.Contains(logs, sub) {
		t.Fatalf("logs leak data: %s", logs)
	}
	if !strings.Contains(logs, `"code":"ok"`) || !strings.Contains(logs, `"request_id":"req-123"`) {
		t.Fatalf("logs = %s", logs)
	}
	report := h.srv.Report()
	if report.Status != heartbeat.StatusOK || report.Detail["accepted"] != uint64(1) ||
		report.Detail["metadata_removed"] != uint64(1) || report.Detail["rejected"] != uint64(0) {
		t.Fatalf("report = %+v", report)
	}
}

func TestShortLivedTokenKeepsItsExpiry(t *testing.T) {
	h := newHarness(t, nil)
	exp := time.Now().Add(40 * time.Second).Unix()
	tok := token(t, func(c map[string]any) { c["exp"] = exp }, secret)
	if rec := h.post(t, "/object/avatars/"+sub+"/me.png", tok, pngBytes(t, 2, 2), nil); rec.Code != http.StatusOK {
		t.Fatalf("status = %d %s", rec.Code, rec.Body.String())
	}
	if claims := verifyMinted(t, h.storage.last(t).headers); int64(claims["exp"].(float64)) != exp {
		t.Fatalf("exp = %v, want %d", claims["exp"], exp)
	}
}

func TestPathValidationAndExtensionRewrite(t *testing.T) {
	png := pngBytes(t, 2, 2)
	cases := map[string]struct {
		path   string
		status int
		code   string
		final  string
	}{
		"adds extension":       {"/object/avatars/" + sub + "/avatar", 200, "", sub + "/avatar.png"},
		"replaces extension":   {"/object/avatars/" + sub + "/avatar.JPG", 200, "", sub + "/avatar.png"},
		"keeps inner dots":     {"/object/avatars/" + sub + "/my.photo.jpeg", 200, "", sub + "/my.photo.png"},
		"dot file":             {"/object/avatars/" + sub + "/.hidden", 200, "", sub + "/.hidden.png"},
		"trailing dot":         {"/object/avatars/" + sub + "/name.", 200, "", sub + "/name.png"},
		"six segments":         {"/object/attachments/a/b/c/d/e/f.png", 200, "", "a/b/c/d/e/f.png"},
		"seven segments":       {"/object/attachments/a/b/c/d/e/f/g.png", 400, codeInvalidPath, ""},
		"no path":              {"/object/avatars/", 400, codeInvalidPath, ""},
		"bucket only":          {"/object/avatars", 400, codeInvalidPath, ""},
		"empty segment":        {"/object/avatars/a//b.png", 400, codeInvalidPath, ""},
		"trailing slash":       {"/object/avatars/a/", 400, codeInvalidPath, ""},
		"dot dot":              {"/object/avatars/../b.png", 400, codeInvalidPath, ""},
		"dot":                  {"/object/avatars/a/./b.png", 400, codeInvalidPath, ""},
		"encoded slash":        {"/object/avatars/a%2Fb.png", 400, codeInvalidPath, ""},
		"space":                {"/object/avatars/a%20b.png", 400, codeInvalidPath, ""},
		"unicode":              {"/object/avatars/%C3%A9.png", 400, codeInvalidPath, ""},
		"long segment":         {"/object/avatars/" + strings.Repeat("a", 129), 400, codeInvalidPath, ""},
		"max segment":          {"/object/avatars/" + strings.Repeat("a", 128), 200, "", strings.Repeat("a", 128) + ".png"},
		"long path":            {"/object/avatars/" + strings.Repeat(strings.Repeat("a", 100)+"/", 4) + "b", 400, codeInvalidPath, ""},
		"unknown bucket":       {"/object/care-documents/x.pdf", 400, codeBucketNotAllowed, ""},
		"bucket case":          {"/object/Avatars/x.png", 400, codeBucketNotAllowed, ""},
		"no bucket":            {"/object/", 400, codeBucketNotAllowed, ""},
		"bad bucket, bad path": {"/object/nope/../x", 400, codeBucketNotAllowed, ""},
	}
	tok := token(t, nil, secret)
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			h := newHarness(t, nil)
			rec := h.post(t, tc.path, tok, png, nil)
			if tc.status != http.StatusOK {
				expectError(t, rec, tc.status, tc.code)
				if h.storage.count() != 0 {
					t.Fatal("storage must not be called")
				}
				return
			}
			if rec.Code != http.StatusOK || decode(t, rec)["path"] != tc.final {
				t.Fatalf("status = %d %s", rec.Code, rec.Body.String())
			}
			bucket := strings.Split(tc.path, "/")[2]
			if got := h.storage.last(t).path; got != "/object/"+bucket+"/"+tc.final {
				t.Fatalf("storage path = %s", got)
			}
		})
	}
}

func TestUpsertOnlyForAvatars(t *testing.T) {
	png := pngBytes(t, 2, 2)
	cases := []struct {
		path, header, want string
	}{
		{"/object/avatars/" + sub + "/a.png", "true", "true"},
		{"/object/avatars/" + sub + "/a.png", "TRUE", "true"},
		{"/object/avatars/" + sub + "/a.png", "", ""},
		{"/object/avatars/" + sub + "/a.png", "false", ""},
		{"/object/attachments/posts/" + sub + "/a.png", "true", ""},
	}
	for _, tc := range cases {
		h := newHarness(t, nil)
		headers := map[string]string{}
		if tc.header != "" {
			headers["x-upsert"] = tc.header
		}
		if rec := h.post(t, tc.path, token(t, nil, secret), png, headers); rec.Code != http.StatusOK {
			t.Fatalf("status = %d", rec.Code)
		}
		if got := h.storage.last(t).headers.Get("x-upsert"); got != tc.want {
			t.Fatalf("%s %q: x-upsert = %q", tc.path, tc.header, got)
		}
	}
}

func TestTokenVerification(t *testing.T) {
	cases := map[string]string{
		"missing":      "",
		"wrong secret": token(t, nil, []byte(strings.Repeat("x", 40))),
		"expired":      token(t, func(c map[string]any) { c["exp"] = time.Now().Add(-time.Minute).Unix() }, secret),
		"anon":         token(t, func(c map[string]any) { c["role"] = "anon" }, secret),
		"service_role": token(t, func(c map[string]any) { c["role"] = "service_role" }, secret),
		"sub not uuid": token(t, func(c map[string]any) { c["sub"] = "1001" }, secret),
		"garbage":      "not-a-jwt",
	}
	for name, tok := range cases {
		t.Run(name, func(t *testing.T) {
			h := newHarness(t, nil)
			rec := h.post(t, "/object/nope/x.png", tok, pngBytes(t, 2, 2), nil)
			expectError(t, rec, http.StatusUnauthorized, codeInvalidToken)
			if rec.Header().Get("WWW-Authenticate") == "" || h.storage.count() != 0 {
				t.Fatal("missing WWW-Authenticate or storage called")
			}
		})
	}
	h := newHarness(t, nil)
	req := httptest.NewRequest(http.MethodPost, "/object/avatars/"+sub+"/a.png", bytes.NewReader(pngBytes(t, 2, 2)))
	req.Header.Set("Authorization", "Basic "+token(t, nil, secret))
	rec := httptest.NewRecorder()
	h.srv.ServeHTTP(rec, req)
	expectError(t, rec, http.StatusUnauthorized, codeInvalidToken)
}

func TestBodyAndTypeChecks(t *testing.T) {
	pdfActive := "%PDF-1.7\n1 0 obj\n<< /OpenAction << /S /JavaScript /JS (app.alert(1)) >> >>\nendobj\n%%EOF\n"
	pdfEncrypted := strings.Replace(plainPDF, "/Root 1 0 R", "/Root 1 0 R /Encrypt 2 0 R", 1)
	bigPNG := pngBytes(t, 2, 2)
	binary.BigEndian.PutUint32(bigPNG[16:], 20000)
	cases := map[string]struct {
		bucket string
		body   []byte
		status int
		code   string
	}{
		"empty":                {"avatars", nil, 400, codeEmptyFile},
		"text":                 {"avatars", []byte("hello"), 415, codeUnsupportedType},
		"svg":                  {"attachments", []byte(`<svg xmlns="http://www.w3.org/2000/svg"/>`), 415, codeUnsupportedType},
		"gif to avatars":       {"avatars", gifBytes(t), 415, codeUnsupportedType},
		"pdf to attachments":   {"attachments", []byte(plainPDF), 415, codeUnsupportedType},
		"png to cs-documents":  {"cs-documents", pngBytes(t, 2, 2), 415, codeUnsupportedType},
		"broken png":           {"avatars", pngBytes(t, 2, 2)[:40], 422, codeInvalidImage},
		"png bad checksum":     {"avatars", bigPNG, 422, codeInvalidImage},
		"pdf javascript":       {"cs-documents", []byte(pdfActive), 422, codePDFActiveContent},
		"pdf encrypted":        {"cs-documents", []byte(pdfEncrypted), 422, codePDFEncrypted},
		"pdf without EOF":      {"cs-documents", []byte(strings.TrimSuffix(plainPDF, "%%EOF\n")), 422, codeInvalidPDF},
		"avatar over 2 MiB":    {"avatars", append(pngBytes(t, 2, 2), make([]byte, 2<<20)...), 413, codeFileTooLarge},
		"document over 10 MiB": {"cs-documents", append([]byte(plainPDF), make([]byte, 10<<20)...), 413, codeFileTooLarge},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			h := newHarness(t, nil)
			rec := h.post(t, "/object/"+tc.bucket+"/"+sub+"/file", token(t, nil, secret), tc.body, nil)
			expectError(t, rec, tc.status, tc.code)
			if h.storage.count() != 0 {
				t.Fatal("storage must not be called")
			}
			if r := h.srv.Report(); r.Detail["rejected"] != uint64(1) || r.Detail["accepted"] != uint64(0) {
				t.Fatalf("report = %+v", r)
			}
		})
	}
}

func TestImageTooLarge(t *testing.T) {
	var buf bytes.Buffer
	img := image.NewGray(image.Rect(0, 0, 10001, 1))
	if err := png.Encode(&buf, img); err != nil {
		t.Fatal(err)
	}
	h := newHarness(t, nil)
	rec := h.post(t, "/object/attachments/posts/"+sub+"/wide.png", token(t, nil, secret), buf.Bytes(), nil)
	expectError(t, rec, http.StatusUnprocessableEntity, codeImageTooLarge)
}

func TestBodyLimitWithoutContentLength(t *testing.T) {
	h := newHarness(t, nil)
	body := io.MultiReader(bytes.NewReader(pngBytes(t, 2, 2)), bytes.NewReader(make([]byte, 2<<20)))
	req := httptest.NewRequest(http.MethodPost, "/object/avatars/"+sub+"/a.png", body)
	req.ContentLength = -1
	req.Header.Set("Authorization", "Bearer "+token(t, nil, secret))
	rec := httptest.NewRecorder()
	h.srv.ServeHTTP(rec, req)
	expectError(t, rec, http.StatusRequestEntityTooLarge, codeFileTooLarge)
	if !strings.Contains(decode(t, rec)["message"].(string), "2 MB") {
		t.Fatalf("message = %v", decode(t, rec)["message"])
	}
}

func TestPDFResponseHasNoDimensions(t *testing.T) {
	h := newHarness(t, nil)
	rec := h.post(t, "/object/cs-documents/"+sub+"/surat.PDF", token(t, nil, secret), []byte(plainPDF), nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d %s", rec.Code, rec.Body.String())
	}
	body := decode(t, rec)
	if _, ok := body["width"]; ok || body["path"] != sub+"/surat.pdf" || body["mime"] != "application/pdf" ||
		body["size"] != float64(len(plainPDF)) {
		t.Fatalf("body = %v", body)
	}
	if got := h.storage.last(t); !bytes.Equal(got.body, []byte(plainPDF)) || got.headers.Get("Content-Type") != "application/pdf" {
		t.Fatal("PDF must be forwarded unchanged")
	}
}

func TestStorageErrorMapping(t *testing.T) {
	reply := func(status int, body string) func(http.ResponseWriter, *http.Request) {
		return func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(status)
			_, _ = w.Write([]byte(body))
		}
	}
	cases := map[string]struct {
		reply  func(http.ResponseWriter, *http.Request)
		status int
		code   string
	}{
		"rls":         {reply(400, `{"statusCode":"403","error":"Unauthorized","message":"new row violates row-level security policy","code":"AccessDenied"}`), 403, storage.CodeForbidden},
		"duplicate":   {reply(400, `{"statusCode":"409","error":"Duplicate","message":"The resource already exists","code":"KeyAlreadyExists"}`), 409, storage.CodeExists},
		"too large":   {reply(400, `{"statusCode":"413","error":"Payload too large","message":"The object exceeded the maximum allowed size"}`), 413, codeFileTooLarge},
		"daily limit": {reply(400, `{"statusCode":"429","error":"too_many_uploads","message":"too_many_uploads"}`), 429, storage.CodeTooMany},
		"other":       {reply(500, `{"statusCode":"500","error":"internal","message":"Internal Server Error"}`), 502, storage.CodeError},
		"bad secret":  {reply(400, `{"statusCode":"403","error":"Unauthorized","message":"signature verification failed"}`), 502, storage.CodeError},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			h := newHarness(t, nil)
			h.storage.setReply(tc.reply)
			rec := h.post(t, "/object/attachments/posts/"+sub+"/a.png", token(t, nil, secret), pngBytes(t, 2, 2), nil)
			expectError(t, rec, tc.status, tc.code)
			if r := h.srv.Report(); r.Status != heartbeat.StatusOK || r.Detail["rejected"] != uint64(1) {
				t.Fatalf("report = %+v", r)
			}
		})
	}
}

type flakyStorage struct {
	mu        sync.Mutex
	uploadErr error
	pingErr   error
}

func (f *flakyStorage) Upload(context.Context, storage.Upload) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.uploadErr
}

func (f *flakyStorage) Delete(context.Context, string, string, string) error {
	return nil
}

func (f *flakyStorage) Ping(context.Context) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.pingErr
}

func (f *flakyStorage) setPing(err error) {
	f.mu.Lock()
	f.pingErr = err
	f.mu.Unlock()
}

func metricsKey(bucket, code string) metrics.Upload {
	return metrics.Upload{Bucket: bucket, Code: code}
}

func TestUnreachableStorageDegradesTheHeartbeat(t *testing.T) {
	fake := &flakyStorage{
		uploadErr: &storage.Failure{Code: storage.CodeUnavailable, Status: 502, Reason: "connection refused", Unreachable: true},
		pingErr:   errors.New("connection refused"),
	}
	h := newHarness(t, func(o *Options) { o.Storage = fake })
	tok := token(t, nil, secret)
	for i := 0; i < 2; i++ {
		rec := h.post(t, "/object/attachments/posts/"+sub+"/a.png", tok, pngBytes(t, 2, 2), nil)
		expectError(t, rec, http.StatusBadGateway, storage.CodeUnavailable)
	}
	if h.srv.Report().Status != heartbeat.StatusOK || h.notify.Load() != 0 {
		t.Fatal("two failures must not degrade")
	}
	h.srv.ProbeStorage(context.Background())
	r := h.srv.Report()
	if r.Status != heartbeat.StatusDegraded || !strings.Contains(r.Error, "3 kali") || h.notify.Load() != 1 {
		t.Fatalf("report = %+v notify = %d", r, h.notify.Load())
	}
	h.srv.ProbeStorage(context.Background())
	if h.notify.Load() != 1 {
		t.Fatal("notify only on a status change")
	}
	fake.setPing(nil)
	h.srv.ProbeStorage(context.Background())
	if r := h.srv.Report(); r.Status != heartbeat.StatusOK || r.Error != "" || h.notify.Load() != 2 {
		t.Fatalf("report = %+v notify = %d", r, h.notify.Load())
	}
	if m := h.srv.Metrics(); m.StorageFailures != 0 || m.Uploads[metricsKey("attachments", storage.CodeUnavailable)] != 2 {
		t.Fatalf("metrics = %+v", m)
	}
}

func TestStorageUnavailableOverHTTP(t *testing.T) {
	h := newHarness(t, nil)
	h.storage.srv.Close()
	rec := h.post(t, "/object/attachments/posts/"+sub+"/a.png", token(t, nil, secret), pngBytes(t, 2, 2), nil)
	expectError(t, rec, http.StatusBadGateway, storage.CodeUnavailable)
	if m := h.srv.Metrics(); m.StorageFailures != 1 {
		t.Fatalf("failures = %d", m.StorageFailures)
	}
}

func TestBusyWhenAllSlotsAreTaken(t *testing.T) {
	entered := make(chan struct{})
	release := make(chan struct{})
	h := newHarness(t, func(o *Options) {
		o.MaxConcurrent = 1
		o.QueueWait = 50 * time.Millisecond
	})
	h.storage.setReply(func(w http.ResponseWriter, _ *http.Request) {
		close(entered)
		<-release
		_, _ = w.Write([]byte(`{}`))
	})
	tok := token(t, nil, secret)
	done := make(chan int)
	first := pngBytes(t, 2, 2)
	go func() {
		req := httptest.NewRequest(http.MethodPost, "/object/attachments/posts/"+sub+"/a.png", bytes.NewReader(first))
		req.Header.Set("Authorization", "Bearer "+tok)
		rec := httptest.NewRecorder()
		h.srv.ServeHTTP(rec, req)
		done <- rec.Code
	}()
	<-entered
	if m := h.srv.Metrics(); m.Inflight != 1 || m.Capacity != 1 {
		t.Fatalf("metrics = %+v", m)
	}
	rec := h.post(t, "/object/attachments/posts/"+sub+"/b.png", tok, pngBytes(t, 2, 2), nil)
	expectError(t, rec, http.StatusServiceUnavailable, codeBusy)
	if rec.Header().Get("Retry-After") == "" {
		t.Fatal("missing Retry-After")
	}
	close(release)
	if code := <-done; code != http.StatusOK {
		t.Fatalf("first upload = %d", code)
	}
	if m := h.srv.Metrics(); m.Inflight != 0 {
		t.Fatalf("slot not released: %+v", m)
	}
}

func TestSlowUploadTimesOut(t *testing.T) {
	h := newHarness(t, func(o *Options) { o.RequestTimeout = 300 * time.Millisecond })
	srv := httptest.NewServer(h.srv)
	defer srv.Close()
	pr, pw := io.Pipe()
	defer pw.Close()
	go func() {
		_, _ = pw.Write(pngBytes(t, 2, 2)[:20])
	}()
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/object/avatars/"+sub+"/a.png", pr)
	req.Header.Set("Authorization", "Bearer "+token(t, nil, secret))
	resp, err := srv.Client().Do(req)
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

func TestOtherRoutesAreNotFound(t *testing.T) {
	h := newHarness(t, nil)
	for _, r := range []struct{ method, path string }{
		{http.MethodGet, "/object/avatars/a.png"},
		{http.MethodPut, "/object/avatars/a.png"},
		{http.MethodPost, "/upload/avatars/a.png"},
		{http.MethodGet, "/"},
		{http.MethodGet, "/metrics"},
	} {
		rec := httptest.NewRecorder()
		h.srv.ServeHTTP(rec, httptest.NewRequest(r.method, r.path, nil))
		expectError(t, rec, http.StatusNotFound, codeNotFound)
	}
	if m := h.srv.Metrics(); m.Requests != 0 {
		t.Fatal("404s are not uploads")
	}
}

func TestRequestIDIsGeneratedWhenMissingOrUnsafe(t *testing.T) {
	h := newHarness(t, nil)
	for _, given := range []string{"", "has space", strings.Repeat("a", 65), "a\"b"} {
		rec := h.post(t, "/object/nope/x.png", "", nil, map[string]string{"X-Request-Id": given})
		id := rec.Header().Get("X-Request-Id")
		if id == given || len(id) != 16 {
			t.Fatalf("given %q got %q", given, id)
		}
	}
}

func TestReportAndMetricsCountOutcomes(t *testing.T) {
	h := newHarness(t, nil)
	tok := token(t, nil, secret)
	h.post(t, "/object/avatars/"+sub+"/a.png", tok, pngBytes(t, 2, 2), nil)
	h.post(t, "/object/attachments/posts/"+sub+"/b.jpg", tok, phoneJPEG(t), nil)
	h.post(t, "/object/avatars/"+sub+"/c.png", "", nil, nil)
	h.post(t, "/object/nope/c.png", tok, nil, nil)
	r := h.srv.Report()
	if r.Detail["accepted"] != uint64(2) || r.Detail["rejected"] != uint64(2) || r.Detail["metadata_removed"] != uint64(1) {
		t.Fatalf("report = %+v", r)
	}
	m := h.srv.Metrics()
	want := map[[2]string]uint64{
		{"avatars", "ok"}: 1, {"attachments", "ok"}: 1, {"avatars", codeInvalidToken}: 1, {otherBucket, codeBucketNotAllowed}: 1,
	}
	for k, v := range want {
		if m.Uploads[metricsKey(k[0], k[1])] != v {
			t.Fatalf("uploads = %v", m.Uploads)
		}
	}
	if m.Requests != 4 || m.MetadataRemoved != 1 || m.StoredBytes == 0 || m.ReceivedBytes <= m.StoredBytes {
		t.Fatalf("metrics = %+v", m)
	}
}
