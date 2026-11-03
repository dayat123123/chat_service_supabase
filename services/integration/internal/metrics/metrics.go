package metrics

import (
	"cmp"
	"fmt"
	"net/http"
	"slices"
	"strings"
	"time"
)

type Request struct {
	Endpoint string
	Code     string
}

type Snapshot struct {
	Requests        map[Request]uint64
	Messages        map[string]uint64
	Posts           map[string]uint64
	Devices         uint64
	DurationSeconds float64
	Handled         uint64
	Inflight        int
	Capacity        int
	KeysCached      int
	StoreFailures   int
	LastHeartbeat   time.Time
}

func Handler(snapshot func() Snapshot) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		_, _ = w.Write([]byte(Render(snapshot())))
	})
}

func Render(s Snapshot) string {
	var b strings.Builder
	header(&b, "integration_requests_total", "Requests handled by this instance, by endpoint and result code (ok or error code).", "counter")
	reqs := make([]Request, 0, len(s.Requests))
	for k := range s.Requests {
		reqs = append(reqs, k)
	}
	slices.SortFunc(reqs, func(a, b Request) int {
		return cmp.Or(cmp.Compare(a.Endpoint, b.Endpoint), cmp.Compare(a.Code, b.Code))
	})
	for _, k := range reqs {
		fmt.Fprintf(&b, "integration_requests_total{endpoint=%q,code=%q} %d\n", k.Endpoint, k.Code, s.Requests[k])
	}
	header(&b, "integration_messages_total", "Notification messages by result (queued, no_recipient, duplicate, invalid).", "counter")
	labeled(&b, "integration_messages_total", s.Messages)
	header(&b, "integration_push_devices_total", "Push rows queued for devices by accepted notification messages.", "counter")
	fmt.Fprintf(&b, "integration_push_devices_total %d\n", s.Devices)
	header(&b, "integration_bot_posts_total", "Bot posts by result (published, rejected, duplicate, invalid, rate_limited).", "counter")
	labeled(&b, "integration_bot_posts_total", s.Posts)
	header(&b, "integration_request_duration_seconds", "Time spent handling authenticated requests.", "summary")
	fmt.Fprintf(&b, "integration_request_duration_seconds_sum %g\n", s.DurationSeconds)
	fmt.Fprintf(&b, "integration_request_duration_seconds_count %d\n", s.Handled)
	header(&b, "integration_inflight_requests", "Requests holding a database slot.", "gauge")
	fmt.Fprintf(&b, "integration_inflight_requests %d\n", s.Inflight)
	header(&b, "integration_max_concurrent_requests", "Configured MAX_CONCURRENT.", "gauge")
	fmt.Fprintf(&b, "integration_max_concurrent_requests %d\n", s.Capacity)
	header(&b, "integration_key_cache_entries", "Cached API key lookups (key hash and client IP).", "gauge")
	fmt.Fprintf(&b, "integration_key_cache_entries %d\n", s.KeysCached)
	header(&b, "integration_store_consecutive_failures", "Consecutive failed calls to the database API (3 or more = degraded).", "gauge")
	fmt.Fprintf(&b, "integration_store_consecutive_failures %d\n", s.StoreFailures)
	header(&b, "integration_last_heartbeat_timestamp_seconds", "Unix time of the last successful heartbeat, 0 before the first one.", "gauge")
	fmt.Fprintf(&b, "integration_last_heartbeat_timestamp_seconds %d\n", unix(s.LastHeartbeat))
	return b.String()
}

func labeled(b *strings.Builder, name string, values map[string]uint64) {
	keys := make([]string, 0, len(values))
	for k := range values {
		keys = append(keys, k)
	}
	slices.Sort(keys)
	for _, k := range keys {
		fmt.Fprintf(b, "%s{result=%q} %d\n", name, k, values[k])
	}
}

func header(b *strings.Builder, name, help, kind string) {
	fmt.Fprintf(b, "# HELP %s %s\n# TYPE %s %s\n", name, help, name, kind)
}

func unix(t time.Time) int64 {
	if t.IsZero() {
		return 0
	}
	return t.Unix()
}
