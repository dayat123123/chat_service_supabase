package evidence

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"reflect"
	"sync"
	"testing"
	"time"

	"olt-social/janitor/internal/metrics"
	"olt-social/janitor/internal/storage"
	"olt-social/janitor/internal/store"
)

type fakeStore struct {
	mu      sync.Mutex
	batches [][]store.CopyJob
	reports [][]store.CopyResult
	fails   int
}

func (s *fakeStore) ClaimCopies(_ context.Context, instance string, limit int, lease time.Duration) ([]store.CopyJob, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if instance != "janitor-test" || limit != 10 || lease != 30*time.Second {
		return nil, fmt.Errorf("unexpected claim %s %d %s", instance, limit, lease)
	}
	if len(s.batches) == 0 {
		return nil, nil
	}
	batch := s.batches[0]
	s.batches = s.batches[1:]
	return batch, nil
}

func (s *fakeStore) ReportCopies(_ context.Context, _ string, results []store.CopyResult) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.fails > 0 {
		s.fails--
		return 0, errors.New("postgrest unavailable")
	}
	s.reports = append(s.reports, append([]store.CopyResult(nil), results...))
	return len(results), nil
}

func (s *fakeStore) reported() [][]store.CopyResult {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([][]store.CopyResult(nil), s.reports...)
}

type fakeStorage struct {
	mu      sync.Mutex
	objects map[string][]byte
	corrupt bool
	broken  string
}

func (f *fakeStorage) Copy(_ context.Context, bucket, name, destBucket, destName string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if bucket == f.broken {
		return errors.New("storage copy " + bucket + ": status 500")
	}
	data, ok := f.objects[bucket+"/"+name]
	if !ok {
		return storage.ErrNotFound
	}
	if f.corrupt {
		data = append([]byte("x"), data...)
	}
	f.objects[destBucket+"/"+destName] = data
	return nil
}

func (f *fakeStorage) Hash(_ context.Context, bucket, name string) (string, int64, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	data, ok := f.objects[bucket+"/"+name]
	if !ok {
		return "", 0, storage.ErrNotFound
	}
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:]), int64(len(data)), nil
}

func (f *fakeStorage) has(key string) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	_, ok := f.objects[key]
	return ok
}

func run(t *testing.T, queue *fakeStore, objects *fakeStorage) *Copier {
	t.Helper()
	c := New(Options{
		Store: queue, Storage: objects, Log: slog.New(slog.DiscardHandler), Instance: "janitor-test",
		BatchSize: 10, Concurrency: 2, Lease: 30 * time.Second, PollInterval: 10 * time.Millisecond,
		RequestTimeout: time.Second, ShutdownTimeout: time.Second,
	})
	c.backoffMin, c.backoffMax = 5*time.Millisecond, 20*time.Millisecond
	c.reportDelays = []time.Duration{time.Millisecond, time.Millisecond, time.Millisecond}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		c.Run(ctx)
		close(done)
	}()
	t.Cleanup(func() {
		cancel()
		<-done
	})
	return c
}

func waitReports(t *testing.T, queue *fakeStore, n int) [][]store.CopyResult {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for {
		if reports := queue.reported(); len(reports) >= n {
			return reports
		}
		if time.Now().After(deadline) {
			t.Fatal("timed out waiting for a report")
		}
		time.Sleep(5 * time.Millisecond)
	}
}

func digest(data string) string {
	sum := sha256.Sum256([]byte(data))
	return hex.EncodeToString(sum[:])
}

func TestCopierCopiesHashesAndReportsMissingSources(t *testing.T) {
	queue := &fakeStore{batches: [][]store.CopyJob{{
		{ID: 1, SourceBucket: "attachments", SourceName: "posts/u/a.png", ObjectName: "e1/01-a.png"},
		{ID: 2, SourceBucket: "attachments", SourceName: "posts/u/gone.png", ObjectName: "e1/02-gone.png"},
	}}}
	objects := &fakeStorage{objects: map[string][]byte{"attachments/posts/u/a.png": []byte("image-bytes")}}
	c := run(t, queue, objects)

	reports := waitReports(t, queue, 1)
	want := []store.CopyResult{{ID: 1, SHA256: digest("image-bytes"), Size: 11}, {ID: 2, Missing: true}}
	if !reflect.DeepEqual(reports[0], want) {
		t.Fatalf("report = %+v", reports[0])
	}
	if !objects.has("evidence/e1/01-a.png") {
		t.Fatal("the copy is not in the evidence bucket")
	}
	outcomes, claimErrors := c.Metrics()
	if !reflect.DeepEqual(outcomes, map[string]uint64{metrics.EvidenceCopied: 1, metrics.EvidenceMissing: 1}) || claimErrors != 0 {
		t.Fatalf("metrics = %v %d", outcomes, claimErrors)
	}
}

func TestCopierRejectsACopyThatDoesNotMatchItsSource(t *testing.T) {
	queue := &fakeStore{batches: [][]store.CopyJob{{
		{ID: 7, SourceBucket: "attachments", SourceName: "a", ObjectName: "e/01-a"},
		{ID: 8, SourceBucket: "broken", SourceName: "b", ObjectName: "e/02-b"},
	}}}
	objects := &fakeStorage{corrupt: true, broken: "broken",
		objects: map[string][]byte{"attachments/a": []byte("one"), "broken/b": []byte("two")}}
	run(t, queue, objects)

	reports := waitReports(t, queue, 1)
	want := []store.CopyResult{{ID: 7, Error: errMismatch.Error()}, {ID: 8, Error: "storage copy broken: status 500"}}
	if !reflect.DeepEqual(reports[0], want) {
		t.Fatalf("report = %+v", reports[0])
	}
}

func TestCopierRetriesTheReport(t *testing.T) {
	queue := &fakeStore{fails: 2, batches: [][]store.CopyJob{{{ID: 3, SourceBucket: "avatars", SourceName: "u/a.jpg", ObjectName: "e/01-a.jpg"}}}}
	objects := &fakeStorage{objects: map[string][]byte{"avatars/u/a.jpg": []byte("avatar")}}
	run(t, queue, objects)

	reports := waitReports(t, queue, 1)
	if !reflect.DeepEqual(reports[0], []store.CopyResult{{ID: 3, SHA256: digest("avatar"), Size: 6}}) {
		t.Fatalf("report = %+v", reports[0])
	}
}
