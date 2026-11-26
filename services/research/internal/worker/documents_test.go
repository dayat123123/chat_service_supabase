package worker

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"testing"

	"olt-social/research/internal/clamd"
	"olt-social/research/internal/storage"
	"olt-social/research/internal/store"
	"olt-social/research/internal/xbrltest"
)

const pdfMime = "application/pdf"

func samplePDF(body string) []byte {
	return []byte("%PDF-1.7\n" + body + "\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n")
}

func TestDocumentBecomesReady(t *testing.T) {
	data := samplePDF("1 0 obj << /Type /Catalog >> endobj")
	st := &fakeStore{}
	w := newWorker(st, fakeObjects{data: data}, fakeScanner{})
	w.processDocument(context.Background(), &store.DocumentJob{ID: "d1", Mime: pdfMime, SHA256: hash(data), Attempts: 1})
	if len(st.docFails) != 0 || len(st.docsDone) != 1 || st.docsDone[0] != "d1:"+hash(data) {
		t.Fatalf("fails %+v done %v", st.docFails, st.docsDone)
	}
	if _, docs, busy := w.Counts(); docs[ResultReady] != 1 || busy {
		t.Fatalf("document counts %v busy %v", docs, busy)
	}
	if r := w.Report(); r.Detail["documents_ready"] != uint64(1) {
		t.Fatalf("report detail = %v", r.Detail)
	}
}

func TestDocumentFailures(t *testing.T) {
	good := samplePDF("1 0 obj << /Type /Catalog >> endobj")
	cases := []struct {
		name    string
		mime    string
		objects fakeObjects
		scanner fakeScanner
		sha     string
		st      *fakeStore
		want    failCall
	}{
		{"unknown type", "application/zip", fakeObjects{data: good}, fakeScanner{}, "", &fakeStore{}, failCall{code: "invalid_document"}},
		{"missing", pdfMime, fakeObjects{err: storage.ErrNotFound}, fakeScanner{}, "", &fakeStore{}, failCall{code: "object_missing"}},
		{"too large", pdfMime, fakeObjects{err: storage.ErrTooLarge}, fakeScanner{}, "", &fakeStore{}, failCall{code: "file_too_large"}},
		{"storage down", pdfMime, fakeObjects{err: errors.New("refused")}, fakeScanner{}, "", &fakeStore{},
			failCall{code: "storage_unavailable", detail: "Storage could not be reached", retry: true}},
		{"checksum", pdfMime, fakeObjects{data: good}, fakeScanner{}, strings.Repeat("0", 64), &fakeStore{},
			failCall{code: "checksum_mismatch"}},
		{"not a pdf", pdfMime, fakeObjects{data: []byte("<html></html>")}, fakeScanner{}, "", &fakeStore{},
			failCall{code: "invalid_document"}},
		{"javascript", pdfMime, fakeObjects{data: samplePDF("<< /S /JavaScript /JS (x) >>")}, fakeScanner{}, "",
			&fakeStore{}, failCall{code: "active_content"}},
		{"macro", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
			fakeObjects{data: xbrltest.Zip(xbrltest.Entry{Name: "[Content_Types].xml", Body: []byte("<Types/>")},
				xbrltest.Entry{Name: "xl/workbook.xml", Body: []byte("<workbook/>")},
				xbrltest.Entry{Name: "xl/vbaProject.bin", Body: []byte("vba")})},
			fakeScanner{}, "", &fakeStore{}, failCall{code: "macro_not_allowed"}},
		{"scanner down", pdfMime, fakeObjects{data: good}, fakeScanner{err: clamd.ErrUnavailable}, "", &fakeStore{},
			failCall{code: "scanner_unavailable", detail: "The antivirus scanner could not be reached", retry: true}},
		{"infected", pdfMime, fakeObjects{data: good}, fakeScanner{res: clamd.Result{Infected: true, Signature: "Eicar-Test"}},
			"", &fakeStore{}, failCall{code: "infected", detail: "antivirus signature Eicar-Test"}},
		{"rejected by db", pdfMime, fakeObjects{data: good}, fakeScanner{}, "",
			&fakeStore{docDoneErr: &store.APIError{Status: 400, Code: "checksum_mismatch"}}, failCall{code: "checksum_mismatch"}},
		{"db down", pdfMime, fakeObjects{data: good}, fakeScanner{}, "", &fakeStore{docDoneErr: store.ErrUnavailable},
			failCall{code: "store_unavailable", detail: "The database API could not be reached", retry: true}},
	}
	for _, c := range cases {
		w := newWorker(c.st, c.objects, c.scanner)
		w.processDocument(context.Background(), &store.DocumentJob{ID: "d1", Mime: c.mime, SHA256: c.sha, Attempts: 1})
		if len(c.st.docFails) != 1 {
			t.Errorf("%s: fails = %+v", c.name, c.st.docFails)
			continue
		}
		got := c.st.docFails[0]
		if got.code != c.want.code || got.retry != c.want.retry || (c.want.detail != "" && got.detail != c.want.detail) {
			t.Errorf("%s: fail = %+v, want %+v", c.name, got, c.want)
		}
	}
}

func TestDocumentLostLeaseIsNotAFailure(t *testing.T) {
	st := &fakeStore{docDoneErr: &store.APIError{Status: http.StatusConflict, Code: "not_claimed"}}
	w := newWorker(st, fakeObjects{data: samplePDF("x")}, nil)
	w.processDocument(context.Background(), &store.DocumentJob{ID: "d1", Mime: pdfMime})
	if _, docs, _ := w.Counts(); len(st.docFails) != 0 || docs[ResultLost] != 1 {
		t.Fatalf("fails %+v counts %v", st.docFails, docs)
	}
}

func TestRunChecksDocumentsAfterReports(t *testing.T) {
	data := xbrltest.Archive(xbrltest.BankQ3())
	st := &fakeStore{jobs: []*store.Job{{ID: "a"}}, docs: []*store.DocumentJob{{ID: "d1", Mime: pdfMime}}}
	w := newWorker(st, fakeObjects{data: data}, nil)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		w.Run(ctx)
		close(done)
	}()
	waitFor(t, func() bool {
		st.mu.Lock()
		defer st.mu.Unlock()
		return len(st.completed) == 1 && len(st.docFails) == 1
	})
	cancel()
	<-done
	if st.docFails[0].code != "invalid_document" {
		t.Fatalf("document fail = %+v", st.docFails[0])
	}
}
