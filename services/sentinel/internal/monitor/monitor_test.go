package monitor

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/sentinel/internal/disk"
	"olt-social/sentinel/internal/probe"
	"olt-social/sentinel/internal/store"
)

type fakeStore struct {
	mu      sync.Mutex
	reports []store.Health
	err     error
}

func (s *fakeStore) HealthReport(_ context.Context, h store.Health) (time.Time, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.reports = append(s.reports, h)
	return time.Now(), s.err
}

type fakeProber struct {
	mu      sync.Mutex
	results []probe.Result
}

func (p *fakeProber) Run(_ context.Context, targets []probe.Target) []probe.Result {
	p.mu.Lock()
	defer p.mu.Unlock()
	if len(targets) != len(p.results) {
		panic("targets and results differ")
	}
	return append([]probe.Result(nil), p.results...)
}

func (p *fakeProber) set(results ...probe.Result) {
	p.mu.Lock()
	p.results = results
	p.mu.Unlock()
}

func status(n int) *int { return &n }

func text(s string) *string { return &s }

type syncBuffer struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (s *syncBuffer) Write(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.Write(p)
}

func (s *syncBuffer) String() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.String()
}

func setup(t *testing.T) (*Monitor, *fakeStore, *fakeProber, *syncBuffer, *error) {
	t.Helper()
	st := &fakeStore{}
	pr := &fakeProber{}
	logs := &syncBuffer{}
	var diskErr error
	m := New(Options{
		Store:  st,
		Prober: pr,
		Measure: func(target disk.Target) (disk.Usage, error) {
			if target.Name == "wal" && diskErr != nil {
				return disk.Usage{}, diskErr
			}
			return disk.Usage{Name: target.Name, TotalBytes: 100, FreeBytes: 50, AvailBytes: 40}, nil
		},
		Log:            slog.New(slog.NewJSONHandler(logs, nil)),
		Probes:         []probe.Target{{Name: "storage", URL: "http://storage:5000/status", Kind: probe.HTTP}, {Name: "db", URL: "tcp://db:5432", Kind: probe.TCP, Addr: "db:5432"}},
		Disks:          []disk.Target{{Name: "data", Path: "/mnt/disks/data"}, {Name: "wal", Path: "/mnt/disks/wal"}},
		Interval:       30 * time.Second,
		RequestTimeout: time.Second,
		Instance:       "sentinel-1",
		Version:        "0.1.0",
		StartedAt:      time.Unix(1_800_000_000, 0),
	})
	return m, st, pr, logs, &diskErr
}

func TestRoundReportsProbesAndDisks(t *testing.T) {
	m, st, pr, logs, diskErr := setup(t)
	up := probe.Result{Name: "storage", Target: "http://storage:5000/status", OK: true, Status: status(200), LatencyMS: 3}
	down := probe.Result{Name: "db", Target: "tcp://db:5432", LatencyMS: 5000, Error: text("koneksi ditolak")}
	pr.set(up, down)
	*diskErr = errors.New("statfs /mnt/disks/wal: no such file or directory")

	m.Round(context.Background())

	if len(st.reports) != 1 {
		t.Fatalf("reports = %d", len(st.reports))
	}
	got := st.reports[0]
	if got.Instance != "sentinel-1" || got.Version != "0.1.0" || !got.StartedAt.Equal(time.Unix(1_800_000_000, 0)) ||
		!reflect.DeepEqual(got.Probes, []probe.Result{up, down}) ||
		!reflect.DeepEqual(got.Disks, []disk.Usage{{Name: "data", TotalBytes: 100, FreeBytes: 50, AvailBytes: 40}}) {
		t.Fatalf("report = %+v", got)
	}
	if failing := m.Failing(); !reflect.DeepEqual(failing, []string{"db"}) {
		t.Fatalf("failing = %v", failing)
	}
	snap := m.Snapshot()
	if snap.Reports[ReportOK] != 1 || snap.LastReport.IsZero() || len(snap.Probes) != 2 || len(snap.Disks) != 1 {
		t.Fatalf("snapshot = %+v", snap)
	}
	out := logs.String()
	if !strings.Contains(out, "Probe is down at start") || !strings.Contains(out, "Could not measure a disk") {
		t.Fatalf("logs = %s", out)
	}

	m.Round(context.Background())
	m.Round(context.Background())
	if n := strings.Count(logs.String(), "Probe is down"); n != 1 {
		t.Fatalf("down logged %d times", n)
	}
	if n := strings.Count(logs.String(), "Could not measure a disk"); n != 1 {
		t.Fatalf("disk error logged %d times", n)
	}

	*diskErr = nil
	pr.set(up, probe.Result{Name: "db", Target: "tcp://db:5432", OK: true, LatencyMS: 1})
	m.Round(context.Background())
	out = logs.String()
	if !strings.Contains(out, "Probe is up again") || !strings.Contains(out, "Disk can be measured again") || len(m.Failing()) != 0 {
		t.Fatalf("logs = %s", out)
	}
	if last := st.reports[len(st.reports)-1]; len(last.Disks) != 2 {
		t.Fatalf("disks = %+v", last.Disks)
	}
}

func TestReportFailuresAreCountedAndLoggedOnce(t *testing.T) {
	m, st, pr, logs, _ := setup(t)
	pr.set(probe.Result{Name: "storage", OK: true}, probe.Result{Name: "db", OK: true})
	st.err = errors.New("rpc health_report: status 503")
	for range 3 {
		m.Round(context.Background())
	}
	if n := strings.Count(logs.String(), "Could not send the health report"); n != 1 {
		t.Fatalf("logged %d times", n)
	}
	st.err = nil
	m.Round(context.Background())
	snap := m.Snapshot()
	if snap.Reports[ReportFailed] != 3 || snap.Reports[ReportOK] != 1 || !strings.Contains(logs.String(), "accepted again") {
		t.Fatalf("snapshot = %+v logs = %s", snap, logs.String())
	}
}

func TestRunStopsWithTheContext(t *testing.T) {
	m, st, pr, _, _ := setup(t)
	pr.set(probe.Result{Name: "storage", OK: true}, probe.Result{Name: "db", OK: true})
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		m.Run(ctx)
		close(done)
	}()
	deadline := time.Now().Add(2 * time.Second)
	for {
		st.mu.Lock()
		n := len(st.reports)
		st.mu.Unlock()
		if n > 0 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("first report was not sent at start")
		}
		time.Sleep(10 * time.Millisecond)
	}
	cancel()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("Run did not stop")
	}
}
