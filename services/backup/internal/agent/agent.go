package agent

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"maps"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"time"

	"olt-social/backup/internal/disk"
	"olt-social/backup/internal/metrics"
	"olt-social/backup/internal/pg"
	"olt-social/backup/internal/restic"
	"olt-social/backup/internal/runner"
	"olt-social/backup/internal/settings"
	"olt-social/backup/internal/state"
	"olt-social/backup/internal/store"
	"olt-social/backup/internal/wal"
)

const (
	JobBase        = "base"
	JobFiles       = "files"
	JobOffsite     = "offsite"
	JobForget      = "forget"
	JobPrune       = "prune"
	JobCheck       = "check"
	JobRestoreTest = "restore_test"
	RecordWAL      = "wal"
	detachedPrefix = "wal-detached-"
	stampLayout    = "20060102T150405Z"
	outboxLimit    = 100
	errorLimit     = 900
)

type Store interface {
	Config(ctx context.Context, known int64) (settings.Settings, error)
	Heartbeat(ctx context.Context, beat store.Beat) ([]string, error)
	Record(ctx context.Context, instance string, run state.Run) error
}

type Repository interface {
	Open(ctx context.Context) error
	Init(ctx context.Context) error
	Unlock(ctx context.Context) error
	Backup(ctx context.Context, req restic.BackupRequest) (restic.Summary, error)
	Snapshots(ctx context.Context, tag string) ([]restic.Snapshot, error)
	Forget(ctx context.Context, p restic.Policy) (int, error)
	Prune(ctx context.Context) error
	Check(ctx context.Context, subset string) error
	Restore(ctx context.Context, spec, target string) error
}

type Database interface {
	Identify(ctx context.Context) (pg.System, error)
	Slot(ctx context.Context) (pg.SlotStatus, error)
	CreateSlot(ctx context.Context) error
	DropSlot(ctx context.Context) error
	DatabaseBytes(ctx context.Context) (int64, error)
	BaseBackup(ctx context.Context, dir, label string) error
	VerifyBackup(ctx context.Context, dir string, ignore ...string) error
	StartReceiver(ctx context.Context, dir string, line func(string)) (runner.Process, error)
	StartServer(ctx context.Context, s pg.LocalServer) (runner.Process, error)
	Query(ctx context.Context, s pg.LocalServer, user, sql string) (string, error)
	StopServer(ctx context.Context, s pg.LocalServer) error
}

type Options struct {
	Store              Store
	Database           Database
	Repository         func(restic.Credentials) Repository
	Disk               func(path string) (disk.Usage, error)
	LocalCheck         func(dir string) error
	Log                *slog.Logger
	Now                func() time.Time
	Instance           string
	Version            string
	StartedAt          time.Time
	DataDir            string
	StorageDir         string
	LocalRepoDir       string
	ConfigPoll         time.Duration
	HeartbeatInterval  time.Duration
	RequestTimeout     time.Duration
	RestoreTestTimeout time.Duration
	Tick               time.Duration
	BackoffMin         time.Duration
	BackoffMax         time.Duration
	SlotCheck          time.Duration
	BaseWait           time.Duration
	RepositoryRetry    time.Duration
	OpenTimeout        time.Duration
	ProbePoll          time.Duration
}

type Agent struct {
	opts       Options
	log        *slog.Logger
	now        func() time.Time
	kick       chan struct{}
	wakeJob    chan struct{}
	wakeRecv   chan struct{}
	walMu      sync.Mutex
	mu         sync.Mutex
	revision   int64
	current    settings.Settings
	table      settings.Timetable
	configured bool
	off        bool
	configErr  string
	readErr    string
	beatErr    string
	creds      restic.Credentials
	repo       Repository
	repoReady  bool
	repoDirty  bool
	repoErr    string
	repoAt     time.Time
	persist    state.Persisted
	running    string
	queue      []string
	streaming  bool
	walErr     string
	slotRisk   bool
	forceReset bool
	recvErr    string
	restarts   uint64
	dropped    bool
	offsiteErr string
	runs       map[string]uint64
	outbox     []state.Run
}

func New(opts Options) *Agent {
	defaults := []struct {
		v *time.Duration
		d time.Duration
	}{
		{&opts.ConfigPoll, 15 * time.Second}, {&opts.HeartbeatInterval, 30 * time.Second}, {&opts.RequestTimeout, 10 * time.Second},
		{&opts.RestoreTestTimeout, 2 * time.Hour}, {&opts.Tick, 5 * time.Second}, {&opts.BackoffMin, time.Second},
		{&opts.BackoffMax, time.Minute}, {&opts.SlotCheck, 30 * time.Second}, {&opts.BaseWait, 2 * time.Minute},
		{&opts.RepositoryRetry, time.Minute}, {&opts.ProbePoll, 2 * time.Second}, {&opts.OpenTimeout, 45 * time.Second},
	}
	for _, d := range defaults {
		if *d.v <= 0 {
			*d.v = d.d
		}
	}
	if opts.Now == nil {
		opts.Now = time.Now
	}
	if opts.Disk == nil {
		opts.Disk = disk.Stat
	}
	if opts.LocalCheck == nil {
		opts.LocalCheck = disk.CheckRepository
	}
	if opts.StartedAt.IsZero() {
		opts.StartedAt = opts.Now()
	}
	return &Agent{
		opts:     opts,
		log:      opts.Log,
		now:      opts.Now,
		kick:     make(chan struct{}, 1),
		wakeJob:  make(chan struct{}, 1),
		wakeRecv: make(chan struct{}, 1),
		revision: settings.UnknownRevision,
		persist:  state.Persisted{Jobs: map[string]state.Job{}},
		runs:     map[string]uint64{},
	}
}

func (a *Agent) Run(ctx context.Context) {
	a.prepare()
	var wg sync.WaitGroup
	for _, loop := range []func(context.Context){a.configLoop, a.heartbeatLoop, a.receiverLoop} {
		wg.Add(1)
		go func() {
			defer wg.Done()
			loop(ctx)
		}()
	}
	a.jobLoop(ctx)
	wg.Wait()
}

func (a *Agent) dir(name string) string { return filepath.Join(a.opts.DataDir, name) }
func (a *Agent) walDir() string         { return a.dir("wal") }
func (a *Agent) baseRoot() string       { return a.dir("base") }
func (a *Agent) restoreRoot() string    { return a.dir("restore-test") }
func (a *Agent) statePath() string      { return a.dir("state.json") }
func (a *Agent) detachedDirs() []string {
	dirs, _ := filepath.Glob(a.dir(detachedPrefix + "*"))
	return dirs
}
func (a *Agent) walDirs() []string { return append([]string{a.walDir()}, a.detachedDirs()...) }
func notify(ch chan struct{}) {
	select {
	case ch <- struct{}{}:
	default:
	}
}
func (a *Agent) kickHeartbeat() { notify(a.kick) }
func (a *Agent) wake()          { notify(a.wakeJob); notify(a.wakeRecv) }

func (a *Agent) prepare() {
	for _, d := range []string{a.walDir(), a.baseRoot(), a.dir("tmp"), a.dir("cache")} {
		if err := os.MkdirAll(d, 0o700); err != nil {
			a.log.Error("Could not create a staging folder", "path", d, "error", err)
		}
	}
	if err := os.RemoveAll(a.restoreRoot()); err != nil {
		a.log.Warn("Could not remove a leftover restore test folder", "error", err)
	}
	if entries, err := os.ReadDir(a.dir("tmp")); err == nil {
		for _, e := range entries {
			_ = os.RemoveAll(filepath.Join(a.dir("tmp"), e.Name()))
		}
	}
	p, err := state.Load(a.statePath())
	if err != nil {
		a.log.Warn("State file is unreadable; starting with a fresh state", "error", err)
	}
	a.mu.Lock()
	a.persist = p
	keep := ""
	if p.Base != nil {
		keep = p.Base.Dir
	}
	a.mu.Unlock()
	a.removeBasesExcept(keep)
}

func (a *Agent) removeBasesExcept(keep string) {
	entries, err := os.ReadDir(a.baseRoot())
	if err != nil {
		return
	}
	for _, e := range entries {
		path := filepath.Join(a.baseRoot(), e.Name())
		if path == keep {
			continue
		}
		if err := os.RemoveAll(path); err != nil {
			a.log.Warn("Could not remove an old local base backup", "path", path, "error", err)
		}
	}
}

func (a *Agent) saveLocked() {
	if err := state.Save(a.statePath(), a.persist); err != nil {
		a.log.Error("Could not save the state file", "error", err)
	}
}

func (a *Agent) idle(ctx context.Context, wait time.Duration, ch chan struct{}) bool {
	timer := time.NewTimer(wait)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-timer.C:
	case <-ch:
	}
	return true
}

func (a *Agent) configLoop(ctx context.Context) {
	for {
		a.refresh(ctx)
		timer := time.NewTimer(a.opts.ConfigPoll)
		select {
		case <-ctx.Done():
			timer.Stop()
			return
		case <-timer.C:
		}
	}
}

func (a *Agent) refresh(ctx context.Context) {
	a.mu.Lock()
	known := a.revision
	a.mu.Unlock()
	c, cancel := context.WithTimeout(ctx, a.opts.RequestTimeout)
	s, err := a.opts.Store.Config(c, known)
	cancel()
	if ctx.Err() != nil {
		return
	}
	text := ""
	if err != nil {
		text = err.Error()
	}
	a.mu.Lock()
	before := a.readErr
	a.readErr = text
	a.mu.Unlock()
	switch {
	case text != "" && text != before:
		a.log.Warn("Could not read the backup settings from the database", "error", text)
	case text == "" && before != "":
		a.log.Info("Reading the backup settings works again")
	}
	if err != nil || s.Unchanged {
		return
	}
	a.apply(s)
}

func (a *Agent) apply(s settings.Settings) {
	a.mu.Lock()
	a.revision = s.Revision
	switch {
	case !s.Configured:
		a.configured, a.off, a.configErr = false, true, ""
		a.current, a.creds, a.repo, a.repoReady, a.repoErr = settings.Settings{}, restic.Credentials{}, nil, false, ""
		a.mu.Unlock()
		a.log.Info("Backup is not configured; only heartbeats are sent", "revision", s.Revision)
	default:
		if err := s.Validate(a.opts.LocalRepoDir); err != nil {
			a.configured, a.off, a.dropped = false, false, false
			a.configErr = "Konfigurasi backup tidak valid: " + strings.ReplaceAll(err.Error(), "\n", "; ")
			a.repo, a.repoReady = nil, false
			msg := a.configErr
			a.mu.Unlock()
			a.log.Warn("Backup settings are invalid", "revision", s.Revision, "error", msg)
			break
		}
		table, _ := s.Timetable()
		creds := s.Credentials()
		a.current, a.table = s, table
		a.configured, a.off, a.dropped, a.configErr = true, false, false, ""
		if creds != a.creds {
			a.creds, a.repoDirty = creds, true
		}
		a.mu.Unlock()
		a.log.Info("Backup settings loaded", "settings", s)
	}
	a.kickHeartbeat()
	a.wake()
}

func (a *Agent) heartbeatLoop(ctx context.Context) {
	timer := time.NewTimer(0)
	defer timer.Stop()
	var backoff time.Duration
	for {
		select {
		case <-ctx.Done():
			return
		case <-a.kick:
		case <-timer.C:
		}
		next := a.opts.HeartbeatInterval
		if err := a.heartbeat(ctx); err != nil {
			if ctx.Err() != nil {
				return
			}
			backoff = grow(backoff, time.Second, a.opts.HeartbeatInterval)
			next = backoff
		} else {
			backoff = 0
		}
		timer.Reset(next)
	}
}

func (a *Agent) heartbeat(ctx context.Context) error {
	report := a.report()
	a.mu.Lock()
	revision := a.revision
	a.mu.Unlock()
	c, cancel := context.WithTimeout(ctx, a.opts.RequestTimeout)
	defer cancel()
	requests, err := a.opts.Store.Heartbeat(c, store.Beat{Instance: a.opts.Instance, Version: a.opts.Version,
		StartedAt: a.opts.StartedAt, ConfigRevision: revision, State: report})
	text := ""
	if err != nil {
		text = err.Error()
	}
	a.mu.Lock()
	before := a.beatErr
	a.beatErr = text
	a.mu.Unlock()
	switch {
	case text != "" && text != before:
		a.log.Warn("Heartbeat failed", "error", text)
	case text == "" && before != "":
		a.log.Info("Heartbeat works again")
	}
	if err != nil {
		return err
	}
	for _, kind := range requests {
		a.request(ctx, kind)
	}
	a.flushOutbox(c)
	return nil
}

func (a *Agent) report() state.Report {
	files, _ := wal.List(a.walDir())
	detached, _ := wal.List(a.detachedDirs()...)
	usage, diskErr := a.opts.Disk(a.opts.DataDir)
	repoDisk := a.repositoryDisk()
	a.mu.Lock()
	defer a.mu.Unlock()
	r := state.Report{RepositoryReady: a.configured && a.repoReady, RepositoryDisk: repoDisk}
	r.WAL.Streaming = a.streaming
	r.WAL.SlotLost = !a.persist.SlotLostAt.IsZero()
	r.WAL.LocalBytes = wal.Bytes(files) + wal.Bytes(detached)
	last, lastAt := newest(files)
	r.WAL.LastSegment, r.WAL.LastReceivedAt = state.Text(last), state.Time(lastAt)
	if a.configured && a.repoReady {
		r.WAL.Error = state.Text(a.walErr)
	}
	r.Offsite = state.OffsiteReport{
		LastOKAt:     state.Time(a.persist.Offsite.LastOKAt),
		LastSnapshot: state.Text(a.persist.Offsite.LastSnapshot),
		LastError:    state.Text(a.offsiteErr),
		PendingBytes: pending(append(files, detached...), a.persist.Offsite.SentFrom),
	}
	if b := a.persist.Base; b != nil && b.Dir != "" {
		r.LocalBase = state.LocalBase{Label: state.Text(b.Label), FinishedAt: state.Time(b.FinishedAt), Bytes: b.Bytes}
	}
	if diskErr == nil {
		r.Disk = state.Disk{TotalBytes: usage.Total, AvailBytes: usage.Avail}
	}
	r.Busy = state.Text(busyName(a.running))
	r.Error = state.Text(a.topErrorLocked())
	return r
}

func (a *Agent) repositoryDisk() *state.Disk {
	a.mu.Lock()
	local := a.configured && a.current.Local()
	a.mu.Unlock()
	if !local {
		return nil
	}
	usage, err := a.opts.Disk(a.opts.LocalRepoDir)
	if err != nil {
		return nil
	}
	return &state.Disk{TotalBytes: usage.Total, AvailBytes: usage.Avail}
}

func newest(files []wal.File) (string, time.Time) {
	name, at := "", time.Time{}
	for _, f := range files {
		if f.History {
			continue
		}
		if base := strings.TrimSuffix(f.Name, wal.PartialSuffix); base > name {
			name = base
		}
		if f.ModTime.After(at) {
			at = f.ModTime
		}
	}
	return name, at
}

func pending(files []wal.File, since time.Time) int64 {
	var n int64
	for _, f := range files {
		if since.IsZero() || !f.ModTime.Before(since) {
			n += f.Size
		}
	}
	return n
}

func busyName(job string) string {
	if job == JobForget {
		return JobPrune
	}
	return job
}

func (a *Agent) topErrorLocked() string {
	if a.configErr != "" {
		return a.configErr
	}
	if a.configured && !a.repoReady {
		return a.repoErr
	}
	return ""
}

func (a *Agent) notReadyLocked() string {
	switch {
	case a.configErr != "":
		return a.configErr
	case !a.configured:
		return "backup belum dikonfigurasi"
	case a.repoErr != "":
		return a.repoErr
	default:
		return "repositori backup belum siap"
	}
}

func (a *Agent) request(ctx context.Context, kind string) {
	if kind != JobBase && kind != JobRestoreTest {
		a.log.Warn("Ignoring an unknown manual backup request", "kind", kind)
		return
	}
	a.mu.Lock()
	ready := a.configured && a.repoReady
	reason := a.notReadyLocked()
	if ready {
		a.enqueueLocked(kind)
	}
	a.mu.Unlock()
	if !ready {
		at := a.now()
		a.log.Warn("Manual backup request cannot run yet", "kind", kind, "reason", reason)
		a.record(ctx, state.Run{Kind: kind, Status: state.StatusFailed, StartedAt: at.UTC(), FinishedAt: at.UTC(),
			Detail: map[string]any{"manual": true}, Error: state.Text("Permintaan manual tidak dijalankan: " + reason)})
		return
	}
	a.log.Info("Manual backup job queued", "kind", kind)
	notify(a.wakeJob)
}

func (a *Agent) enqueueLocked(jobs ...string) {
	for _, job := range jobs {
		if job == a.running || slices.Contains(a.queue, job) {
			continue
		}
		a.queue = append(a.queue, job)
	}
}

func (a *Agent) enqueueFrontLocked(jobs ...string) {
	a.queue = slices.DeleteFunc(a.queue, func(j string) bool { return slices.Contains(jobs, j) })
	a.queue = append(slices.Clone(jobs), a.queue...)
}

func (a *Agent) record(ctx context.Context, run state.Run) {
	if run.Detail == nil {
		run.Detail = map[string]any{}
	}
	a.mu.Lock()
	a.runs[metrics.RunKey(run.Kind, run.Status)]++
	a.mu.Unlock()
	c, cancel := context.WithTimeout(context.WithoutCancel(ctx), a.opts.RequestTimeout)
	defer cancel()
	if err := a.opts.Store.Record(c, a.opts.Instance, run); err != nil {
		a.log.Warn("Could not record a backup run; it will be sent again", "kind", run.Kind, "status", run.Status, "error", err)
		a.mu.Lock()
		a.outbox = append(a.outbox, run)
		if over := len(a.outbox) - outboxLimit; over > 0 {
			a.outbox = a.outbox[over:]
		}
		a.mu.Unlock()
	}
}

func (a *Agent) flushOutbox(ctx context.Context) {
	a.mu.Lock()
	queued := a.outbox
	a.outbox = nil
	a.mu.Unlock()
	for i, run := range queued {
		if err := a.opts.Store.Record(ctx, a.opts.Instance, run); err != nil {
			a.mu.Lock()
			a.outbox = append(slices.Clone(queued[i:]), a.outbox...)
			a.mu.Unlock()
			return
		}
	}
}

func (a *Agent) Metrics() metrics.Snapshot {
	r := a.report()
	a.mu.Lock()
	defer a.mu.Unlock()
	s := metrics.Snapshot{
		Configured:        a.configured,
		RepositoryReady:   r.RepositoryReady,
		Streaming:         r.WAL.Streaming,
		SlotLost:          r.WAL.SlotLost,
		Busy:              busyName(a.running),
		Runs:              maps.Clone(a.runs),
		ReceiverRestarts:  a.restarts,
		WALLocalBytes:     r.WAL.LocalBytes,
		OffsitePending:    r.Offsite.PendingBytes,
		LocalBaseBytes:    r.LocalBase.Bytes,
		DiskTotal:         r.Disk.TotalBytes,
		DiskAvail:         r.Disk.AvailBytes,
		LastOffsiteOK:     a.persist.Offsite.LastOKAt,
		LastBaseOK:        a.persist.Job(JobBase).LastOK,
		LastRestoreTestOK: a.persist.Job(JobRestoreTest).LastOK,
	}
	if r.WAL.LastReceivedAt != nil {
		s.LastWALReceived = *r.WAL.LastReceivedAt
	}
	if r.RepositoryDisk != nil {
		s.RepoDiskTotal, s.RepoDiskAvail = r.RepositoryDisk.TotalBytes, r.RepositoryDisk.AvailBytes
	}
	return s
}

func grow(current, lo, hi time.Duration) time.Duration {
	if current <= 0 {
		return min(lo, hi)
	}
	return min(current*2, hi)
}

func clip(text string) string {
	text = strings.TrimSpace(text)
	if len(text) <= errorLimit {
		return text
	}
	return text[:errorLimit] + "…"
}

func describe(prefix string, err error) error {
	if err == nil {
		return nil
	}
	return errors.New(clip(prefix + ": " + runner.Detail(err)))
}

func human(n int64) string {
	const unit = 1024
	if n < unit {
		return fmt.Sprintf("%d B", n)
	}
	div, exp := int64(unit), 0
	for m := n / unit; m >= unit; m /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %ciB", float64(n)/float64(div), "KMGTPE"[exp])
}
