package stats

import (
	"context"
	"log/slog"
	"sync"
	"sync/atomic"
	"time"
)

type Event int

const (
	View Event = iota
	Preview
	Open
	Android
	IOS
	Windows
	Mac
)

type Row struct {
	Code     string `json:"code"`
	Views    int64  `json:"views,omitempty"`
	Previews int64  `json:"previews,omitempty"`
	Opens    int64  `json:"opens,omitempty"`
	Android  int64  `json:"android,omitempty"`
	IOS      int64  `json:"ios,omitempty"`
	Windows  int64  `json:"windows,omitempty"`
	Mac      int64  `json:"mac,omitempty"`
}

func (r *Row) add(e Event, n int64) {
	switch e {
	case View:
		r.Views += n
	case Preview:
		r.Previews += n
	case Open:
		r.Opens += n
	case Android:
		r.Android += n
	case IOS:
		r.IOS += n
	case Windows:
		r.Windows += n
	case Mac:
		r.Mac += n
	}
}

func (r *Row) merge(o Row) {
	r.Views += o.Views
	r.Previews += o.Previews
	r.Opens += o.Opens
	r.Android += o.Android
	r.IOS += o.IOS
	r.Windows += o.Windows
	r.Mac += o.Mac
}

type Sink interface {
	RecordStats(ctx context.Context, rows []Row) error
}

type Tracker struct {
	mu      sync.Mutex
	pending map[string]*Row
	limit   int
	dropped atomic.Int64
	sent    atomic.Int64
	failed  atomic.Int64
}

func New(limit int) *Tracker {
	return &Tracker{pending: map[string]*Row{}, limit: limit}
}

func (t *Tracker) Add(code string, e Event) {
	t.mu.Lock()
	defer t.mu.Unlock()
	row, ok := t.pending[code]
	if !ok {
		if len(t.pending) >= t.limit {
			t.dropped.Add(1)
			return
		}
		row = &Row{Code: code}
		t.pending[code] = row
	}
	row.add(e, 1)
}

func (t *Tracker) take() []Row {
	t.mu.Lock()
	defer t.mu.Unlock()
	rows := make([]Row, 0, len(t.pending))
	for _, row := range t.pending {
		rows = append(rows, *row)
	}
	t.pending = map[string]*Row{}
	return rows
}

func (t *Tracker) restore(rows []Row) {
	t.mu.Lock()
	defer t.mu.Unlock()
	for _, r := range rows {
		row, ok := t.pending[r.Code]
		if !ok {
			if len(t.pending) >= t.limit {
				t.dropped.Add(1)
				continue
			}
			row = &Row{Code: r.Code}
			t.pending[r.Code] = row
		}
		row.merge(r)
	}
}

func (t *Tracker) Pending() int {
	t.mu.Lock()
	defer t.mu.Unlock()
	return len(t.pending)
}

func (t *Tracker) Dropped() int64 { return t.dropped.Load() }

func (t *Tracker) Sent() int64 { return t.sent.Load() }

func (t *Tracker) Failed() int64 { return t.failed.Load() }

func (t *Tracker) Flush(ctx context.Context, sink Sink) error {
	rows := t.take()
	if len(rows) == 0 {
		return nil
	}
	if err := sink.RecordStats(ctx, rows); err != nil {
		t.failed.Add(1)
		t.restore(rows)
		return err
	}
	t.sent.Add(int64(len(rows)))
	return nil
}

func (t *Tracker) Run(ctx context.Context, sink Sink, every, timeout time.Duration, log *slog.Logger) {
	ticker := time.NewTicker(every)
	defer ticker.Stop()
	flush := func(parent context.Context) {
		callCtx, cancel := context.WithTimeout(parent, timeout)
		defer cancel()
		if err := t.Flush(callCtx, sink); err != nil {
			log.Warn("Failed to send share link stats; keeping them for the next try", "error", err, "pending", t.Pending())
		}
	}
	for {
		select {
		case <-ctx.Done():
			flush(context.Background())
			return
		case <-ticker.C:
			flush(ctx)
		}
	}
}
