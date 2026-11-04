package monitor

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/sentinel/internal/disk"
	"olt-social/sentinel/internal/probe"
	"olt-social/sentinel/internal/scrape"
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

type fakeScraper struct {
	mu      sync.Mutex
	results []scrape.Result
	calls   int
}

func (s *fakeScraper) Run(_ context.Context, sources []scrape.Source) []scrape.Result {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.calls++
	return append([]scrape.Result{}, s.results...)
}

func (s *fakeScraper) set(results ...scrape.Result) {
	s.mu.Lock()
	s.results = results
	s.mu.Unlock()
}

func TestRoundReportsMetricsSources(t *testing.T) {
	st := &fakeStore{}
	logs := &syncBuffer{}
	sc := &fakeScraper{}
	m := New(Options{
		Store:          st,
		Prober:         &fakeProber{},
		Scraper:        sc,
		Sources:        []scrape.Source{{Name: "rest", Kind: scrape.Prometheus}},
		Log:            slog.New(slog.NewJSONHandler(logs, nil)),
		Interval:       30 * time.Second,
		RequestTimeout: time.Second,
	})
	bad := scrape.Result{Source: "rest", Instance: "10.0.0.4", Error: text("HTTP 503"), Values: map[string]float64{}}
	sc.set(bad)
	m.Round(context.Background())
	m.Round(context.Background())
	if len(st.reports) != 2 || !reflect.DeepEqual(st.reports[0].Metrics, []scrape.Result{bad}) {
		t.Fatalf("reports = %+v", st.reports)
	}
	if n := strings.Count(logs.String(), "Could not read a metrics source"); n != 1 {
		t.Fatalf("scrape failure logged %d times: %s", n, logs.String())
	}
	good := scrape.Result{Source: "rest", Instance: "10.0.0.4", OK: true, Values: map[string]float64{"pgrst_db_pool_waiting": 1}}
	sc.set(good)
	m.Round(context.Background())
	if !strings.Contains(logs.String(), "Metrics source can be read again") {
		t.Fatalf("logs = %s", logs.String())
	}
	if snap := m.Snapshot(); !reflect.DeepEqual(snap.Metrics, []scrape.Result{good}) {
		t.Fatalf("snapshot = %+v", snap.Metrics)
	}
}

func TestRoundLeavesMetricsOutWithoutSources(t *testing.T) {
	st := &fakeStore{}
	sc := &fakeScraper{}
	m := New(Options{Store: st, Prober: &fakeProber{}, Scraper: sc, Log: slog.New(slog.NewJSONHandler(&syncBuffer{}, nil)),
		Interval: 30 * time.Second, RequestTimeout: time.Second})
	m.Round(context.Background())
	if sc.calls != 0 || st.reports[0].Metrics != nil {
		t.Fatalf("scraper called %d times, metrics %+v", sc.calls, st.reports[0].Metrics)
	}
}

func TestLostReportsAreCarriedIntoTheNextReport(t *testing.T) {
	st := &fakeStore{}
	sc := &fakeScraper{}
	pr := &fakeProber{}
	m := New(Options{
		Store:          st,
		Prober:         pr,
		Scraper:        sc,
		Sources:        []scrape.Source{{Name: "rest", Kind: scrape.Prometheus}, {Name: "realtime", Kind: scrape.Prometheus}},
		Probes:         []probe.Target{{Name: "rest", URL: "http://rest:3000/", Kind: probe.HTTP}},
		Log:            slog.New(slog.NewJSONHandler(&syncBuffer{}, nil)),
		Interval:       30 * time.Second,
		RequestTimeout: time.Second,
		Instance:       "sentinel-1",
	})
	restDown := scrape.Result{Source: "rest", Instance: "10.0.0.4", Error: text("waktu habis setelah 5s"), Values: map[string]float64{}}
	restUp := scrape.Result{Source: "rest", Instance: "10.0.0.4", OK: true, Values: map[string]float64{"pgrst_db_pool_max": 10}}
	realtime := scrape.Result{Source: "realtime", Instance: "10.0.0.5", OK: true, Values: map[string]float64{"realtime_channel_global_events": 7}}
	probeDown := probe.Result{Name: "rest", Target: "http://rest:3000/", LatencyMS: 5000, Error: text("waktu habis setelah 5s")}
	probeUp := probe.Result{Name: "rest", Target: "http://rest:3000/", OK: true, Status: status(200), LatencyMS: 4}

	st.err = &store.Error{Status: 504, Code: "PGRST003"}
	sc.set(restDown, realtime)
	pr.set(probeDown)
	m.Round(context.Background())
	sc.set(restUp, realtime)
	pr.set(probeDown)
	m.Round(context.Background())

	st.err = nil
	sc.set(restDown, realtime)
	pr.set(probeUp)
	m.Round(context.Background())

	if len(st.reports) != 3 {
		t.Fatalf("reports = %d", len(st.reports))
	}
	if first := st.reports[0]; len(first.Metrics) != 2 || first.Metrics[0].Missed != 0 || first.Probes[0].Missed != 0 {
		t.Fatalf("first report = %+v", first)
	}
	got := st.reports[2]
	wantRest := restDown
	wantRest.Missed = 1
	lost := scrape.Result{Source: LostSource, Instance: "sentinel-1", OK: true, Values: map[string]float64{LostMetric: 2}}
	if !reflect.DeepEqual(got.Metrics, []scrape.Result{wantRest, realtime, lost}) {
		t.Fatalf("metrics = %+v", got.Metrics)
	}
	wantProbe := probeUp
	wantProbe.Missed = 2
	if !reflect.DeepEqual(got.Probes, []probe.Result{wantProbe}) {
		t.Fatalf("probes = %+v", got.Probes)
	}
	if snap := m.Snapshot(); !reflect.DeepEqual(snap.Metrics, []scrape.Result{restDown, realtime}) || !reflect.DeepEqual(snap.Probes, []probe.Result{probeUp}) {
		t.Fatalf("snapshot = %+v", snap)
	}

	sc.set(restUp, realtime)
	m.Round(context.Background())
	if next := st.reports[3]; !reflect.DeepEqual(next.Metrics, []scrape.Result{restUp, realtime}) || next.Probes[0].Missed != 0 {
		t.Fatalf("delivered report must reset the carry: %+v", next)
	}
}

func TestRoundForwardsTheHealerStateAndLogsReadErrorsOnce(t *testing.T) {
	st := &fakeStore{}
	logs := &syncBuffer{}
	path := filepath.Join(t.TempDir(), "state.json")
	m := New(Options{
		Store:          st,
		Prober:         &fakeProber{},
		Log:            slog.New(slog.NewJSONHandler(logs, nil)),
		HealerFile:     path,
		Interval:       30 * time.Second,
		RequestTimeout: time.Second,
		Instance:       "sentinel-1",
		Version:        "0.4.0",
	})
	m.Round(context.Background())
	m.Round(context.Background())
	if st.reports[1].Healer == nil || !strings.Contains(st.reports[1].Healer.ReadError, "not found") {
		t.Fatalf("healer = %+v", st.reports[1].Healer)
	}
	if n := strings.Count(logs.String(), "Could not read the healer state file"); n != 1 {
		t.Fatalf("read error logged %d times", n)
	}
	_ = os.WriteFile(path, []byte(`{"project":"olt-social","enabled":true,"checked_at":"2026-11-04T04:00:00Z","events":[]}`), 0o644)
	m.Round(context.Background())
	got := st.reports[2].Healer
	if got == nil || got.ReadError != "" || got.Project != "olt-social" {
		t.Fatalf("healer = %+v", got)
	}
	if !strings.Contains(logs.String(), "Healer state file can be read again") {
		t.Fatal("recovery not logged")
	}
}

func TestRoundLeavesTheHealerOutWithoutAStateFile(t *testing.T) {
	m, st, pr, _, _ := setup(t)
	pr.set(probe.Result{Name: "storage", OK: true}, probe.Result{Name: "db", OK: true})
	m.Round(context.Background())
	if st.reports[0].Healer != nil {
		t.Fatalf("healer = %+v", st.reports[0].Healer)
	}
}
