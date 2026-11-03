package metrics

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestRenderWritesPrometheusText(t *testing.T) {
	out := Render(Snapshot{
		Uploads: map[Upload]uint64{
			{"avatars", "ok"}:                 3,
			{"attachments", "invalid_image"}:  1,
			{"other", "bucket_not_allowed"}:   2,
			{"attachments", "already_exists"}: 4,
		},
		MetadataRemoved: 2,
		ReceivedBytes:   1000,
		StoredBytes:     900,
		DurationSeconds: 1.5,
		Requests:        10,
		Inflight:        1,
		Capacity:        8,
		StorageFailures: 3,
		LastHeartbeat:   time.Unix(1_800_000_000, 0),
	})
	want := []string{
		`media_uploads_total{bucket="attachments",code="already_exists"} 4`,
		`media_uploads_total{bucket="attachments",code="invalid_image"} 1`,
		`media_uploads_total{bucket="avatars",code="ok"} 3`,
		`media_uploads_total{bucket="other",code="bucket_not_allowed"} 2`,
		"media_metadata_removed_total 2",
		"media_received_bytes_total 1000",
		"media_stored_bytes_total 900",
		"# TYPE media_upload_duration_seconds summary",
		"media_upload_duration_seconds_sum 1.5",
		"media_upload_duration_seconds_count 10",
		"media_inflight_uploads 1",
		"media_max_concurrent_uploads 8",
		"media_storage_consecutive_failures 3",
		"media_last_heartbeat_timestamp_seconds 1800000000",
	}
	last := -1
	for _, line := range want {
		i := strings.Index(out, line+"\n")
		if i < 0 || (strings.HasPrefix(line, "media_uploads_total") && i < last) {
			t.Fatalf("missing or out of order %q in\n%s", line, out)
		}
		last = i
	}
}

func TestHandlerServesTheSnapshot(t *testing.T) {
	rec := httptest.NewRecorder()
	Handler(func() Snapshot { return Snapshot{} }).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	if rec.Code != http.StatusOK || !strings.HasPrefix(rec.Header().Get("Content-Type"), "text/plain") ||
		!strings.Contains(rec.Body.String(), "media_last_heartbeat_timestamp_seconds 0\n") {
		t.Fatalf("%d %s", rec.Code, rec.Body.String())
	}
}
