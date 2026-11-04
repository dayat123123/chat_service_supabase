package healer

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func write(t *testing.T, body string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "state.json")
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestReadKeepsTheStateAndTheNewestEvents(t *testing.T) {
	var events []string
	for i := range MaxEvents + 5 {
		events = append(events, fmt.Sprintf(`{"id":"e%d","at":"2026-11-04T03:%02d:00Z","service":"rest","container":"olt-social-rest-1","action":"restart","reason":"unhealthy","result":"ok","detail":"unhealthy 61s"}`, i, i))
	}
	path := write(t, `{"version":"0.1.0","project":"olt-social","enabled":true,"started_at":"2026-11-04T02:00:00Z",
		"checked_at":"2026-11-04T04:00:00Z","rules":{"unhealthy_seconds":60,"min_uptime_seconds":120,"max_restarts_per_hour":3,
		"global_cooldown_seconds":30,"systemic_fraction":0.5,"interval_seconds":10},"watched":19,
		"unhealthy":[{"service":"rest","container":"olt-social-rest-1","since":"2026-11-04T03:59:00Z"}],
		"skip":{"reason":"systemic","since":"2026-11-04T03:59:30Z","services":["auth","rest"]},
		"gave_up":[{"service":"rest","since":"2026-11-04T03:58:00Z","until":"2026-11-04T04:30:00Z","restarts":3}],
		"events":[`+strings.Join(events, ",")+`],"error":"","unknown_field":1}`)
	r := Read(path)
	if r.ReadError != "" || r.Project != "olt-social" || r.Enabled == nil || !*r.Enabled || r.Watched != 19 ||
		!r.CheckedAt.Equal(time.Date(2026, 11, 4, 4, 0, 0, 0, time.UTC)) || r.Rules.MaxRestartsPerHour != 3 ||
		r.Skip == nil || r.Skip.Reason != "systemic" || len(r.GaveUp) != 1 || r.GaveUp[0].Restarts != 3 || len(r.Unhealthy) != 1 {
		t.Fatalf("report = %+v", r)
	}
	if len(r.Events) != MaxEvents || r.Events[0].ID != "e5" || r.Events[MaxEvents-1].ID != fmt.Sprintf("e%d", MaxEvents+4) {
		t.Fatalf("events = %d first %s", len(r.Events), r.Events[0].ID)
	}
	raw, _ := json.Marshal(r)
	if strings.Contains(string(raw), "read_error") || strings.Contains(string(raw), "unknown_field") {
		t.Fatalf("payload = %s", raw)
	}
}

func TestReadReportsProblemsInsteadOfFailing(t *testing.T) {
	dir := t.TempDir()
	cases := map[string]string{
		filepath.Join(dir, "missing.json"):        "state file not found",
		write(t, "{broken"):                       "decode state file",
		write(t, `{"project":"olt-social"}`):      "no checked_at",
		write(t, strings.Repeat(" ", 5<<20)+"{}"): "larger than 4 MiB",
	}
	for path, want := range cases {
		r := Read(path)
		if !strings.Contains(r.ReadError, want) {
			t.Fatalf("%s: read error = %q, want %q", path, r.ReadError, want)
		}
		raw, _ := json.Marshal(r)
		if !strings.Contains(string(raw), `"events":[]`) || !strings.Contains(string(raw), `"gave_up":[]`) || strings.Contains(string(raw), `"checked_at":`) {
			t.Fatalf("payload = %s", raw)
		}
	}
}

func TestReadClipsLongText(t *testing.T) {
	long := strings.Repeat("x", 1000)
	path := write(t, `{"checked_at":"2026-11-04T04:00:00Z","error":"`+long+`","events":[{"id":"1","at":"2026-11-04T04:00:00Z","detail":"`+long+`","error":"`+long+`"}]}`)
	r := Read(path)
	if len(r.Error) != maxText || len(r.Events[0].Detail) != maxText || len(r.Events[0].Error) != maxText {
		t.Fatalf("lengths %d %d %d", len(r.Error), len(r.Events[0].Detail), len(r.Events[0].Error))
	}
}
