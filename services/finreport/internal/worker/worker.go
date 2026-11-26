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

	"olt-social/finreport/internal/analysis"
	"olt-social/finreport/internal/clamd"
	"olt-social/finreport/internal/heartbeat"
	"olt-social/finreport/internal/storage"
	"olt-social/finreport/internal/store"
	"olt-social/finreport/internal/summary"
	"olt-social/finreport/internal/xbrl"
)

const (
	degradedAfter = 3
	dateLayout    = "2006-01-02"

	ResultDone      = "done"
	ResultDuplicate = "duplicate"
	ResultRetry     = "retry"
	ResultRejected  = "rejected"
	ResultLost      = "lease_lost"
)

type Store interface {
	Claim(ctx context.Context, instance string, lease time.Duration) (*store.Job, error)
	Related(ctx context.Context, entity string, start, end time.Time) (*store.Related, error)
	Complete(ctx context.Context, fileID, instance string, report any) (json.RawMessage, error)
	Fail(ctx context.Context, fileID, instance, code, detail string, retry bool) error
}

type Objects interface {
	Download(ctx context.Context, name string, limit int64) ([]byte, error)
}

type Scanner interface {
	Scan(ctx context.Context, body []byte) (clamd.Result, error)
}

type Options struct {
	Store        Store
	Objects      Objects
	Scanner      Scanner
	Log          *slog.Logger
	Instance     string
	PollInterval time.Duration
	Lease        time.Duration
	JobTimeout   time.Duration
	MaxFileBytes int64
	Limits       xbrl.Limits
}

type Worker struct {
	opts Options
	wake chan struct{}

	mu        sync.Mutex
	results   map[string]uint64
	failing   int
	lastError string
	busy      bool
}

func New(opts Options) *Worker {
	return &Worker{opts: opts, wake: make(chan struct{}, 1), results: map[string]uint64{}}
}

func (w *Worker) Wake() {
	select {
	case w.wake <- struct{}{}:
	default:
	}
}

func (w *Worker) Run(ctx context.Context) {
	for ctx.Err() == nil {
		job, err := w.opts.Store.Claim(ctx, w.opts.Instance, w.opts.Lease)
		w.claimed(err)
		if err != nil {
			if ctx.Err() == nil {
				w.opts.Log.Warn("Could not claim a financial report; retrying after the poll interval", "error", err)
			}
		} else if job != nil {
			w.process(ctx, job)
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
	switch {
	case err == nil:
	case errors.As(err, &f):
		result = ResultRejected
		if f.retry {
			result = ResultRetry
		}
		if parent.Err() != nil {
			return
		}
		detail := f.err.Error()
		if f.retry {
			detail = transientDetail[f.code]
		}
		failCtx, stop := context.WithTimeout(context.WithoutCancel(parent), 10*time.Second)
		ferr := w.opts.Store.Fail(failCtx, job.ID, w.opts.Instance, f.code, detail, f.retry)
		stop()
		if ferr != nil {
			log.Warn("Could not record the failure; the lease will expire and the file will be retried", "error", ferr)
		}
	default:
		result = ResultLost
	}
	w.count(result)
	attrs := []any{"result", result, "duration_ms", time.Since(start).Milliseconds()}
	if report != nil {
		attrs = append(attrs, "entity", report.EntityCode, "period", report.Period, "period_end", report.PeriodEnd)
	}
	switch {
	case f != nil && f.retry:
		log.Warn("Financial report will be retried", append(attrs, "code", f.code, "error", f.err.Error())...)
	case f != nil:
		log.Warn("Financial report rejected", append(attrs, "code", f.code, "error", f.err.Error())...)
	case result == ResultLost:
		log.Warn("Lost the lease on a financial report before finishing", append(attrs, "error", err.Error())...)
	default:
		log.Info("Financial report processed", attrs...)
	}
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

	related, err := w.opts.Store.Related(ctx, r.EntityCode, r.PeriodStart, r.PeriodEnd)
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
	text := summary.Render(summary.Meta{EntityCode: r.EntityCode, Period: r.Period, PeriodStart: r.PeriodStart,
		PeriodEnd: r.PeriodEnd, Audit: r.Audit, Currency: r.Currency}, res.Metrics)
	return &payload{
		SHA256:      sha,
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
		Summary:     text,
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

func (w *Worker) Counts() (map[string]uint64, bool) {
	w.mu.Lock()
	defer w.mu.Unlock()
	out := make(map[string]uint64, len(w.results))
	for k, v := range w.results {
		out[k] = v
	}
	return out, w.busy
}

func (w *Worker) Report() heartbeat.Report {
	w.mu.Lock()
	defer w.mu.Unlock()
	detail := map[string]any{"busy": w.busy}
	for k, v := range w.results {
		detail["reports_"+k] = v
	}
	if w.failing >= degradedAfter {
		return heartbeat.Report{Status: heartbeat.StatusDegraded,
			Error:  fmt.Sprintf("Database API unreachable (%d consecutive failures): %s", w.failing, w.lastError),
			Detail: detail}
	}
	return heartbeat.Report{Status: heartbeat.StatusOK, Detail: detail}
}
