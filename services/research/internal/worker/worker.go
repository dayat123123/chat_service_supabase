package worker

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"olt-social/research/internal/analysis"
	"olt-social/research/internal/clamd"
	"olt-social/research/internal/heartbeat"
	"olt-social/research/internal/storage"
	"olt-social/research/internal/store"
	"olt-social/research/internal/summary"
	"olt-social/research/internal/xbrl"
)

const (
	degradedAfter = 3
	dateLayout    = "2006-01-02"

	ResultDone      = "done"
	ResultDuplicate = "duplicate"
	ResultRetry     = "retry"
	ResultRejected  = "rejected"
	ResultLost      = "lease_lost"

	KindFinancialReport = "financial_report"
)

type Store interface {
	Claim(ctx context.Context, instance string, lease time.Duration) (*store.Job, error)
	Related(ctx context.Context, kind, entity string, start, end time.Time) (*store.Related, error)
	Complete(ctx context.Context, fileID, instance string, report any) (json.RawMessage, error)
	Fail(ctx context.Context, fileID, instance, code, detail string, retry bool) error
	ClaimDocument(ctx context.Context, instance string, lease time.Duration) (*store.DocumentJob, error)
	CompleteDocument(ctx context.Context, id, instance, sha string) error
	FailDocument(ctx context.Context, id, instance, code, detail string, retry bool) error
}

type Objects interface {
	Download(ctx context.Context, name string, limit int64) ([]byte, error)
	Get(ctx context.Context, bucket, name string, limit int64) ([]byte, error)
}

type Scanner interface {
	Scan(ctx context.Context, body []byte) (clamd.Result, error)
}

type Options struct {
	Store            Store
	Objects          Objects
	Scanner          Scanner
	Log              *slog.Logger
	Instance         string
	PollInterval     time.Duration
	Lease            time.Duration
	JobTimeout       time.Duration
	MaxFileBytes     int64
	MaxDocumentBytes int64
	Limits           xbrl.Limits
}

type Worker struct {
	opts Options
	wake chan struct{}

	mu        sync.Mutex
	results   map[string]uint64
	documents map[string]uint64
	failing   int
	lastError string
	busy      bool
}

func New(opts Options) *Worker {
	return &Worker{opts: opts, wake: make(chan struct{}, 1), results: map[string]uint64{}, documents: map[string]uint64{}}
}

func (w *Worker) Wake() {
	select {
	case w.wake <- struct{}{}:
	default:
	}
}

func (w *Worker) Run(ctx context.Context) {
	for ctx.Err() == nil {
		if w.step(ctx) {
			continue
		}
		select {
		case <-ctx.Done():
			return
		case <-w.wake:
		case <-time.After(w.opts.PollInterval):
		}
	}
}

func (w *Worker) step(ctx context.Context) bool {
	job, err := w.opts.Store.Claim(ctx, w.opts.Instance, w.opts.Lease)
	w.claimed(err)
	if err != nil {
		if ctx.Err() == nil {
			w.opts.Log.Warn("Could not claim a research file; retrying after the poll interval", "error", err)
		}
		return false
	}
	if job != nil {
		w.process(ctx, job)
		return true
	}
	doc, err := w.opts.Store.ClaimDocument(ctx, w.opts.Instance, w.opts.Lease)
	w.claimed(err)
	if err != nil {
		if ctx.Err() == nil {
			w.opts.Log.Warn("Could not claim a research document; retrying after the poll interval", "error", err)
		}
		return false
	}
	if doc != nil {
		w.processDocument(ctx, doc)
		return true
	}
	return false
}

var transientDetail = map[string]string{
	"storage_unavailable": "Storage could not be reached",
	"scanner_unavailable": "The antivirus scanner could not be reached",
	"store_unavailable":   "The database API could not be reached",
}

type failure struct {
	code  string
	retry bool
	err   error
}

func (f *failure) Error() string {
	return f.code + ": " + f.err.Error()
}

func permanent(code string, err error) *failure {
	return &failure{code: code, err: err}
}

func transient(code string, err error) *failure {
	return &failure{code: code, retry: true, err: err}
}

type payload struct {
	SHA256      string             `json:"sha256"`
	Kind        string             `json:"kind"`
	EntityCode  string             `json:"entity_code"`
	EntityName  string             `json:"entity_name"`
	Sector      string             `json:"sector,omitempty"`
	Subsector   string             `json:"subsector,omitempty"`
	Period      string             `json:"period"`
	PeriodStart string             `json:"period_start"`
	PeriodEnd   string             `json:"period_end"`
	Audit       string             `json:"audit"`
	Currency    string             `json:"currency"`
	Template    string             `json:"template"`
	Facts       xbrl.Facts         `json:"facts"`
	Metrics     analysis.Metrics   `json:"metrics"`
	Summary     string             `json:"summary"`
	Document    summary.Document   `json:"document"`
	Warnings    []analysis.Warning `json:"warnings"`
}

func (w *Worker) process(parent context.Context, job *store.Job) {
	start := time.Now()
	w.setBusy(true)
	defer w.setBusy(false)
	ctx, cancel := context.WithTimeout(parent, w.opts.JobTimeout)
	defer cancel()
	log := w.opts.Log.With("file_id", job.ID, "attempt", job.Attempts)

	report, err := w.prepare(ctx, job)
	var result string
	if err == nil {
		result, err = w.complete(ctx, job, report)
	}
	var f *failure
	if err != nil {
		var stop bool
		result, f, stop = w.recordFailure(parent, err, log, func(ctx context.Context, code, detail string, retry bool) error {
			return w.opts.Store.Fail(ctx, job.ID, w.opts.Instance, code, detail, retry)
		})
		if stop {
			return
		}
	}
	w.count(result)
	attrs := []any{"result", result, "duration_ms", time.Since(start).Milliseconds()}
	if report != nil {
		attrs = append(attrs, "entity", report.EntityCode, "period", report.Period, "period_end", report.PeriodEnd)
	}
	switch {
	case f != nil && f.retry:
		log.Warn("Research file will be retried", append(attrs, "code", f.code, "error", f.err.Error())...)
	case f != nil:
		log.Warn("Research file rejected", append(attrs, "code", f.code, "error", f.err.Error())...)
	case result == ResultLost:
		log.Warn("Lost the lease on a research file before finishing", append(attrs, "error", err.Error())...)
	default:
		log.Info("Research file processed", attrs...)
	}
}

func (w *Worker) recordFailure(parent context.Context, err error, log *slog.Logger,
	fail func(ctx context.Context, code, detail string, retry bool) error) (string, *failure, bool) {
	var f *failure
	if !errors.As(err, &f) {
		return ResultLost, nil, false
	}
	if parent.Err() != nil {
		return "", f, true
	}
	result, detail := ResultRejected, f.err.Error()
	if f.retry {
		result, detail = ResultRetry, transientDetail[f.code]
	}
	failCtx, stop := context.WithTimeout(context.WithoutCancel(parent), 10*time.Second)
	ferr := fail(failCtx, f.code, detail, f.retry)
	stop()
	if ferr != nil {
		log.Warn("Could not record the failure; the lease will expire and the job will be retried", "error", ferr)
	}
	return result, f, false
}

func (w *Worker) prepare(ctx context.Context, job *store.Job) (*payload, error) {
	data, err := w.opts.Objects.Download(ctx, job.ObjectName, w.opts.MaxFileBytes)
	switch {
	case errors.Is(err, storage.ErrNotFound):
		return nil, permanent("object_missing", err)
	case errors.Is(err, storage.ErrTooLarge):
		return nil, permanent("zip_unsafe", err)
	case err != nil:
		return nil, transient("storage_unavailable", err)
	}
	sum := sha256.Sum256(data)
	sha := hex.EncodeToString(sum[:])
	if job.SHA256 != "" && job.SHA256 != sha {
		return nil, permanent("checksum_mismatch", fmt.Errorf("stored object hash %s differs from the submitted one", sha))
	}
	if w.opts.Scanner != nil {
		res, err := w.opts.Scanner.Scan(ctx, data)
		if err != nil {
			return nil, transient("scanner_unavailable", err)
		}
		if res.Infected {
			return nil, permanent("infected", fmt.Errorf("antivirus signature %s", res.Signature))
		}
	}
	rc, err := xbrl.Open(data, w.opts.Limits)
	if err != nil {
		return nil, permanent(zipCode(err), err)
	}
	defer rc.Close()
	r, err := xbrl.Parse(rc)
	switch {
	case errors.Is(err, xbrl.ErrUnknownEntity):
		return nil, permanent("unknown_entity", err)
	case errors.Is(err, xbrl.ErrUnsafeZip):
		return nil, permanent("zip_unsafe", err)
	case err != nil:
		return nil, permanent("invalid_xbrl", err)
	}

	related, err := w.opts.Store.Related(ctx, KindFinancialReport, r.EntityCode, r.PeriodStart, r.PeriodEnd)
	if err != nil {
		return nil, transient("store_unavailable", err)
	}
	in := analysis.Input{Current: analysis.Snapshot{Period: r.Period, PeriodStart: r.PeriodStart, PeriodEnd: r.PeriodEnd,
		Facts: r.Facts}}
	in.Previous = snapshot(related.Previous)
	in.PriorYear = snapshot(related.PriorYear)
	res := analysis.Analyze(in)
	warnings := res.Warnings
	if warnings == nil {
		warnings = []analysis.Warning{}
	}
	meta := summary.Meta{EntityCode: r.EntityCode, EntityName: r.EntityName, Period: r.Period, PeriodStart: r.PeriodStart,
		PeriodEnd: r.PeriodEnd, Audit: r.Audit, Currency: r.Currency}
	return &payload{
		SHA256:      sha,
		Kind:        KindFinancialReport,
		EntityCode:  r.EntityCode,
		EntityName:  r.EntityName,
		Sector:      r.Sector,
		Subsector:   r.Subsector,
		Period:      r.Period,
		PeriodStart: r.PeriodStart.Format(dateLayout),
		PeriodEnd:   r.PeriodEnd.Format(dateLayout),
		Audit:       r.Audit,
		Currency:    r.Currency,
		Template:    res.Metrics.Template,
		Facts:       r.Facts,
		Metrics:     res.Metrics,
		Summary:     summary.Render(meta, res.Metrics),
		Document:    summary.Build(meta, res.Metrics),
		Warnings:    warnings,
	}, nil
}

func (w *Worker) complete(ctx context.Context, job *store.Job, p *payload) (string, error) {
	out, err := w.opts.Store.Complete(ctx, job.ID, w.opts.Instance, p)
	var api *store.APIError
	switch {
	case errors.As(err, &api) && api.Status == http.StatusConflict:
		return "", err
	case errors.As(err, &api):
		return "", permanent(api.Code, err)
	case err != nil:
		return "", transient("store_unavailable", err)
	}
	var body struct {
		Status string `json:"status"`
	}
	_ = json.Unmarshal(out, &body)
	if body.Status == ResultDuplicate {
		return ResultDuplicate, nil
	}
	return ResultDone, nil
}

func snapshot(v *store.Version) *analysis.Snapshot {
	if v == nil {
		return nil
	}
	start, end, err := v.Dates()
	if err != nil {
		return nil
	}
	return &analysis.Snapshot{ID: v.ID, Period: v.Period, PeriodStart: start, PeriodEnd: end, Facts: v.Facts}
}

func zipCode(err error) string {
	switch {
	case errors.Is(err, xbrl.ErrUnsafeZip):
		return "zip_unsafe"
	case errors.Is(err, xbrl.ErrNoInstance):
		return "no_instance"
	}
	return "not_zip"
}

func (w *Worker) claimed(err error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	if err != nil {
		w.failing++
		w.lastError = err.Error()
		return
	}
	w.failing = 0
}

func (w *Worker) count(result string) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.results[result]++
}

func (w *Worker) setBusy(v bool) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.busy = v
}

func (w *Worker) countDocument(result string) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.documents[result]++
}

func (w *Worker) Counts() (map[string]uint64, map[string]uint64, bool) {
	w.mu.Lock()
	defer w.mu.Unlock()
	return clone(w.results), clone(w.documents), w.busy
}

func clone(in map[string]uint64) map[string]uint64 {
	out := make(map[string]uint64, len(in))
	for k, v := range in {
		out[k] = v
	}
	return out
}

func (w *Worker) Report() heartbeat.Report {
	w.mu.Lock()
	defer w.mu.Unlock()
	detail := map[string]any{"busy": w.busy}
	for k, v := range w.results {
		detail["reports_"+k] = v
	}
	for k, v := range w.documents {
		detail["documents_"+k] = v
	}
	if w.failing >= degradedAfter {
		return heartbeat.Report{Status: heartbeat.StatusDegraded,
			Error:  fmt.Sprintf("Database API unreachable (%d consecutive failures): %s", w.failing, w.lastError),
			Detail: detail}
	}
	return heartbeat.Report{Status: heartbeat.StatusOK, Detail: detail}
}
