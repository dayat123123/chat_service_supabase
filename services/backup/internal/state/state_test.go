package state

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"
)

func TestLoadMissingFileStartsEmpty(t *testing.T) {
	p, err := Load(filepath.Join(t.TempDir(), "state.json"))
	if err != nil || p.Jobs == nil || p.Base != nil {
		t.Fatalf("p = %+v err = %v", p, err)
	}
}

func TestSaveAndLoadRoundTrip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")
	at := time.Date(2026, 11, 3, 1, 2, 3, 0, time.UTC)
	p := Persisted{Repository: "s3:http://s3/b", SystemID: "77", NeedBase: true, WeeklyFrom: at,
		Base:    &Base{Label: "base-1", Dir: "/d/base/base-1", StartWAL: "000000010000000000000027", SnapshotID: "abc", StartedAt: at, FinishedAt: at, Bytes: 9},
		Offsite: Offsite{LastOKAt: at, LastSnapshot: "def"}}
	p.SetJob("base", Job{LastOK: at, Failures: 2, LastError: "x"})
	if err := Save(path, p); err != nil {
		t.Fatal(err)
	}
	got, err := Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, p) {
		t.Fatalf("got %+v\nwant %+v", got, p)
	}
	entries, _ := os.ReadDir(filepath.Dir(path))
	if len(entries) != 1 {
		t.Fatalf("temporary files left: %v", entries)
	}
	if got.Job("missing") != (Job{}) {
		t.Fatal("missing job")
	}
}

func TestLoadRejectsCorruptFiles(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")
	_ = os.WriteFile(path, []byte("{"), 0o600)
	p, err := Load(path)
	if err == nil || p.Jobs == nil {
		t.Fatalf("p = %+v err = %v", p, err)
	}
}

func TestReportMatchesTheContractShape(t *testing.T) {
	at := time.Date(2026, 11, 3, 1, 0, 0, 0, time.FixedZone("WIB", 7*3600))
	r := Report{
		RepositoryReady: true,
		WAL:             WAL{Streaming: true, LastSegment: Text("000000010000000000000027"), LastReceivedAt: Time(at), LocalBytes: 1},
		Offsite:         OffsiteReport{PendingBytes: 2},
		LocalBase:       LocalBase{Bytes: 3},
		Disk:            Disk{TotalBytes: 4, AvailBytes: 5},
		Busy:            Text("base"),
	}
	data, _ := json.Marshal(r)
	var got map[string]any
	_ = json.Unmarshal(data, &got)
	want := map[string]any{
		"repository_ready": true,
		"wal": map[string]any{"streaming": true, "slot_lost": false, "last_segment": "000000010000000000000027",
			"last_received_at": "2026-11-02T18:00:00Z", "local_bytes": float64(1), "error": nil},
		"offsite":    map[string]any{"last_ok_at": nil, "last_snapshot": nil, "last_error": nil, "pending_bytes": float64(2)},
		"local_base": map[string]any{"label": nil, "finished_at": nil, "bytes": float64(3)},
		"disk":       map[string]any{"total_bytes": float64(4), "avail_bytes": float64(5)},
		"busy":       "base",
		"error":      nil,
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v\nwant %v", got, want)
	}
}

func TestRunMatchesTheContractShape(t *testing.T) {
	at := time.Date(2026, 11, 3, 1, 0, 0, 0, time.UTC)
	data, _ := json.Marshal(Run{Kind: "base", Status: StatusOK, StartedAt: at, FinishedAt: at, Bytes: Int(10), SnapshotID: Text("abc"), Detail: map[string]any{}})
	if string(data) != `{"kind":"base","status":"ok","started_at":"2026-11-03T01:00:00Z","finished_at":"2026-11-03T01:00:00Z","bytes":10,"snapshot_id":"abc","detail":{},"error":null}` {
		t.Fatalf("json = %s", data)
	}
	if Text("") != nil || Time(time.Time{}) != nil {
		t.Fatal("empty values must be null")
	}
}
