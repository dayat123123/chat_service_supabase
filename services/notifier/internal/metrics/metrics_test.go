package metrics

import (
	"io"
	"net/http/httptest"
	"strings"
	"testing"

	"olt-social/notifier/internal/push"
)

func TestHandlerRendersPrometheusText(t *testing.T) {
	snapshot := Snapshot{
		Pushes:       map[push.Outcome]uint64{push.Sent: 12, push.Invalid: 2},
		ClaimBatches: 3,
		QueueDepth:   40,
		Configured:   true,
	}
	rec := httptest.NewRecorder()
	Handler(func() Snapshot { return snapshot }).ServeHTTP(rec, httptest.NewRequest("GET", "/metrics", nil))
	body, _ := io.ReadAll(rec.Body)
	text := string(body)

	if !strings.HasPrefix(rec.Header().Get("Content-Type"), "text/plain; version=0.0.4") {
		t.Fatalf("content type = %q", rec.Header().Get("Content-Type"))
	}
	for _, line := range []string{
		"# TYPE notifier_push_total counter",
		`notifier_push_total{outcome="sent"} 12`,
		`notifier_push_total{outcome="retry"} 0`,
		`notifier_push_total{outcome="invalid"} 2`,
		`notifier_push_total{outcome="failed"} 0`,
		`notifier_push_total{outcome="release"} 0`,
		"notifier_claim_batches_total 3",
		"# TYPE notifier_queue_depth gauge",
		"notifier_queue_depth 40",
		"notifier_configured 1",
		"notifier_healthy 0",
	} {
		if !strings.Contains(text, line+"\n") {
			t.Errorf("missing %q in\n%s", line, text)
		}
	}
}
