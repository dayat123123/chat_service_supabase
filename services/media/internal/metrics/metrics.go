package metrics

import (
	"cmp"
	"fmt"
	"net/http"
	"slices"
	"strings"
	"time"
)

type Upload struct {
	Bucket string
	Code   string
}

type Snapshot struct {
	Uploads         map[Upload]uint64
	MetadataRemoved uint64
	ReceivedBytes   uint64
	StoredBytes     uint64
	DurationSeconds float64
	Requests        uint64
	Inflight        int
	Capacity        int
	StorageFailures int
	LastHeartbeat   time.Time
	Verdicts        map[string]uint64
	ClassifierFails int
	ClassifySeconds float64
	Classifications uint64
	Revision        int64
}

func Handler(snapshot func() Snapshot) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		_, _ = w.Write([]byte(Render(snapshot())))
	})
}

func Render(s Snapshot) string {
	var b strings.Builder
	header(&b, "media_uploads_total", "Upload requests handled by this instance, by bucket and result code (ok or error code).", "counter")
	keys := make([]Upload, 0, len(s.Uploads))
	for k := range s.Uploads {
		keys = append(keys, k)
	}
	slices.SortFunc(keys, func(a, b Upload) int {
		return cmp.Or(cmp.Compare(a.Bucket, b.Bucket), cmp.Compare(a.Code, b.Code))
	})
	for _, k := range keys {
		fmt.Fprintf(&b, "media_uploads_total{bucket=%q,code=%q} %d\n", k.Bucket, k.Code, s.Uploads[k])
	}
	header(&b, "media_metadata_removed_total", "Stored files that had metadata or trailing data removed.", "counter")
	fmt.Fprintf(&b, "media_metadata_removed_total %d\n", s.MetadataRemoved)
	header(&b, "media_received_bytes_total", "Upload bytes read from clients.", "counter")
	fmt.Fprintf(&b, "media_received_bytes_total %d\n", s.ReceivedBytes)
	header(&b, "media_stored_bytes_total", "Sanitized bytes accepted by Storage.", "counter")
	fmt.Fprintf(&b, "media_stored_bytes_total %d\n", s.StoredBytes)
	header(&b, "media_upload_duration_seconds", "Time spent handling upload requests.", "summary")
	fmt.Fprintf(&b, "media_upload_duration_seconds_sum %g\n", s.DurationSeconds)
	fmt.Fprintf(&b, "media_upload_duration_seconds_count %d\n", s.Requests)
	header(&b, "media_inflight_uploads", "Uploads holding a processing slot.", "gauge")
	fmt.Fprintf(&b, "media_inflight_uploads %d\n", s.Inflight)
	header(&b, "media_max_concurrent_uploads", "Configured MAX_CONCURRENT.", "gauge")
	fmt.Fprintf(&b, "media_max_concurrent_uploads %d\n", s.Capacity)
	header(&b, "media_storage_consecutive_failures", "Consecutive failed attempts to reach Storage (3 or more = degraded).", "gauge")
	fmt.Fprintf(&b, "media_storage_consecutive_failures %d\n", s.StorageFailures)
	header(&b, "media_moderation_total", "Classified image uploads by decision (allow, hold, block, unclassified).", "counter")
	verdicts := make([]string, 0, len(s.Verdicts))
	for v := range s.Verdicts {
		verdicts = append(verdicts, v)
	}
	slices.Sort(verdicts)
	for _, v := range verdicts {
		fmt.Fprintf(&b, "media_moderation_total{decision=%q} %d\n", v, s.Verdicts[v])
	}
	header(&b, "media_classifier_duration_seconds", "Time spent waiting for the classifier on answered requests.", "summary")
	fmt.Fprintf(&b, "media_classifier_duration_seconds_sum %g\n", s.ClassifySeconds)
	fmt.Fprintf(&b, "media_classifier_duration_seconds_count %d\n", s.Classifications)
	header(&b, "media_classifier_consecutive_failures", "Consecutive failed attempts to use the classifier (3 or more = degraded).", "gauge")
	fmt.Fprintf(&b, "media_classifier_consecutive_failures %d\n", s.ClassifierFails)
	header(&b, "media_thresholds_revision", "Revision of the image thresholds in use, -1 before they are loaded.", "gauge")
	fmt.Fprintf(&b, "media_thresholds_revision %d\n", s.Revision)
	header(&b, "media_last_heartbeat_timestamp_seconds", "Unix time of the last successful heartbeat, 0 before the first one.", "gauge")
	fmt.Fprintf(&b, "media_last_heartbeat_timestamp_seconds %d\n", unix(s.LastHeartbeat))
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
