package metrics

import (
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestRenderPrometheusText(t *testing.T) {
	out := Render(Snapshot{
		Requests:   map[string]uint64{"ok": 3, "busy": 1},
		Inferences: 6, DurationSeconds: 0.25, Classified: 3, Inflight: 1, Capacity: 2, ModelLoaded: true,
		ConsecutiveFailures: 0, LastHeartbeat: time.Unix(1_800_000_000, 0),
	})
	for _, want := range []string{
		"# TYPE classifier_requests_total counter",
		"classifier_requests_total{code=\"busy\"} 1\nclassifier_requests_total{code=\"ok\"} 3\n",
		"classifier_inferences_total 6\n",
		"classifier_duration_seconds_sum 0.25\n",
		"classifier_duration_seconds_count 3\n",
		"classifier_inflight_requests 1\n",
		"classifier_max_concurrent_requests 2\n",
		"classifier_model_loaded 1\n",
		"classifier_consecutive_failures 0\n",
		"classifier_last_heartbeat_timestamp_seconds 1800000000\n",
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("missing %q in\n%s", want, out)
		}
	}
	empty := Render(Snapshot{})
	if !strings.Contains(empty, "classifier_model_loaded 0\n") || !strings.Contains(empty, "classifier_last_heartbeat_timestamp_seconds 0\n") {
		t.Fatal(empty)
	}
}

func TestHandlerServesText(t *testing.T) {
	rec := httptest.NewRecorder()
	Handler(func() Snapshot { return Snapshot{} }).ServeHTTP(rec, httptest.NewRequest("GET", "/metrics", nil))
	if !strings.HasPrefix(rec.Header().Get("Content-Type"), "text/plain") || !strings.Contains(rec.Body.String(), "classifier_") {
		t.Fatalf("%v %s", rec.Header(), rec.Body.String())
	}
}
