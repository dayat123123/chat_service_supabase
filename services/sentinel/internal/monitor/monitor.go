package monitor

import (
	"context"
	"log/slog"
	"maps"
	"slices"
	"sync"
	"time"

	"olt-social/sentinel/internal/disk"
	"olt-social/sentinel/internal/healer"
	"olt-social/sentinel/internal/logstate"
	"olt-social/sentinel/internal/probe"
	"olt-social/sentinel/internal/scrape"
	"olt-social/sentinel/internal/store"
)

const (
	ReportOK     = "ok"
	ReportFailed = "failed"

	LostSource = "sentinel"
	LostMetric = "sentinel_reports_lost"
	maxCarried = 1000
)

type Store interface {
	HealthReport(ctx context.Context, h store.Health) (time.Time, error)
}

type Prober interface {
	Run(ctx context.Context, targets []probe.Target) []probe.Result
}

type Scraper interface {
	Run(ctx context.Context, sources []scrape.Source) []scrape.Result
}

type Options struct {
	Store          Store
	Prober         Prober
	Scraper        Scraper
	Sources        []scrape.Source
	Measure        func(disk.Target) (disk.Usage, error)
	HealerFile     string
	Log            *slog.Logger
	Probes         []probe.Target
	Disks          []disk.Target
	Interval       time.Duration
	RequestTimeout time.Duration
	Instance       string
	Version        string
	StartedAt      time.Time
	Now            func() time.Time
}

type Snapshot struct {
	Probes     []probe.Result
	Disks      []disk.Usage
	Metrics    []scrape.Result
	Reports    map[string]uint64
	LastReport time.Time
}

type Monitor struct {
	opts   Options
	log    *slog.Logger
	now    func() time.Time
	report logstate.Latch
	healer logstate.Latch
	disks  map[string]*logstate.Latch

	mu         sync.Mutex
	probes     []probe.Result
	usage      []disk.Usage
	metrics    []scrape.Result
	scrapeOK   map[string]bool
	up         map[string]bool
	lost       int
	probeLost  map[string]int
	scrapeLost map[string]int
	reports    map[string]uint64
	lastReport time.Time
}

func New(opts Options) *Monitor {
	if opts.Measure == nil {
		opts.Measure = disk.Measure
	}
	now := opts.Now
	if now == nil {
		now = time.Now
	}
	disks := make(map[string]*logstate.Latch, len(opts.Disks))
	for _, d := range opts.Disks {
		disks[d.Name] = &logstate.Latch{}
	}
	return &Monitor{
		opts:       opts,
		log:        opts.Log,
		now:        now,
		disks:      disks,
		up:         map[string]bool{},
		scrapeOK:   map[string]bool{},
		reports:    map[string]uint64{},
		probeLost:  map[string]int{},
		scrapeLost: map[string]int{},
	}
}

func (m *Monitor) Run(ctx context.Context) {
	timer := time.NewTimer(0)
	defer timer.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-timer.C:
		}
		started := time.Now()
		m.Round(ctx)
		timer.Reset(max(m.opts.Interval-time.Since(started), time.Second))
	}
}

func (m *Monitor) Round(ctx context.Context) {
	var metrics []scrape.Result
	scraped := make(chan struct{})
	go func() {
		defer close(scraped)
		if m.opts.Scraper != nil && len(m.opts.Sources) > 0 {
			metrics = m.opts.Scraper.Run(ctx, m.opts.Sources)
		}
	}()
	results := m.opts.Prober.Run(ctx, m.opts.Probes)
	usage := m.measure()
	var healerState *healer.Report
	if m.opts.HealerFile != "" {
		r := healer.Read(m.opts.HealerFile)
		healerState = &r
		m.noteHealer(r)
	}
	<-scraped
	if ctx.Err() != nil {
		return
	}
	m.remember(results, usage)
	m.rememberMetrics(metrics)
	probes, sent := m.carried(results, metrics)
	call, cancel := context.WithTimeout(ctx, m.opts.RequestTimeout)
	_, err := m.opts.Store.HealthReport(call, store.Health{
		Instance:  m.opts.Instance,
		Version:   m.opts.Version,
		StartedAt: m.opts.StartedAt,
		Probes:    probes,
		Disks:     usage,
		Metrics:   sent,
		Healer:    healerState,
	})
	cancel()
	if ctx.Err() != nil {
		return
	}
	m.mu.Lock()
	if err != nil {
		m.reports[ReportFailed]++
		m.carry(results, metrics)
	} else {
		m.reports[ReportOK]++
		m.lastReport = m.now()
		m.lost = 0
		clear(m.probeLost)
		clear(m.scrapeLost)
	}
	m.mu.Unlock()
	if err != nil {
		if m.report.Fail(err.Error()) {
			m.log.Warn("Could not send the health report", "error", err)
		}
		return
	}
	if m.report.Recover() {
		m.log.Info("Health reports are accepted again")
	}
}

func (m *Monitor) carried(results []probe.Result, metrics []scrape.Result) ([]probe.Result, []scrape.Result) {
	m.mu.Lock()
	defer m.mu.Unlock()
	probes := slices.Clone(results)
	for i := range probes {
		probes[i].Missed = m.probeLost[probes[i].Name]
	}
	sent := slices.Clone(metrics)
	for i := range sent {
		sent[i].Missed = m.scrapeLost[sent[i].Source+"@"+sent[i].Instance]
	}
	if m.lost > 0 {
		sent = append(sent, scrape.Result{
			Source:   LostSource,
			Instance: m.opts.Instance,
			OK:       true,
			Values:   map[string]float64{LostMetric: float64(m.lost)},
		})
	}
	return probes, sent
}

func (m *Monitor) carry(results []probe.Result, metrics []scrape.Result) {
	m.lost = min(m.lost+1, maxCarried)
	for _, r := range results {
		if !r.OK {
			m.probeLost[r.Name] = min(m.probeLost[r.Name]+1, maxCarried)
		}
	}
	for _, r := range metrics {
		if !r.OK {
			key := r.Source + "@" + r.Instance
			m.scrapeLost[key] = min(m.scrapeLost[key]+1, maxCarried)
		}
	}
}

func (m *Monitor) measure() []disk.Usage {
	usage := make([]disk.Usage, 0, len(m.opts.Disks))
	for _, target := range m.opts.Disks {
		u, err := m.opts.Measure(target)
		latch := m.disks[target.Name]
		if err != nil {
			if latch.Fail(err.Error()) {
				m.log.Warn("Could not measure a disk; it is left out of the health report", "disk", target.Name, "path", target.Path, "error", err)
			}
			continue
		}
		if latch.Recover() {
			m.log.Info("Disk can be measured again", "disk", target.Name)
		}
		usage = append(usage, u)
	}
	return usage
}

func (m *Monitor) remember(results []probe.Result, usage []disk.Usage) {
	m.mu.Lock()
	first := m.probes == nil
	type change struct {
		result probe.Result
		up     bool
	}
	var changes []change
	for _, r := range results {
		before, known := m.up[r.Name]
		if (!known && !r.OK) || (known && before != r.OK) {
			changes = append(changes, change{r, r.OK})
		}
		m.up[r.Name] = r.OK
	}
	m.probes = slices.Clone(results)
	if m.probes == nil {
		m.probes = []probe.Result{}
	}
	m.usage = slices.Clone(usage)
	m.mu.Unlock()
	for _, c := range changes {
		if c.up {
			m.log.Info("Probe is up again", "probe", c.result.Name, "target", c.result.Target, "latency_ms", c.result.LatencyMS)
			continue
		}
		msg := "Probe is down"
		if first {
			msg = "Probe is down at start"
		}
		m.log.Warn(msg, "probe", c.result.Name, "target", c.result.Target, "error", deref(c.result.Error))
	}
}

func (m *Monitor) rememberMetrics(results []scrape.Result) {
	m.mu.Lock()
	m.metrics = slices.Clone(results)
	var changed []scrape.Result
	for _, r := range results {
		key := r.Source + "@" + r.Instance
		before, known := m.scrapeOK[key]
		if (!known && !r.OK) || (known && before != r.OK) {
			changed = append(changed, r)
		}
		m.scrapeOK[key] = r.OK
	}
	m.mu.Unlock()
	for _, r := range changed {
		if r.OK {
			m.log.Info("Metrics source can be read again", "source", r.Source, "instance", r.Instance)
			continue
		}
		m.log.Warn("Could not read a metrics source", "source", r.Source, "instance", r.Instance, "error", deref(r.Error))
	}
}

func (m *Monitor) noteHealer(r healer.Report) {
	if r.ReadError != "" {
		if m.healer.Fail(r.ReadError) {
			m.log.Warn("Could not read the healer state file", "path", m.opts.HealerFile, "error", r.ReadError)
		}
		return
	}
	if m.healer.Recover() {
		m.log.Info("Healer state file can be read again", "path", m.opts.HealerFile)
	}
}

func (m *Monitor) Failing() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	var names []string
	for _, r := range m.probes {
		if !r.OK {
			names = append(names, r.Name)
		}
	}
	return names
}

func (m *Monitor) Snapshot() Snapshot {
	m.mu.Lock()
	defer m.mu.Unlock()
	return Snapshot{
		Probes:     slices.Clone(m.probes),
		Disks:      slices.Clone(m.usage),
		Metrics:    slices.Clone(m.metrics),
		Reports:    maps.Clone(m.reports),
		LastReport: m.lastReport,
	}
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
