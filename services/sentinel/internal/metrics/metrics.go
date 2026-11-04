package metrics

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"olt-social/sentinel/internal/disk"
	"olt-social/sentinel/internal/probe"
	"olt-social/sentinel/internal/scrape"
)

var (
	ReportOutcomes = []string{"ok", "failed"}
	Channels       = []string{"telegram", "email", "other"}
	Outcomes       = []string{"sent", "retry", "failed"}
	NoticeOutcomes = []string{"sent", "failed"}
)

type Snapshot struct {
	Probes             []probe.Result
	Disks              []disk.Usage
	Scrapes            []scrape.Result
	Reports            map[string]uint64
	LastReport         time.Time
	Alerts             map[string]map[string]uint64
	Notices            map[string]uint64
	ChannelsRevision   int64
	TelegramConfigured bool
	EmailConfigured    bool
	DatabaseReachable  bool
	DatabaseDown       bool
	Outages            uint64
}

func Handler(snapshot func() Snapshot) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		_, _ = w.Write([]byte(Render(snapshot())))
	})
}

func Render(s Snapshot) string {
	var b strings.Builder
	header(&b, "sentinel_probe_up", "1 when the last probe of the target succeeded.", "gauge")
	for _, p := range s.Probes {
		fmt.Fprintf(&b, "sentinel_probe_up{probe=%q} %d\n", p.Name, flag(p.OK))
	}
	header(&b, "sentinel_probe_latency_seconds", "Duration of the last probe of the target.", "gauge")
	for _, p := range s.Probes {
		fmt.Fprintf(&b, "sentinel_probe_latency_seconds{probe=%q} %.3f\n", p.Name, float64(p.LatencyMS)/1000)
	}
	header(&b, "sentinel_disk_total_bytes", "Size of the filesystem holding the disk.", "gauge")
	for _, d := range s.Disks {
		fmt.Fprintf(&b, "sentinel_disk_total_bytes{disk=%q} %d\n", d.Name, d.TotalBytes)
	}
	header(&b, "sentinel_disk_free_bytes", "Free bytes on the filesystem, including the root reserve.", "gauge")
	for _, d := range s.Disks {
		fmt.Fprintf(&b, "sentinel_disk_free_bytes{disk=%q} %d\n", d.Name, d.FreeBytes)
	}
	header(&b, "sentinel_disk_avail_bytes", "Bytes available to unprivileged users on the filesystem.", "gauge")
	for _, d := range s.Disks {
		fmt.Fprintf(&b, "sentinel_disk_avail_bytes{disk=%q} %d\n", d.Name, d.AvailBytes)
	}
	header(&b, "sentinel_scrape_up", "1 when the last read of the metrics source instance succeeded.", "gauge")
	for _, r := range s.Scrapes {
		fmt.Fprintf(&b, "sentinel_scrape_up{source=%q,instance=%q} %d\n", r.Source, r.Instance, flag(r.OK))
	}
	header(&b, "sentinel_health_reports_total", "Health reports sent to the database, by outcome.", "counter")
	for _, outcome := range ReportOutcomes {
		fmt.Fprintf(&b, "sentinel_health_reports_total{outcome=%q} %d\n", outcome, s.Reports[outcome])
	}
	header(&b, "sentinel_last_report_timestamp_seconds", "Unix time of the last accepted health report, 0 before the first one.", "gauge")
	fmt.Fprintf(&b, "sentinel_last_report_timestamp_seconds %d\n", unix(s.LastReport))
	header(&b, "sentinel_alerts_total", "Queued alerts handled by this instance, by channel and outcome.", "counter")
	for _, channel := range Channels {
		for _, outcome := range Outcomes {
			fmt.Fprintf(&b, "sentinel_alerts_total{channel=%q,outcome=%q} %d\n", channel, outcome, s.Alerts[channel][outcome])
		}
	}
	header(&b, "sentinel_direct_alerts_total", "Alerts sent by the sentinel itself while the database was unreachable, by outcome.", "counter")
	for _, outcome := range NoticeOutcomes {
		fmt.Fprintf(&b, "sentinel_direct_alerts_total{outcome=%q} %d\n", outcome, s.Notices[outcome])
	}
	header(&b, "sentinel_channels_revision", "Revision of the alert channels in memory, -1 before the first load.", "gauge")
	fmt.Fprintf(&b, "sentinel_channels_revision %d\n", s.ChannelsRevision)
	header(&b, "sentinel_channel_configured", "1 when the alert channel is enabled in the channels in memory.", "gauge")
	fmt.Fprintf(&b, "sentinel_channel_configured{channel=\"telegram\"} %d\n", flag(s.TelegramConfigured))
	fmt.Fprintf(&b, "sentinel_channel_configured{channel=\"email\"} %d\n", flag(s.EmailConfigured))
	header(&b, "sentinel_database_reachable", "1 when the last database call reached the API.", "gauge")
	fmt.Fprintf(&b, "sentinel_database_reachable %d\n", flag(s.DatabaseReachable))
	header(&b, "sentinel_database_down", "1 while an API/database outage has been declared.", "gauge")
	fmt.Fprintf(&b, "sentinel_database_down %d\n", flag(s.DatabaseDown))
	header(&b, "sentinel_database_outages_total", "API/database outages declared since start.", "counter")
	fmt.Fprintf(&b, "sentinel_database_outages_total %d\n", s.Outages)
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

func unix(t time.Time) int64 {
	if t.IsZero() {
		return 0
	}
	return t.Unix()
}
