package nodes

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type fakeStore struct {
	sent []Report
	err  error
}

func (f *fakeStore) NodesReport(_ context.Context, instance string, r Report) error {
	if instance != "sentinel-1" {
		return errors.New("unexpected instance")
	}
	if f.err != nil {
		return f.err
	}
	f.sent = append(f.sent, r)
	return nil
}

func writeFile(t *testing.T, path, body string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestReadSanitizesTheHealerFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nodes.json")
	long := strings.Repeat("x", 500)
	writeFile(t, path, `{"version":"0.2.0","project":"olt-social","checked_at":"2026-11-16T03:00:00Z",
		"host":{"name":"srv-1","cpus":8,"memory_bytes":34359738368},
		"containers":[{"service":"rest","name":"olt-social-rest-1","replica":1,"state":"running","health":"healthy","image":"`+long+`","cpu_percent":-5},
		              {"service":"db","name":"olt-social-db-1","replica":1,"state":"running","cpu_percent":12.5}]}`)
	r := Read(path)
	if r.ReadError != "" || r.Project != "olt-social" || r.Host == nil || r.Host.CPUs != 8 || len(r.Containers) != 2 {
		t.Fatalf("report = %+v", r)
	}
	if len(r.Containers[0].Image) != 200 || r.Containers[0].CPUPercent != nil || *r.Containers[1].CPUPercent != 12.5 {
		t.Fatalf("containers = %+v", r.Containers)
	}
}

func TestReadExplainsMissingAndBrokenFiles(t *testing.T) {
	dir := t.TempDir()
	if r := Read(filepath.Join(dir, "missing.json")); !strings.Contains(r.ReadError, "healer") || r.Containers == nil {
		t.Fatalf("missing = %+v", r)
	}
	broken := filepath.Join(dir, "broken.json")
	writeFile(t, broken, `{"containers":[]}`)
	if r := Read(broken); !strings.Contains(r.ReadError, "checked_at") {
		t.Fatalf("broken = %+v", r)
	}
}

func TestForwarderSendsOnlyNewSnapshots(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nodes.json")
	writeFile(t, path, `{"checked_at":"2026-11-16T03:00:00Z","containers":[]}`)
	store := &fakeStore{}
	f := NewForwarder(Options{Store: store, Log: slog.New(slog.NewTextHandler(io.Discard, nil)), File: path, Instance: "sentinel-1", Interval: time.Second})
	if !f.Tick(context.Background()) || f.Tick(context.Background()) {
		t.Fatalf("sent = %d", len(store.sent))
	}
	writeFile(t, path, `{"checked_at":"2026-11-16T03:00:10Z","containers":[]}`)
	if !f.Tick(context.Background()) || len(store.sent) != 2 {
		t.Fatalf("sent = %d", len(store.sent))
	}
}

func TestForwarderRetriesAfterAFailedSend(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nodes.json")
	writeFile(t, path, `{"checked_at":"2026-11-16T03:00:00Z","containers":[]}`)
	store := &fakeStore{err: errors.New("rpc nodes_report: status 503")}
	f := NewForwarder(Options{Store: store, Log: slog.New(slog.NewTextHandler(io.Discard, nil)), File: path, Instance: "sentinel-1", Interval: time.Second})
	if f.Tick(context.Background()) {
		t.Fatal("failed send reported as sent")
	}
	store.err = nil
	if !f.Tick(context.Background()) || len(store.sent) != 1 {
		t.Fatalf("sent = %d", len(store.sent))
	}
}

func TestForwarderKeepsReportingAReadError(t *testing.T) {
	store := &fakeStore{}
	f := NewForwarder(Options{Store: store, Log: slog.New(slog.NewTextHandler(io.Discard, nil)), File: filepath.Join(t.TempDir(), "nodes.json"), Instance: "sentinel-1", Interval: time.Second})
	f.Tick(context.Background())
	f.Tick(context.Background())
	if len(store.sent) != 2 || store.sent[1].ReadError == "" {
		t.Fatalf("sent = %+v", store.sent)
	}
}
