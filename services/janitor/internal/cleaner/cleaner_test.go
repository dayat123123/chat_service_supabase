package cleaner

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log/slog"
	"reflect"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"olt-social/janitor/internal/metrics"
	"olt-social/janitor/internal/store"
)

type claimArgs struct {
	limit, objects int
	lease          time.Duration
}

type fakeStore struct {
	mu          sync.Mutex
	batches     [][]store.Entry
	claims      []claimArgs
	claimErr    error
	reportFails int
	reportCalls int
	reports     [][]store.Result
}

func (s *fakeStore) Claim(_ context.Context, instance string, limit, objects int, lease time.Duration) ([]store.Entry, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.claims = append(s.claims, claimArgs{limit, objects, lease})
	if instance != "janitor-test" {
		return nil, fmt.Errorf("unexpected instance %q", instance)
	}
	if s.claimErr != nil {
		return nil, s.claimErr
	}
	if len(s.batches) == 0 {
		return nil, nil
	}
	batch := s.batches[0]
	s.batches = s.batches[1:]
	return batch, nil
}

func (s *fakeStore) Report(_ context.Context, _ string, results []store.Result) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.reportCalls++
	if s.reportFails > 0 {
		s.reportFails--
		return 0, errors.New("postgrest unavailable")
	}
	s.reports = append(s.reports, slices.Clone(results))
	return len(results), nil
}

func (s *fakeStore) state() (claims []claimArgs, reports [][]store.Result) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return slices.Clone(s.claims), slices.Clone(s.reports)
}

func (s *fakeStore) reportAttempts() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.reportCalls
}

func (s *fakeStore) setClaimErr(err error) {
	s.mu.Lock()
	s.claimErr = err
	s.mu.Unlock()
}

type call struct {
	bucket string
	names  []string
}

type fakeStorage struct {
	mu     sync.Mutex
	calls  []call
	delete func(ctx context.Context, bucket string, names []string) (int, error)
}

func (f *fakeStorage) Delete(ctx context.Context, bucket string, names []string) (int, error) {
	f.mu.Lock()
	f.calls = append(f.calls, call{bucket, slices.Clone(names)})
	deleteFn := f.delete
	f.mu.Unlock()
	if deleteFn == nil {
		return len(names), nil
	}
	return deleteFn(ctx, bucket, names)
}

func (f *fakeStorage) attempted() []call {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.calls)
}

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

func files(prefix string, n int) []string {
	out := make([]string, 0, n)
	for i := range n {
		out = append(out, fmt.Sprintf("%sfile-%d.jpg", prefix, i))
	}
	return out
}

func entry(id int64, bucket string, objects int) store.Entry {
	prefix := fmt.Sprintf("user-%d/", id)
	return store.Entry{ID: id, Bucket: bucket, Prefix: prefix, Objects: files(prefix, objects)}
}

func newCleaner(queue Store, objects Storage, adjust func(*Options)) *Cleaner {
	opts := Options{
		Store:           queue,
		Storage:         objects,
		Log:             slog.New(slog.DiscardHandler),
		Instance:        "janitor-test",
		BatchSize:       10,
		ObjectsPerEntry: 1000,
		DeleteChunk:     100,
		Concurrency:     4,
		Lease:           30 * time.Second,
		PollInterval:    10 * time.Millisecond,
		RequestTimeout:  time.Second,
		ShutdownTimeout: time.Second,
	}
	if adjust != nil {
		adjust(&opts)
	}
	c := New(opts)
	c.backoffMin, c.backoffMax = 10*time.Millisecond, 40*time.Millisecond
	c.reportDelays = []time.Duration{time.Millisecond, time.Millisecond, time.Millisecond}
	return c
}

func start(t *testing.T, c *Cleaner) (context.CancelFunc, <-chan struct{}) {
	t.Helper()
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
	return cancel, done
}

func eventually(t *testing.T, what string, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for !cond() {
		if time.Now().After(deadline) {
			t.Fatalf("timed out waiting for %s", what)
		}
		time.Sleep(5 * time.Millisecond)
	}
}

func reported(queue *fakeStore, n int) func() bool {
	return func() bool {
		_, reports := queue.state()
		return len(reports) >= n
	}
}

func TestCleanerDeletesInChunksAndReportsTheTotal(t *testing.T) {
	queue := &fakeStore{batches: [][]store.Entry{{entry(1, "avatars", 5), entry(2, "attachments", 0)}}}
	objects := &fakeStorage{}
	c := newCleaner(queue, objects, func(o *Options) { o.DeleteChunk = 2 })
	start(t, c)

	eventually(t, "a report", reported(queue, 1))
	claims, reports := queue.state()
	if claims[0] != (claimArgs{limit: 10, objects: 1000, lease: 30 * time.Second}) {
		t.Fatalf("claim = %+v", claims[0])
	}
	want := []store.Result{{ID: 1, Deleted: 5}, {ID: 2, Deleted: 0}}
	if !reflect.DeepEqual(reports[0], want) {
		t.Fatalf("report = %+v", reports[0])
	}
	all := files("user-1/", 5)
	wantCalls := []call{{"avatars", all[0:2]}, {"avatars", all[2:4]}, {"avatars", all[4:5]}}
	if got := objects.attempted(); !reflect.DeepEqual(got, wantCalls) {
		t.Fatalf("calls = %+v", got)
	}
	snapshot := c.Metrics()
	if snapshot.ObjectsDeleted != 5 || !reflect.DeepEqual(snapshot.Entries, map[string]uint64{metrics.Cleaned: 2}) ||
		snapshot.ClaimErrors != 0 || snapshot.LastSuccess.IsZero() {
		t.Fatalf("metrics = %+v", snapshot)
	}
}

func TestCleanerReportsAnEmptyFolderWithoutCallingStorage(t *testing.T) {
	queue := &fakeStore{batches: [][]store.Entry{{entry(7, "care-documents", 0)}}}
	objects := &fakeStorage{}
	start(t, newCleaner(queue, objects, nil))

	eventually(t, "a report", reported(queue, 1))
	_, reports := queue.state()
	if !reflect.DeepEqual(reports[0], []store.Result{{ID: 7}}) {
		t.Fatalf("report = %+v", reports[0])
	}
	if calls := objects.attempted(); len(calls) != 0 {
		t.Fatalf("calls = %+v", calls)
	}
}

func TestCleanerStopsOnlyTheFailingEntry(t *testing.T) {
	queue := &fakeStore{batches: [][]store.Entry{{entry(1, "broken", 5), entry(2, "avatars", 3)}}}
	failure := "storage delete broken: status 400: Bucket not found"
	objects := &fakeStorage{delete: func(_ context.Context, bucket string, names []string) (int, error) {
		if bucket == "broken" && names[0] == "user-1/file-2.jpg" {
			return 0, errors.New(failure)
		}
		return len(names), nil
	}}
	logs := &syncBuffer{}
	c := newCleaner(queue, objects, func(o *Options) {
		o.DeleteChunk = 2
		o.Log = slog.New(slog.NewJSONHandler(logs, nil))
	})
	start(t, c)

	eventually(t, "a report", reported(queue, 1))
	_, reports := queue.state()
	want := []store.Result{{ID: 1, Deleted: 2, Error: failure}, {ID: 2, Deleted: 3}}
	if !reflect.DeepEqual(reports[0], want) {
		t.Fatalf("report = %+v", reports[0])
	}
	broken := 0
	for _, call := range objects.attempted() {
		if call.bucket == "broken" {
			broken++
		}
	}
	if broken != 2 {
		t.Fatalf("calls to the failing bucket = %d", broken)
	}
	if snapshot := c.Metrics(); snapshot.ObjectsDeleted != 5 ||
		!reflect.DeepEqual(snapshot.Entries, map[string]uint64{metrics.Cleaned: 1, metrics.Failed: 1}) {
		t.Fatalf("metrics = %+v", snapshot)
	}
	text := logs.String()
	for _, part := range []string{`"msg":"Storage cleanup entry failed"`, `"bucket":"broken"`, `"prefix":"user-1/"`, failure,
		`"msg":"Storage cleanup round finished"`, `"entries":2`, `"objects_deleted":5`, `"failed":1`} {
		if !strings.Contains(text, part) {
			t.Errorf("missing %q in logs\n%s", part, text)
		}
	}
	if strings.Contains(text, "file-0.jpg") {
		t.Fatalf("object names leaked into the logs\n%s", text)
	}
}

func TestCleanerProcessesEntriesInParallelUpToTheLimit(t *testing.T) {
	queue := &fakeStore{batches: [][]store.Entry{{entry(1, "a", 3), entry(2, "a", 3), entry(3, "a", 3), entry(4, "a", 3)}}}
	var active, peak atomic.Int32
	var perEntry sync.Map
	objects := &fakeStorage{delete: func(_ context.Context, _ string, names []string) (int, error) {
		prefix := names[0][:strings.Index(names[0], "/")]
		counter, _ := perEntry.LoadOrStore(prefix, &atomic.Int32{})
		if counter.(*atomic.Int32).Add(1) > 1 {
			t.Errorf("chunks of %s ran in parallel", prefix)
		}
		defer counter.(*atomic.Int32).Add(-1)
		now := active.Add(1)
		defer active.Add(-1)
		for {
			old := peak.Load()
			if now <= old || peak.CompareAndSwap(old, now) {
				break
			}
		}
		time.Sleep(20 * time.Millisecond)
		return len(names), nil
	}}
	start(t, newCleaner(queue, objects, func(o *Options) {
		o.Concurrency = 2
		o.DeleteChunk = 1
	}))

	eventually(t, "a report", reported(queue, 1))
	if got := peak.Load(); got != 2 {
		t.Fatalf("peak parallel deletes = %d", got)
	}
	_, reports := queue.state()
	for _, r := range reports[0] {
		if r.Deleted != 3 || r.Error != "" || r.Release {
			t.Fatalf("report = %+v", reports[0])
		}
	}
}

func TestCleanerReleasesEntriesWhenTheLeaseRunsOut(t *testing.T) {
	queue := &fakeStore{batches: [][]store.Entry{{entry(1, "avatars", 3), entry(2, "avatars", 1), entry(3, "avatars", 0)}}}
	objects := &fakeStorage{delete: func(_ context.Context, _ string, names []string) (int, error) {
		time.Sleep(300 * time.Millisecond)
		return len(names), nil
	}}
	c := newCleaner(queue, objects, func(o *Options) {
		o.Concurrency = 1
		o.DeleteChunk = 1
		o.RequestTimeout = 0
		o.Lease = leaseMargin + 150*time.Millisecond
	})
	start(t, c)

	eventually(t, "a report", reported(queue, 1))
	_, reports := queue.state()
	want := []store.Result{{ID: 1, Deleted: 1, Release: true}, {ID: 2, Release: true}, {ID: 3}}
	if !reflect.DeepEqual(reports[0], want) {
		t.Fatalf("report = %+v", reports[0])
	}
	if calls := objects.attempted(); len(calls) != 1 {
		t.Fatalf("calls = %+v", calls)
	}
	if snapshot := c.Metrics(); !reflect.DeepEqual(snapshot.Entries, map[string]uint64{metrics.Released: 2, metrics.Cleaned: 1}) {
		t.Fatalf("metrics = %+v", snapshot)
	}
}

func TestCleanerReleasesUnstartedWorkOnShutdown(t *testing.T) {
	queue := &fakeStore{batches: [][]store.Entry{{entry(1, "avatars", 4), entry(2, "avatars", 1)}}}
	release := make(chan struct{})
	started := make(chan struct{}, 4)
	objects := &fakeStorage{delete: func(_ context.Context, _ string, names []string) (int, error) {
		started <- struct{}{}
		<-release
		return len(names), nil
	}}
	cancel, done := start(t, newCleaner(queue, objects, func(o *Options) {
		o.Concurrency = 1
		o.DeleteChunk = 2
	}))

	<-started
	cancel()
	select {
	case <-done:
		t.Fatal("Run returned before the delete in flight finished")
	case <-time.After(100 * time.Millisecond):
	}
	close(release)
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("Run did not return after the delete finished")
	}
	claims, reports := queue.state()
	want := []store.Result{{ID: 1, Deleted: 2, Release: true}, {ID: 2, Release: true}}
	if len(claims) != 1 || len(reports) != 1 || !reflect.DeepEqual(reports[0], want) {
		t.Fatalf("claims = %d reports = %+v", len(claims), reports)
	}
	if calls := objects.attempted(); len(calls) != 1 {
		t.Fatalf("calls = %+v", calls)
	}
}

func TestCleanerAbandonsDeletesAfterTheShutdownTimeout(t *testing.T) {
	queue := &fakeStore{batches: [][]store.Entry{{entry(1, "avatars", 3)}}}
	started := make(chan struct{}, 3)
	objects := &fakeStorage{delete: func(ctx context.Context, bucket string, names []string) (int, error) {
		if names[0] == "user-1/file-0.jpg" {
			return 1, nil
		}
		started <- struct{}{}
		<-ctx.Done()
		return 0, fmt.Errorf("storage delete %s: %w", bucket, ctx.Err())
	}}
	cancel, done := start(t, newCleaner(queue, objects, func(o *Options) {
		o.DeleteChunk = 1
		o.ShutdownTimeout = 100 * time.Millisecond
	}))

	<-started
	began := time.Now()
	cancel()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("Run ignored the shutdown timeout")
	}
	if elapsed := time.Since(began); elapsed < 100*time.Millisecond {
		t.Fatalf("Run returned after %v, before the shutdown timeout", elapsed)
	}
	_, reports := queue.state()
	want := []store.Result{{ID: 1, Deleted: 1, Release: true}}
	if len(reports) != 1 || !reflect.DeepEqual(reports[0], want) {
		t.Fatalf("reports = %+v", reports)
	}
}

func TestCleanerClaimsAgainRightAwayAfterAFullBatch(t *testing.T) {
	queue := &fakeStore{batches: [][]store.Entry{{entry(1, "a", 1), entry(2, "a", 1)}, {entry(3, "a", 1)}}}
	start(t, newCleaner(queue, &fakeStorage{}, func(o *Options) {
		o.BatchSize = 2
		o.PollInterval = time.Hour
	}))

	eventually(t, "the second batch", reported(queue, 2))
	time.Sleep(50 * time.Millisecond)
	if claims, _ := queue.state(); len(claims) != 2 {
		t.Fatalf("a partial batch must wait for the poll interval, claims = %d", len(claims))
	}
}

func TestCleanerClaimsAgainRightAwayWhenAFolderMayHoldMore(t *testing.T) {
	queue := &fakeStore{batches: [][]store.Entry{{entry(1, "a", 3)}, {entry(1, "a", 2)}}}
	start(t, newCleaner(queue, &fakeStorage{}, func(o *Options) {
		o.ObjectsPerEntry = 3
		o.PollInterval = time.Hour
	}))

	eventually(t, "the rest of the folder", reported(queue, 2))
	time.Sleep(50 * time.Millisecond)
	if claims, _ := queue.state(); len(claims) != 2 {
		t.Fatalf("claims = %d", len(claims))
	}
}

func TestCleanerWaitsAfterAFullFolderFails(t *testing.T) {
	queue := &fakeStore{batches: [][]store.Entry{{entry(1, "broken", 3)}, {entry(2, "a", 1)}}}
	objects := &fakeStorage{delete: func(context.Context, string, []string) (int, error) {
		return 0, errors.New("storage delete broken: status 400: Bucket not found")
	}}
	start(t, newCleaner(queue, objects, func(o *Options) {
		o.ObjectsPerEntry = 3
		o.PollInterval = time.Hour
	}))

	eventually(t, "a report", reported(queue, 1))
	time.Sleep(50 * time.Millisecond)
	if claims, _ := queue.state(); len(claims) != 1 {
		t.Fatalf("a failed folder must wait for the poll interval, claims = %d", len(claims))
	}
}

func TestCleanerBacksOffWhileClaimsFail(t *testing.T) {
	queue := &fakeStore{batches: [][]store.Entry{{entry(1, "a", 1)}}, claimErr: errors.New("rpc storage_cleanup_claim: status 503")}
	c := newCleaner(queue, &fakeStorage{}, nil)
	start(t, c)

	time.Sleep(300 * time.Millisecond)
	claims, _ := queue.state()
	if len(claims) < 2 || len(claims) > 15 {
		t.Fatalf("claims while PostgREST is down = %d", len(claims))
	}
	if errs := c.Metrics().ClaimErrors; errs < 2 {
		t.Fatalf("claim errors = %d", errs)
	}
	queue.setClaimErr(nil)
	eventually(t, "recovery", reported(queue, 1))
}

func TestCleanerRetriesTheReport(t *testing.T) {
	queue := &fakeStore{batches: [][]store.Entry{{entry(1, "a", 1)}}, reportFails: 3}
	c := newCleaner(queue, &fakeStorage{}, nil)
	start(t, c)

	eventually(t, "a report", reported(queue, 1))
	if calls := queue.reportAttempts(); calls != 4 {
		t.Fatalf("report calls = %d", calls)
	}
	if c.Metrics().LastSuccess.IsZero() {
		t.Fatal("a successful report must set the last success time")
	}
}

func TestCleanerMovesOnWhenTheReportKeepsFailing(t *testing.T) {
	queue := &fakeStore{batches: [][]store.Entry{{entry(1, "a", 1)}, {entry(2, "a", 1)}}, reportFails: 4}
	start(t, newCleaner(queue, &fakeStorage{}, nil))

	eventually(t, "the next batch", reported(queue, 1))
	_, reports := queue.state()
	if calls := queue.reportAttempts(); reports[0][0].ID != 2 || calls != 5 {
		t.Fatalf("reports = %+v calls = %d", reports, calls)
	}
}
