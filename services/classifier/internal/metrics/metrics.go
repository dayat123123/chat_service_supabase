package metrics

import (
	"fmt"
	"net/http"
	"slices"
	"strings"
	"time"
)

type Snapshot struct {
	Requests            map[string]uint64
	Inferences          uint64
	DurationSeconds     float64
	Classified          uint64
	Inflight            int
	Capacity            int
	ModelLoaded         bool
	ConsecutiveFailures int
	LastHeartbeat       time.Time
}

func Handler(snapshot func() Snapshot) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		_, _ = w.Write([]byte(Render(snapshot())))
	})
}

func Render(s Snapshot) string {
	var b strings.Builder
	header(&b, "classifier_requests_total", "Classification requests by result code (ok or error code).", "counter")
	codes := make([]string, 0, len(s.Requests))
	for code := range s.Requests {
		codes = append(codes, code)
	}
	slices.Sort(codes)
	for _, code := range codes {
		fmt.Fprintf(&b, "classifier_requests_total{code=%q} %d\n", code, s.Requests[code])
	}
	header(&b, "classifier_inferences_total", "Model runs (one per view of a sampled frame).", "counter")
	fmt.Fprintf(&b, "classifier_inferences_total %d\n", s.Inferences)
	header(&b, "classifier_duration_seconds", "Time spent decoding and classifying images that were classified.", "summary")
	fmt.Fprintf(&b, "classifier_duration_seconds_sum %g\n", s.DurationSeconds)
	fmt.Fprintf(&b, "classifier_duration_seconds_count %d\n", s.Classified)
	header(&b, "classifier_inflight_requests", "Requests holding a processing slot.", "gauge")
	fmt.Fprintf(&b, "classifier_inflight_requests %d\n", s.Inflight)
	header(&b, "classifier_max_concurrent_requests", "Configured MAX_CONCURRENT.", "gauge")
	fmt.Fprintf(&b, "classifier_max_concurrent_requests %d\n", s.Capacity)
	header(&b, "classifier_model_loaded", "1 when the model is loaded and verified.", "gauge")
	fmt.Fprintf(&b, "classifier_model_loaded %d\n", boolInt(s.ModelLoaded))
	header(&b, "classifier_consecutive_failures", "Consecutive failed model runs (3 or more = degraded).", "gauge")
	fmt.Fprintf(&b, "classifier_consecutive_failures %d\n", s.ConsecutiveFailures)
	header(&b, "classifier_last_heartbeat_timestamp_seconds", "Unix time of the last successful heartbeat, 0 before the first one.", "gauge")
	fmt.Fprintf(&b, "classifier_last_heartbeat_timestamp_seconds %d\n", unix(s.LastHeartbeat))
	return b.String()
}

func header(b *strings.Builder, name, help, kind string) {
	fmt.Fprintf(b, "# HELP %s %s\n# TYPE %s %s\n", name, help, name, kind)
}

func boolInt(v bool) int {
	if v {
		return 1
	}
	return 0
}

func unix(t time.Time) int64 {
	if t.IsZero() {
		return 0
	}
	return t.Unix()
}
