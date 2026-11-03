package outage

import (
	"sync"
	"time"
)

type Kind int

const (
	Down Kind = iota + 1
	Recovered
)

type Event struct {
	Kind  Kind
	Since time.Time
	At    time.Time
	Cause string
}

func (e Event) Duration() time.Duration {
	return e.At.Sub(e.Since)
}

type State struct {
	Reachable bool
	Down      bool
	Since     time.Time
	Outages   uint64
}

type Detector struct {
	after       time.Duration
	now         func() time.Time
	unreachable func(error) bool

	mu      sync.Mutex
	since   time.Time
	cause   string
	down    bool
	pending []Event
	outages uint64
}

func New(after time.Duration, now func() time.Time, unreachable func(error) bool) *Detector {
	if now == nil {
		now = time.Now
	}
	if unreachable == nil {
		unreachable = func(err error) bool { return err != nil }
	}
	return &Detector{after: after, now: now, unreachable: unreachable}
}

func (d *Detector) Observe(err error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	now := d.now()
	if err == nil || !d.unreachable(err) {
		if d.down {
			d.pending = append(d.pending, Event{Kind: Recovered, Since: d.since, At: now, Cause: d.cause})
		}
		d.since, d.cause, d.down = time.Time{}, "", false
		return
	}
	if d.since.IsZero() {
		d.since = now
	}
	d.cause = err.Error()
	d.evaluate(now)
}

func (d *Detector) Check() {
	d.mu.Lock()
	defer d.mu.Unlock()
	if !d.since.IsZero() {
		d.evaluate(d.now())
	}
}

func (d *Detector) evaluate(now time.Time) {
	if d.down || now.Sub(d.since) < d.after {
		return
	}
	d.down = true
	d.outages++
	d.pending = append(d.pending, Event{Kind: Down, Since: d.since, At: now, Cause: d.cause})
}

func (d *Detector) Events() []Event {
	d.mu.Lock()
	defer d.mu.Unlock()
	events := d.pending
	d.pending = nil
	return events
}

func (d *Detector) State() State {
	d.mu.Lock()
	defer d.mu.Unlock()
	return State{Reachable: d.since.IsZero(), Down: d.down, Since: d.since, Outages: d.outages}
}
