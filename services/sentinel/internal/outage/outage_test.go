package outage

import (
	"errors"
	"testing"
	"time"
)

type clock struct{ now time.Time }

func (c *clock) Now() time.Time { return c.now }

func (c *clock) advance(d time.Duration) { c.now = c.now.Add(d) }

var (
	errDown     = errors.New("rpc alert_channels: connection refused")
	errAnswered = errors.New("rpc alert_claim: status 404")
)

func newDetector(c *clock) *Detector {
	return New(2*time.Minute, c.Now, func(err error) bool { return err != nil && err != errAnswered })
}

func TestOutageIsDeclaredOnceAfterTheThreshold(t *testing.T) {
	c := &clock{now: time.Date(2026, 11, 3, 7, 0, 0, 0, time.UTC)}
	start := c.now
	d := newDetector(c)

	for range 23 {
		d.Observe(errDown)
		c.advance(5 * time.Second)
	}
	if events := d.Events(); len(events) != 0 {
		t.Fatalf("declared after %v: %+v", c.now.Sub(start), events)
	}
	if s := d.State(); s.Reachable || s.Down || !s.Since.Equal(start) {
		t.Fatalf("state = %+v", s)
	}
	c.now = start.Add(2 * time.Minute)
	d.Observe(errDown)
	events := d.Events()
	if len(events) != 1 || events[0].Kind != Down || !events[0].Since.Equal(start) || events[0].Cause != errDown.Error() {
		t.Fatalf("events = %+v", events)
	}
	for range 10 {
		c.advance(5 * time.Second)
		d.Observe(errDown)
		d.Check()
	}
	if events := d.Events(); len(events) != 0 {
		t.Fatalf("outage announced twice: %+v", events)
	}
	if s := d.State(); !s.Down || s.Outages != 1 {
		t.Fatalf("state = %+v", s)
	}

	c.advance(time.Minute)
	d.Observe(nil)
	events = d.Events()
	if len(events) != 1 || events[0].Kind != Recovered || !events[0].Since.Equal(start) {
		t.Fatalf("events = %+v", events)
	}
	if got := events[0].Duration(); got != 3*time.Minute+50*time.Second {
		t.Fatalf("duration = %v", got)
	}
	d.Observe(nil)
	if events := d.Events(); len(events) != 0 {
		t.Fatalf("recovery announced twice: %+v", events)
	}
	if s := d.State(); !s.Reachable || s.Down || s.Outages != 1 {
		t.Fatalf("state = %+v", s)
	}
}

func TestAnySuccessResetsTheStreak(t *testing.T) {
	c := &clock{now: time.Unix(1_800_000_000, 0)}
	d := newDetector(c)
	d.Observe(errDown)
	c.advance(90 * time.Second)
	d.Observe(nil)
	c.advance(60 * time.Second)
	d.Observe(errDown)
	c.advance(90 * time.Second)
	d.Observe(errDown)
	if events := d.Events(); len(events) != 0 {
		t.Fatalf("a success inside the window must restart it: %+v", events)
	}
}

func TestAnAnsweringAPIIsNotAnOutage(t *testing.T) {
	c := &clock{now: time.Unix(1_800_000_000, 0)}
	d := newDetector(c)
	d.Observe(errDown)
	c.advance(3 * time.Minute)
	d.Observe(errAnswered)
	d.Check()
	if events := d.Events(); len(events) != 0 || !d.State().Reachable {
		t.Fatalf("events = %+v", events)
	}
}

func TestCheckDeclaresWithoutANewCall(t *testing.T) {
	c := &clock{now: time.Unix(1_800_000_000, 0)}
	d := newDetector(c)
	d.Check()
	if len(d.Events()) != 0 {
		t.Fatal("no failures, no outage")
	}
	d.Observe(errDown)
	c.advance(2*time.Minute + time.Second)
	d.Check()
	if events := d.Events(); len(events) != 1 || events[0].Kind != Down {
		t.Fatalf("events = %+v", events)
	}
}

func TestDefaultsTreatEveryErrorAsUnreachable(t *testing.T) {
	d := New(time.Nanosecond, nil, nil)
	d.Observe(errAnswered)
	time.Sleep(time.Millisecond)
	d.Check()
	if events := d.Events(); len(events) != 1 {
		t.Fatalf("events = %+v", events)
	}
}
