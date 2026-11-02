package metrics

import (
	"fmt"
	"net/http"
	"strings"
	"time"
)

const (
	Cleaned  = "cleaned"
	Failed   = "failed"
	Released = "released"
)

var Outcomes = []string{Cleaned, Failed, Released}

type Snapshot struct {
	ObjectsDeleted uint64
	Entries        map[string]uint64
	ClaimErrors    uint64
	LastSuccess    time.Time
}

func Handler(snapshot func() Snapshot) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		_, _ = w.Write([]byte(Render(snapshot())))
	})
}

func Render(s Snapshot) string {
	var b strings.Builder
	header(&b, "janitor_objects_deleted_total", "Storage objects deleted by this instance.", "counter")
	fmt.Fprintf(&b, "janitor_objects_deleted_total %d\n", s.ObjectsDeleted)
	header(&b, "janitor_entries_total", "Cleanup queue entries handled by this instance, by outcome.", "counter")
	for _, outcome := range Outcomes {
		fmt.Fprintf(&b, "janitor_entries_total{outcome=%q} %d\n", outcome, s.Entries[outcome])
	}
	header(&b, "janitor_claim_errors_total", "Claims that failed.", "counter")
	fmt.Fprintf(&b, "janitor_claim_errors_total %d\n", s.ClaimErrors)
	header(&b, "janitor_last_success_timestamp_seconds", "Unix time of the last successful report, 0 before the first one.", "gauge")
	fmt.Fprintf(&b, "janitor_last_success_timestamp_seconds %d\n", unix(s.LastSuccess))
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
