package healer

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"net/http"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/healer/internal/docker"
	"olt-social/healer/internal/state"
)

const project = "olt-social"

type box struct {
	id, name, service, health string
	project                   string
	autoheal, running         bool
	started                   time.Time
}

type fakeDocker struct {
	mu         sync.Mutex
	boxes      []*box
	restarted  []string
	listErr    error
	restartErr error
	inspects   int
	clock      *time.Time
}

func (f *fakeDocker) List(_ context.Context, labels ...string) ([]docker.Container, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.listErr != nil {
		return nil, f.listErr
	}
	if len(labels) != 1 || !strings.HasPrefix(labels[0], docker.ProjectLabel+"=") {
		panic("unexpected filter " + strings.Join(labels, ","))
	}
	want := strings.TrimPrefix(labels[0], docker.ProjectLabel+"=")
	var out []docker.Container
	for _, b := range f.boxes {
		if b.project != want || !b.running {
			continue
		}
		out = append(out, docker.Container{ID: b.id, Name: b.name, Service: b.service, Labels: b.labels()})
	}
	return out, nil
}

func (b *box) labels() map[string]string {
	l := map[string]string{docker.ProjectLabel: b.project, docker.ServiceLabel: b.service}
	if b.autoheal {
		l[AutohealLabel] = "true"
	}
	return l
}

func (f *fakeDocker) Inspect(_ context.Context, id string) (docker.Detail, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.inspects++
	for _, b := range f.boxes {
		if b.id == id || (len(id) >= 12 && strings.HasPrefix(b.id, id)) {
			return docker.Detail{ID: b.id, Name: b.name, Service: b.service, Labels: b.labels(), Running: b.running,
				Health: b.health, StartedAt: b.started, Output: "exit 1"}, nil
		}
	}
	return docker.Detail{}, &docker.Error{Op: "inspect", Status: http.StatusNotFound}
}

func (f *fakeDocker) Restart(_ context.Context, id string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.restarted = append(f.restarted, id)
	if f.restartErr != nil {
		return f.restartErr
	}
	for _, b := range f.boxes {
		if b.id == id {
			b.started = *f.clock
			b.health = "starting"
		}
	}
	return nil
}

func (f *fakeDocker) set(id, health string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, b := range f.boxes {
		if b.id == id {
			b.health = health
		}
	}
}

func (f *fakeDocker) restarts() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.restarted)
}

type env struct {
	h     *Healer
	d     *fakeDocker
	now   time.Time
	saved []state.State
	logs  *bytes.Buffer
}

func id(n string) string {
	return strings.Repeat(n, 64)[:64]
}

func newEnv(t *testing.T, mutate func(*Options)) *env {
	t.Helper()
	e := &env{now: time.Date(2026, 11, 4, 10, 0, 0, 0, time.UTC), logs: &bytes.Buffer{}}
	start := e.now.Add(-time.Hour)
	e.d = &fakeDocker{clock: &e.now, boxes: []*box{
		{id: id("a"), name: "olt-social-db-1", service: "db", health: "healthy", project: project, running: true, started: start},
		{id: id("b"), name: "olt-social-pgbouncer-1", service: "pgbouncer", health: "healthy", project: project, autoheal: true, running: true, started: start},
		{id: id("c"), name: "olt-social-rest-1", service: "rest", health: "healthy", project: project, autoheal: true, running: true, started: start},
		{id: id("d"), name: "olt-social-auth-1", service: "auth", health: "healthy", project: project, autoheal: true, running: true, started: start},
		{id: id("e"), name: "olt-social-kong-1", service: "kong", health: "healthy", project: project, autoheal: true, running: true, started: start},
		{id: id("f"), name: "olt-social-media-1", service: "media", health: "healthy", project: project, autoheal: true, running: true, started: start},
		{id: id("1"), name: "olt-social-valkey-1", service: "valkey", health: "unhealthy", project: project, running: true, started: start},
		{id: id("2"), name: "chatstack-api-1", service: "api", health: "unhealthy", project: "chatstack", autoheal: true, running: true, started: start},
		{id: id("9"), name: "olt-social-healer-1", service: "healer", health: "healthy", project: project, running: true, started: start},
	}}
	opts := Options{
		Docker:           e.d,
		Log:              slog.New(slog.NewJSONHandler(e.logs, nil)),
		Hostname:         id("9")[:12],
		Enabled:          true,
		Interval:         10 * time.Second,
		UnhealthyFor:     60 * time.Second,
		MinUptime:        120 * time.Second,
		MaxRestarts:      3,
		GlobalCooldown:   30 * time.Second,
		SystemicFraction: 0.5,
		Version:          "0.1.0",
		StartedAt:        e.now,
		StateFile:        "/var/lib/olt-healer/state.json",
		Save: func(_ string, s state.State) error {
			e.saved = append(e.saved, s)
			return nil
		},
		Now: func() time.Time { return e.now },
	}
	if mutate != nil {
		mutate(&opts)
	}
	e.h = New(opts)
	return e
}

func (e *env) cycle(advance time.Duration) state.State {
	e.now = e.now.Add(advance)
	e.h.Cycle(context.Background())
	return e.saved[len(e.saved)-1]
}

func (e *env) runFor(total, step time.Duration) {
	for elapsed := time.Duration(0); elapsed < total; elapsed += step {
		e.cycle(step)
	}
}

func actions(s state.State) []string {
	var out []string
	for _, ev := range s.Events {
		out = append(out, ev.Action+":"+ev.Service+":"+ev.Result)
	}
	return out
}

func TestResolvesProjectFromOwnContainerAndIgnoresOtherProjects(t *testing.T) {
	e := newEnv(t, nil)
	s := e.cycle(0)
	if s.Project != project || s.Error != "" {
		t.Fatalf("state = %+v", s)
	}
	if s.Watched != 5 {
		t.Fatalf("watched = %d, want 5 labeled containers of the project", s.Watched)
	}
	if len(s.Unhealthy) != 0 {
		t.Fatalf("unhealthy = %+v; valkey has no label and chatstack is another project", s.Unhealthy)
	}
	if !strings.Contains(e.logs.String(), "Watching compose project") {
		t.Fatalf("logs = %s", e.logs.String())
	}
}

func TestExplicitProjectWinsOverOwnLabel(t *testing.T) {
	e := newEnv(t, func(o *Options) {
		o.Project = "chatstack"
		o.Hostname = ""
	})
	e.h.Cycle(context.Background())
	if len(e.saved) == 0 || e.saved[0].Project != "chatstack" || e.saved[0].Watched != 1 {
		t.Fatalf("saved = %+v", e.saved)
	}
}

func TestRestartsOnlyAfterBothThresholds(t *testing.T) {
	e := newEnv(t, nil)
	for _, b := range e.d.boxes {
		if b.service == "rest" {
			b.started = e.now.Add(-30 * time.Second)
		}
	}
	e.d.set(id("c"), "unhealthy")
	e.cycle(0)
	e.runFor(50*time.Second, 10*time.Second)
	if got := e.d.restarts(); len(got) != 0 {
		t.Fatalf("restarted after 50s unhealthy and 80s uptime: %v", got)
	}
	e.runFor(30*time.Second, 10*time.Second)
	if got := e.d.restarts(); len(got) != 0 {
		t.Fatalf("restarted before 120s uptime: %v", got)
	}
	s := e.cycle(10 * time.Second)
	if got := e.d.restarts(); !slices.Equal(got, []string{id("c")}) {
		t.Fatalf("restarts = %v", got)
	}
	last := s.Events[len(s.Events)-1]
	if last.Action != state.ActionRestart || last.Result != state.ResultOK || last.Service != "rest" ||
		last.Container != "olt-social-rest-1" || last.Reason != state.ReasonUnhealthy ||
		!strings.HasPrefix(last.Detail, "unhealthy 90s, uptime 120s: exit 1") || last.ID == "" {
		t.Fatalf("event = %+v", last)
	}
	if len(s.Unhealthy) != 0 {
		t.Fatalf("restarted container still listed as unhealthy: %+v", s.Unhealthy)
	}
}

func TestUnhealthyTimerResetsWhenContainerRecovers(t *testing.T) {
	e := newEnv(t, nil)
	e.d.set(id("c"), "unhealthy")
	e.cycle(0)
	e.cycle(50 * time.Second)
	e.d.set(id("c"), "healthy")
	e.cycle(5 * time.Second)
	e.d.set(id("c"), "unhealthy")
	e.cycle(5 * time.Second)
	e.cycle(50 * time.Second)
	if got := e.d.restarts(); len(got) != 0 {
		t.Fatalf("restarted although the unhealthy streak was broken: %v", got)
	}
	e.cycle(10 * time.Second)
	if got := e.d.restarts(); len(got) != 1 {
		t.Fatalf("restarts = %v", got)
	}
}

func TestGivesUpAfterMaxRestartsPerHourAndRetriesAfterTheWindow(t *testing.T) {
	e := newEnv(t, nil)
	e.d.set(id("c"), "unhealthy")
	var s state.State
	for range 3 {
		e.cycle(0)
		e.d.set(id("c"), "unhealthy")
		e.runFor(130*time.Second, 10*time.Second)
	}
	if got := e.d.restarts(); len(got) != 3 {
		t.Fatalf("restarts = %v", got)
	}
	e.d.set(id("c"), "unhealthy")
	e.runFor(130*time.Second, 10*time.Second)
	s = e.saved[len(e.saved)-1]
	if got := e.d.restarts(); len(got) != 3 {
		t.Fatalf("fourth restart within an hour: %v", got)
	}
	if len(s.GaveUp) != 1 || s.GaveUp[0].Service != "rest" || s.GaveUp[0].Restarts != 3 {
		t.Fatalf("gave up = %+v", s.GaveUp)
	}
	first := s.Events[0].At
	if !s.GaveUp[0].Until.Equal(first.Add(time.Hour)) {
		t.Fatalf("until = %v, want first restart %v + 1h", s.GaveUp[0].Until, first)
	}
	gaveUp := 0
	for _, ev := range s.Events {
		if ev.Action == state.ActionGiveUp {
			gaveUp++
			if ev.Reason != state.ReasonRestartLimit || ev.Result != state.ResultGaveUp || ev.Service != "rest" {
				t.Fatalf("give up event = %+v", ev)
			}
		}
	}
	if gaveUp != 1 {
		t.Fatalf("give up events = %d, want exactly one: %v", gaveUp, actions(s))
	}
	if !strings.Contains(e.logs.String(), "Giving up on an unhealthy service") {
		t.Fatal("give up is not logged")
	}
	e.now = s.GaveUp[0].Until.Add(-time.Second)
	e.cycle(0)
	if len(e.d.restarts()) != 3 {
		t.Fatal("restarted before the window passed")
	}
	s = e.cycle(2 * time.Second)
	if got := e.d.restarts(); len(got) != 4 {
		t.Fatalf("restarts after window = %v", got)
	}
	if len(s.GaveUp) != 0 {
		t.Fatalf("still gave up after the window: %+v", s.GaveUp)
	}
}

func TestGiveUpClearsWhenTheServiceIsGone(t *testing.T) {
	e := newEnv(t, nil)
	e.h.st.GaveUp = []state.GaveUp{{Service: "rest", Since: e.now, Until: e.now.Add(time.Hour), Restarts: 3}}
	e.d.set(id("c"), "unhealthy")
	s := e.cycle(0)
	if len(s.GaveUp) != 1 {
		t.Fatalf("gave up = %+v", s.GaveUp)
	}
	e.d.boxes[2].running = false
	s = e.cycle(10 * time.Second)
	if len(s.GaveUp) != 0 {
		t.Fatalf("gave up kept for a removed container: %+v", s.GaveUp)
	}
}

func TestGlobalCooldownSpacesRestartsAcrossServices(t *testing.T) {
	e := newEnv(t, nil)
	e.d.set(id("c"), "unhealthy")
	e.cycle(0)
	e.cycle(10 * time.Second)
	e.d.set(id("d"), "unhealthy")
	e.runFor(60*time.Second, 10*time.Second)
	if got := e.d.restarts(); !slices.Equal(got, []string{id("c")}) {
		t.Fatalf("restarts = %v", got)
	}
	e.cycle(10 * time.Second)
	if got := e.d.restarts(); len(got) != 1 {
		t.Fatalf("second restart inside the 30s cooldown: %v", got)
	}
	e.runFor(20*time.Second, 10*time.Second)
	if got := e.d.restarts(); !slices.Equal(got, []string{id("c"), id("d")}) {
		t.Fatalf("restarts = %v", got)
	}
}

func TestSkipsEverythingWhileTheDatabaseIsUnhealthy(t *testing.T) {
	e := newEnv(t, nil)
	e.d.set(id("a"), "unhealthy")
	e.d.set(id("c"), "unhealthy")
	e.cycle(0)
	e.runFor(200*time.Second, 10*time.Second)
	s := e.saved[len(e.saved)-1]
	if got := e.d.restarts(); len(got) != 0 {
		t.Fatalf("restarted while db is unhealthy: %v", got)
	}
	if s.Skip == nil || s.Skip.Reason != state.ReasonDB || !slices.Equal(s.Skip.Services, []string{"rest"}) {
		t.Fatalf("skip = %+v", s.Skip)
	}
	if got := actions(s); !slices.Equal(got, []string{"skip::skipped"}) {
		t.Fatalf("events = %v, want a single skip event", got)
	}
	e.d.set(id("a"), "healthy")
	s = e.cycle(10 * time.Second)
	if s.Skip != nil {
		t.Fatalf("skip kept after db recovered: %+v", s.Skip)
	}
	if got := e.d.restarts(); !slices.Equal(got, []string{id("c")}) {
		t.Fatalf("restarts after recovery = %v", got)
	}
}

func TestMissingDatabaseContainerBlocksRestarts(t *testing.T) {
	e := newEnv(t, nil)
	e.d.boxes[0].running = false
	e.d.set(id("c"), "unhealthy")
	e.cycle(0)
	s := e.cycle(200 * time.Second)
	if len(e.d.restarts()) != 0 || s.Skip == nil || s.Skip.Reason != state.ReasonDB {
		t.Fatalf("restarts = %v skip = %+v", e.d.restarts(), s.Skip)
	}
}

func TestOnlyPgBouncerIsRestartedWhilePgBouncerIsUnhealthy(t *testing.T) {
	e := newEnv(t, nil)
	e.d.set(id("b"), "unhealthy")
	e.d.set(id("c"), "unhealthy")
	e.d.set(id("d"), "unhealthy")
	e.d.set(id("e"), "unhealthy")
	e.cycle(0)
	s := e.cycle(70 * time.Second)
	if got := e.d.restarts(); !slices.Equal(got, []string{id("b")}) {
		t.Fatalf("restarts = %v, want only pgbouncer", got)
	}
	if s.Skip == nil || s.Skip.Reason != state.ReasonPgBouncer || !slices.Equal(s.Skip.Services, []string{"auth", "kong", "rest"}) {
		t.Fatalf("skip = %+v", s.Skip)
	}
}

func TestSystemicOutageSkipsAllRestarts(t *testing.T) {
	e := newEnv(t, nil)
	e.d.set(id("c"), "unhealthy")
	e.d.set(id("d"), "unhealthy")
	e.d.set(id("e"), "unhealthy")
	e.cycle(0)
	s := e.cycle(200 * time.Second)
	if len(e.d.restarts()) != 0 {
		t.Fatalf("restarted during a systemic outage: %v", e.d.restarts())
	}
	if s.Skip == nil || s.Skip.Reason != state.ReasonSystemic || len(s.Skip.Services) != 3 {
		t.Fatalf("skip = %+v", s.Skip)
	}
	if !strings.Contains(e.logs.String(), "Holding back restarts") {
		t.Fatal("skip is not logged")
	}
}

func TestSingleUnhealthyServiceIsNeverSystemic(t *testing.T) {
	e := newEnv(t, func(o *Options) { o.SystemicFraction = 0.1 })
	e.d.set(id("c"), "unhealthy")
	e.cycle(0)
	e.cycle(130 * time.Second)
	if len(e.d.restarts()) != 1 {
		t.Fatalf("restarts = %v", e.d.restarts())
	}
}

func TestReportOnlyModeRecordsOnceAndNeverRestarts(t *testing.T) {
	e := newEnv(t, func(o *Options) { o.Enabled = false })
	e.d.set(id("c"), "unhealthy")
	e.cycle(0)
	e.runFor(400*time.Second, 10*time.Second)
	s := e.saved[len(e.saved)-1]
	if len(e.d.restarts()) != 0 {
		t.Fatalf("restarted in report-only mode: %v", e.d.restarts())
	}
	if s.Enabled {
		t.Fatal("state says enabled")
	}
	if got := actions(s); !slices.Equal(got, []string{"report:rest:report_only"}) {
		t.Fatalf("events = %v", got)
	}
}

func TestFailedRestartCountsAndIsRecorded(t *testing.T) {
	e := newEnv(t, nil)
	e.d.restartErr = errors.New("docker restart: status 500: cannot kill container")
	e.d.set(id("c"), "unhealthy")
	e.cycle(0)
	s := e.cycle(130 * time.Second)
	last := s.Events[len(s.Events)-1]
	if last.Result != state.ResultFailed || !strings.Contains(last.Error, "cannot kill container") {
		t.Fatalf("event = %+v", last)
	}
	if got := e.h.restartsSince("rest", e.now.Add(-time.Hour)); len(got) != 1 {
		t.Fatalf("failed restart not counted: %v", got)
	}
}

func TestDockerErrorsAreReportedInTheState(t *testing.T) {
	e := newEnv(t, nil)
	e.cycle(0)
	e.d.listErr = &docker.Error{Op: "list", Err: errors.New("dial unix /var/run/docker.sock: permission denied")}
	s := e.cycle(10 * time.Second)
	if !strings.Contains(s.Error, "permission denied") || !s.CheckedAt.Equal(e.now) || s.Watched != 5 {
		t.Fatalf("state = %+v", s)
	}
	e.cycle(10 * time.Second)
	if n := strings.Count(e.logs.String(), "Cannot read container state"); n != 1 {
		t.Fatalf("docker error logged %d times", n)
	}
	e.d.listErr = nil
	s = e.cycle(10 * time.Second)
	if s.Error != "" || !strings.Contains(e.logs.String(), "Docker is reachable again") {
		t.Fatalf("state = %+v", s)
	}
}

func TestUnknownProjectIsAnError(t *testing.T) {
	e := newEnv(t, func(o *Options) { o.Hostname = "" })
	s := e.cycle(0)
	if !strings.Contains(s.Error, "HEALER_PROJECT") || len(e.d.restarts()) != 0 {
		t.Fatalf("state = %+v", s)
	}
}

func TestHistoryFromThePreviousRunIsKept(t *testing.T) {
	now := time.Date(2026, 11, 4, 10, 0, 0, 0, time.UTC)
	var events []state.Event
	for i := 3; i >= 1; i-- {
		events = append(events, state.Event{ID: "x", At: now.Add(-time.Duration(i) * 10 * time.Minute), Service: "rest", Action: state.ActionRestart, Result: state.ResultOK})
	}
	e := newEnv(t, func(o *Options) {
		o.Initial = state.State{Project: project, Events: events, Skip: &state.Skip{Reason: state.ReasonSystemic}}
	})
	if !e.h.lastRestart.Equal(now.Add(-10 * time.Minute)) {
		t.Fatalf("last restart = %v", e.h.lastRestart)
	}
	e.d.set(id("c"), "unhealthy")
	e.cycle(0)
	s := e.cycle(130 * time.Second)
	if len(e.d.restarts()) != 0 || len(s.GaveUp) != 1 {
		t.Fatalf("restarts = %v gave up = %+v", e.d.restarts(), s.GaveUp)
	}
	if s.Skip != nil {
		t.Fatalf("old skip survived the restart: %+v", s.Skip)
	}
}

func TestHistoryOfAnotherProjectIsDropped(t *testing.T) {
	e := newEnv(t, func(o *Options) {
		o.Initial = state.State{Project: "other", Events: []state.Event{{ID: "x", At: time.Now(), Service: "rest", Action: state.ActionRestart}}}
	})
	s := e.cycle(0)
	if len(s.Events) != 0 {
		t.Fatalf("events = %+v", s.Events)
	}
}

func TestSaveFailuresAreLoggedOnce(t *testing.T) {
	e := newEnv(t, nil)
	e.h.save = func(string, state.State) error { return errors.New("read-only file system") }
	e.h.Cycle(context.Background())
	e.h.Cycle(context.Background())
	if n := strings.Count(e.logs.String(), "Could not write the state file"); n != 1 {
		t.Fatalf("save failure logged %d times", n)
	}
	e.h.save = func(string, state.State) error { return nil }
	e.h.Cycle(context.Background())
	if !strings.Contains(e.logs.String(), "State file can be written again") {
		t.Fatal("recovery not logged")
	}
}

func TestRunStopsWithTheContext(t *testing.T) {
	e := newEnv(t, nil)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		e.h.Run(ctx)
		close(done)
	}()
	cancel()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("Run did not stop")
	}
}
