package metrics

import (
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestRenderExposesAllSeries(t *testing.T) {
	at := time.Unix(1_800_000_000, 0)
	out := Render(Snapshot{
		Configured: true, RepositoryReady: true, Streaming: true, Busy: "offsite",
		Runs:             map[string]uint64{RunKey("base", "ok"): 2, RunKey("wal", "failed"): 1},
		ReceiverRestarts: 3, WALLocalBytes: 10, OffsitePending: 11, LocalBaseBytes: 12, DiskTotal: 100, DiskAvail: 50,
		LastWALReceived: at, LastBaseOK: at,
	})
	for _, want := range []string{
		"backup_configured 1\n", "backup_repository_ready 1\n", "backup_wal_streaming 1\n", "backup_wal_slot_lost 0\n",
		`backup_busy{job="offsite"} 1`, `backup_busy{job="base"} 0`,
		`backup_runs_total{kind="base",status="ok"} 2`, `backup_runs_total{kind="wal",status="failed"} 1`,
		`backup_runs_total{kind="restore_test",status="ok"} 0`,
		"backup_wal_receiver_restarts_total 3\n", "backup_wal_local_bytes 10\n", "backup_offsite_pending_bytes 11\n",
		"backup_local_base_bytes 12\n", "backup_disk_total_bytes 100\n", "backup_disk_avail_bytes 50\n",
		"backup_wal_last_received_timestamp_seconds 1800000000\n", "backup_offsite_last_success_timestamp_seconds 0\n",
		"backup_base_last_success_timestamp_seconds 1800000000\n", "# TYPE backup_runs_total counter",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q", want)
		}
	}
}

func TestHandlerServesPrometheusText(t *testing.T) {
	rec := httptest.NewRecorder()
	Handler(func() Snapshot { return Snapshot{} }).ServeHTTP(rec, httptest.NewRequest("GET", "/metrics", nil))
	if rec.Header().Get("Content-Type") != "text/plain; version=0.0.4; charset=utf-8" || !strings.Contains(rec.Body.String(), "backup_configured 0") {
		t.Fatalf("response = %v %q", rec.Header(), rec.Body.String())
	}
}
