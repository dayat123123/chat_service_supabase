package metrics

import (
	"fmt"
	"net/http"
	"strings"
	"time"
)

var (
	Kinds    = []string{"base", "files", "wal", "prune", "check", "restore_test"}
	Statuses = []string{"ok", "failed"}
	Busy     = []string{"base", "files", "offsite", "prune", "check", "restore_test"}
)

type Snapshot struct {
	Configured        bool
	RepositoryReady   bool
	Streaming         bool
	SlotLost          bool
	Busy              string
	Runs              map[string]uint64
	ReceiverRestarts  uint64
	WALLocalBytes     int64
	OffsitePending    int64
	LocalBaseBytes    int64
	DiskTotal         int64
	DiskAvail         int64
	RepoDiskTotal     int64
	RepoDiskAvail     int64
	LastWALReceived   time.Time
	LastOffsiteOK     time.Time
	LastBaseOK        time.Time
	LastRestoreTestOK time.Time
}

func RunKey(kind, status string) string {
	return kind + "/" + status
}

func Handler(snapshot func() Snapshot) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		_, _ = w.Write([]byte(Render(snapshot())))
	})
}

func Render(s Snapshot) string {
	var b strings.Builder
	gauge(&b, "backup_configured", "1 when a valid backup target is configured.", flag(s.Configured))
	gauge(&b, "backup_repository_ready", "1 when the restic repository opened with the configured password.", flag(s.RepositoryReady))
	gauge(&b, "backup_wal_streaming", "1 while pg_receivewal is streaming.", flag(s.Streaming))
	gauge(&b, "backup_wal_slot_lost", "1 after the replication slot was lost until a new base backup succeeds.", flag(s.SlotLost))
	header(&b, "backup_busy", "1 for the job currently running.", "gauge")
	for _, kind := range Busy {
		fmt.Fprintf(&b, "backup_busy{job=%q} %d\n", kind, flag(s.Busy == kind))
	}
	header(&b, "backup_runs_total", "Finished jobs recorded by this instance, by kind and status.", "counter")
	for _, kind := range Kinds {
		for _, status := range Statuses {
			fmt.Fprintf(&b, "backup_runs_total{kind=%q,status=%q} %d\n", kind, status, s.Runs[RunKey(kind, status)])
		}
	}
	header(&b, "backup_wal_receiver_restarts_total", "Times pg_receivewal exited and was started again.", "counter")
	fmt.Fprintf(&b, "backup_wal_receiver_restarts_total %d\n", s.ReceiverRestarts)
	gauge(&b, "backup_wal_local_bytes", "WAL bytes kept in the staging volume.", s.WALLocalBytes)
	gauge(&b, "backup_offsite_pending_bytes", "WAL bytes written since the last successful offsite copy.", s.OffsitePending)
	gauge(&b, "backup_local_base_bytes", "Size of the newest local base backup.", s.LocalBaseBytes)
	gauge(&b, "backup_disk_total_bytes", "Size of the staging file system.", s.DiskTotal)
	gauge(&b, "backup_disk_avail_bytes", "Free space of the staging file system.", s.DiskAvail)
	gauge(&b, "backup_repository_disk_total_bytes", "Size of the file system holding a local repository, 0 for S3.", s.RepoDiskTotal)
	gauge(&b, "backup_repository_disk_avail_bytes", "Free space of the file system holding a local repository, 0 for S3.", s.RepoDiskAvail)
	gauge(&b, "backup_wal_last_received_timestamp_seconds", "Unix time WAL was last written locally, 0 if never.", unix(s.LastWALReceived))
	gauge(&b, "backup_offsite_last_success_timestamp_seconds", "Unix time of the last successful offsite WAL copy, 0 if never.", unix(s.LastOffsiteOK))
	gauge(&b, "backup_base_last_success_timestamp_seconds", "Unix time of the last successful base backup, 0 if never.", unix(s.LastBaseOK))
	gauge(&b, "backup_restore_test_last_success_timestamp_seconds", "Unix time of the last successful restore test, 0 if never.", unix(s.LastRestoreTestOK))
	return b.String()
}

func gauge(b *strings.Builder, name, help string, value int64) {
	header(b, name, help, "gauge")
	fmt.Fprintf(b, "%s %d\n", name, value)
}

func header(b *strings.Builder, name, help, kind string) {
	fmt.Fprintf(b, "# HELP %s %s\n# TYPE %s %s\n", name, help, name, kind)
}

func flag(v bool) int64 {
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
