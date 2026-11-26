package api

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"regexp"
	"strings"
	"sync/atomic"
	"testing"

	"olt-social/research/internal/store"
)

const (
	fileUUID = "0b6a4f1e-2c3d-4e5f-8a9b-0c1d2e3f4a5b"
	pdfType  = "application/pdf"
	xlsxType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
)

var documentObject = regexp.MustCompile(`^research/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/file\.(pdf|xlsx)$`)

func samplePDF() []byte {
	return []byte("%PDF-1.7\n1 0 obj << /Type /Catalog >> endobj\n%%EOF\n")
}

func postDocument(s *Server, id string, body []byte, contentType, query string) *httptest.ResponseRecorder {
	target := "/research/" + id + "/documents"
	if query != "" {
		target += "?" + query
	}
	req := httptest.NewRequest(http.MethodPost, target, bytes.NewReader(body))
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	req.Header.Set("Authorization", "Bearer "+secret)
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, req)
	return rec
}

func TestDocumentIsStreamedToStorageAndRegistered(t *testing.T) {
	var accepted atomic.Int32
	st := &fakeStore{fileOut: `{"id":"ID","status":"queued"}`, docOut: `{"id":"d1","status":"queued","resubmitted":false}`}
	objects := &fakeObjects{}
	s := newServer(fakeKeys{key: validKey()}, st, objects, &accepted)
	data := samplePDF()
	rec := postDocument(s, fileUUID, data, pdfType, "name="+url.QueryEscape("Laporan Keuangan ITMG Q3 2026.pdf"))
	if rec.Code != http.StatusAccepted || accepted.Load() != 1 {
		t.Fatalf("status %d accepted %d body %s", rec.Code, accepted.Load(), rec.Body)
	}
	if len(objects.puts) != 1 {
		t.Fatalf("puts = %+v", objects.puts)
	}
	p := objects.puts[0]
	if p.bucket != "post-files" || !documentObject.MatchString(p.name) || !strings.HasSuffix(p.name, ".pdf") ||
		p.mime != pdfType || !bytes.Equal(p.data, data) || p.size != int64(len(data)) {
		t.Fatalf("put = %+v", p)
	}
	sum := sha256.Sum256(data)
	want := strings.Join([]string{"k1", fileUUID, p.name, hex.EncodeToString(sum[:]), "Laporan Keuangan ITMG Q3 2026.pdf"}, "|")
	if len(st.docs) != 1 || st.docs[0] != want || len(objects.removed) != 0 {
		t.Fatalf("docs %v removed %v", st.docs, objects.removed)
	}
	if snap := s.Snapshot(); snap.Requests[Request{Endpoint: EndpointDocument, Code: "ok"}] != 1 || snap.Bytes != uint64(len(data)) {
		t.Fatalf("snapshot = %+v", snap)
	}
}

func TestResubmittedDocumentDropsTheCopy(t *testing.T) {
	var accepted atomic.Int32
	st := &fakeStore{fileOut: `{"status":"done"}`, docOut: `{"id":"d1","status":"ready","resubmitted":true}`}
	objects := &fakeObjects{}
	s := newServer(fakeKeys{key: validKey()}, st, objects, &accepted)
	rec := postDocument(s, fileUUID, []byte("PK\x03\x04workbook"), xlsxType, "")
	if rec.Code != http.StatusOK || accepted.Load() != 0 {
		t.Fatalf("status %d accepted %d", rec.Code, accepted.Load())
	}
	if len(objects.puts) != 1 || len(objects.removed) != 1 || objects.removed[0] != "post-files/"+objects.puts[0].name ||
		!strings.HasSuffix(objects.puts[0].name, ".xlsx") {
		t.Fatalf("puts %+v removed %v", objects.puts, objects.removed)
	}
}

func TestDocumentRejectsBadRequests(t *testing.T) {
	var accepted atomic.Int32
	cases := []struct {
		name    string
		id      string
		body    []byte
		ctype   string
		query   string
		fileOut string
		fileErr error
		status  int
		code    string
	}{
		{"bad id", "nope", samplePDF(), pdfType, "", `{}`, nil, 400, codeInvalidID},
		{"zip", fileUUID, samplePDF(), "application/zip", "", `{}`, nil, 415, codeUnsupportedDocument},
		{"old excel", fileUUID, samplePDF(), "application/vnd.ms-excel", "", `{}`, nil, 415, codeUnsupportedDocument},
		{"name", fileUUID, samplePDF(), pdfType, "name=a%2Fb.pdf", `{}`, nil, 400, codeInvalidDocumentName},
		{"empty", fileUUID, nil, pdfType, "", `{}`, nil, 400, codeEmptyBody},
		{"too large", fileUUID, append(samplePDF(), make([]byte, 1<<20)...), pdfType, "", `{}`, nil, 413, codeBodyTooLarge},
		{"unknown file", fileUUID, samplePDF(), pdfType, "", "", &store.APIError{Status: 404, Code: "file_not_found"}, 404,
			"file_not_found"},
		{"rejected file", fileUUID, samplePDF(), pdfType, "", `{"status":"rejected"}`, nil, 409, codeFileRejected},
		{"html as pdf", fileUUID, []byte("<html>%%EOF</html>"), pdfType, "", `{"status":"queued"}`, nil, 400, codeInvalidDocument},
		{"pdf as xlsx", fileUUID, samplePDF(), xlsxType, "", `{"status":"queued"}`, nil, 400, codeInvalidDocument},
	}
	for _, c := range cases {
		objects := &fakeObjects{}
		st := &fakeStore{fileOut: c.fileOut, fileErr: c.fileErr, docOut: `{}`}
		s := newServer(fakeKeys{key: validKey()}, st, objects, &accepted)
		rec := postDocument(s, c.id, c.body, c.ctype, c.query)
		if rec.Code != c.status || errorCode(t, rec) != c.code {
			t.Errorf("%s: %d %s, want %d %s", c.name, rec.Code, rec.Body, c.status, c.code)
		}
		if len(objects.puts) != 0 || len(st.docs) != 0 {
			t.Errorf("%s: stored before validation", c.name)
		}
	}
}

func TestDocumentNeedsALength(t *testing.T) {
	var accepted atomic.Int32
	s := newServer(fakeKeys{key: validKey()}, &fakeStore{fileOut: `{}`}, &fakeObjects{}, &accepted)
	req := httptest.NewRequest(http.MethodPost, "/research/"+fileUUID+"/documents", bytes.NewReader(samplePDF()))
	req.ContentLength = -1
	req.Header.Set("Content-Type", pdfType)
	req.Header.Set("Authorization", "Bearer "+secret)
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, req)
	if rec.Code != http.StatusLengthRequired || errorCode(t, rec) != codeLengthRequired {
		t.Fatalf("status %d body %s", rec.Code, rec.Body)
	}
	req = httptest.NewRequest(http.MethodGet, "/research/"+fileUUID+"/documents", nil)
	rec = httptest.NewRecorder()
	s.ServeHTTP(rec, req)
	if rec.Code != http.StatusMethodNotAllowed || rec.Header().Get("Allow") != http.MethodPost {
		t.Fatalf("method %d %v", rec.Code, rec.Header())
	}
}

func TestDocumentFailuresRemoveTheUpload(t *testing.T) {
	var accepted atomic.Int32
	st := &fakeStore{fileOut: `{"status":"queued"}`,
		docErr: &store.APIError{Status: 409, Code: "too_many_documents", Detail: "Maksimal 3 dokumen per laporan"}}
	objects := &fakeObjects{}
	s := newServer(fakeKeys{key: validKey()}, st, objects, &accepted)
	rec := postDocument(s, fileUUID, samplePDF(), pdfType, "")
	if rec.Code != 409 || errorCode(t, rec) != "too_many_documents" || !strings.Contains(rec.Body.String(), "3 dokumen") {
		t.Fatalf("status %d body %s", rec.Code, rec.Body)
	}
	if len(objects.removed) != 1 || objects.removed[0] != "post-files/"+objects.puts[0].name {
		t.Fatalf("removed %v", objects.removed)
	}
	objects = &fakeObjects{err: errors.New("storage down")}
	s = newServer(fakeKeys{key: validKey()}, &fakeStore{fileOut: `{"status":"queued"}`}, objects, &accepted)
	if rec := postDocument(s, fileUUID, samplePDF(), pdfType, ""); rec.Code != 503 || rec.Header().Get("Retry-After") != "5" {
		t.Fatalf("storage down: %d %v", rec.Code, rec.Header())
	}
}
