package metrics

import (
	"fmt"
	"net/http"
	"strings"

	"olt-social/notifier/internal/push"
)

type Snapshot struct {
	Pushes       map[push.Outcome]uint64
	ClaimBatches uint64
	QueueDepth   int
	Configured   bool
	Healthy      bool
}

func Handler(snapshot func() Snapshot) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		_, _ = w.Write([]byte(Render(snapshot())))
	})
}

func Render(s Snapshot) string {
	var b strings.Builder
	header(&b, "notifier_push_total", "Push jobs handled by this instance, by outcome.", "counter")
	for _, outcome := range push.Outcomes {
		fmt.Fprintf(&b, "notifier_push_total{outcome=%q} %d\n", outcome, s.Pushes[outcome])
	}
	header(&b, "notifier_claim_batches_total", "Claims that returned at least one push job.", "counter")
	fmt.Fprintf(&b, "notifier_claim_batches_total %d\n", s.ClaimBatches)
	header(&b, "notifier_queue_depth", "Queued push jobs reported by the last heartbeat.", "gauge")
	fmt.Fprintf(&b, "notifier_queue_depth %d\n", s.QueueDepth)
	header(&b, "notifier_configured", "1 when a Firebase credentials file is present.", "gauge")
	fmt.Fprintf(&b, "notifier_configured %d\n", flag(s.Configured))
	header(&b, "notifier_healthy", "1 when configured and no Firebase error is reported.", "gauge")
	fmt.Fprintf(&b, "notifier_healthy %d\n", flag(s.Healthy))
	return b.String()
}

func header(b *strings.Builder, name, help, kind string) {
	fmt.Fprintf(b, "# HELP %s %s\n# TYPE %s %s\n", name, help, name, kind)
}

func flag(v bool) int {
	if v {
		return 1
	}
	return 0
}
