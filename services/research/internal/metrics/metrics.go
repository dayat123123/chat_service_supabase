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
	Requests      map[Request]uint64
	UploadedBytes uint64
	Inflight      int
	Capacity      int
	KeysCached    int
	StoreFailures int
	Reports       map[string]uint64
	Documents     map[string]uint64
	WorkerBusy    bool
	LastHeartbeat time.Time
}

func Handler(snapshot func() Snapshot) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		_, _ = w.Write([]byte(Render(snapshot())))
	})
}

func Render(s Snapshot) string {
	var b strings.Builder
	header(&b, "research_requests_total", "API requests by endpoint and result code (ok or error code).", "counter")
	reqs := make([]Request, 0, len(s.Requests))
	for k := range s.Requests {
		reqs = append(reqs, k)
	}
	slices.SortFunc(reqs, func(a, b Request) int {
		return cmp.Or(cmp.Compare(a.Endpoint, b.Endpoint), cmp.Compare(a.Code, b.Code))
	})
	for _, k := range reqs {
		fmt.Fprintf(&b, "research_requests_total{endpoint=%q,code=%q} %d\n", k.Endpoint, k.Code, s.Requests[k])
	}
	header(&b, "research_uploaded_bytes_total", "Bytes of accepted report files and documents.", "counter")
	fmt.Fprintf(&b, "research_uploaded_bytes_total %d\n", s.UploadedBytes)
	header(&b, "research_reports_total", "Processed files by result (done, duplicate, retry, rejected, lease_lost).", "counter")
	results(&b, "research_reports_total", s.Reports)
	header(&b, "research_documents_total", "Checked source documents by result (ready, retry, rejected, lease_lost).", "counter")
	results(&b, "research_documents_total", s.Documents)
	header(&b, "research_inflight_uploads", "Uploads holding an upload slot.", "gauge")
	fmt.Fprintf(&b, "research_inflight_uploads %d\n", s.Inflight)
	header(&b, "research_max_uploads", "Configured MAX_UPLOADS.", "gauge")
	fmt.Fprintf(&b, "research_max_uploads %d\n", s.Capacity)
	header(&b, "research_worker_busy", "1 while the worker is processing a file or a document.", "gauge")
	busy := 0
	if s.WorkerBusy {
		busy = 1
	}
	fmt.Fprintf(&b, "research_worker_busy %d\n", busy)
	header(&b, "research_key_cache_entries", "Cached API key lookups (key hash and client IP).", "gauge")
	fmt.Fprintf(&b, "research_key_cache_entries %d\n", s.KeysCached)
	header(&b, "research_store_consecutive_failures", "Consecutive failed calls to the database or storage API (3 or more = degraded).", "gauge")
	fmt.Fprintf(&b, "research_store_consecutive_failures %d\n", s.StoreFailures)
	header(&b, "research_last_heartbeat_timestamp_seconds", "Unix time of the last successful heartbeat, 0 before the first one.", "gauge")
	last := int64(0)
	if !s.LastHeartbeat.IsZero() {
		last = s.LastHeartbeat.Unix()
	}
	fmt.Fprintf(&b, "research_last_heartbeat_timestamp_seconds %d\n", last)
	return b.String()
}

func results(b *strings.Builder, name string, counts map[string]uint64) {
	keys := make([]string, 0, len(counts))
	for k := range counts {
		keys = append(keys, k)
	}
	slices.Sort(keys)
	for _, k := range keys {
		fmt.Fprintf(b, "%s{result=%q} %d\n", name, k, counts[k])
	}
}

func header(b *strings.Builder, name, help, kind string) {
	fmt.Fprintf(b, "# HELP %s %s\n# TYPE %s %s\n", name, help, name, kind)
}
