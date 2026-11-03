package metrics

import (
	"io"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func render(t *testing.T, snapshot Snapshot) string {
	t.Helper()
	rec := httptest.NewRecorder()
	Handler(func() Snapshot { return snapshot }).ServeHTTP(rec, httptest.NewRequest("GET", "/metrics", nil))
	if !strings.HasPrefix(rec.Header().Get("Content-Type"), "text/plain; version=0.0.4") {
		t.Fatalf("content type = %q", rec.Header().Get("Content-Type"))
	}
	body, _ := io.ReadAll(rec.Body)
	return string(body)
}

func expectLines(t *testing.T, text string, lines ...string) {
	t.Helper()
	for _, line := range lines {
		if !strings.Contains(text, line+"\n") {
			t.Errorf("missing %q in\n%s", line, text)
		}
	}
}

func TestHandlerRendersPrometheusText(t *testing.T) {
	text := render(t, Snapshot{
		ObjectsDeleted: 1234,
		Entries:        map[string]uint64{Cleaned: 40, Failed: 2},
		ClaimErrors:    3,
		LastSuccess:    time.Unix(1_800_000_000, 500_000_000),
	})
	expectLines(t, text,
		"# TYPE janitor_objects_deleted_total counter",
		"janitor_objects_deleted_total 1234",
		"# TYPE janitor_entries_total counter",
		`janitor_entries_total{outcome="cleaned"} 40`,
		`janitor_entries_total{outcome="failed"} 2`,
		`janitor_entries_total{outcome="released"} 0`,
		"# TYPE janitor_claim_errors_total counter",
		"janitor_claim_errors_total 3",
		"# TYPE janitor_last_success_timestamp_seconds gauge",
		"janitor_last_success_timestamp_seconds 1800000000",
	)
}

func TestHandlerRendersZeroBeforeTheFirstSuccess(t *testing.T) {
	expectLines(t, render(t, Snapshot{}),
		"janitor_objects_deleted_total 0",
		`janitor_entries_total{outcome="cleaned"} 0`,
		"janitor_last_success_timestamp_seconds 0",
	)
}

func TestHandlerRendersEvidenceCopies(t *testing.T) {
	expectLines(t, render(t, Snapshot{EvidenceFiles: map[string]uint64{EvidenceCopied: 9, EvidenceError: 1}, EvidenceClaimErrors: 2}),
		"# TYPE janitor_evidence_files_total counter",
		`janitor_evidence_files_total{outcome="copied"} 9`,
		`janitor_evidence_files_total{outcome="missing"} 0`,
		`janitor_evidence_files_total{outcome="error"} 1`,
		`janitor_evidence_files_total{outcome="released"} 0`,
		"janitor_evidence_claim_errors_total 2",
	)
}
