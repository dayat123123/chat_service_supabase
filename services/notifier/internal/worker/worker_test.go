package worker

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"reflect"
	"slices"
	"sync"
	"testing"
	"time"

	"olt-social/notifier/internal/push"
)

type fakeStore struct {
	mu          sync.Mutex
	batches     [][]push.Job
	claims      int
	claimErr    error
	reportFails int
	reportCalls int
	reports     [][]push.Result
	beats       []push.Heartbeat
}

func (s *fakeStore) Claim(_ context.Context, instance string, limit int, lease time.Duration) ([]push.Job, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.claims++
	if instance != "notifier-test" || limit <= 0 || lease <= 0 {
		return nil, fmt.Errorf("unexpected claim %q %d %v", instance, limit, lease)
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

func (s *fakeStore) Report(_ context.Context, _ string, results []push.Result) (int, error) {
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

func (s *fakeStore) Heartbeat(_ context.Context, beat push.Heartbeat) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.beats = append(s.beats, beat)
	return 17, nil
}

func (s *fakeStore) state() (claims int, reports [][]push.Result, beats []push.Heartbeat) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.claims, slices.Clone(s.reports), slices.Clone(s.beats)
}

func (s *fakeStore) enqueue(batch []push.Job) {
	s.mu.Lock()
	s.batches = append(s.batches, batch)
	s.mu.Unlock()
}

func sawError(store *fakeStore, problem string) func() bool {
	return func() bool {
		_, _, beats := store.state()
		for _, beat := range beats {
			if beat.Error == problem {
				return true
			}
		}
		return false
	}
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

type fakeSender struct {
	mu      sync.Mutex
	status  push.Status
	changed bool
	deliver func(ctx context.Context, job push.Job) push.Delivery
	sent    []int64
}

func newSender(status push.Status, deliver func(ctx context.Context, job push.Job) push.Delivery) *fakeSender {
	return &fakeSender{status: status, changed: true, deliver: deliver}
}

func (f *fakeSender) Reload() (push.Status, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	changed := f.changed
	f.changed = false
	return f.status, changed
}

func (f *fakeSender) Send(ctx context.Context, job push.Job) push.Delivery {
	f.mu.Lock()
	f.sent = append(f.sent, job.ID)
	deliver := f.deliver
	f.mu.Unlock()
	return deliver(ctx, job)
}

func (f *fakeSender) setStatus(status push.Status) {
	f.mu.Lock()
	f.status, f.changed = status, true
	f.mu.Unlock()
}

func (f *fakeSender) attempted() []int64 {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.sent)
}

var (
	configured = push.Status{Configured: true, ProjectID: "demo-project"}
	startedAt  = time.Date(2026, 11, 2, 1, 0, 0, 0, time.UTC)
	delivered  = push.Delivery{Result: push.Result{Outcome: push.Sent}, Healthy: true}
	outage     = push.Delivery{Result: push.Result{Outcome: push.Release}, Problem: "Tidak bisa menghubungi Firebase", Systemic: true}
)

func always(d push.Delivery) func(context.Context, push.Job) push.Delivery {
	return func(context.Context, push.Job) push.Delivery { return d }
}

func jobs(ids ...int64) []push.Job {
	out := make([]push.Job, 0, len(ids))
	for _, id := range ids {
		out = append(out, push.Job{ID: id, Token: fmt.Sprintf("device-token-%06d", id), Platform: push.Android, Kind: "chat.message", Title: "Rina"})
	}
	return out
}

func newWorker(store Store, sender Sender, adjust func(*Options)) *Worker {
	opts := Options{
		Store:             store,
		Sender:            sender,
		Log:               slog.New(slog.DiscardHandler),
		Instance:          "notifier-test",
		Version:           "0.1.0",
		StartedAt:         startedAt,
		BatchSize:         10,
		Concurrency:       4,
		Lease:             30 * time.Second,
		PollInterval:      10 * time.Millisecond,
		HeartbeatInterval: time.Hour,
		ReloadInterval:    10 * time.Millisecond,
		SendTimeout:       time.Second,
		ShutdownTimeout:   time.Second,
	}
	if adjust != nil {
		adjust(&opts)
	}
	w := New(opts)
	w.pauseMin, w.pauseMax = 500*time.Millisecond, 2*time.Second
	w.backoffMin, w.backoffMax = 10*time.Millisecond, 40*time.Millisecond
	w.reportDelays = []time.Duration{time.Millisecond, time.Millisecond, time.Millisecond}
	return w
}

func start(t *testing.T, w *Worker) (context.CancelFunc, <-chan struct{}) {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		w.Run(ctx)
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

func reportCount(store *fakeStore) func() bool {
	return func() bool {
		_, reports, _ := store.state()
		return len(reports) > 0
	}
}

func lastBeat(store *fakeStore) push.Heartbeat {
	_, _, beats := store.state()
	if len(beats) == 0 {
		return push.Heartbeat{}
	}
	return beats[len(beats)-1]
}

func TestWorkerReportsTheOutcomeOfEveryJob(t *testing.T) {
	store := &fakeStore{batches: [][]push.Job{jobs(1, 2, 3, 4)}}
	sender := newSender(configured, func(_ context.Context, job push.Job) push.Delivery {
		switch job.ID {
		case 1:
			return delivered
		case 2:
			return push.Delivery{Result: push.Result{Outcome: push.Invalid, Error: "Token perangkat tidak berlaku (UNREGISTERED)"}}
		case 3:
			return push.Delivery{Result: push.Result{Outcome: push.Failed, Error: "Invalid value at 'message.data'"}}
		default:
			return push.Delivery{Result: push.Result{Outcome: push.Retry, Error: "Firebase sementara gagal (UNAVAILABLE)", RetryAfter: 7 * time.Second}}
		}
	})
	w := newWorker(store, sender, nil)
	start(t, w)

	eventually(t, "a report", reportCount(store))
	_, reports, beats := store.state()
	want := []push.Result{
		{ID: 1, Outcome: push.Sent},
		{ID: 2, Outcome: push.Invalid, Error: "Token perangkat tidak berlaku (UNREGISTERED)"},
		{ID: 3, Outcome: push.Failed, Error: "Invalid value at 'message.data'"},
		{ID: 4, Outcome: push.Retry, Error: "Firebase sementara gagal (UNAVAILABLE)", RetryAfter: 7 * time.Second},
	}
	if !reflect.DeepEqual(reports[0], want) {
		t.Fatalf("report = %+v", reports[0])
	}
	wantBeat := push.Heartbeat{Instance: "notifier-test", Version: "0.1.0", Configured: true, ProjectID: "demo-project", StartedAt: startedAt}
	if len(beats) == 0 || beats[0] != wantBeat {
		t.Fatalf("beats = %+v", beats)
	}
	snapshot := w.Metrics()
	wantPushes := map[push.Outcome]uint64{push.Sent: 1, push.Invalid: 1, push.Failed: 1, push.Retry: 1}
	if !reflect.DeepEqual(snapshot.Pushes, wantPushes) || snapshot.ClaimBatches != 1 || snapshot.QueueDepth != 17 ||
		!snapshot.Configured || !snapshot.Healthy {
		t.Fatalf("metrics = %+v", snapshot)
	}
}

func TestWorkerReleasesTheRestOfTheBatchAndPausesOnASystemicFailure(t *testing.T) {
	store := &fakeStore{batches: [][]push.Job{jobs(1, 2, 3)}}
	sender := newSender(configured, func(_ context.Context, job push.Job) push.Delivery {
		if job.ID == 2 {
			return outage
		}
		return delivered
	})
	w := newWorker(store, sender, func(o *Options) { o.Concurrency = 1 })
	start(t, w)

	eventually(t, "a report", reportCount(store))
	_, reports, _ := store.state()
	want := []push.Result{
		{ID: 1, Outcome: push.Sent},
		{ID: 2, Outcome: push.Release, Error: "Tidak bisa menghubungi Firebase", RetryAfter: 500 * time.Millisecond},
		{ID: 3, Outcome: push.Release, Error: "Tidak bisa menghubungi Firebase", RetryAfter: 500 * time.Millisecond},
	}
	if !reflect.DeepEqual(reports[0], want) {
		t.Fatalf("report = %+v", reports[0])
	}
	if got := sender.attempted(); !reflect.DeepEqual(got, []int64{1, 2}) {
		t.Fatalf("attempted = %v", got)
	}
	eventually(t, "a heartbeat with the error", func() bool { return lastBeat(store).Error == "Tidak bisa menghubungi Firebase" })
	if beat := lastBeat(store); !beat.Configured {
		t.Fatalf("beat = %+v", beat)
	}
	if snapshot := w.Metrics(); snapshot.Healthy || snapshot.Pushes[push.Release] != 2 {
		t.Fatalf("metrics = %+v", snapshot)
	}

	time.Sleep(200 * time.Millisecond)
	if claims, _, _ := store.state(); claims != 1 {
		t.Fatalf("claims during the pause = %d", claims)
	}
	eventually(t, "claiming again after the pause", func() bool {
		claims, _, _ := store.state()
		return claims > 1
	})
}

func TestWorkerClearsTheErrorAfterASuccessfulSend(t *testing.T) {
	store := &fakeStore{batches: [][]push.Job{jobs(1)}}
	sender := newSender(configured, func(_ context.Context, job push.Job) push.Delivery {
		if job.ID == 1 {
			return outage
		}
		return delivered
	})
	w := newWorker(store, sender, nil)
	w.pauseMin = 50 * time.Millisecond
	start(t, w)

	eventually(t, "the error heartbeat", sawError(store, "Tidak bisa menghubungi Firebase"))
	store.enqueue(jobs(2))
	eventually(t, "two reports", func() bool {
		_, reports, _ := store.state()
		return len(reports) == 2
	})
	eventually(t, "the error to clear", func() bool { return lastBeat(store).Error == "" })
	_, reports, _ := store.state()
	if reports[1][0] != (push.Result{ID: 2, Outcome: push.Sent}) {
		t.Fatalf("reports = %+v", reports)
	}
	if !w.Metrics().Healthy {
		t.Fatalf("metrics = %+v", w.Metrics())
	}
}

func TestWorkerReportsNonSystemicProblemsWithoutPausing(t *testing.T) {
	store := &fakeStore{batches: [][]push.Job{jobs(1)}}
	problem := "Firebase ditolak APNs/Web Push (periksa sertifikat atau kunci APNs di Firebase)"
	sender := newSender(configured, func(_ context.Context, job push.Job) push.Delivery {
		if job.ID == 1 {
			return push.Delivery{Result: push.Result{Outcome: push.Failed, Error: "Auth error from APNS"}, Problem: problem}
		}
		return delivered
	})
	w := newWorker(store, sender, nil)
	w.pauseMin = time.Hour
	start(t, w)

	eventually(t, "the problem heartbeat", sawError(store, problem))
	if w.Metrics().Healthy {
		t.Fatal("a reported problem must mark the notifier unhealthy")
	}
	store.enqueue(jobs(2))
	eventually(t, "the next batch without a pause", func() bool {
		_, reports, _ := store.state()
		return len(reports) == 2
	})
	eventually(t, "the error to clear", func() bool { return lastBeat(store).Error == "" })
}

func TestWorkerDoesNotClaimWithoutUsableCredentials(t *testing.T) {
	cases := []struct {
		name   string
		status push.Status
	}{
		{"not configured", push.Status{}},
		{"unusable credentials", push.Status{Configured: true, Problem: "Ada lebih dari satu file .json di folder kredensial Firebase"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			store := &fakeStore{batches: [][]push.Job{jobs(1)}}
			sender := newSender(tc.status, always(delivered))
			w := newWorker(store, sender, func(o *Options) { o.HeartbeatInterval = 20 * time.Millisecond })
			start(t, w)

			eventually(t, "periodic heartbeats", func() bool {
				_, _, beats := store.state()
				return len(beats) >= 3
			})
			claims, _, beats := store.state()
			if claims != 0 {
				t.Fatalf("claims = %d", claims)
			}
			for _, beat := range beats {
				if beat.Configured != tc.status.Configured || beat.Error != tc.status.Problem || beat.ProjectID != "" {
					t.Fatalf("beat = %+v", beat)
				}
			}
			if snapshot := w.Metrics(); snapshot.Healthy || snapshot.Configured != tc.status.Configured {
				t.Fatalf("metrics = %+v", snapshot)
			}

			sender.setStatus(configured)
			eventually(t, "a configured heartbeat", func() bool {
				beat := lastBeat(store)
				return beat.Configured && beat.Error == "" && beat.ProjectID == "demo-project"
			})
			eventually(t, "delivery to start", reportCount(store))
		})
	}
}

func TestWorkerSendsAHeartbeatAsSoonAsCredentialsChange(t *testing.T) {
	store := &fakeStore{}
	sender := newSender(push.Status{}, always(delivered))
	start(t, newWorker(store, sender, nil))

	eventually(t, "the first heartbeat", func() bool {
		_, _, beats := store.state()
		return len(beats) == 1
	})
	sender.setStatus(configured)
	eventually(t, "a heartbeat for the new credentials", func() bool {
		_, _, beats := store.state()
		return len(beats) == 2 && beats[1].Configured
	})
}

func TestWorkerFinishesTheInFlightBatchOnShutdown(t *testing.T) {
	store := &fakeStore{batches: [][]push.Job{jobs(1, 2)}}
	release := make(chan struct{})
	started := make(chan struct{}, 2)
	sender := newSender(configured, func(_ context.Context, job push.Job) push.Delivery {
		started <- struct{}{}
		<-release
		return delivered
	})
	cancel, done := start(t, newWorker(store, sender, nil))

	<-started
	cancel()
	select {
	case <-done:
		t.Fatal("Run returned before the in-flight batch finished")
	case <-time.After(100 * time.Millisecond):
	}
	close(release)
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("Run did not return after the batch finished")
	}
	claims, reports, _ := store.state()
	want := []push.Result{{ID: 1, Outcome: push.Sent}, {ID: 2, Outcome: push.Sent}}
	if claims != 1 || len(reports) != 1 || !reflect.DeepEqual(reports[0], want) {
		t.Fatalf("claims = %d reports = %+v", claims, reports)
	}
}

func TestWorkerAbandonsSendsAfterTheShutdownTimeout(t *testing.T) {
	store := &fakeStore{batches: [][]push.Job{jobs(1, 2, 3)}}
	started := make(chan struct{}, 3)
	stopped := push.Delivery{Result: push.Result{Outcome: push.Release, Error: "Pengiriman dihentikan karena notifier berhenti", RetryAfter: time.Second}}
	sender := newSender(configured, func(ctx context.Context, job push.Job) push.Delivery {
		started <- struct{}{}
		<-ctx.Done()
		return stopped
	})
	cancel, done := start(t, newWorker(store, sender, func(o *Options) {
		o.Concurrency = 1
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
	_, reports, _ := store.state()
	want := []push.Result{
		{ID: 1, Outcome: push.Release, Error: "Pengiriman dihentikan karena notifier berhenti", RetryAfter: time.Second},
		{ID: 2, Outcome: push.Release, Error: errorNotSent, RetryAfter: time.Second},
		{ID: 3, Outcome: push.Release, Error: errorNotSent, RetryAfter: time.Second},
	}
	if len(reports) != 1 || !reflect.DeepEqual(reports[0], want) {
		t.Fatalf("reports = %+v", reports)
	}
}

func TestWorkerClaimsAgainRightAwayAfterAFullBatch(t *testing.T) {
	store := &fakeStore{batches: [][]push.Job{jobs(1, 2), jobs(3)}}
	start(t, newWorker(store, newSender(configured, always(delivered)), func(o *Options) {
		o.BatchSize = 2
		o.PollInterval = time.Hour
	}))

	eventually(t, "the second batch", func() bool {
		_, reports, _ := store.state()
		return len(reports) == 2
	})
	time.Sleep(50 * time.Millisecond)
	if claims, _, _ := store.state(); claims != 2 {
		t.Fatalf("a partial batch must wait for the poll interval, claims = %d", claims)
	}
}

func TestWorkerStopsStartingSendsBeforeTheLeaseEnds(t *testing.T) {
	store := &fakeStore{batches: [][]push.Job{jobs(1, 2)}}
	sender := newSender(configured, func(context.Context, push.Job) push.Delivery {
		time.Sleep(300 * time.Millisecond)
		return delivered
	})
	start(t, newWorker(store, sender, func(o *Options) {
		o.Concurrency = 1
		o.SendTimeout = 0
		o.Lease = leaseMargin + 150*time.Millisecond
	}))

	eventually(t, "a report", reportCount(store))
	_, reports, _ := store.state()
	want := []push.Result{{ID: 1, Outcome: push.Sent}, {ID: 2, Outcome: push.Release, Error: errorNotSent, RetryAfter: time.Second}}
	if !reflect.DeepEqual(reports[0], want) {
		t.Fatalf("report = %+v", reports[0])
	}
}

func TestWorkerRetriesTheReport(t *testing.T) {
	store := &fakeStore{batches: [][]push.Job{jobs(1)}, reportFails: 3}
	start(t, newWorker(store, newSender(configured, always(delivered)), nil))

	eventually(t, "a report", reportCount(store))
	if calls := store.reportAttempts(); calls != 4 {
		t.Fatalf("report calls = %d", calls)
	}
}

func TestWorkerMovesOnWhenTheReportKeepsFailing(t *testing.T) {
	store := &fakeStore{batches: [][]push.Job{jobs(1), jobs(2)}, reportFails: 4}
	start(t, newWorker(store, newSender(configured, always(delivered)), nil))

	eventually(t, "the next batch", reportCount(store))
	_, reports, _ := store.state()
	if calls := store.reportAttempts(); reports[0][0].ID != 2 || calls != 5 {
		t.Fatalf("reports = %+v calls = %d", reports, calls)
	}
}

func TestWorkerBacksOffWhileClaimsFail(t *testing.T) {
	store := &fakeStore{batches: [][]push.Job{jobs(1)}, claimErr: errors.New("rpc push_claim: status 503")}
	start(t, newWorker(store, newSender(configured, always(delivered)), nil))

	time.Sleep(300 * time.Millisecond)
	claims, _, _ := store.state()
	if claims < 2 || claims > 15 {
		t.Fatalf("claims while PostgREST is down = %d", claims)
	}
	store.setClaimErr(nil)
	eventually(t, "recovery", reportCount(store))
}
