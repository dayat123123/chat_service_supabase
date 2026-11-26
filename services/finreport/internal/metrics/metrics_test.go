package metrics

import (
	"strings"
	"testing"
	"time"
)

func TestRender(t *testing.T) {
	out := Render(Snapshot{
		Requests:      map[Request]uint64{{Endpoint: "submit", Code: "ok"}: 3, {Endpoint: "status", Code: "invalid_id"}: 1},
		UploadedBytes: 2048,
		Inflight:      1,
		Capacity:      2,
		Reports:       map[string]uint64{"done": 2, "rejected": 1},
		WorkerBusy:    true,
		LastHeartbeat: time.Unix(1700000000, 0),
	})
	for _, want := range []string{
		`finreport_requests_total{endpoint="status",code="invalid_id"} 1`,
		`finreport_requests_total{endpoint="submit",code="ok"} 3`,
		"finreport_uploaded_bytes_total 2048",
		`finreport_reports_total{result="done"} 2`,
		"finreport_max_uploads 2",
		"finreport_worker_busy 1",
		"finreport_last_heartbeat_timestamp_seconds 1700000000",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q", want)
		}
	}
	if strings.Index(out, `endpoint="status"`) > strings.Index(out, `endpoint="submit"`) {
		t.Error("requests are not sorted")
	}
	if !strings.Contains(Render(Snapshot{}), "finreport_last_heartbeat_timestamp_seconds 0") {
		t.Error("zero heartbeat not rendered as 0")
	}
}
