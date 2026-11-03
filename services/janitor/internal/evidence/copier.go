package evidence

import (
	"context"
	"errors"
	"log/slog"
	"maps"
	"sync"
	"time"

	"olt-social/janitor/internal/metrics"
	"olt-social/janitor/internal/storage"
	"olt-social/janitor/internal/store"
)

const (
	Bucket        = "evidence"
	leaseMargin   = 5 * time.Second
	reportTimeout = 15 * time.Second
)

var errMismatch = errors.New("evidence copy does not match its source")

type Store interface {
	ClaimCopies(ctx context.Context, instance string, limit int, lease time.Duration) ([]store.CopyJob, error)
	ReportCopies(ctx context.Context, instance string, results []store.CopyResult) (int, error)
}

type Storage interface {
	Copy(ctx context.Context, bucket, name, destBucket, destName string) error
	Hash(ctx context.Context, bucket, name string) (string, int64, error)
}

type Options struct {
	Store           Store
	Storage         Storage
	Log             *slog.Logger
	Instance        string
	BatchSize       int
	Concurrency     int
	Lease           time.Duration
	PollInterval    time.Duration
	RequestTimeout  time.Duration
	ShutdownTimeout time.Duration
}

type Copier struct {
	opts         Options
	log          *slog.Logger
	backoffMin   time.Duration
	backoffMax   time.Duration
	reportDelays []time.Duration

	mu          sync.Mutex
	outcomes    map[string]uint64
	claimErrors uint64
}

func New(opts Options) *Copier {
	return &Copier{
		opts:         opts,
		log:          opts.Log,
		backoffMin:   time.Second,
		backoffMax:   time.Minute,
		reportDelays: []time.Duration{250 * time.Millisecond, 500 * time.Millisecond, time.Second},
		outcomes:     map[string]uint64{},
	}
}

func (c *Copier) Metrics() (map[string]uint64, uint64) {
	c.mu.Lock()
	defer c.mu.Unlock()
	return maps.Clone(c.outcomes), c.claimErrors
}

func (c *Copier) Run(ctx context.Context) {
	work, cancelWork := context.WithCancel(context.WithoutCancel(ctx))
	defer cancelWork()
	go func() {
		select {
		case <-work.Done():
			return
		case <-ctx.Done():
		}
		timer := time.NewTimer(c.opts.ShutdownTimeout)
		defer timer.Stop()
		select {
		case <-timer.C:
			c.log.Warn("Shutdown timeout reached; abandoning evidence copies still in flight", "timeout", c.opts.ShutdownTimeout.String())
			cancelWork()
		case <-work.Done():
		}
	}()
	var backoff time.Duration
	for ctx.Err() == nil {
		more, err := c.round(ctx, work)
		switch {
		case err != nil:
			backoff = min(max(backoff*2, c.backoffMin), c.backoffMax)
			if ctx.Err() == nil {
				c.log.Warn("Could not claim evidence copy jobs", "error", err, "retry_in", backoff.String())
			}
			c.idle(ctx, backoff)
		case more:
			backoff = 0
		default:
			backoff = 0
			c.idle(ctx, c.opts.PollInterval)
		}
	}
}

func (c *Copier) idle(ctx context.Context, wait time.Duration) {
	timer := time.NewTimer(wait)
	defer timer.Stop()
	select {
	case <-ctx.Done():
	case <-timer.C:
	}
}

func (c *Copier) round(ctx, work context.Context) (bool, error) {
	claimedAt := time.Now()
	jobs, err := c.opts.Store.ClaimCopies(work, c.opts.Instance, c.opts.BatchSize, c.opts.Lease)
	if err != nil {
		c.mu.Lock()
		c.claimErrors++
		c.mu.Unlock()
		return false, err
	}
	if len(jobs) == 0 {
		return false, nil
	}
	window := max(c.opts.Lease-3*c.opts.RequestTimeout-leaseMargin, c.opts.Lease/3)
	results := c.process(ctx, work, jobs, claimedAt.Add(window))
	c.record(jobs, results, time.Since(claimedAt))
	c.report(ctx, results)
	return len(jobs) >= c.opts.BatchSize, nil
}

func (c *Copier) process(ctx, work context.Context, jobs []store.CopyJob, startBy time.Time) []store.CopyResult {
	results := make([]store.CopyResult, len(jobs))
	for i, job := range jobs {
		results[i] = store.CopyResult{ID: job.ID, Release: true}
	}
	starting, stopStarting := context.WithDeadline(ctx, startBy)
	defer stopStarting()
	slots := make(chan struct{}, c.opts.Concurrency)
	var wg sync.WaitGroup
	for i, job := range jobs {
		select {
		case slots <- struct{}{}:
		case <-starting.Done():
		}
		if starting.Err() != nil {
			break
		}
		wg.Add(1)
		go func() {
			defer wg.Done()
			defer func() { <-slots }()
			results[i] = c.copy(work, job)
		}()
	}
	wg.Wait()
	return results
}

func (c *Copier) copy(work context.Context, job store.CopyJob) store.CopyResult {
	result := store.CopyResult{ID: job.ID}
	fail := func(err error) store.CopyResult {
		switch {
		case errors.Is(err, storage.ErrNotFound):
			result.Missing = true
		case work.Err() != nil:
			result.Release = true
		default:
			result.Error = err.Error()
		}
		return result
	}
	source, sourceSize, err := c.opts.Storage.Hash(work, job.SourceBucket, job.SourceName)
	if err != nil {
		return fail(err)
	}
	if err := c.opts.Storage.Copy(work, job.SourceBucket, job.SourceName, Bucket, job.ObjectName); err != nil {
		return fail(err)
	}
	copied, size, err := c.opts.Storage.Hash(work, Bucket, job.ObjectName)
	if errors.Is(err, storage.ErrNotFound) {
		err = errors.New("evidence copy is missing right after copying")
	}
	if err != nil {
		return fail(err)
	}
	if copied != source || size != sourceSize {
		return fail(errMismatch)
	}
	result.SHA256 = copied
	result.Size = size
	return result
}

func outcome(r store.CopyResult) string {
	switch {
	case r.Error != "":
		return metrics.EvidenceError
	case r.Release:
		return metrics.Released
	case r.Missing:
		return metrics.EvidenceMissing
	default:
		return metrics.EvidenceCopied
	}
}

func (c *Copier) record(jobs []store.CopyJob, results []store.CopyResult, took time.Duration) {
	counts := map[string]uint64{}
	for i, r := range results {
		kind := outcome(r)
		counts[kind]++
		if kind == metrics.EvidenceError {
			c.log.Warn("Evidence copy failed", "id", jobs[i].ID, "bucket", jobs[i].SourceBucket, "error", r.Error)
		}
	}
	c.mu.Lock()
	for kind, n := range counts {
		c.outcomes[kind] += n
	}
	c.mu.Unlock()
	c.log.Info("Evidence copy round finished", "jobs", len(jobs), "copied", counts[metrics.EvidenceCopied],
		"missing", counts[metrics.EvidenceMissing], "failed", counts[metrics.EvidenceError],
		"released", counts[metrics.Released], "took_ms", took.Milliseconds())
}

func (c *Copier) report(ctx context.Context, results []store.CopyResult) {
	ctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), reportTimeout)
	defer cancel()
	var err error
	for attempt := 0; ; attempt++ {
		var updated int
		if updated, err = c.opts.Store.ReportCopies(ctx, c.opts.Instance, results); err == nil {
			if updated < len(results) {
				c.log.Warn("Some evidence copy results were not applied; their lease may have ended",
					"results", len(results), "updated", updated)
			}
			return
		}
		if attempt == len(c.reportDelays) {
			break
		}
		timer := time.NewTimer(c.reportDelays[attempt])
		select {
		case <-ctx.Done():
			timer.Stop()
		case <-timer.C:
		}
	}
	c.log.Error("Could not report evidence copy results; the jobs return to the queue when the lease ends",
		"error", err, "results", len(results))
}
