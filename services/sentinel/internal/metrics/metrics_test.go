package metrics

import (
	"io"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"olt-social/sentinel/internal/disk"
	"olt-social/sentinel/internal/probe"
	"olt-social/sentinel/internal/scrape"
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
		Probes: []probe.Result{
			{Name: "storage", OK: true, LatencyMS: 12},
			{Name: "db", OK: false, LatencyMS: 5000},
		},
		Disks: []disk.Usage{{Name: "data", TotalBytes: 1000, FreeBytes: 400, AvailBytes: 300}},
		Scrapes: []scrape.Result{
			{Source: "rest", Instance: "10.0.0.4", OK: true},
			{Source: "pgbouncer", Instance: "10.0.0.5"},
		},
		Reports:            map[string]uint64{"ok": 40, "failed": 2},
		LastReport:         time.Unix(1_800_000_000, 0),
		Alerts:             map[string]map[string]uint64{"telegram": {"sent": 3, "retry": 1}, "email": {"failed": 2}},
		Notices:            map[string]uint64{"sent": 2},
		ChannelsRevision:   7,
		TelegramConfigured: true,
		DatabaseReachable:  true,
		Outages:            1,
	})
	expectLines(t, text,
		"# TYPE sentinel_probe_up gauge",
		`sentinel_probe_up{probe="storage"} 1`,
		`sentinel_probe_up{probe="db"} 0`,
		`sentinel_probe_latency_seconds{probe="storage"} 0.012`,
		`sentinel_probe_latency_seconds{probe="db"} 5.000`,
		`sentinel_disk_total_bytes{disk="data"} 1000`,
		`sentinel_disk_free_bytes{disk="data"} 400`,
		`sentinel_disk_avail_bytes{disk="data"} 300`,
		"# TYPE sentinel_scrape_up gauge",
		`sentinel_scrape_up{source="rest",instance="10.0.0.4"} 1`,
		`sentinel_scrape_up{source="pgbouncer",instance="10.0.0.5"} 0`,
		"# TYPE sentinel_health_reports_total counter",
		`sentinel_health_reports_total{outcome="ok"} 40`,
		`sentinel_health_reports_total{outcome="failed"} 2`,
		"sentinel_last_report_timestamp_seconds 1800000000",
		`sentinel_alerts_total{channel="telegram",outcome="sent"} 3`,
		`sentinel_alerts_total{channel="telegram",outcome="retry"} 1`,
		`sentinel_alerts_total{channel="email",outcome="failed"} 2`,
		`sentinel_alerts_total{channel="other",outcome="sent"} 0`,
		`sentinel_direct_alerts_total{outcome="sent"} 2`,
		`sentinel_direct_alerts_total{outcome="failed"} 0`,
		"sentinel_channels_revision 7",
		`sentinel_channel_configured{channel="telegram"} 1`,
		`sentinel_channel_configured{channel="email"} 0`,
		"sentinel_database_reachable 1",
		"sentinel_database_down 0",
		"sentinel_database_outages_total 1",
	)
}

func TestHandlerRendersZerosBeforeTheFirstRound(t *testing.T) {
	expectLines(t, render(t, Snapshot{ChannelsRevision: -1}),
		`sentinel_health_reports_total{outcome="ok"} 0`,
		"sentinel_last_report_timestamp_seconds 0",
		"sentinel_channels_revision -1",
		"sentinel_database_reachable 0",
	)
}
