package heartbeat

import (
	"context"
	"log/slog"
	"sync"
	"time"
)

const (
	StatusOK       = "ok"
	StatusDegraded = "degraded"
	StatusError    = "error"

	defaultTimeout = 10 * time.Second
)

type Beat struct {
	Service   string
	Instance  string
	Version   string
	StartedAt time.Time
	Status    string
	Error     string
	Detail    map[string]any
}

type Report struct {
	Status string
	Error  string
	Detail map[string]any
}

type Store interface {
	Heartbeat(ctx context.Context, beat Beat) error
}

type Options struct {
	Store     Store
	Log       *slog.Logger
	Service   string
	Instance  string
	Version   string
	StartedAt time.Time
	Interval  time.Duration
	Timeout   time.Duration
	Probe     func(ctx context.Context)
	Report    func() Report
}

type Loop struct {
	opts Options
	kick chan struct{}

	mu          sync.Mutex
	failing     bool
	lastSuccess time.Time
}

func New(opts Options) *Loop {
	if opts.Timeout <= 0 {
		opts.Timeout = defaultTimeout
	}
	return &Loop{opts: opts, kick: make(chan struct{}, 1)}
}

func (l *Loop) Kick() {
	select {
	case l.kick <- struct{}{}:
	default:
	}
}

func (l *Loop) LastSuccess() time.Time {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.lastSuccess
}

func (l *Loop) Run(ctx context.Context) {
	l.tick(ctx)
	ticker := time.NewTicker(l.opts.Interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			l.tick(ctx)
		case <-l.kick:
			l.send(ctx)
		}
	}
}

func (l *Loop) tick(ctx context.Context) {
	if l.opts.Probe != nil {
		l.opts.Probe(ctx)
	}
	l.send(ctx)
}

func (l *Loop) send(ctx context.Context) {
	if ctx.Err() != nil {
		return
	}
	select {
	case <-l.kick:
	default:
	}
	report := l.opts.Report()
	beat := Beat{
		Service:   l.opts.Service,
		Instance:  l.opts.Instance,
		Version:   l.opts.Version,
		StartedAt: l.opts.StartedAt,
		Status:    report.Status,
		Error:     report.Error,
		Detail:    report.Detail,
	}
	call, cancel := context.WithTimeout(ctx, l.opts.Timeout)
	err := l.opts.Store.Heartbeat(call, beat)
	cancel()
	if ctx.Err() != nil {
		return
	}
	l.mu.Lock()
	was := l.failing
	l.failing = err != nil
	if err == nil {
		l.lastSuccess = time.Now()
	}
	l.mu.Unlock()
	switch {
	case err != nil && !was:
		l.opts.Log.Warn("Heartbeat failed; retrying on the next interval", "error", err)
	case err == nil && was:
		l.opts.Log.Info("Heartbeat works again", "status", beat.Status)
	}
}
