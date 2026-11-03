package metrics

import (
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestRenderListsEveryCounter(t *testing.T) {
	out := Render(Snapshot{
		Results:       map[string]uint64{"ok": 3, "blocked": 1},
		Images:        map[string]uint64{"stored": 2},
		Blocked:       map[string]uint64{"private_address": 1, "port": 2},
		FetchSeconds:  1.5,
		Fetches:       4,
		ClaimErrors:   1,
		Inflight:      2,
		Concurrency:   4,
		LastClaim:     time.Unix(1_800_000_000, 0),
		LastHeartbeat: time.Time{},
		Verdicts:      map[string]uint64{"block": 2},
		CacheHits:     5,
		ThresholdsSet: true,
	})
	for _, line := range []string{
		`link_preview_fetch_total{result="ok"} 3`,
		`link_preview_fetch_total{result="release"} 0`,
		`link_preview_blocked_total{reason="port"} 2`,
		`link_preview_blocked_total{reason="private_address"} 1`,
		`link_preview_images_total{outcome="stored"} 2`,
		`link_preview_images_total{outcome="failed"} 0`,
		`link_preview_fetch_duration_seconds_sum 1.5`,
		`link_preview_fetch_duration_seconds_count 4`,
		`link_preview_claim_errors_total 1`,
		`link_preview_inflight 2`,
		`link_preview_last_claim_timestamp_seconds 1800000000`,
		`link_preview_last_heartbeat_timestamp_seconds 0`,
		`link_preview_image_verdicts_total{verdict="block"} 2`,
		`link_preview_image_verdicts_total{verdict="unavailable"} 0`,
		`link_preview_image_cache_hits_total 5`,
		`link_preview_classifier_consecutive_failures 0`,
		`link_preview_thresholds_loaded 1`,
	} {
		if !strings.Contains(out, line+"\n") {
			t.Fatalf("missing %q in\n%s", line, out)
		}
	}
	if strings.Index(out, `reason="port"`) > strings.Index(out, `reason="private_address"`) {
		t.Fatal("reasons must be sorted")
	}
}

func TestHandlerServesTextFormat(t *testing.T) {
	rec := httptest.NewRecorder()
	Handler(func() Snapshot { return Snapshot{} }).ServeHTTP(rec, httptest.NewRequest("GET", "/metrics", nil))
	if !strings.HasPrefix(rec.Header().Get("Content-Type"), "text/plain") || !strings.Contains(rec.Body.String(), "# TYPE link_preview_fetch_total counter") {
		t.Fatalf("response = %q", rec.Body.String())
	}
}
