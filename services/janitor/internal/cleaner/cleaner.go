package cleaner

import (
	"context"
	"log/slog"
	"maps"
	"sync"
	"time"

	"olt-social/janitor/internal/metrics"
	"olt-social/janitor/internal/store"
)

const (
	leaseMargin   = 5 * time.Second
	reportTimeout = 15 * time.Second
)

type Store interface {
	Claim(ctx context.Context, instance string, limit, objects int, lease time.Duration) ([]store.Entry, error)
	Report(ctx context.Context, instance string, results []store.Result) (int, error)
}

type Storage interface {
	Delete(ctx context.Context, bucket string, names []string) (int, error)
}

type Options struct {
	Store           Store
	Storage         Storage
	Log             *slog.Logger
	Instance        string
	BatchSize       int
	ObjectsPerEntry int
	DeleteChunk     int
	Concurrency     int
	Lease           time.Duration
	PollInterval    time.Duration
	RequestTimeout  time.Duration
	ShutdownTimeout time.Duration
}

type Cleaner struct {
	opts         Options
	log          *slog.Logger
	backoffMin   time.Duration
	backoffMax   time.Duration
	reportDelays []time.Duration
	now          func() time.Time

	mu          sync.Mutex
	deleted     uint64
	entries     map[string]uint64
	claimErrors uint64
	lastSuccess time.Time
}

func New(opts Options) *Cleaner {
	return &Cleaner{
		opts:         opts,
		log:          opts.Log,
		backoffMin:   time.Second,
		backoffMax:   time.Minute,
		reportDelays: []time.Duration{250 * time.Millisecond, 500 * time.Millisecond, time.Second},
		now:          time.Now,
		entries:      map[string]uint64{},
	}
}

func (c *Cleaner) Run(ctx context.Context) {
	work, cancelWork := context.WithCancel(context.WithoutCancel(ctx))
	defer cancelWork()
	go c.enforceShutdown(ctx, work, cancelWork)
	c.loop(ctx, work)
}

func (c *Cleaner) Metrics() metrics.Snapshot {
	c.mu.Lock()
	defer c.mu.Unlock()
	return metrics.Snapshot{
		ObjectsDeleted: c.deleted,
		Entries:        maps.Clone(c.entries),
		ClaimErrors:    c.claimErrors,
		LastSuccess:    c.lastSuccess,
	}
}

func (c *Cleaner) enforceShutdown(ctx, work context.Context, cancelWork context.CancelFunc) {
	select {
	case <-work.Done():
		return
	case <-ctx.Done():
	}
	timer := time.NewTimer(c.opts.ShutdownTimeout)
	defer timer.Stop()
	select {
	case <-timer.C:
		c.log.Warn("Shutdown timeout reached; abandoning storage deletes still in flight", "timeout", c.opts.ShutdownTimeout.String())
		cancelWork()
	case <-work.Done():
	}
}

func (c *Cleaner) loop(ctx, work context.Context) {
	var backoff time.Duration
	for ctx.Err() == nil {
		more, err := c.round(ctx, work)
		switch {
		case err != nil:
			backoff = grow(backoff, c.backoffMin, c.backoffMax)
			if ctx.Err() == nil {
				c.log.Warn("Could not claim storage cleanup entries", "error", err, "retry_in", backoff.String())
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

func (c *Cleaner) idle(ctx context.Context, wait time.Duration) {
	timer := time.NewTimer(wait)
	defer timer.Stop()
	select {
	case <-ctx.Done():
	case <-timer.C:
	}
}

func (c *Cleaner) round(ctx, work context.Context) (bool, error) {
	claimedAt := time.Now()
	entries, err := c.opts.Store.Claim(work, c.opts.Instance, c.opts.BatchSize, c.opts.ObjectsPerEntry, c.opts.Lease)
	if err != nil {
		c.mu.Lock()
		c.claimErrors++
		c.mu.Unlock()
		return false, err
	}
	if len(entries) == 0 {
		return false, nil
	}
	results := c.process(ctx, work, entries, claimedAt.Add(c.opts.Lease-c.opts.RequestTimeout-leaseMargin))
	c.record(entries, results, time.Since(claimedAt))
	c.report(ctx, results)
	return c.more(entries, results), nil
}

func (c *Cleaner) process(ctx, work context.Context, entries []store.Entry, startBy time.Time) []store.Result {
	results := make([]store.Result, len(entries))
	for i, entry := range entries {
		results[i] = store.Result{ID: entry.ID, Release: len(entry.Objects) > 0}
	}
	starting, stopStarting := context.WithDeadline(ctx, startBy)
	defer stopStarting()
	slots := make(chan struct{}, c.opts.Concurrency)
	var wg sync.WaitGroup
	for i, entry := range entries {
		if len(entry.Objects) == 0 {
			continue
		}
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
			results[i] = c.clean(starting, work, entry)
		}()
	}
	wg.Wait()
	return results
}

func (c *Cleaner) clean(starting, work context.Context, entry store.Entry) store.Result {
	result := store.Result{ID: entry.ID}
	for from := 0; from < len(entry.Objects); from += c.opts.DeleteChunk {
		if starting.Err() != nil {
			result.Release = true
			return result
		}
		chunk := entry.Objects[from:min(from+c.opts.DeleteChunk, len(entry.Objects))]
		deleted, err := c.opts.Storage.Delete(work, entry.Bucket, chunk)
		result.Deleted += max(deleted, 0)
		if err != nil {
			if work.Err() != nil {
				result.Release = true
			} else {
				result.Error = err.Error()
			}
			return result
		}
	}
	return result
}

func (c *Cleaner) record(entries []store.Entry, results []store.Result, took time.Duration) {
	counts := map[string]uint64{}
	var deleted uint64
	for i, r := range results {
		deleted += uint64(r.Deleted)
		switch {
		case r.Error != "":
			counts[metrics.Failed]++
			entry := entries[i]
			c.log.Warn("Storage cleanup entry failed", "id", entry.ID, "bucket", entry.Bucket, "prefix", entry.Prefix,
				"objects", len(entry.Objects), "deleted", r.Deleted, "error", r.Error)
		case r.Release:
			counts[metrics.Released]++
		default:
			counts[metrics.Cleaned]++
		}
	}
	c.mu.Lock()
	c.deleted += deleted
	for outcome, n := range counts {
		c.entries[outcome] += n
	}
	c.mu.Unlock()
	c.log.Info("Storage cleanup round finished", "entries", len(entries), "objects_deleted", deleted,
		"failed", counts[metrics.Failed], "released", counts[metrics.Released], "took_ms", took.Milliseconds())
}

func (c *Cleaner) report(ctx context.Context, results []store.Result) {
	ctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), reportTimeout)
	defer cancel()
	var err error
	for attempt := 0; ; attempt++ {
		var updated int
		if updated, err = c.opts.Store.Report(ctx, c.opts.Instance, results); err == nil {
			c.mu.Lock()
			c.lastSuccess = c.now()
			c.mu.Unlock()
			if updated < len(results) {
				c.log.Warn("Some cleanup results were not applied; their lease may have ended", "results", len(results), "updated", updated)
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
	c.log.Error("Could not report storage cleanup results; the entries return to the queue when the lease ends",
		"error", err, "results", len(results))
}

func (c *Cleaner) more(entries []store.Entry, results []store.Result) bool {
	if len(entries) >= c.opts.BatchSize {
		return true
	}
	for i, entry := range entries {
		if len(entry.Objects) >= c.opts.ObjectsPerEntry && results[i].Error == "" {
			return true
		}
	}
	return false
}

func grow(current, lo, hi time.Duration) time.Duration {
	if current <= 0 {
		return min(lo, hi)
	}
	return min(current*2, hi)
}
