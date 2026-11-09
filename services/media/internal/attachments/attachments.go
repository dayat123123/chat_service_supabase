package attachments

import (
	"context"
	"log/slog"
	"reflect"
	"slices"
	"sync"
	"time"
)

type Format struct {
	Code string `json:"code"`
	MIME string `json:"mime"`
	Ext  string `json:"ext"`
}

type Rule struct {
	Enabled    bool     `json:"enabled"`
	Bucket     string   `json:"bucket"`
	MaxBytes   int64    `json:"max_bytes"`
	MaxSeconds float64  `json:"max_seconds"`
	Formats    []Format `json:"formats"`
}

func (r Rule) Allows(code string) bool {
	return slices.ContainsFunc(r.Formats, func(f Format) bool { return f.Code == code })
}

func (r Rule) Codes() []string {
	out := make([]string, 0, len(r.Formats))
	for _, f := range r.Formats {
		out = append(out, f.Code)
	}
	return out
}

type Policy map[string]Rule

func (p Policy) ForBucket(bucket string) (Rule, bool) {
	for _, r := range p {
		if r.Bucket == bucket {
			return r, true
		}
	}
	return Rule{}, false
}

type Store interface {
	AttachmentPolicy(ctx context.Context) (Policy, error)
}

type Loader struct {
	store    Store
	log      *slog.Logger
	interval time.Duration
	timeout  time.Duration
	changed  func()

	mu      sync.Mutex
	current Policy
	failing bool
}

func NewLoader(store Store, log *slog.Logger, interval time.Duration, changed func()) *Loader {
	return &Loader{store: store, log: log, interval: interval, timeout: 10 * time.Second, changed: changed}
}

func (l *Loader) Current() (Policy, bool) {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.current, l.current != nil
}

func (l *Loader) Run(ctx context.Context) {
	ticker := time.NewTicker(l.interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			l.Refresh(ctx)
		}
	}
}

func (l *Loader) Refresh(ctx context.Context) {
	call, cancel := context.WithTimeout(ctx, l.timeout)
	policy, err := l.store.AttachmentPolicy(call)
	cancel()
	if ctx.Err() != nil {
		return
	}
	l.mu.Lock()
	was := l.failing
	l.failing = err != nil
	loadedBefore := l.current != nil
	changed := err == nil && !reflect.DeepEqual(l.current, policy)
	if changed {
		l.current = policy
	}
	l.mu.Unlock()
	switch {
	case err != nil && !was:
		l.log.Warn("Attachment policy could not be loaded; retrying on the next interval", "error", err,
			"loaded", loadedBefore)
	case err == nil && was:
		l.log.Info("Attachment policy can be loaded again")
	}
	if !changed {
		return
	}
	attrs := []any{}
	for _, kind := range []string{"documents", "images", "videos"} {
		r := policy[kind]
		attrs = append(attrs, kind, map[string]any{"enabled": r.Enabled, "max_bytes": r.MaxBytes, "formats": r.Codes()})
	}
	l.log.Info("Attachment policy loaded", attrs...)
	if !loadedBefore && l.changed != nil {
		l.changed()
	}
}
