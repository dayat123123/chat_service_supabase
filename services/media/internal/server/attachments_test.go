package server

import (
	"archive/zip"
	"bytes"
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/media/internal/attachments"
	"olt-social/media/internal/clamd"
	"olt-social/media/internal/heartbeat"
	"olt-social/media/internal/sniff"
	"olt-social/media/internal/video"
)

const (
	room         = "0b7c9d1e-2f3a-4b5c-8d6e-7f8091a2b3c4"
	eicar        = `X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*`
	docxMain     = "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"
	docxMIME     = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
	contentTypes = `<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">` +
		`<Default Extension="xml" ContentType="application/xml"/>%s<Override PartName="/word/document.xml" ContentType="%s"/></Types>`
)

var freshVersion = "ClamAV 1.5.4/27820/" + time.Now().UTC().Format("Mon Jan _2 15:04:05 2006")

type fakeAttachments struct {
	mu     sync.Mutex
	loaded bool
	policy attachments.Policy
}

func (f *fakeAttachments) Current() (attachments.Policy, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if !f.loaded {
		return nil, false
	}
	return f.policy, true
}

func (f *fakeAttachments) change(kind string, edit func(*attachments.Rule)) {
	f.mu.Lock()
	defer f.mu.Unlock()
	r := f.policy[kind]
	edit(&r)
	f.policy[kind] = r
}

func formats(codes ...string) []attachments.Format {
	out := make([]attachments.Format, 0, len(codes))
	for _, c := range codes {
		out = append(out, attachments.Format{Code: c})
	}
	return out
}

func defaultAttachments() attachments.Policy {
	return attachments.Policy{
		"documents": {Enabled: true, Bucket: "cs-documents", MaxBytes: 10 << 20,
			Formats: formats("pdf", "docx", "xlsx", "pptx", "txt", "csv")},
		"images": {Enabled: true, Bucket: "attachments", MaxBytes: 5 << 20, Formats: formats("jpeg", "png", "webp", "gif")},
		"videos": {Enabled: true, Bucket: "cs-videos", MaxBytes: 25 << 20, MaxSeconds: 120, Formats: formats("mp4", "mov", "webm")},
	}
}

type fakeScanner struct {
	mu      sync.Mutex
	calls   int
	err     error
	version string
	verErr  error
}

func (f *fakeScanner) Scan(_ context.Context, body []byte) (clamd.Result, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls++
	if f.err != nil {
		return clamd.Result{}, f.err
	}
	if bytes.Contains(body, []byte("EICAR-STANDARD-ANTIVIRUS-TEST-FILE")) {
		return clamd.Result{Infected: true, Signature: "Eicar-Test-Signature"}, nil
	}
	return clamd.Result{}, nil
}

func (f *fakeScanner) Version(context.Context) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.version, f.verErr
}

func (f *fakeScanner) set(err, verErr error) {
	f.mu.Lock()
	f.err, f.verErr = err, verErr
	f.mu.Unlock()
}

func (f *fakeScanner) count() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.calls
}

type fakeVideo struct {
	mu     sync.Mutex
	calls  []string
	result *video.Result
	err    error
}

func (f *fakeVideo) Process(_ context.Context, body []byte, kind sniff.Kind, maxSeconds float64) (video.Result, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, fmt.Sprintf("%s %d %g", kind, len(body), maxSeconds))
	if f.err != nil {
		return video.Result{}, f.err
	}
	if f.result != nil {
		return *f.result, nil
	}
	return video.Result{Body: []byte("remuxed-without-metadata"), Thumbnail: []byte("thumb-jpeg"), Duration: 12.345,
		Width: 720, Height: 1280}, nil
}

func officeZip(t *testing.T, mainType, extraTypes string, files map[string][]byte) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	all := map[string][]byte{
		"[Content_Types].xml": []byte(fmt.Sprintf(contentTypes, extraTypes, mainType)),
		"_rels/.rels": []byte(`<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` +
			`<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>`),
		"word/document.xml": []byte(`<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Halo</w:t></w:r></w:p></w:body></w:document>`),
	}
	for k, v := range files {
		all[k] = v
	}
	for name, body := range all {
		w, err := zw.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		_, _ = w.Write(body)
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func docPath(name string) string {
	return "/object/cs-documents/rooms/" + room + "/" + sub + "/" + name
}

func videoPath(name string) string {
	return "/object/cs-videos/rooms/" + room + "/" + sub + "/" + name
}

func TestOfficeDocumentIsScannedAndStoredUnchanged(t *testing.T) {
	h := newHarness(t, nil)
	docx := officeZip(t, docxMain, "", nil)
	rec := h.post(t, docPath("laporan.zip"), token(t, nil, secret), docx, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d %s", rec.Code, rec.Body.String())
	}
	body := decode(t, rec)
	if body["mime"] != docxMIME || body["path"] != "rooms/"+room+"/"+sub+"/laporan.docx" || body["size"] != float64(len(docx)) {
		t.Fatalf("body = %v", body)
	}
	if _, ok := body["width"]; ok {
		t.Fatalf("documents have no dimensions: %v", body)
	}
	got := h.storage.last(t)
	if !bytes.Equal(got.body, docx) || got.headers.Get("Content-Type") != docxMIME {
		t.Fatal("office document must be stored byte for byte")
	}
	if h.scanner.count() != 1 || h.classifier.count() != 0 {
		t.Fatalf("scanner = %d classifier = %d", h.scanner.count(), h.classifier.count())
	}
}

func TestUnsafeDocumentsAreRejectedBeforeScanning(t *testing.T) {
	manyFiles := map[string][]byte{}
	for i := range 1001 {
		manyFiles[fmt.Sprintf("word/media/p%04d.xml", i)] = []byte("<a/>")
	}
	cases := map[string]struct {
		body   []byte
		name   string
		status int
		code   string
	}{
		"docx with vba project": {officeZip(t, docxMain, "", map[string][]byte{"word/vbaProject.bin": []byte("macro")}), "a.docx", 422, codeOfficeMacro},
		"docm content type":     {officeZip(t, "application/vnd.ms-word.document.macroEnabled.main+xml", "", nil), "a.docx", 422, codeOfficeMacro},
		"ole object":            {officeZip(t, docxMain, "", map[string][]byte{"word/embeddings/oleObject1.bin": []byte("ole")}), "a.docx", 422, codeOfficeUnsafe},
		"activex":               {officeZip(t, docxMain, "", map[string][]byte{"word/activeX/activeX1.xml": []byte("<ax/>")}), "a.docx", 422, codeOfficeUnsafe},
		"zip bomb":              {officeZip(t, docxMain, "", map[string][]byte{"word/media/zeros.xml": make([]byte, 4<<20)}), "a.docx", 422, codeArchiveBomb},
		"too many entries":      {officeZip(t, docxMain, "", manyFiles), "a.docx", 422, codeArchiveBomb},
		"exe renamed to pdf":    {append([]byte("MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xff\xff"), make([]byte, 64)...), "invoice.pdf", 415, codeUnsupportedType},
		"exe renamed to txt":    {append([]byte("MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xff\xff"), make([]byte, 64)...), "notes.txt", 422, codeInvalidText},
		"csv invalid utf-8":     {[]byte("nama,saldo\nbudi,\xff\xfe100\n"), "rekening.csv", 422, codeInvalidText},
		"html named txt":        {[]byte("<!DOCTYPE html><script>alert(1)</script>"), "page.txt", 415, codeUnsupportedType},
		"script with js ext":    {[]byte("alert(1)"), "run.js", 415, codeUnsupportedType},
		"plain zip":             {func() []byte { b := officeZip(t, "application/zip", "", nil); return b }(), "a.zip", 415, codeUnsupportedType},
		"video to documents":    {mp4Header(), "clip.mp4", 415, codeUnsupportedType},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			h := newHarness(t, nil)
			rec := h.post(t, docPath(tc.name), token(t, nil, secret), tc.body, nil)
			expectError(t, rec, tc.status, tc.code)
			if h.storage.count() != 0 || h.scanner.count() != 0 {
				t.Fatalf("storage = %d scanner = %d", h.storage.count(), h.scanner.count())
			}
		})
	}
}

func TestTextDocumentsTakeTheirKindFromTheExtension(t *testing.T) {
	cases := map[string]struct {
		name, mime, path string
		body             []byte
	}{
		"csv":           {"rekening.csv", "text/csv", "rekening.csv", []byte("\xEF\xBB\xBFnama;saldo\nbudi;100\n")},
		"txt":           {"catatan.TXT", "text/plain", "catatan.txt", []byte("Halo CS, aplikasi error saat login.\n")},
		"log as txt":    {"app.log", "text/plain", "app.txt", []byte("2026-11-09 error: timeout\n")},
		"pdf stays pdf": {"surat.csv", "application/pdf", "surat.pdf", []byte(plainPDF)},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			h := newHarness(t, nil)
			rec := h.post(t, docPath(tc.name), token(t, nil, secret), tc.body, nil)
			if rec.Code != http.StatusOK {
				t.Fatalf("status = %d %s", rec.Code, rec.Body.String())
			}
			body := decode(t, rec)
			if body["mime"] != tc.mime || body["path"] != "rooms/"+room+"/"+sub+"/"+tc.path {
				t.Fatalf("body = %v", body)
			}
			if !bytes.Equal(h.storage.last(t).body, tc.body) {
				t.Fatal("text must be stored unchanged")
			}
		})
	}
}

func TestMalwareIsRejectedBeforeStoring(t *testing.T) {
	h := newHarness(t, nil)
	rec := h.post(t, docPath("eicar.txt"), token(t, nil, secret), []byte(eicar), nil)
	expectError(t, rec, http.StatusUnprocessableEntity, codeMalwareDetected)
	if h.storage.count() != 0 || h.scanner.count() != 1 {
		t.Fatal("infected file reached storage")
	}
	if !strings.Contains(h.logs.String(), "Eicar-Test-Signature") {
		t.Fatalf("logs = %s", h.logs.String())
	}
	if r := h.srv.Report(); r.Status != heartbeat.StatusOK || r.Detail["malware_detected"] != uint64(1) || r.Detail["scanned"] != uint64(1) {
		t.Fatalf("report = %+v", r)
	}
	rec = h.post(t, videoPath("clip.mp4"), token(t, nil, secret), append(mp4Header(), eicar...), nil)
	expectError(t, rec, http.StatusUnprocessableEntity, codeMalwareDetected)
	if len(h.video.calls) != 0 {
		t.Fatal("infected video must not reach ffmpeg")
	}
	if m := h.srv.Metrics(); m.Infected != 2 || m.Scanned != 2 {
		t.Fatalf("metrics = %+v", m)
	}
}

func TestScannerDownFailsClosedAndDegradesTheHeartbeat(t *testing.T) {
	h := newHarness(t, nil)
	h.scanner.set(fmt.Errorf("%w: dial tcp clamav:3310: connection refused", clamd.ErrUnavailable), nil)
	for range failThreshold {
		rec := h.post(t, docPath("surat.pdf"), token(t, nil, secret), []byte(plainPDF), nil)
		expectError(t, rec, http.StatusServiceUnavailable, codeScannerUnavailable)
		if rec.Header().Get("Retry-After") == "" {
			t.Fatal("missing Retry-After")
		}
	}
	if h.storage.count() != 0 {
		t.Fatal("unscanned file reached storage")
	}
	r := h.srv.Report()
	if r.Status != heartbeat.StatusDegraded || !strings.Contains(r.Error, "Pemindai antivirus tidak bisa dihubungi (3 kali berturut-turut)") ||
		r.Detail["scanner_failures"] != failThreshold {
		t.Fatalf("report = %+v", r)
	}
	if h.notify.Load() != 1 {
		t.Fatalf("notify = %d", h.notify.Load())
	}
	rec := h.post(t, "/object/attachments/posts/"+sub+"/a.png", token(t, nil, secret), pngBytes(t, 2, 2), nil)
	if rec.Code != http.StatusOK || h.scanner.count() != failThreshold {
		t.Fatal("images do not depend on the scanner")
	}
	h.scanner.set(nil, nil)
	h.srv.Probe(context.Background())
	if r := h.srv.Report(); r.Status != heartbeat.StatusOK || r.Detail["scanner_version"] != freshVersion {
		t.Fatalf("report after recovery = %+v", r)
	}
	if h.notify.Load() != 2 {
		t.Fatalf("notify = %d", h.notify.Load())
	}
}

func TestScannerProbeFailuresAndStaleSignatures(t *testing.T) {
	h := newHarness(t, nil)
	h.scanner.set(nil, errors.New("connection refused"))
	for range failThreshold {
		h.srv.ProbeScanner(context.Background())
	}
	if r := h.srv.Report(); r.Status != heartbeat.StatusDegraded || !strings.Contains(r.Error, "Pemindai antivirus") {
		t.Fatalf("report = %+v", r)
	}
	h.scanner.mu.Lock()
	h.scanner.version, h.scanner.verErr = "ClamAV 1.5.4/27000/Mon Oct  5 08:00:00 2026", nil
	h.scanner.mu.Unlock()
	h.srv.ProbeScanner(context.Background())
	r := h.srv.Report()
	if r.Status != heartbeat.StatusDegraded || !strings.Contains(r.Error, "belum diperbarui sejak 5 Oct 2026") {
		t.Fatalf("report = %+v", r)
	}
}

func TestAttachmentPolicyIsEnforcedPerBucket(t *testing.T) {
	t.Run("not loaded", func(t *testing.T) {
		h := newHarness(t, nil)
		h.rules.loaded = false
		for _, p := range []string{docPath("a.pdf"), videoPath("a.mp4")} {
			expectError(t, h.post(t, p, token(t, nil, secret), []byte(plainPDF), nil), http.StatusServiceUnavailable, codePolicyUnavailable)
		}
		rec := h.post(t, "/object/attachments/rooms/"+room+"/"+sub+"/a.png", token(t, nil, secret), pngBytes(t, 2, 2), nil)
		if rec.Code != http.StatusOK {
			t.Fatalf("images keep working without the attachment policy: %d", rec.Code)
		}
		if r := h.srv.Report(); r.Status != heartbeat.StatusDegraded || !strings.Contains(r.Error, "Kebijakan lampiran chat CS belum termuat") ||
			r.Detail["attachment_policy_loaded"] != false {
			t.Fatalf("report = %+v", r)
		}
	})
	t.Run("kind disabled", func(t *testing.T) {
		h := newHarness(t, nil)
		h.rules.change("videos", func(r *attachments.Rule) { r.Enabled = false })
		expectError(t, h.post(t, videoPath("a.mp4"), token(t, nil, secret), mp4Header(), nil), http.StatusForbidden, codeKindDisabled)
		if len(h.video.calls) != 0 || h.scanner.count() != 0 {
			t.Fatal("disabled kind must be refused before any work")
		}
		if rec := h.post(t, docPath("a.pdf"), token(t, nil, secret), []byte(plainPDF), nil); rec.Code != http.StatusOK {
			t.Fatalf("documents still enabled: %d", rec.Code)
		}
	})
	t.Run("format narrowed", func(t *testing.T) {
		h := newHarness(t, nil)
		h.rules.change("documents", func(r *attachments.Rule) { r.Formats = formats("pdf") })
		expectError(t, h.post(t, docPath("a.docx"), token(t, nil, secret), officeZip(t, docxMain, "", nil), nil),
			http.StatusUnsupportedMediaType, codeUnsupportedType)
		h.rules.change("videos", func(r *attachments.Rule) { r.Formats = formats("mp4") })
		expectError(t, h.post(t, videoPath("a.mov"), token(t, nil, secret), movHeader(), nil), http.StatusUnsupportedMediaType, codeUnsupportedType)
	})
	t.Run("lower size limit", func(t *testing.T) {
		h := newHarness(t, nil)
		h.rules.change("documents", func(r *attachments.Rule) { r.MaxBytes = 1 << 20 })
		rec := h.post(t, docPath("a.txt"), token(t, nil, secret), bytes.Repeat([]byte("a"), 1<<20+1), nil)
		expectError(t, rec, http.StatusRequestEntityTooLarge, codeFileTooLarge)
		if !strings.Contains(decode(t, rec)["message"].(string), "1 MB") {
			t.Fatalf("message = %v", decode(t, rec)["message"])
		}
	})
	t.Run("policy cannot raise the bucket ceiling", func(t *testing.T) {
		h := newHarness(t, nil)
		h.rules.change("documents", func(r *attachments.Rule) { r.MaxBytes = 50 << 20 })
		rec := h.post(t, docPath("a.txt"), token(t, nil, secret), bytes.Repeat([]byte("a"), 10<<20+1), nil)
		expectError(t, rec, http.StatusRequestEntityTooLarge, codeFileTooLarge)
	})
	t.Run("max seconds reaches the video processor", func(t *testing.T) {
		h := newHarness(t, nil)
		h.rules.change("videos", func(r *attachments.Rule) { r.MaxSeconds = 30 })
		if rec := h.post(t, videoPath("a.webm"), token(t, nil, secret), webmHeader(), nil); rec.Code != http.StatusOK {
			t.Fatalf("status = %d %s", rec.Code, rec.Body.String())
		}
		if h.video.calls[0] != fmt.Sprintf("webm %d 30", len(webmHeader())) {
			t.Fatalf("calls = %v", h.video.calls)
		}
	})
}

func TestVideoIsRemuxedWithAThumbnail(t *testing.T) {
	h := newHarness(t, nil)
	rec := h.post(t, videoPath("layar.MOV"), token(t, nil, secret), movHeader(), map[string]string{"X-Olt-Edge": "public"})
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d %s", rec.Code, rec.Body.String())
	}
	body := decode(t, rec)
	base := "rooms/" + room + "/" + sub + "/layar"
	want := map[string]any{"bucket": "cs-videos", "path": base + ".mov", "mime": "video/quicktime",
		"size": float64(len("remuxed-without-metadata")), "width": float64(720), "height": float64(1280),
		"duration": 12.345, "thumbnail": base + ".jpg"}
	for k, v := range want {
		if body[k] != v {
			t.Fatalf("response %s = %v, want %v (%v)", k, body[k], v, body)
		}
	}
	if len(body) != len(want) {
		t.Fatalf("response = %v", body)
	}
	h.storage.mu.Lock()
	reqs := append([]received(nil), h.storage.requests...)
	h.storage.mu.Unlock()
	if len(reqs) != 2 || reqs[0].path != "/object/cs-videos/"+base+".jpg" || reqs[0].headers.Get("Content-Type") != "image/jpeg" ||
		string(reqs[0].body) != "thumb-jpeg" || reqs[1].path != "/object/cs-videos/"+base+".mov" ||
		reqs[1].headers.Get("Content-Type") != "video/quicktime" || string(reqs[1].body) != "remuxed-without-metadata" {
		t.Fatalf("storage requests = %+v", reqs)
	}
	for _, r := range reqs {
		if verifyMinted(t, r.headers)["media_verified"] != true || r.headers.Get("X-Olt-Edge") != "public" {
			t.Fatal("thumbnail and video use the verified token and the edge marker")
		}
	}
	if h.scanner.count() != 1 || h.classifier.count() != 0 {
		t.Fatal("videos are scanned once and not classified")
	}
}

func TestVideoErrors(t *testing.T) {
	cases := map[string]struct {
		err    error
		status int
		code   string
	}{
		"too long": {fmt.Errorf("%w: 150.00 s", video.ErrTooLong), 422, codeVideoTooLong},
		"invalid":  {fmt.Errorf("%w: video codec \"mpeg4\"", video.ErrInvalid), 422, codeInvalidVideo},
		"busy":     {video.ErrBusy, 503, codeBusy},
		"tool":     {fmt.Errorf("%w: ffmpeg not found", video.ErrTool), 500, codeInternal},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			h := newHarness(t, nil)
			h.video.err = tc.err
			rec := h.post(t, videoPath("a.mp4"), token(t, nil, secret), mp4Header(), nil)
			expectError(t, rec, tc.status, tc.code)
			if h.storage.count() != 0 {
				t.Fatal("storage must not be called")
			}
			if name == "too long" && !strings.Contains(decode(t, rec)["message"].(string), "2 minutes") {
				t.Fatalf("message = %v", decode(t, rec)["message"])
			}
		})
	}
}

func TestVideoBucketRejectsOtherKinds(t *testing.T) {
	h := newHarness(t, nil)
	for _, body := range [][]byte{phoneJPEG(t), []byte(plainPDF), heicHeader()} {
		expectError(t, h.post(t, videoPath("a.mp4"), token(t, nil, secret), body, nil), http.StatusUnsupportedMediaType, codeUnsupportedType)
	}
	if len(h.video.calls) != 0 || h.storage.count() != 0 {
		t.Fatal("only videos reach the processor")
	}
}

func TestThumbnailFailureStopsTheVideo(t *testing.T) {
	h := newHarness(t, nil)
	h.storage.setReply(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"statusCode":"409","error":"Duplicate","message":"The resource already exists"}`))
	})
	expectError(t, h.post(t, videoPath("a.mp4"), token(t, nil, secret), mp4Header(), nil), http.StatusConflict, "already_exists")
	if h.storage.count() != 1 {
		t.Fatalf("storage calls = %d", h.storage.count())
	}
}

func mp4Header() []byte {
	return append([]byte("\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom"), make([]byte, 32)...)
}

func movHeader() []byte {
	return append([]byte("\x00\x00\x00\x14ftypqt  \x00\x00\x00\x00qt  "), make([]byte, 32)...)
}

func heicHeader() []byte {
	return append([]byte("\x00\x00\x00\x18ftypheic\x00\x00\x00\x00mif1heic"), make([]byte, 32)...)
}

func webmHeader() []byte {
	return []byte("\x1a\x45\xdf\xa3\x9f\x42\x86\x81\x01\x42\xf7\x81\x01\x42\xf2\x81\x04\x42\xf3\x81\x08\x42\x82\x84webm\x42\x87\x81\x04\x42\x85\x81\x02")
}
