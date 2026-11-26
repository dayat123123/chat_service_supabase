package worker

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/research/internal/clamd"
	"olt-social/research/internal/heartbeat"
	"olt-social/research/internal/storage"
	"olt-social/research/internal/store"
	"olt-social/research/internal/xbrl"
	"olt-social/research/internal/xbrltest"
)

type failCall struct {
	code   string
	detail string
	retry  bool
}

type fakeStore struct {
	mu          sync.Mutex
	jobs        []*store.Job
	claimErr    error
	related     *store.Related
	relatedErr  error
	completeErr error
	completeOut string
	completed   []payload
	fails       []failCall
	docs        []*store.DocumentJob
	docDoneErr  error
	docsDone    []string
	docFails    []failCall
}

func (f *fakeStore) ClaimDocument(context.Context, string, time.Duration) (*store.DocumentJob, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if len(f.docs) == 0 {
		return nil, nil
	}
	job := f.docs[0]
	f.docs = f.docs[1:]
	return job, nil
}

func (f *fakeStore) CompleteDocument(_ context.Context, id, _, sha string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.docDoneErr != nil {
		return f.docDoneErr
	}
	f.docsDone = append(f.docsDone, id+":"+sha)
	return nil
}

func (f *fakeStore) FailDocument(_ context.Context, _, _, code, detail string, retry bool) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.docFails = append(f.docFails, failCall{code: code, detail: detail, retry: retry})
	return nil
}

func (f *fakeStore) Claim(context.Context, string, time.Duration) (*store.Job, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.claimErr != nil {
		return nil, f.claimErr
	}
	if len(f.jobs) == 0 {
		return nil, nil
	}
	job := f.jobs[0]
	f.jobs = f.jobs[1:]
	return job, nil
}

func (f *fakeStore) Related(context.Context, string, string, time.Time, time.Time) (*store.Related, error) {
	if f.relatedErr != nil {
		return nil, f.relatedErr
	}
	if f.related == nil {
		return &store.Related{}, nil
	}
	return f.related, nil
}

func (f *fakeStore) Complete(_ context.Context, _, _ string, report any) (json.RawMessage, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.completeErr != nil {
		return nil, f.completeErr
	}
	f.completed = append(f.completed, *report.(*payload))
	if f.completeOut != "" {
		return json.RawMessage(f.completeOut), nil
	}
	return json.RawMessage(`{"status":"done"}`), nil
}

func (f *fakeStore) Fail(_ context.Context, _, _, code, detail string, retry bool) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.fails = append(f.fails, failCall{code: code, detail: detail, retry: retry})
	return nil
}

type fakeObjects struct {
	data []byte
	err  error
}

func (o fakeObjects) Download(context.Context, string, int64) ([]byte, error) {
	return o.data, o.err
}

func (o fakeObjects) Get(_ context.Context, bucket, _ string, _ int64) ([]byte, error) {
	if bucket != storage.PostFiles {
		return nil, errors.New("unexpected bucket " + bucket)
	}
	return o.data, o.err
}

type fakeScanner struct {
	res clamd.Result
	err error
}

func (s fakeScanner) Scan(context.Context, []byte) (clamd.Result, error) {
	return s.res, s.err
}

func newWorker(st *fakeStore, objects Objects, scanner Scanner) *Worker {
	return New(Options{
		Store: st, Objects: objects, Scanner: scanner,
		Log:      slog.New(slog.NewTextHandler(io.Discard, nil)),
		Instance: "test-1", PollInterval: time.Hour, Lease: time.Minute, JobTimeout: 10 * time.Second,
		MaxFileBytes: 8 << 20, MaxDocumentBytes: 20 << 20, Limits: xbrl.DefaultLimits(),
	})
}

func hash(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func TestProcessBuildsTheReportPayload(t *testing.T) {
	data := xbrltest.Archive(xbrltest.BankQ3())
	q2 := xbrltest.BankQ2()
	rc, _ := xbrl.Open(xbrltest.Archive(q2), xbrl.DefaultLimits())
	prev, _ := xbrl.Parse(rc)
	rc.Close()
	st := &fakeStore{related: &store.Related{Previous: &store.Version{ID: "q2", Period: "Q2",
		PeriodStart: "2026-01-01", PeriodEnd: "2026-06-30", Facts: prev.Facts}}}
	w := newWorker(st, fakeObjects{data: data}, fakeScanner{})
	w.process(context.Background(), &store.Job{ID: "f1", SHA256: hash(data), Attempts: 1})

	if len(st.fails) != 0 || len(st.completed) != 1 {
		t.Fatalf("fails %+v completed %d", st.fails, len(st.completed))
	}
	p := st.completed[0]
	if p.SHA256 != hash(data) || p.EntityCode != "ABCD" || p.Period != "Q3" || p.PeriodStart != "2026-01-01" ||
		p.PeriodEnd != "2026-09-30" || p.Audit != "unaudited" || p.Currency != "IDR" || p.Template != "bank" ||
		p.Metrics.PreviousReport != "q2" || p.Warnings == nil {
		t.Fatalf("payload = %+v", p)
	}
	if !strings.HasPrefix(p.Summary, "$ABCD — ") || !strings.Contains(p.Summary, "kuartal III") {
		t.Fatalf("summary = %q", p.Summary)
	}
	if p.Kind != KindFinancialReport || p.Document.Version != 1 || p.Document.Headline == "" || len(p.Document.Blocks) == 0 {
		t.Fatalf("document = %+v", p.Document)
	}
	body, _ := json.Marshal(&p)
	if !strings.Contains(string(body), `"warnings":[]`) || !strings.Contains(string(body), `"facts":{"current":{`) ||
		!strings.Contains(string(body), `"kind":"financial_report"`) || !strings.Contains(string(body), `"document":{"version":1`) {
		t.Fatalf("payload JSON = %.300s", body)
	}
	if counts, _, busy := w.Counts(); counts[ResultDone] != 1 || busy {
		t.Fatalf("counts %v busy %v", counts, busy)
	}
}

func TestProcessRecordsFailures(t *testing.T) {
	good := xbrltest.Archive(xbrltest.BankQ3())
	badXML := xbrltest.Zip(xbrltest.Entry{Name: "instance.xbrl", Body: []byte("<oops")})
	badCode := xbrltest.BankQ3()
	badCode.Code = "1234"
	cases := []struct {
		name    string
		objects fakeObjects
		scanner fakeScanner
		sha     string
		st      *fakeStore
		want    failCall
	}{
		{"missing object", fakeObjects{err: storage.ErrNotFound}, fakeScanner{}, "", &fakeStore{}, failCall{code: "object_missing"}},
		{"too large", fakeObjects{err: storage.ErrTooLarge}, fakeScanner{}, "", &fakeStore{}, failCall{code: "zip_unsafe"}},
		{"storage down", fakeObjects{err: errors.New("dial tcp storage:5000: refused")}, fakeScanner{}, "", &fakeStore{},
			failCall{code: "storage_unavailable", detail: "Storage could not be reached", retry: true}},
		{"checksum", fakeObjects{data: good}, fakeScanner{}, strings.Repeat("0", 64), &fakeStore{}, failCall{code: "checksum_mismatch"}},
		{"scanner down", fakeObjects{data: good}, fakeScanner{err: clamd.ErrUnavailable}, "", &fakeStore{},
			failCall{code: "scanner_unavailable", detail: "The antivirus scanner could not be reached", retry: true}},
		{"infected", fakeObjects{data: good}, fakeScanner{res: clamd.Result{Infected: true, Signature: "Eicar-Test"}}, "",
			&fakeStore{}, failCall{code: "infected", detail: "antivirus signature Eicar-Test"}},
		{"not zip", fakeObjects{data: []byte("plain text")}, fakeScanner{}, "", &fakeStore{}, failCall{code: "not_zip"}},
		{"no instance", fakeObjects{data: xbrltest.Zip(xbrltest.Entry{Name: "a.txt", Body: []byte("x")})}, fakeScanner{}, "",
			&fakeStore{}, failCall{code: "no_instance"}},
		{"bad xml", fakeObjects{data: badXML}, fakeScanner{}, "", &fakeStore{}, failCall{code: "invalid_xbrl"}},
		{"bad code", fakeObjects{data: xbrltest.Archive(badCode)}, fakeScanner{}, "", &fakeStore{}, failCall{code: "unknown_entity"}},
		{"related down", fakeObjects{data: good}, fakeScanner{}, "", &fakeStore{relatedErr: store.ErrUnavailable},
			failCall{code: "store_unavailable", detail: "The database API could not be reached", retry: true}},
		{"rejected by db", fakeObjects{data: good}, fakeScanner{}, "",
			&fakeStore{completeErr: &store.APIError{Status: 400, Code: "invalid_report"}}, failCall{code: "invalid_report"}},
		{"complete down", fakeObjects{data: good}, fakeScanner{}, "", &fakeStore{completeErr: store.ErrUnavailable},
			failCall{code: "store_unavailable", detail: "The database API could not be reached", retry: true}},
	}
	for _, c := range cases {
		w := newWorker(c.st, c.objects, c.scanner)
		w.process(context.Background(), &store.Job{ID: "f1", SHA256: c.sha, Attempts: 1})
		if len(c.st.fails) != 1 {
			t.Errorf("%s: fails = %+v", c.name, c.st.fails)
			continue
		}
		got := c.st.fails[0]
		if got.code != c.want.code || got.retry != c.want.retry || (c.want.detail != "" && got.detail != c.want.detail) {
			t.Errorf("%s: fail = %+v, want %+v", c.name, got, c.want)
		}
	}
}

func TestLostLeaseAndDuplicatesAreNotFailures(t *testing.T) {
	data := xbrltest.Archive(xbrltest.BankQ3())
	lost := &fakeStore{completeErr: &store.APIError{Status: http.StatusConflict, Code: "not_claimed"}}
	w := newWorker(lost, fakeObjects{data: data}, nil)
	w.process(context.Background(), &store.Job{ID: "f1"})
	if counts, _, _ := w.Counts(); len(lost.fails) != 0 || counts[ResultLost] != 1 {
		t.Fatalf("lost lease: fails %+v counts %v", lost.fails, counts)
	}
	dup := &fakeStore{completeOut: `{"status":"duplicate","report_id":"r1"}`}
	w = newWorker(dup, fakeObjects{data: data}, nil)
	w.process(context.Background(), &store.Job{ID: "f2"})
	if counts, _, _ := w.Counts(); len(dup.fails) != 0 || counts[ResultDuplicate] != 1 {
		t.Fatalf("duplicate: fails %+v counts %v", dup.fails, counts)
	}
}

func TestRunDrainsTheQueueAndWakesUp(t *testing.T) {
	data := xbrltest.Archive(xbrltest.BankQ3())
	st := &fakeStore{jobs: []*store.Job{{ID: "a"}, {ID: "b"}}}
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
		return len(st.completed) == 2
	})
	st.mu.Lock()
	st.jobs = append(st.jobs, &store.Job{ID: "c"})
	st.mu.Unlock()
	w.Wake()
	waitFor(t, func() bool {
		st.mu.Lock()
		defer st.mu.Unlock()
		return len(st.completed) == 3
	})
	cancel()
	<-done
}

func TestReportTurnsDegradedAfterRepeatedClaimFailures(t *testing.T) {
	st := &fakeStore{claimErr: store.ErrUnavailable}
	w := newWorker(st, fakeObjects{}, nil)
	for range 3 {
		_, err := st.Claim(context.Background(), "", 0)
		w.claimed(err)
	}
	if r := w.Report(); r.Status != heartbeat.StatusDegraded || !strings.Contains(r.Error, "3 consecutive") {
		t.Fatalf("report = %+v", r)
	}
	w.claimed(nil)
	if r := w.Report(); r.Status != heartbeat.StatusOK {
		t.Fatalf("report after recovery = %+v", r)
	}
}

func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for !cond() {
		if time.Now().After(deadline) {
			t.Fatal("condition not reached in time")
		}
		time.Sleep(5 * time.Millisecond)
	}
}
