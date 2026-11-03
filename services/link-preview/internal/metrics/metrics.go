package metrics

import (
	"fmt"
	"net/http"
	"slices"
	"strings"
	"time"
)

var (
	Results     = []string{"ok", "empty", "blocked", "failed", "retry", "release"}
	ImageEvents = []string{"stored", "skipped", "rejected", "blocked", "failed"}
)

type Snapshot struct {
	Results         map[string]uint64
	Images          map[string]uint64
	Blocked         map[string]uint64
	FetchSeconds    float64
	Fetches         uint64
	ClaimErrors     uint64
	ReportErrors    uint64
	Inflight        int
	Concurrency     int
	LastClaim       time.Time
	LastHeartbeat   time.Time
	StoredImageSize uint64
}

func Handler(snapshot func() Snapshot) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		_, _ = w.Write([]byte(Render(snapshot())))
	})
}

func Render(s Snapshot) string {
	var b strings.Builder
	header(&b, "link_preview_fetch_total", "Links handled by this instance, by result.", "counter")
	for _, r := range Results {
		fmt.Fprintf(&b, "link_preview_fetch_total{result=%q} %d\n", r, s.Results[r])
	}
	header(&b, "link_preview_blocked_total", "Fetches refused by the SSRF guard or the domain block list, by reason.", "counter")
	reasons := make([]string, 0, len(s.Blocked))
	for r := range s.Blocked {
		reasons = append(reasons, r)
	}
	slices.Sort(reasons)
	for _, r := range reasons {
		fmt.Fprintf(&b, "link_preview_blocked_total{reason=%q} %d\n", r, s.Blocked[r])
	}
	header(&b, "link_preview_images_total", "Preview images, by outcome.", "counter")
	for _, e := range ImageEvents {
		fmt.Fprintf(&b, "link_preview_images_total{outcome=%q} %d\n", e, s.Images[e])
	}
	header(&b, "link_preview_image_bytes_total", "Sanitized image bytes uploaded to Storage.", "counter")
	fmt.Fprintf(&b, "link_preview_image_bytes_total %d\n", s.StoredImageSize)
	header(&b, "link_preview_fetch_duration_seconds", "Time spent per link, including the image.", "summary")
	fmt.Fprintf(&b, "link_preview_fetch_duration_seconds_sum %g\n", s.FetchSeconds)
	fmt.Fprintf(&b, "link_preview_fetch_duration_seconds_count %d\n", s.Fetches)
	header(&b, "link_preview_claim_errors_total", "Claims that failed.", "counter")
	fmt.Fprintf(&b, "link_preview_claim_errors_total %d\n", s.ClaimErrors)
	header(&b, "link_preview_report_errors_total", "Reports that failed after retries.", "counter")
	fmt.Fprintf(&b, "link_preview_report_errors_total %d\n", s.ReportErrors)
	header(&b, "link_preview_inflight", "Links being fetched now.", "gauge")
	fmt.Fprintf(&b, "link_preview_inflight %d\n", s.Inflight)
	header(&b, "link_preview_concurrency", "Configured CONCURRENCY.", "gauge")
	fmt.Fprintf(&b, "link_preview_concurrency %d\n", s.Concurrency)
	header(&b, "link_preview_last_claim_timestamp_seconds", "Unix time of the last successful claim, 0 before the first one.", "gauge")
	fmt.Fprintf(&b, "link_preview_last_claim_timestamp_seconds %d\n", unix(s.LastClaim))
	header(&b, "link_preview_last_heartbeat_timestamp_seconds", "Unix time of the last successful heartbeat, 0 before the first one.", "gauge")
	fmt.Fprintf(&b, "link_preview_last_heartbeat_timestamp_seconds %d\n", unix(s.LastHeartbeat))
	return b.String()
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
