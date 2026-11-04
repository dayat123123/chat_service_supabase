package agent

import (
	"fmt"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	"olt-social/backup/internal/disk"
	"olt-social/backup/internal/restic"
	"olt-social/backup/internal/state"
)

func TestLocalRepositoryRunsWithoutAWSCredentials(t *testing.T) {
	h := newHarness(t, localSettings(20))
	h.repo.openErr = fmt.Errorf("%w: restic exited with status 10", restic.ErrNoRepository)
	h.start()

	eventually(t, "base backup", func() bool { _, ok := h.store.run(JobBase, state.StatusOK); return ok })
	if calls := h.repo.called(); !slices.Equal(calls[:3], []string{"open", "init", "unlock"}) {
		t.Fatalf("repository bootstrap = %v", calls[:3])
	}
	if h.checks.Load() == 0 {
		t.Fatal("local folder was never checked")
	}
	h.credMu.Lock()
	creds := slices.Clone(h.creds)
	h.credMu.Unlock()
	env := creds[0].Env()
	if creds[0].Repository != localRepo || !slices.Equal(env, []string{"RESTIC_REPOSITORY=" + localRepo, "RESTIC_PASSWORD=" + secretPassword}) {
		t.Fatalf("creds env = %v", env)
	}
	eventually(t, "repository disk in heartbeat", func() bool {
		return h.store.sawBeat(func(r state.Report) bool {
			return r.RepositoryReady && r.RepositoryDisk != nil && r.RepositoryDisk.TotalBytes == 200<<30 &&
				r.RepositoryDisk.AvailBytes == 30<<30 && r.Disk.TotalBytes == 100<<30
		})
	})
	m := h.agent.Metrics()
	if m.RepoDiskTotal != 200<<30 || m.RepoDiskAvail != 30<<30 || m.DiskTotal != 100<<30 {
		t.Fatalf("metrics = %+v", m)
	}
	if strings.Contains(h.logText(), secretPassword) {
		t.Fatal("password leaked into the log")
	}
}

func TestS3RepositoryReportsNoRepositoryDisk(t *testing.T) {
	h := newHarness(t, validSettings(21))
	h.start()
	eventually(t, "ready heartbeat", func() bool {
		return h.store.sawBeat(func(r state.Report) bool { return r.RepositoryReady })
	})
	if h.store.sawBeat(func(r state.Report) bool { return r.RepositoryDisk != nil }) {
		t.Fatal("S3 repository must not report a repository disk")
	}
	if h.checks.Load() != 0 {
		t.Fatal("S3 repository must not run the local folder check")
	}
	if m := h.agent.Metrics(); m.RepoDiskTotal != 0 || m.RepoDiskAvail != 0 {
		t.Fatalf("metrics = %+v", m)
	}
}

func TestUnmountedLocalRepositoryIsReportedUntilFixed(t *testing.T) {
	h := newHarness(t, localSettings(22))
	missing := error(fmt.Errorf("%w: %s", disk.ErrNotMounted, localRepo))
	h.local.Store(&missing)
	h.start()
	eventually(t, "mount error", func() bool {
		return h.store.sawBeat(func(r state.Report) bool {
			return !r.RepositoryReady && r.Error != nil && strings.Contains(*r.Error, "belum di-mount") &&
				strings.Contains(*r.Error, "BACKUP_LOCAL_REPO_DIR")
		})
	})
	if slices.Contains(h.repo.called(), "open") || slices.Contains(h.repo.called(), "init") {
		t.Fatal("restic must not touch an unmounted folder")
	}
	readonly := error(fmt.Errorf("%w: %s (uid 10001)", disk.ErrNotWritable, localRepo))
	h.local.Store(&readonly)
	eventually(t, "permission error", func() bool {
		return h.store.sawBeat(func(r state.Report) bool {
			return r.Error != nil && strings.Contains(*r.Error, "tidak bisa ditulis") && strings.Contains(*r.Error, "uid 10001")
		})
	})
	h.local.Store(nil)
	eventually(t, "repository ready", func() bool {
		return h.store.sawBeat(func(r state.Report) bool { return r.RepositoryReady && r.Error == nil })
	})
}

func TestLocalRepositoryPathMustMatchTheMount(t *testing.T) {
	s := localSettings(23)
	s.Repository = "/mnt/elsewhere"
	h := newHarness(t, s)
	h.start()
	eventually(t, "config error", func() bool {
		return h.store.sawBeat(func(r state.Report) bool {
			return r.Error != nil && strings.Contains(*r.Error, "LOCAL_REPO_DIR")
		})
	})
	if h.made.Load() != 0 {
		t.Fatal("a mismatched folder must not open the repository")
	}
}

func TestRecreatedLocalRepositoryTakesANewBase(t *testing.T) {
	h := newHarness(t, localSettings(24))
	at := time.Now().Add(-time.Hour)
	prev := state.Persisted{Repository: localRepo, SystemID: "7702039750691532834", WeeklyFrom: at,
		Base:    &state.Base{Label: "base-old", StartWAL: "000000010000000000000001", SnapshotID: "old", StartedAt: at, FinishedAt: at},
		Offsite: state.Offsite{LastStartedAt: at, LastOKAt: at}}
	prev.SetJob(JobBase, state.Job{LastOK: time.Now(), LastAttempt: time.Now()})
	prev.SetJob(JobFiles, state.Job{LastOK: time.Now(), LastAttempt: time.Now()})
	if err := state.Save(filepath.Join(h.dir, "state.json"), prev); err != nil {
		t.Fatal(err)
	}
	h.repo.openErr = fmt.Errorf("%w: restic exited with status 10", restic.ErrNoRepository)
	h.start()
	eventually(t, "new base in the empty repository", func() bool { _, ok := h.store.run(JobBase, state.StatusOK); return ok })
	eventually(t, "files backup", func() bool { _, ok := h.store.run(JobFiles, state.StatusOK); return ok })
}
