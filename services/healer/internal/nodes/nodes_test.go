package nodes

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"olt-social/healer/internal/docker"
)

type fakeDocker struct {
	mu       sync.Mutex
	list     []docker.Summary
	listErr  error
	status   map[string]docker.Status
	usage    map[string]docker.Usage
	gone     map[string]bool
	labels   map[string]string
	inspects int
}

func (f *fakeDocker) ListAll(_ context.Context, labels ...string) ([]docker.Summary, error) {
	if len(labels) != 1 || labels[0] != docker.ProjectLabel+"=olt-social" {
		return nil, errors.New("unexpected labels")
	}
	return f.list, f.listErr
}

func (f *fakeDocker) Status(_ context.Context, id string) (docker.Status, error) {
	if f.gone[id] {
		return docker.Status{}, &docker.Error{Op: "inspect", Status: http.StatusNotFound}
	}
	return f.status[id], nil
}

func (f *fakeDocker) Usage(_ context.Context, id string) (docker.Usage, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.usage[id], nil
}

func (f *fakeDocker) Info(context.Context) (docker.Info, error) {
	return docker.Info{Name: "srv-1", CPUs: 8, Memory: 32 << 30, OS: "Ubuntu", ServerVersion: "28.1.1"}, nil
}

func (f *fakeDocker) Inspect(_ context.Context, _ string) (docker.Detail, error) {
	f.inspects++
	return docker.Detail{Labels: f.labels}, nil
}

func (f *fakeDocker) setUsage(id string, u docker.Usage) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.usage[id] = u
}

func id(c string) string {
	return c + "f1c0b7e9a2d4c5b6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5"
}

func observer(t *testing.T, f *fakeDocker, project string) (*Observer, string) {
	t.Helper()
	file := filepath.Join(t.TempDir(), "nodes.json")
	now := time.Date(2026, 11, 16, 3, 0, 0, 0, time.UTC)
	return New(Options{
		Docker:   f,
		Log:      slog.New(slog.NewTextHandler(io.Discard, nil)),
		Project:  project,
		Hostname: "abc123",
		Interval: 10 * time.Second,
		File:     file,
		Version:  "0.2.0",
		Now:      func() time.Time { return now },
	}), file
}

func fixture() *fakeDocker {
	started := time.Date(2026, 11, 16, 1, 0, 0, 0, time.UTC)
	return &fakeDocker{
		list: []docker.Summary{
			{ID: id("2"), Name: "olt-social-rest-2", Service: "rest", Number: 2, State: "running", Labels: map[string]string{"olt.autoheal": "true"}},
			{ID: id("1"), Name: "olt-social-rest-1", Service: "rest", Number: 1, State: "running", Labels: map[string]string{"olt.autoheal": "true"}},
			{ID: id("3"), Name: "olt-social-trade-relay-1", Service: "trade-relay", Number: 1, State: "exited", Labels: map[string]string{}},
			{ID: id("4"), Name: "olt-social-migrate-1", Service: "migrate", Number: 1, State: "exited", Labels: map[string]string{}},
		},
		status: map[string]docker.Status{
			id("1"): {State: "running", Running: true, Health: "healthy", StartedAt: started, Image: "postgrest/postgrest:v13", RestartCount: 1},
			id("2"): {State: "running", Running: true, Health: "starting", StartedAt: started, Image: "postgrest/postgrest:v13"},
			id("3"): {State: "exited", ExitCode: 0, StartedAt: started, FinishedAt: started.Add(time.Hour), Image: "olt-social/trade-relay:0.1.0"},
		},
		usage: map[string]docker.Usage{
			id("1"): {CPUTotal: 1000, SystemTotal: 100000, OnlineCPUs: 8, Memory: 64 << 20, MemoryLimit: 512 << 20},
			id("2"): {CPUTotal: 2000, SystemTotal: 100000, OnlineCPUs: 8, Memory: 32 << 20, MemoryLimit: 512 << 20},
		},
		gone: map[string]bool{id("4"): true},
	}
}

func TestCycleListsEveryContainerSortedWithHostAndLifecycle(t *testing.T) {
	f := fixture()
	o, file := observer(t, f, "olt-social")
	r := o.Cycle(context.Background())
	if r.Error != "" || r.Project != "olt-social" || r.Host.Name != "srv-1" || r.Host.CPUs != 8 {
		t.Fatalf("report = %+v", r)
	}
	if len(r.Containers) != 3 {
		t.Fatalf("containers = %+v", r.Containers)
	}
	a, b, relay := r.Containers[0], r.Containers[1], r.Containers[2]
	if a.Name != "olt-social-rest-1" || a.Replica != 1 || a.Health != "healthy" || a.Restarts != 1 || !a.Autoheal || a.Host != "srv-1" ||
		a.MemoryBytes == nil || *a.MemoryBytes != 64<<20 || a.MemoryLimitBytes == nil || a.CPUPercent != nil {
		t.Fatalf("rest-1 = %+v", a)
	}
	if b.Name != "olt-social-rest-2" || b.Health != "starting" {
		t.Fatalf("rest-2 = %+v", b)
	}
	if relay.Service != "trade-relay" || relay.State != "exited" || relay.FinishedAt == nil || relay.MemoryBytes != nil || relay.Autoheal {
		t.Fatalf("relay = %+v", relay)
	}
	var onDisk Report
	data, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(data, &onDisk); err != nil || len(onDisk.Containers) != 3 || onDisk.Version != "0.2.0" {
		t.Fatalf("file = %s err = %v", data, err)
	}
}

func TestCPUPercentComesFromTheDeltaBetweenCycles(t *testing.T) {
	f := fixture()
	o, _ := observer(t, f, "olt-social")
	o.Cycle(context.Background())
	f.setUsage(id("1"), docker.Usage{CPUTotal: 3000, SystemTotal: 116000, OnlineCPUs: 8, Memory: 64 << 20})
	f.setUsage(id("2"), docker.Usage{CPUTotal: 1000, SystemTotal: 116000, OnlineCPUs: 8, Memory: 32 << 20})
	r := o.Cycle(context.Background())
	if r.Containers[0].CPUPercent == nil || *r.Containers[0].CPUPercent != 100 {
		t.Fatalf("rest-1 cpu = %v", r.Containers[0].CPUPercent)
	}
	if r.Containers[1].CPUPercent != nil {
		t.Fatalf("a counter that went backwards (container restarted) must not produce a value: %v", *r.Containers[1].CPUPercent)
	}
}

func TestListFailureIsRecordedAndStillWritten(t *testing.T) {
	f := fixture()
	f.listErr = errors.New("docker list: dial unix /var/run/docker.sock: connect: permission denied")
	o, file := observer(t, f, "olt-social")
	r := o.Cycle(context.Background())
	if r.Error == "" || len(r.Containers) != 0 {
		t.Fatalf("report = %+v", r)
	}
	if _, err := os.Stat(file); err != nil {
		t.Fatalf("file not written: %v", err)
	}
}

func TestProjectComesFromTheOwnContainerLabel(t *testing.T) {
	f := fixture()
	f.labels = map[string]string{docker.ProjectLabel: "olt-social"}
	o, _ := observer(t, f, "")
	r := o.Cycle(context.Background())
	o.Cycle(context.Background())
	if r.Project != "olt-social" || len(r.Containers) != 3 || f.inspects != 1 {
		t.Fatalf("project = %q containers = %d inspects = %d", r.Project, len(r.Containers), f.inspects)
	}
}

func TestMissingProjectLabelIsAnError(t *testing.T) {
	f := fixture()
	f.labels = map[string]string{}
	o, _ := observer(t, f, "")
	if r := o.Cycle(context.Background()); r.Error == "" {
		t.Fatalf("report = %+v", r)
	}
}
