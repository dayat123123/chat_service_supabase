package worker

import (
	"context"
	"log/slog"
	"maps"
	"sync"
	"time"

	"olt-social/notifier/internal/metrics"
	"olt-social/notifier/internal/push"
)

const (
	leaseMargin      = 3 * time.Second
	heartbeatTimeout = 10 * time.Second
	reportTimeout    = 15 * time.Second
	errorNotSent     = "Belum sempat dikirim, dijadwalkan ulang"
)

type Store interface {
	Claim(ctx context.Context, instance string, limit int, lease time.Duration) ([]push.Job, error)
	Report(ctx context.Context, instance string, results []push.Result) (int, error)
	Heartbeat(ctx context.Context, beat push.Heartbeat) (int, error)
	Credentials(ctx context.Context, known int64) (push.Credentials, error)
}

type Sender interface {
	Load(data []byte) push.Status
	Verify(ctx context.Context) error
	Send(ctx context.Context, job push.Job) push.Delivery
}

type Options struct {
	Store             Store
	Sender            Sender
	Log               *slog.Logger
	Instance          string
	Version           string
	StartedAt         time.Time
	BatchSize         int
	Concurrency       int
	Lease             time.Duration
	PollInterval      time.Duration
	HeartbeatInterval time.Duration
	ReloadInterval    time.Duration
	SendTimeout       time.Duration
	ShutdownTimeout   time.Duration
}

type Worker struct {
	opts         Options
	log          *slog.Logger
	pauseMin     time.Duration
	pauseMax     time.Duration
	backoffMin   time.Duration
	backoffMax   time.Duration
	reportDelays []time.Duration
	kick         chan struct{}
	wake         chan struct{}

	mu          sync.Mutex
	revision    int64
	readError   string
	status      push.Status
	problem     string
	probe       bool
	pause       time.Duration
	pausedUntil time.Time
	queued      int
	pushes      map[push.Outcome]uint64
	batches     uint64
}

func New(opts Options) *Worker {
	if opts.StartedAt.IsZero() {
		opts.StartedAt = time.Now()
	}
	return &Worker{
		opts:         opts,
		log:          opts.Log,
		pauseMin:     15 * time.Second,
		pauseMax:     5 * time.Minute,
		backoffMin:   time.Second,
		backoffMax:   30 * time.Second,
		reportDelays: []time.Duration{250 * time.Millisecond, 500 * time.Millisecond, time.Second},
		kick:         make(chan struct{}, 1),
		wake:         make(chan struct{}, 1),
		revision:     push.UnknownRevision,
		pushes:       map[push.Outcome]uint64{},
	}
}

func (w *Worker) Run(ctx context.Context) {
	w.refresh(ctx)
	work, cancelWork := context.WithCancel(context.WithoutCancel(ctx))
	defer cancelWork()
	go w.enforceShutdown(ctx, work, cancelWork)

	var monitor sync.WaitGroup
	monitor.Add(1)
	go func() {
		defer monitor.Done()
		w.monitor(ctx)
	}()
	w.loop(ctx, work)
	monitor.Wait()
}

func (w *Worker) Metrics() metrics.Snapshot {
	w.mu.Lock()
	defer w.mu.Unlock()
	return metrics.Snapshot{
		Pushes:       maps.Clone(w.pushes),
		ClaimBatches: w.batches,
		QueueDepth:   w.queued,
		Configured:   w.status.Configured,
		Healthy:      w.status.Configured && w.errorLocked() == "",
	}
}

func (w *Worker) enforceShutdown(ctx, work context.Context, cancelWork context.CancelFunc) {
	select {
	case <-work.Done():
		return
	case <-ctx.Done():
	}
	timer := time.NewTimer(w.opts.ShutdownTimeout)
	defer timer.Stop()
	select {
	case <-timer.C:
		w.log.Warn("Shutdown timeout reached; abandoning pushes still in flight", "timeout", w.opts.ShutdownTimeout.String())
		cancelWork()
	case <-work.Done():
	}
}

func (w *Worker) refresh(ctx context.Context) bool {
	w.mu.Lock()
	known := w.revision
	w.mu.Unlock()
	fetch, cancel := context.WithTimeout(ctx, heartbeatTimeout)
	creds, err := w.opts.Store.Credentials(fetch, known)
	cancel()
	if ctx.Err() != nil {
		return false
	}
	w.noteReadError(err)
	if err != nil {
		return false
	}
	if creds.Unchanged {
		return w.recheck(ctx)
	}
	status := push.Status{Configured: creds.Configured, Problem: creds.Problem}
	if creds.Configured && creds.Problem == "" && creds.Data != nil {
		status = w.opts.Sender.Load(creds.Data)
	} else {
		w.opts.Sender.Load(nil)
	}
	w.mu.Lock()
	w.revision = creds.Revision
	w.status = status
	w.problem = ""
	w.probe = false
	w.pause = 0
	w.pausedUntil = time.Time{}
	w.mu.Unlock()
	switch {
	case !status.Configured:
		w.log.Info("No Firebase credentials yet; push delivery is idle", "revision", creds.Revision)
	case status.Problem != "":
		w.log.Warn("Firebase credentials cannot be used", "revision", creds.Revision, "error", status.Problem)
	default:
		w.log.Info("Firebase credentials loaded", "revision", creds.Revision, "project_id", status.ProjectID)
		w.verify(ctx)
	}
	return true
}

func (w *Worker) noteReadError(err error) {
	text := ""
	if err != nil {
		text = err.Error()
	}
	w.mu.Lock()
	before := w.readError
	w.readError = text
	w.mu.Unlock()
	switch {
	case text != "" && text != before:
		w.log.Warn("Could not read Firebase credentials from the database", "error", text)
	case text == "" && before != "":
		w.log.Info("Reading Firebase credentials from the database works again")
	}
}

func (w *Worker) recheck(ctx context.Context) bool {
	w.mu.Lock()
	due := w.probe && w.status.Configured && w.status.Problem == "" && !time.Now().Before(w.pausedUntil)
	w.mu.Unlock()
	if !due {
		return false
	}
	return w.verify(ctx)
}

func (w *Worker) verify(ctx context.Context) bool {
	err := w.opts.Sender.Verify(ctx)
	if ctx.Err() != nil {
		return false
	}
	w.mu.Lock()
	before := w.problem
	if err != nil {
		w.problem, w.probe = err.Error(), true
		w.pause = grow(w.pause, w.pauseMin, w.pauseMax)
		w.pausedUntil = time.Now().Add(w.pause)
	} else {
		w.problem, w.probe, w.pause, w.pausedUntil = "", false, 0, time.Time{}
	}
	after, pause := w.problem, w.pause
	project := w.status.ProjectID
	w.mu.Unlock()
	if err != nil {
		w.log.Warn("Firebase credentials check failed", "project_id", project, "error", after, "retry_in", pause.String())
	} else {
		w.log.Info("Firebase credentials verified", "project_id", project)
	}
	return after != before
}

func (w *Worker) monitor(ctx context.Context) {
	beat := time.NewTimer(0)
	defer beat.Stop()
	reload := time.NewTicker(w.opts.ReloadInterval)
	defer reload.Stop()
	var backoff time.Duration
	for {
		select {
		case <-ctx.Done():
			return
		case <-reload.C:
			if !w.refresh(ctx) {
				continue
			}
			notify(w.wake)
		case <-w.kick:
		case <-beat.C:
		}
		next := w.opts.HeartbeatInterval
		if err := w.heartbeat(ctx); err != nil {
			if ctx.Err() != nil {
				return
			}
			backoff = grow(backoff, w.backoffMin, min(w.backoffMax, w.opts.HeartbeatInterval))
			next = backoff
			w.log.Warn("Heartbeat failed", "error", err, "retry_in", backoff.String())
		} else {
			backoff = 0
		}
		beat.Reset(next)
	}
}

func (w *Worker) heartbeat(ctx context.Context) error {
	w.mu.Lock()
	beat := push.Heartbeat{
		Instance:            w.opts.Instance,
		Version:             w.opts.Version,
		Configured:          w.status.Configured,
		ProjectID:           w.status.ProjectID,
		Error:               w.errorLocked(),
		StartedAt:           w.opts.StartedAt,
		CredentialsRevision: w.revision,
	}
	w.mu.Unlock()
	ctx, cancel := context.WithTimeout(ctx, heartbeatTimeout)
	defer cancel()
	queued, err := w.opts.Store.Heartbeat(ctx, beat)
	if err != nil {
		return err
	}
	w.mu.Lock()
	w.queued = queued
	w.mu.Unlock()
	return nil
}

func (w *Worker) errorLocked() string {
	if w.status.Problem != "" {
		return w.status.Problem
	}
	return w.problem
}

func (w *Worker) loop(ctx, work context.Context) {
	var backoff time.Duration
	for ctx.Err() == nil {
		if wait := w.blocked(); wait > 0 {
			w.idle(ctx, wait)
			continue
		}
		claimed, err := w.cycle(ctx, work)
		switch {
		case err != nil:
			backoff = grow(backoff, w.backoffMin, w.backoffMax)
			if ctx.Err() == nil {
				w.log.Warn("Could not claim push jobs", "error", err, "retry_in", backoff.String())
			}
			w.idle(ctx, backoff)
		case claimed >= w.opts.BatchSize:
			backoff = 0
		default:
			backoff = 0
			w.idle(ctx, w.opts.PollInterval)
		}
	}
}

func (w *Worker) blocked() time.Duration {
	w.mu.Lock()
	defer w.mu.Unlock()
	if !w.status.Configured || w.status.Problem != "" {
		return time.Minute
	}
	return time.Until(w.pausedUntil)
}

func (w *Worker) idle(ctx context.Context, wait time.Duration) {
	timer := time.NewTimer(wait)
	defer timer.Stop()
	select {
	case <-ctx.Done():
	case <-timer.C:
	case <-w.wake:
	}
}

func (w *Worker) cycle(ctx, work context.Context) (int, error) {
	claimedAt := time.Now()
	jobs, err := w.opts.Store.Claim(work, w.opts.Instance, w.opts.BatchSize, w.opts.Lease)
	if err != nil {
		return 0, err
	}
	if len(jobs) == 0 {
		return 0, nil
	}
	deliveries := w.dispatch(work, jobs, claimedAt.Add(w.opts.Lease-w.opts.SendTimeout-leaseMargin))
	systemic, pause := w.settle(deliveries)
	results := make([]push.Result, len(jobs))
	for i, job := range jobs {
		results[i] = w.result(job, deliveries[i], systemic, pause)
	}
	w.record(jobs, results, time.Since(claimedAt))
	w.report(ctx, results)
	return len(jobs), nil
}

func (w *Worker) dispatch(work context.Context, jobs []push.Job, startBy time.Time) []*push.Delivery {
	deliveries := make([]*push.Delivery, len(jobs))
	starting, stopStarting := context.WithDeadline(work, startBy)
	defer stopStarting()
	slots := make(chan struct{}, w.opts.Concurrency)
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
			delivery := w.opts.Sender.Send(work, job)
			deliveries[i] = &delivery
			if delivery.Systemic {
				stopStarting()
			}
		}()
	}
	wg.Wait()
	return deliveries
}

func (w *Worker) settle(deliveries []*push.Delivery) (*push.Delivery, time.Duration) {
	var systemic *push.Delivery
	problem, healthy := "", false
	for _, d := range deliveries {
		switch {
		case d == nil:
		case d.Systemic:
			if systemic == nil {
				systemic = d
			}
		case d.Problem != "":
			problem = d.Problem
		case d.Healthy:
			healthy = true
		}
	}
	w.mu.Lock()
	before := w.problem
	var pause time.Duration
	switch {
	case systemic != nil:
		w.pause = grow(w.pause, w.pauseMin, w.pauseMax)
		w.pausedUntil = time.Now().Add(w.pause)
		w.problem, w.probe = systemic.Problem, true
		pause = w.pause
	case problem != "":
		w.problem, w.probe = problem, false
	case healthy:
		w.problem, w.probe = "", false
		w.pause = 0
	}
	after := w.problem
	w.mu.Unlock()

	switch {
	case systemic != nil:
		w.log.Warn("Firebase problem; pausing push delivery", "error", systemic.Problem, "pause", pause.String())
	case after != before && after != "":
		w.log.Warn("Firebase reported a problem", "error", after)
	case after != before:
		w.log.Info("Firebase delivery recovered")
	}
	if systemic != nil || after != before {
		notify(w.kick)
	}
	return systemic, pause
}

func (w *Worker) result(job push.Job, d *push.Delivery, systemic *push.Delivery, pause time.Duration) push.Result {
	switch {
	case d != nil && !d.Systemic:
		r := d.Result
		r.ID = job.ID
		return r
	case systemic != nil:
		return push.Result{ID: job.ID, Outcome: push.Release, Error: systemic.Problem, RetryAfter: pause}
	default:
		return push.Result{ID: job.ID, Outcome: push.Release, Error: errorNotSent, RetryAfter: time.Second}
	}
}

func (w *Worker) record(jobs []push.Job, results []push.Result, took time.Duration) {
	counts := map[push.Outcome]int{}
	for i, r := range results {
		counts[r.Outcome]++
		job := jobs[i]
		switch r.Outcome {
		case push.Failed:
			w.log.Warn("Push failed", "id", job.ID, "kind", job.Kind, "platform", job.Platform,
				"device", deviceHint(job.Token), "attempt", job.Attempt, "error", r.Error)
		case push.Invalid, push.Retry:
			w.log.Debug("Push not delivered", "id", job.ID, "outcome", r.Outcome, "platform", job.Platform,
				"device", deviceHint(job.Token), "attempt", job.Attempt, "error", r.Error)
		}
	}
	w.mu.Lock()
	w.batches++
	for outcome, n := range counts {
		w.pushes[outcome] += uint64(n)
	}
	w.mu.Unlock()
	w.log.Info("Push batch processed", "claimed", len(jobs), "sent", counts[push.Sent], "retry", counts[push.Retry],
		"invalid", counts[push.Invalid], "failed", counts[push.Failed], "release", counts[push.Release],
		"took_ms", took.Milliseconds())
}

func (w *Worker) report(ctx context.Context, results []push.Result) {
	ctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), reportTimeout)
	defer cancel()
	var err error
	for attempt := 0; ; attempt++ {
		var updated int
		if updated, err = w.opts.Store.Report(ctx, w.opts.Instance, results); err == nil {
			if updated < len(results) {
				w.log.Debug("Some push results were not applied", "results", len(results), "updated", updated)
			}
			return
		}
		if attempt == len(w.reportDelays) {
			break
		}
		timer := time.NewTimer(w.reportDelays[attempt])
		select {
		case <-ctx.Done():
			timer.Stop()
		case <-timer.C:
		}
	}
	w.log.Error("Could not report push results; the jobs return to the queue when the lease ends",
		"error", err, "results", len(results))
}

func grow(current, lo, hi time.Duration) time.Duration {
	if current <= 0 {
		return min(lo, hi)
	}
	return min(current*2, hi)
}

func notify(ch chan struct{}) {
	select {
	case ch <- struct{}{}:
	default:
	}
}

func deviceHint(token string) string {
	if len(token) <= 6 {
		return "..."
	}
	return "..." + token[len(token)-6:]
}
