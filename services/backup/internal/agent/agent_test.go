package agent

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"olt-social/backup/internal/disk"
	"olt-social/backup/internal/pg"
	"olt-social/backup/internal/restic"
	"olt-social/backup/internal/runner"
	"olt-social/backup/internal/settings"
	"olt-social/backup/internal/state"
	"olt-social/backup/internal/store"
)

const (
	secretPassword = "restic-password-0123456789"
	secretKey      = "s3-secret-access-key"
)

func validSettings(rev int64) settings.Settings {
	return settings.Settings{
		Revision: rev, Configured: true,
		Repository: "s3:http://seaweed:8333/olt-backup/dev",
		S3:         settings.S3{AccessKeyID: "olt-access", SecretAccessKey: secretKey},
		Password:   secretPassword,
		Schedule: settings.Schedule{BaseTime: "02:00", Timezone: "Asia/Jakarta", OffsiteMinutes: 5,
			RestoreTestWeekday: 0, RestoreTestTime: "04:00"},
		Retention:   settings.Retention{Daily: 7, Weekly: 4, Monthly: 6, WALDays: 7},
		RestoreTest: true,
	}
}

type fakeStore struct {
	mu       sync.Mutex
	current  settings.Settings
	beats    []store.Beat
	runs     []state.Run
	requests []string
	failRuns int
}

func (s *fakeStore) Config(_ context.Context, known int64) (settings.Settings, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if known == s.current.Revision {
		return settings.Settings{Revision: known, Unchanged: true}, nil
	}
	return s.current, nil
}

func (s *fakeStore) Heartbeat(_ context.Context, beat store.Beat) ([]string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.beats = append(s.beats, beat)
	reqs := s.requests
	s.requests = nil
	return reqs, nil
}

func (s *fakeStore) Record(_ context.Context, _ string, run state.Run) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.failRuns > 0 {
		s.failRuns--
		return errors.New("postgrest down")
	}
	s.runs = append(s.runs, run)
	return nil
}

func (s *fakeStore) request(kinds ...string) {
	s.mu.Lock()
	s.requests = append(s.requests, kinds...)
	s.mu.Unlock()
}

func (s *fakeStore) recorded() []state.Run {
	s.mu.Lock()
	defer s.mu.Unlock()
	return slices.Clone(s.runs)
}

func (s *fakeStore) lastBeat() (store.Beat, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.beats) == 0 {
		return store.Beat{}, false
	}
	return s.beats[len(s.beats)-1], true
}

func (s *fakeStore) sawBeat(match func(state.Report) bool) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return slices.ContainsFunc(s.beats, func(b store.Beat) bool { return match(b.State) })
}

func (s *fakeStore) run(kind, status string) (state.Run, bool) {
	for _, r := range s.recorded() {
		if r.Kind == kind && r.Status == status {
			return r, true
		}
	}
	return state.Run{}, false
}

type tracker struct {
	inflight atomic.Int32
	peak     atomic.Int32
}

func (t *tracker) enter() func() {
	n := t.inflight.Add(1)
	for {
		p := t.peak.Load()
		if n <= p || t.peak.CompareAndSwap(p, n) {
			break
		}
	}
	time.Sleep(2 * time.Millisecond)
	return func() { t.inflight.Add(-1) }
}

type fakeRepo struct {
	mu       sync.Mutex
	track    *tracker
	openErr  error
	calls    []string
	snaps    []restic.Snapshot
	backups  []restic.BackupRequest
	forgets  []restic.Policy
	restores []string
}

func (r *fakeRepo) log(call string) {
	r.mu.Lock()
	r.calls = append(r.calls, call)
	r.mu.Unlock()
}

func (r *fakeRepo) Open(context.Context) error {
	r.log("open")
	r.mu.Lock()
	defer r.mu.Unlock()
	err := r.openErr
	if errors.Is(err, restic.ErrNoRepository) {
		r.openErr = nil
	}
	return err
}

func (r *fakeRepo) Init(context.Context) error   { r.log("init"); return nil }
func (r *fakeRepo) Unlock(context.Context) error { r.log("unlock"); return nil }

func (r *fakeRepo) Backup(_ context.Context, req restic.BackupRequest) (restic.Summary, error) {
	defer r.track.enter()()
	r.mu.Lock()
	defer r.mu.Unlock()
	r.calls = append(r.calls, "backup:"+req.Tags[0])
	r.backups = append(r.backups, req)
	id := fmt.Sprintf("%064x", len(r.backups))
	r.snaps = append(r.snaps, restic.Snapshot{ID: id, ShortID: id[56:], Time: time.Now(), Paths: req.Paths, Tags: req.Tags,
		Summary: &restic.SnapshotSummary{TotalBytesProcessed: 64, TotalFilesProcessed: 2}})
	return restic.Summary{SnapshotID: id, TotalBytesProcessed: 64, TotalFilesProcessed: 2, DataAdded: 32}, nil
}

func (r *fakeRepo) Snapshots(context.Context, string) ([]restic.Snapshot, error) {
	defer r.track.enter()()
	r.mu.Lock()
	defer r.mu.Unlock()
	return slices.Clone(r.snaps), nil
}

func (r *fakeRepo) Forget(_ context.Context, p restic.Policy) (int, error) {
	defer r.track.enter()()
	r.mu.Lock()
	r.forgets = append(r.forgets, p)
	r.mu.Unlock()
	r.log("forget:" + p.Tag)
	return 1, nil
}

func (r *fakeRepo) Prune(context.Context) error { defer r.track.enter()(); r.log("prune"); return nil }

func (r *fakeRepo) Check(_ context.Context, subset string) error {
	defer r.track.enter()()
	r.log("check:" + subset)
	return nil
}

func (r *fakeRepo) Restore(_ context.Context, spec, target string) error {
	defer r.track.enter()()
	r.mu.Lock()
	r.restores = append(r.restores, spec)
	r.mu.Unlock()
	files := map[string]string{}
	if strings.Contains(spec, ":") {
		files = map[string]string{
			"PG_VERSION":                      "17",
			"backup_label":                    "START WAL LOCATION: 0/1000028 (file 000000010000000000000001)\n",
			"pg_wal/000000010000000000000001": strings.Repeat("w", 16),
		}
	} else {
		files = map[string]string{
			"var/lib/olt-backup/wal/000000010000000000000001":         strings.Repeat("w", 16),
			"var/lib/olt-backup/wal/000000010000000000000002.partial": strings.Repeat("p", 16),
		}
	}
	for name, content := range files {
		path := filepath.Join(target, name)
		_ = os.MkdirAll(filepath.Dir(path), 0o700)
		_ = os.WriteFile(path, []byte(content), 0o600)
	}
	return nil
}

func (r *fakeRepo) called() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return slices.Clone(r.calls)
}

type fakeProc struct {
	done chan struct{}
	once sync.Once
}

func newProc() *fakeProc { return &fakeProc{done: make(chan struct{})} }

func (p *fakeProc) Done() <-chan struct{} { return p.done }
func (p *fakeProc) Wait() error           { <-p.done; return nil }
func (p *fakeProc) Interrupt()            { p.once.Do(func() { close(p.done) }) }

type fakeDB struct {
	mu        sync.Mutex
	track     *tracker
	system    string
	slot      pg.SlotStatus
	dbBytes   int64
	calls     []string
	receivers int
	verifies  [][]string
	recovery  bool
}

func (d *fakeDB) log(call string) {
	d.mu.Lock()
	d.calls = append(d.calls, call)
	d.mu.Unlock()
}

func (d *fakeDB) called() []string {
	d.mu.Lock()
	defer d.mu.Unlock()
	return slices.Clone(d.calls)
}

func (d *fakeDB) setSlot(s pg.SlotStatus) {
	d.mu.Lock()
	d.slot = s
	d.mu.Unlock()
}

func (d *fakeDB) Identify(context.Context) (pg.System, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	return pg.System{ID: d.system, Timeline: 1, LSN: "0/1000000"}, nil
}

func (d *fakeDB) Slot(context.Context) (pg.SlotStatus, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.slot, nil
}

func (d *fakeDB) CreateSlot(context.Context) error {
	d.log("create-slot")
	d.setSlot(pg.SlotStatus{Exists: true})
	return nil
}

func (d *fakeDB) DropSlot(context.Context) error {
	d.log("drop-slot")
	d.setSlot(pg.SlotStatus{})
	return nil
}

func (d *fakeDB) DatabaseBytes(context.Context) (int64, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.dbBytes, nil
}

func (d *fakeDB) BaseBackup(_ context.Context, dir, label string) error {
	defer d.track.enter()()
	d.log("basebackup:" + label)
	_ = os.MkdirAll(filepath.Join(dir, "pg_wal"), 0o700)
	_ = os.WriteFile(filepath.Join(dir, "backup_label"), []byte("START WAL LOCATION: 0/1000028 (file 000000010000000000000001)\nLABEL: "+label+"\n"), 0o600)
	return os.WriteFile(filepath.Join(dir, "PG_VERSION"), []byte("17"), 0o600)
}

func (d *fakeDB) VerifyBackup(_ context.Context, dir string, ignore ...string) error {
	defer d.track.enter()()
	d.mu.Lock()
	d.verifies = append(d.verifies, append([]string{dir}, ignore...))
	d.mu.Unlock()
	return nil
}

func (d *fakeDB) StartReceiver(ctx context.Context, dir string, line func(string)) (runner.Process, error) {
	d.mu.Lock()
	d.receivers++
	d.slot = pg.SlotStatus{Exists: true, WALStatus: "reserved", Active: true, Reserved: true}
	d.mu.Unlock()
	_ = os.WriteFile(filepath.Join(dir, "000000010000000000000001.partial"), make([]byte, 16), 0o600)
	p := newProc()
	go func() {
		line("pg_receivewal: starting log streaming at 0/1000000 (timeline 1)")
		select {
		case <-ctx.Done():
			p.Interrupt()
		case <-p.done:
		}
	}()
	return p, nil
}

func (d *fakeDB) StartServer(context.Context, pg.LocalServer) (runner.Process, error) {
	defer d.track.enter()()
	d.log("start-server")
	return newProc(), nil
}

func (d *fakeDB) Query(_ context.Context, s pg.LocalServer, user, sql string) (string, error) {
	if _, err := os.Stat(filepath.Join(s.DataDir, "recovery.signal")); err != nil {
		return "", errors.New("recovery.signal missing")
	}
	if strings.Contains(sql, "pg_is_in_recovery") {
		d.mu.Lock()
		defer d.mu.Unlock()
		if !d.recovery {
			d.recovery = true
			return "", errors.New("the database system is starting up")
		}
		return "f", nil
	}
	return `{"recovered_until":"2026-11-03T01:33:53+00:00","last_message_at":"2026-11-03T01:00:00+00:00","tables":{"public.profiles":12,"public.messages":340,"cs.tickets":7}}`, nil
}

func (d *fakeDB) StopServer(context.Context, pg.LocalServer) error {
	d.log("stop-server")
	return nil
}

type harness struct {
	t      *testing.T
	agent  *Agent
	store  *fakeStore
	repo   *fakeRepo
	db     *fakeDB
	track  *tracker
	dir    string
	logs   *syncBuffer
	disk   atomic.Int64
	made   atomic.Int32
	cancel context.CancelFunc
	done   chan struct{}
}

type syncBuffer struct {
	mu  sync.Mutex
	buf *bytes.Buffer
}

func (s *syncBuffer) Write(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.buf.Write(p)
}

func newHarness(t *testing.T, current settings.Settings) *harness {
	t.Helper()
	track := &tracker{}
	h := &harness{t: t, store: &fakeStore{current: current}, track: track, dir: t.TempDir(), logs: &syncBuffer{buf: &bytes.Buffer{}},
		repo: &fakeRepo{track: track}, db: &fakeDB{track: track, system: "7702039750691532834", dbBytes: 50 << 20}}
	h.disk.Store(50 << 30)
	return h
}

func (h *harness) logText() string {
	h.logs.mu.Lock()
	defer h.logs.mu.Unlock()
	return h.logs.buf.String()
}

func (h *harness) start() {
	h.t.Helper()
	h.agent = New(Options{
		Store:    h.store,
		Database: h.db,
		Repository: func(restic.Credentials) Repository {
			h.made.Add(1)
			return h.repo
		},
		Disk: func(string) (disk.Usage, error) {
			return disk.Usage{Total: 100 << 30, Avail: h.disk.Load()}, nil
		},
		Log:                slog.New(slog.NewJSONHandler(h.logs, &slog.HandlerOptions{Level: slog.LevelDebug})),
		Instance:           "backup-test",
		Version:            "0.1.0",
		DataDir:            h.dir,
		StorageDir:         h.t.TempDir(),
		ConfigPoll:         20 * time.Millisecond,
		HeartbeatInterval:  20 * time.Millisecond,
		RequestTimeout:     time.Second,
		RestoreTestTimeout: 10 * time.Second,
		Tick:               5 * time.Millisecond,
		BackoffMin:         5 * time.Millisecond,
		BackoffMax:         20 * time.Millisecond,
		SlotCheck:          20 * time.Millisecond,
		BaseWait:           2 * time.Second,
		RepositoryRetry:    50 * time.Millisecond,
		ProbePoll:          time.Millisecond,
	})
	ctx, cancel := context.WithCancel(context.Background())
	h.cancel, h.done = cancel, make(chan struct{})
	go func() {
		h.agent.Run(ctx)
		close(h.done)
	}()
	h.t.Cleanup(h.stop)
}

func (h *harness) stop() {
	h.cancel()
	select {
	case <-h.done:
	case <-time.After(5 * time.Second):
		h.t.Error("agent did not stop")
	}
}

func eventually(t *testing.T, what string, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for !cond() {
		if time.Now().After(deadline) {
			t.Fatalf("timed out waiting for %s", what)
		}
		time.Sleep(5 * time.Millisecond)
	}
}

func TestUnconfiguredOnlySendsHeartbeatsAndDropsTheSlot(t *testing.T) {
	h := newHarness(t, settings.Settings{Revision: 2, Configured: false})
	h.db.setSlot(pg.SlotStatus{Exists: true, WALStatus: "reserved", Reserved: true})
	h.start()
	eventually(t, "heartbeats", func() bool {
		h.store.mu.Lock()
		defer h.store.mu.Unlock()
		return len(h.store.beats) >= 3
	})
	eventually(t, "slot drop", func() bool { return slices.Contains(h.db.called(), "drop-slot") })
	beat, _ := h.store.lastBeat()
	if beat.State.RepositoryReady || beat.State.WAL.Streaming || beat.State.Error != nil || beat.ConfigRevision != 2 {
		t.Fatalf("beat = %+v", beat)
	}
	if h.made.Load() != 0 || h.db.receiverCount() != 0 || len(h.store.recorded()) != 0 {
		t.Fatalf("unconfigured agent did work: repos=%d receivers=%d runs=%v", h.made.Load(), h.db.receiverCount(), h.store.recorded())
	}
	h.store.request(JobBase)
	eventually(t, "manual request rejection", func() bool {
		r, ok := h.store.run(JobBase, state.StatusFailed)
		return ok && strings.Contains(*r.Error, "Permintaan manual tidak dijalankan: backup belum dikonfigurasi")
	})
}

func TestInvalidSettingsAreReportedAsError(t *testing.T) {
	bad := validSettings(3)
	bad.Password = ""
	h := newHarness(t, bad)
	h.start()
	eventually(t, "error heartbeat", func() bool {
		return h.store.sawBeat(func(r state.Report) bool {
			return r.Error != nil && strings.Contains(*r.Error, "Konfigurasi backup tidak valid") && !r.RepositoryReady
		})
	})
	if h.made.Load() != 0 {
		t.Fatal("invalid settings must not open the repository")
	}
}

func TestWrongPasswordIsReportedWithoutInit(t *testing.T) {
	h := newHarness(t, validSettings(4))
	h.repo.openErr = fmt.Errorf("%w: restic exited with status 12", restic.ErrWrongPassword)
	h.start()
	eventually(t, "password error", func() bool {
		return h.store.sawBeat(func(r state.Report) bool {
			return r.Error != nil && strings.Contains(*r.Error, "Password enkripsi salah") && !r.RepositoryReady
		})
	})
	time.Sleep(100 * time.Millisecond)
	if slices.Contains(h.repo.called(), "init") || h.db.receiverCount() != 0 {
		t.Fatalf("calls = %v receivers = %d", h.repo.called(), h.db.receiverCount())
	}
	if !slices.Contains(h.repo.called(), "open") || len(slices.DeleteFunc(h.repo.called(), func(c string) bool { return c != "open" })) < 2 {
		t.Fatal("repository must be retried")
	}
}

func TestFullCycleBaseFilesRetentionAndManualRestoreTest(t *testing.T) {
	h := newHarness(t, validSettings(5))
	h.repo.openErr = fmt.Errorf("%w: restic exited with status 10", restic.ErrNoRepository)
	h.start()

	eventually(t, "base backup", func() bool { _, ok := h.store.run(JobBase, state.StatusOK); return ok })
	eventually(t, "files backup", func() bool { _, ok := h.store.run(JobFiles, state.StatusOK); return ok })
	eventually(t, "retention", func() bool { _, ok := h.store.run(JobPrune, state.StatusOK); return ok })

	calls := h.repo.called()
	if calls[0] != "open" || calls[1] != "init" || calls[2] != "unlock" {
		t.Fatalf("repository bootstrap = %v", calls[:3])
	}
	if !slices.Contains(h.db.called(), "create-slot") || h.db.receiverCount() < 1 {
		t.Fatalf("db calls = %v", h.db.called())
	}
	base, _ := h.store.run(JobBase, state.StatusOK)
	label := base.Detail["label"].(string)
	if !strings.HasPrefix(label, "base-") || base.Detail["start_wal"] != "000000010000000000000001" || base.SnapshotID == nil || *base.Bytes == 0 {
		t.Fatalf("base run = %+v", base)
	}
	h.repo.mu.Lock()
	var baseReq restic.BackupRequest
	for _, b := range h.repo.backups {
		if b.Tags[0] == restic.TagBase {
			baseReq = b
		}
	}
	forgets := slices.Clone(h.repo.forgets)
	h.repo.mu.Unlock()
	if !slices.Equal(baseReq.Tags, []string{"base", label}) || baseReq.Paths[0] != filepath.Join(h.dir, "base", label) {
		t.Fatalf("base backup request = %+v", baseReq)
	}
	if len(forgets) != 3 || forgets[0] != (restic.Policy{Tag: "base", KeepDaily: 7, KeepWeekly: 4, KeepMonthly: 6}) ||
		forgets[2] != (restic.Policy{Tag: "wal", KeepWithin: "7d"}) {
		t.Fatalf("forgets = %+v", forgets)
	}
	prune, _ := h.store.run(JobPrune, state.StatusOK)
	if prune.Detail["prune"] != false {
		t.Fatalf("retention after base must not prune: %+v", prune.Detail)
	}
	eventually(t, "streaming heartbeat with local base", func() bool {
		return h.store.sawBeat(func(r state.Report) bool {
			return r.RepositoryReady && r.WAL.Streaming && r.LocalBase.Label != nil && *r.LocalBase.Label == label &&
				r.WAL.LastSegment != nil && *r.WAL.LastSegment == "000000010000000000000001" && r.Disk.AvailBytes == 50<<30
		})
	})
	if !h.store.sawBeat(func(r state.Report) bool { return r.Busy != nil && *r.Busy == "base" }) {
		t.Fatal("busy=base never reported")
	}

	h.store.request(JobRestoreTest)
	eventually(t, "restore test", func() bool {
		_, ok := h.store.run(JobRestoreTest, state.StatusOK)
		_, failed := h.store.run(JobRestoreTest, state.StatusFailed)
		return ok || failed
	})
	test, ok := h.store.run(JobRestoreTest, state.StatusOK)
	if !ok {
		failed, _ := h.store.run(JobRestoreTest, state.StatusFailed)
		t.Fatalf("restore test failed: %v", *failed.Error)
	}
	tables := test.Detail["tables"].(map[string]int64)
	if tables["public.messages"] != 340 || test.Detail["recovered_until"] == nil || test.Detail["duration_s"] == nil || test.Detail["wal_segments"] != 2 {
		t.Fatalf("restore test detail = %+v", test.Detail)
	}
	if _, ok := h.store.run(RecordWAL, state.StatusOK); !ok {
		t.Fatal("restore test must ship WAL first and record it")
	}
	if !slices.Equal(h.db.called()[len(h.db.called())-2:], []string{"start-server", "stop-server"}) {
		t.Fatalf("db calls = %v", h.db.called())
	}
	h.db.mu.Lock()
	lastVerify := h.db.verifies[len(h.db.verifies)-1]
	h.db.mu.Unlock()
	if lastVerify[1] != "restore_wal" || !strings.HasPrefix(lastVerify[0], filepath.Join(h.dir, "restore-test")) {
		t.Fatalf("verify = %v", lastVerify)
	}
	if _, err := os.Stat(filepath.Join(h.dir, "restore-test")); !os.IsNotExist(err) {
		t.Fatal("restore test folder must be removed")
	}
	if peak := h.track.peak.Load(); peak != 1 {
		t.Fatalf("jobs overlapped: peak concurrency %d", peak)
	}
	p, err := state.Load(filepath.Join(h.dir, "state.json"))
	if err != nil || p.Base == nil || p.Base.Label != label || p.NeedBase || p.SystemID != "7702039750691532834" {
		t.Fatalf("persisted = %+v err = %v", p, err)
	}
	for _, leaked := range []string{secretPassword, secretKey} {
		if strings.Contains(h.logText(), leaked) {
			t.Fatalf("secret %q leaked into the log", leaked)
		}
	}
}

func TestSlotLostDetachesWALAndTakesNewBase(t *testing.T) {
	h := newHarness(t, validSettings(6))
	at := time.Now().Add(-time.Hour)
	_ = os.MkdirAll(filepath.Join(h.dir, "wal"), 0o700)
	_ = os.WriteFile(filepath.Join(h.dir, "wal", "000000010000000000000009"), make([]byte, 16), 0o600)
	prev := state.Persisted{Repository: validSettings(6).Repository, SystemID: "7702039750691532834", WeeklyFrom: at,
		Base:    &state.Base{Label: "base-old", StartWAL: "000000010000000000000008", SnapshotID: "old", StartedAt: at, FinishedAt: at},
		Offsite: state.Offsite{LastStartedAt: time.Now(), LastOKAt: at}}
	prev.SetJob(JobBase, state.Job{LastOK: time.Now(), LastAttempt: time.Now()})
	prev.SetJob(JobFiles, state.Job{LastOK: time.Now(), LastAttempt: time.Now()})
	if err := state.Save(filepath.Join(h.dir, "state.json"), prev); err != nil {
		t.Fatal(err)
	}
	h.db.setSlot(pg.SlotStatus{Exists: true, WALStatus: "lost", Reserved: true})
	h.start()

	eventually(t, "slot_lost heartbeat", func() bool {
		return h.store.sawBeat(func(r state.Report) bool { return r.WAL.SlotLost })
	})
	eventually(t, "new base", func() bool { _, ok := h.store.run(JobBase, state.StatusOK); return ok })
	calls := h.db.called()
	if i, j := slices.Index(calls, "drop-slot"), slices.Index(calls, "create-slot"); i < 0 || j < i {
		t.Fatalf("db calls = %v", calls)
	}
	detached, _ := filepath.Glob(filepath.Join(h.dir, "wal-detached-*"))
	if len(detached) != 1 {
		t.Fatalf("detached = %v", detached)
	}
	if _, err := os.Stat(filepath.Join(detached[0], "000000010000000000000009")); err != nil {
		t.Fatal("old WAL must be kept aside until it is offsite")
	}
	eventually(t, "slot_lost cleared", func() bool {
		beat, _ := h.store.lastBeat()
		return !beat.State.WAL.SlotLost
	})
	p, _ := state.Load(filepath.Join(h.dir, "state.json"))
	if p.NeedBase || !p.SlotLostAt.IsZero() || p.ResetAt.IsZero() {
		t.Fatalf("persisted = %+v", p)
	}
}

func TestDetachedWALIsShippedThenRemoved(t *testing.T) {
	h := newHarness(t, validSettings(7))
	old := filepath.Join(h.dir, "wal-detached-20200101T000000Z")
	_ = os.MkdirAll(old, 0o700)
	_ = os.WriteFile(filepath.Join(old, "000000010000000000000003"), make([]byte, 16), 0o600)
	h.start()
	eventually(t, "base", func() bool { _, ok := h.store.run(JobBase, state.StatusOK); return ok })
	h.store.request(JobRestoreTest)
	eventually(t, "restore test", func() bool { _, ok := h.store.run(JobRestoreTest, state.StatusOK); return ok })
	h.repo.mu.Lock()
	var shipped bool
	for _, b := range h.repo.backups {
		if b.Tags[0] == restic.TagWAL && slices.Contains(b.Paths, old) {
			shipped = true
		}
	}
	h.repo.mu.Unlock()
	if !shipped {
		t.Fatal("detached WAL folder was not sent offsite")
	}
	if _, err := os.Stat(old); !os.IsNotExist(err) {
		t.Fatal("detached WAL folder must be removed once offsite and older than the new base")
	}
}

func TestBaseRefusedWhenDiskIsTooSmall(t *testing.T) {
	h := newHarness(t, validSettings(8))
	h.disk.Store(10 << 20)
	h.db.dbBytes = 50 << 20
	h.start()
	eventually(t, "failed base", func() bool { _, ok := h.store.run(JobBase, state.StatusFailed); return ok })
	run, _ := h.store.run(JobBase, state.StatusFailed)
	if !strings.Contains(*run.Error, "Ruang disk staging tidak cukup untuk base backup: tersedia 10.0 MiB, dibutuhkan sekitar 60.0 MiB") {
		t.Fatalf("error = %q", *run.Error)
	}
	if slices.ContainsFunc(h.db.called(), func(c string) bool { return strings.HasPrefix(c, "basebackup") }) {
		t.Fatal("pg_basebackup must not start without space")
	}
	p, _ := state.Load(filepath.Join(h.dir, "state.json"))
	if p.Job(JobBase).Failures != 1 {
		t.Fatalf("failures = %d", p.Job(JobBase).Failures)
	}
}

func TestRecordsAreRetriedAfterPostgRESTFailure(t *testing.T) {
	h := newHarness(t, validSettings(9))
	h.store.failRuns = 1
	h.start()
	eventually(t, "base record delivered later", func() bool { _, ok := h.store.run(JobBase, state.StatusOK); return ok })
}

func TestSettingsChangeReopensRepository(t *testing.T) {
	h := newHarness(t, validSettings(10))
	h.start()
	eventually(t, "first open", func() bool { return h.made.Load() == 1 })
	next := validSettings(11)
	next.Repository = "s3:http://seaweed:8333/olt-backup/other"
	h.store.mu.Lock()
	h.store.current = next
	h.store.mu.Unlock()
	eventually(t, "second open", func() bool { return h.made.Load() == 2 })
	eventually(t, "persisted repository", func() bool {
		p, _ := state.Load(filepath.Join(h.dir, "state.json"))
		return p.Repository == next.Repository
	})
	schedule := validSettings(12)
	schedule.Repository = next.Repository
	schedule.Schedule.BaseTime = "03:00"
	h.store.mu.Lock()
	h.store.current = schedule
	h.store.mu.Unlock()
	eventually(t, "revision 12 applied", func() bool {
		beat, _ := h.store.lastBeat()
		return beat.ConfigRevision == 12
	})
	if h.made.Load() != 2 {
		t.Fatal("a schedule change must not reopen the repository")
	}
}

func (d *fakeDB) receiverCount() int {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.receivers
}
