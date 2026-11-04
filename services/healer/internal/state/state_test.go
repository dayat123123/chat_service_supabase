package state

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"testing"
	"time"
)

func TestSaveThenLoadRoundTripsAndLeavesNoTempFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "state.json")
	now := time.Date(2026, 11, 4, 10, 0, 0, 0, time.UTC)
	want := State{
		Version:   "0.1.0",
		Project:   "olt-social",
		Enabled:   true,
		StartedAt: now.Add(-time.Hour),
		CheckedAt: now,
		Rules:     Rules{UnhealthySeconds: 60, MinUptimeSeconds: 120, MaxRestartsPerHour: 3, GlobalCooldownSeconds: 30, SystemicFraction: 0.5, IntervalSeconds: 10},
		Watched:   19,
		Unhealthy: []Unhealthy{{Service: "rest", Container: "olt-social-rest-1", Since: now}},
		Skip:      &Skip{Reason: ReasonSystemic, Since: now, Services: []string{"auth", "rest"}},
		GaveUp:    []GaveUp{{Service: "rest", Since: now, Until: now.Add(time.Hour), Restarts: 3}},
		Events:    []Event{{ID: "1", At: now, Service: "rest", Container: "olt-social-rest-1", Action: ActionRestart, Reason: ReasonUnhealthy, Result: ResultOK, Detail: "unhealthy 61s"}},
	}
	if err := Save(path, want); err != nil {
		t.Fatal(err)
	}
	got, err := Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %+v\nwant %+v", got, want)
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != 1 {
		t.Fatalf("files = %v", entries)
	}
	if runtime.GOOS != "windows" {
		info, _ := os.Stat(path)
		if info.Mode().Perm() != 0o644 {
			t.Fatalf("mode = %v; sentinel reads the file as another user", info.Mode())
		}
	}
	raw, _ := os.ReadFile(path)
	for _, key := range []string{`"checked_at"`, `"gave_up"`, `"skip"`, `"events"`, `"max_restarts_per_hour"`} {
		if !strings.Contains(string(raw), key) {
			t.Fatalf("file lacks %s:\n%s", key, raw)
		}
	}
}

func TestSaveReplacesTheWholeFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")
	if err := Save(path, State{Project: "olt-social", Events: make([]Event, 50)}); err != nil {
		t.Fatal(err)
	}
	if err := Save(path, State{Project: "olt-social"}); err != nil {
		t.Fatal(err)
	}
	got, err := Load(path)
	if err != nil || len(got.Events) != 0 {
		t.Fatalf("got %+v err %v", got, err)
	}
}

func TestSaveFailsWhenTheDirectoryIsMissing(t *testing.T) {
	if err := Save(filepath.Join(t.TempDir(), "missing", "state.json"), State{}); err == nil {
		t.Fatal("expected an error")
	}
}

func TestLoadReportsMissingAndBrokenFiles(t *testing.T) {
	dir := t.TempDir()
	if _, err := Load(filepath.Join(dir, "none.json")); !errors.Is(err, fs.ErrNotExist) {
		t.Fatalf("err = %v", err)
	}
	broken := filepath.Join(dir, "broken.json")
	_ = os.WriteFile(broken, []byte("{not json"), 0o644)
	if _, err := Load(broken); err == nil || !strings.Contains(err.Error(), "decode state") {
		t.Fatalf("err = %v", err)
	}
	big := filepath.Join(dir, "big.json")
	_ = os.WriteFile(big, []byte(strings.Repeat(" ", maxFileSize+1)), 0o644)
	if _, err := Load(big); err == nil {
		t.Fatal("oversized file accepted")
	}
}

func TestTrimKeepsTheNewestEventsWithinSevenDays(t *testing.T) {
	now := time.Date(2026, 11, 4, 10, 0, 0, 0, time.UTC)
	var s State
	s.Events = append(s.Events, Event{ID: "old", At: now.Add(-8 * 24 * time.Hour)})
	for i := range MaxEvents + 20 {
		s.Events = append(s.Events, Event{ID: "e", At: now.Add(-time.Duration(MaxEvents+20-i) * time.Minute)})
	}
	s.Trim(now)
	if len(s.Events) != MaxEvents {
		t.Fatalf("events = %d", len(s.Events))
	}
	if s.Events[0].ID == "old" || !s.Events[len(s.Events)-1].At.Equal(now.Add(-time.Minute)) {
		t.Fatalf("first %+v last %+v", s.Events[0], s.Events[len(s.Events)-1])
	}
	for i := 1; i < len(s.Events); i++ {
		if s.Events[i].At.Before(s.Events[i-1].At) {
			t.Fatal("events are not in time order")
		}
	}
}
