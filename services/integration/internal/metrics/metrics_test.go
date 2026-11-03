package metrics

import (
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestRender(t *testing.T) {
	out := Render(Snapshot{
		Requests:        map[Request]uint64{{"notify", "ok"}: 3, {"bot_posts", "rate_limited"}: 1},
		Messages:        map[string]uint64{"queued": 10, "invalid": 2},
		Posts:           map[string]uint64{"published": 1},
		Devices:         14,
		DurationSeconds: 0.5,
		Handled:         4,
		Inflight:        1,
		Capacity:        8,
		KeysCached:      2,
		StoreFailures:   0,
		LastHeartbeat:   time.Unix(1_800_000_000, 0),
	})
	for _, want := range []string{
		`integration_requests_total{endpoint="bot_posts",code="rate_limited"} 1`,
		`integration_requests_total{endpoint="notify",code="ok"} 3`,
		`integration_messages_total{result="invalid"} 2`,
		`integration_messages_total{result="queued"} 10`,
		`integration_push_devices_total 14`,
		`integration_bot_posts_total{result="published"} 1`,
		`integration_request_duration_seconds_count 4`,
		`integration_max_concurrent_requests 8`,
		`integration_key_cache_entries 2`,
		`integration_last_heartbeat_timestamp_seconds 1800000000`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in:\n%s", want, out)
		}
	}
	if strings.Index(out, `endpoint="bot_posts"`) > strings.Index(out, `endpoint="notify"`) {
		t.Error("label harus terurut")
	}
}

func TestHandler(t *testing.T) {
	rec := httptest.NewRecorder()
	Handler(func() Snapshot { return Snapshot{} }).ServeHTTP(rec, httptest.NewRequest("GET", "/metrics", nil))
	if !strings.HasPrefix(rec.Header().Get("Content-Type"), "text/plain") ||
		!strings.Contains(rec.Body.String(), "integration_last_heartbeat_timestamp_seconds 0") {
		t.Fatalf("respons = %q", rec.Body.String())
	}
}
