package attachments

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"strings"
	"sync"
	"testing"
	"time"
)

type fakeStore struct {
	mu     sync.Mutex
	policy Policy
	err    error
	calls  int
}

func (f *fakeStore) AttachmentPolicy(context.Context) (Policy, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls++
	return f.policy, f.err
}

func sample() Policy {
	return Policy{
		"documents": {Enabled: true, Bucket: "cs-documents", MaxBytes: 10 << 20, Formats: []Format{{Code: "pdf"}, {Code: "docx"}}},
		"videos":    {Enabled: false, Bucket: "cs-videos", MaxBytes: 25 << 20, MaxSeconds: 120, Formats: []Format{{Code: "mp4"}}},
	}
}

func TestLoaderLoadsKeepsAndLogsChanges(t *testing.T) {
	var logs bytes.Buffer
	store := &fakeStore{policy: sample()}
	changed := 0
	l := NewLoader(store, slog.New(slog.NewJSONHandler(&logs, nil)), time.Minute, func() { changed++ })
	if _, ok := l.Current(); ok {
		t.Fatal("nothing loaded yet")
	}
	l.Refresh(context.Background())
	l.Refresh(context.Background())
	p, ok := l.Current()
	if !ok || !p["documents"].Allows("docx") || p["documents"].Allows("xlsx") || p["videos"].Enabled || changed != 1 {
		t.Fatalf("policy = %+v ok = %v changed = %d", p, ok, changed)
	}
	if strings.Count(logs.String(), "Attachment policy loaded") != 1 {
		t.Fatalf("logs = %s", logs.String())
	}
	store.mu.Lock()
	store.err = errors.New("rpc media_attachment_policy: status 503")
	store.mu.Unlock()
	l.Refresh(context.Background())
	l.Refresh(context.Background())
	if p, ok := l.Current(); !ok || !p["documents"].Enabled {
		t.Fatal("a failed refresh keeps the last policy")
	}
	if strings.Count(logs.String(), "could not be loaded") != 1 {
		t.Fatalf("logs = %s", logs.String())
	}
	store.mu.Lock()
	store.err = nil
	store.policy = sample()
	store.policy["videos"] = Rule{Enabled: true, Bucket: "cs-videos", MaxBytes: 5 << 20, MaxSeconds: 30, Formats: []Format{{Code: "webm"}}}
	store.mu.Unlock()
	l.Refresh(context.Background())
	p, _ = l.Current()
	if !p["videos"].Enabled || p["videos"].MaxSeconds != 30 || !strings.Contains(logs.String(), "can be loaded again") ||
		strings.Count(logs.String(), "Attachment policy loaded") != 2 || changed != 1 {
		t.Fatalf("policy = %+v logs = %s", p, logs.String())
	}
}

func TestRuleHelpers(t *testing.T) {
	p := sample()
	r, ok := p.ForBucket("cs-videos")
	if !ok || r.MaxSeconds != 120 || strings.Join(r.Codes(), ",") != "mp4" {
		t.Fatalf("rule = %+v", r)
	}
	if _, ok := p.ForBucket("attachments"); ok {
		t.Fatal("unknown bucket")
	}
}

func TestLoaderRunStopsWithTheContext(t *testing.T) {
	store := &fakeStore{policy: sample()}
	l := NewLoader(store, slog.New(slog.NewTextHandler(&bytes.Buffer{}, nil)), 10*time.Millisecond, nil)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		l.Run(ctx)
		close(done)
	}()
	time.Sleep(50 * time.Millisecond)
	cancel()
	<-done
	store.mu.Lock()
	defer store.mu.Unlock()
	if store.calls < 2 {
		t.Fatalf("calls = %d", store.calls)
	}
}
