package heartbeat

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

type fakeStore struct {
	mu    sync.Mutex
	beats []Beat
	fails int
}

func (s *fakeStore) Heartbeat(_ context.Context, beat Beat) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.beats = append(s.beats, beat)
	if s.fails > 0 {
		s.fails--
		return errors.New("postgrest unavailable")
	}
	return nil
}

func (s *fakeStore) count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.beats)
}

func (s *fakeStore) last() Beat {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.beats[len(s.beats)-1]
}

type syncBuffer struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (b *syncBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.Write(p)
}

func (b *syncBuffer) String() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.String()
}

func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for !cond() {
		if time.Now().After(deadline) {
			t.Fatal("condition not reached")
		}
		time.Sleep(5 * time.Millisecond)
	}
}

func TestLoopSendsAtStartOnKickAndEveryInterval(t *testing.T) {
	store := &fakeStore{}
	var status atomic.Value
	status.Store(StatusOK)
	var probes atomic.Int32
	started := time.Unix(1_800_000_000, 0)
	loop := New(Options{
		Store:     store,
		Log:       slog.New(slog.NewTextHandler(&syncBuffer{}, nil)),
		Service:   "media",
		Instance:  "media-1",
		Version:   "0.1.0",
		StartedAt: started,
		Interval:  time.Hour,
		Probe:     func(context.Context) { probes.Add(1) },
		Report: func() Report {
			return Report{Status: status.Load().(string), Detail: map[string]any{"accepted": 1}}
		},
	})
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		loop.Run(ctx)
		close(done)
	}()
	waitFor(t, func() bool { return store.count() == 1 })
	first := store.last()
	if first.Service != "media" || first.Instance != "media-1" || first.Version != "0.1.0" ||
		!first.StartedAt.Equal(started) || first.Status != StatusOK || first.Detail["accepted"] != 1 || probes.Load() != 1 {
		t.Fatalf("beat = %+v probes = %d", first, probes.Load())
	}
	if loop.LastSuccess().IsZero() {
		t.Fatal("last success not recorded")
	}
	status.Store(StatusDegraded)
	loop.Kick()
	waitFor(t, func() bool { return store.count() == 2 })
	if store.last().Status != StatusDegraded || probes.Load() != 1 {
		t.Fatalf("kick beat = %+v", store.last())
	}
	cancel()
	<-done
}

func TestLoopTicksAndLogsOncePerStateChange(t *testing.T) {
	store := &fakeStore{fails: 3}
	logs := &syncBuffer{}
	var probes atomic.Int32
	loop := New(Options{
		Store:    store,
		Log:      slog.New(slog.NewTextHandler(logs, nil)),
		Service:  "media",
		Interval: 10 * time.Millisecond,
		Probe:    func(context.Context) { probes.Add(1) },
		Report:   func() Report { return Report{Status: StatusOK} },
	})
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		loop.Run(ctx)
		close(done)
	}()
	waitFor(t, func() bool { return store.count() >= 5 })
	cancel()
	<-done
	out := logs.String()
	if strings.Count(out, "Heartbeat failed") != 1 || strings.Count(out, "Heartbeat works again") != 1 {
		t.Fatalf("logs = %s", out)
	}
	if probes.Load() < 5 {
		t.Fatalf("probes = %d", probes.Load())
	}
}
