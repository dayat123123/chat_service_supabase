package agent

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"
	"unicode"
	"unicode/utf8"

	"olt-social/backup/internal/disk"
	"olt-social/backup/internal/restic"
	"olt-social/backup/internal/restore"
	"olt-social/backup/internal/runner"
	"olt-social/backup/internal/state"
	"olt-social/backup/internal/wal"
)

const checkSubset = "2%"

type outcome struct {
	bytes    *int64
	snapshot string
	detail   map[string]any
}

func errDetail(err error) string {
	return runner.Detail(err)
}

func (a *Agent) finish(ctx context.Context, job, kind string, started time.Time, out outcome, err error) {
	if err != nil && ctx.Err() != nil {
		a.log.Info("Backup job interrupted by shutdown", "job", job)
		return
	}
	finished := a.now()
	msg := ""
	if err != nil {
		msg = sentence(clip(err.Error()))
	}
	a.mu.Lock()
	j := a.persist.Job(job)
	j.LastAttempt = started
	if err == nil {
		j.LastOK, j.Failures, j.LastError = finished, 0, ""
	} else {
		j.Failures++
		j.LastError = msg
	}
	a.persist.SetJob(job, j)
	a.saveLocked()
	a.mu.Unlock()
	status := state.StatusOK
	if err != nil {
		status = state.StatusFailed
		a.log.Warn("Backup job failed", "job", job, "error", msg, "failures", j.Failures)
	} else {
		a.log.Info("Backup job finished", "job", job, "took", finished.Sub(started).Round(time.Second).String(), "snapshot", out.snapshot)
	}
	if out.detail == nil {
		out.detail = map[string]any{}
	}
	out.detail["duration_s"] = int64(finished.Sub(started).Seconds())
	a.record(ctx, state.Run{Kind: kind, Status: status, StartedAt: started.UTC(), FinishedAt: finished.UTC(),
		Bytes: out.bytes, SnapshotID: state.Text(out.snapshot), Detail: out.detail, Error: state.Text(msg)})
}

func (a *Agent) runOffsite(ctx context.Context, repo Repository) {
	started := a.now()
	a.mu.Lock()
	a.persist.Offsite.LastStartedAt = started
	a.saveLocked()
	a.mu.Unlock()
	dirs := a.walDirs()
	files, err := wal.List(dirs...)
	if err == nil && len(files) == 0 {
		return
	}
	sent := map[string]bool{}
	for _, f := range files {
		if f.Complete() {
			sent[f.Path()] = true
		}
	}
	var sum restic.Summary
	if err == nil {
		sum, err = repo.Backup(ctx, restic.BackupRequest{Paths: dirs, Tags: []string{restic.TagWAL}})
		if errors.Is(err, restic.ErrIncomplete) && sum.SnapshotID != "" {
			err = nil
		}
	}
	if err != nil && ctx.Err() != nil {
		return
	}
	finished := a.now()
	if err != nil {
		msg := clip("Kirim WAL ke repositori gagal: " + errDetail(err))
		a.mu.Lock()
		a.offsiteErr = msg
		a.mu.Unlock()
		a.kickHeartbeat()
		a.log.Warn("Offsite WAL copy failed", "error", msg)
		a.record(ctx, state.Run{Kind: RecordWAL, Status: state.StatusFailed, StartedAt: started.UTC(), FinishedAt: finished.UTC(),
			Detail: map[string]any{"files": len(files)}, Error: state.Text(msg)})
		return
	}
	a.mu.Lock()
	recovered := a.offsiteErr != ""
	a.offsiteErr = ""
	a.persist.Offsite.LastOKAt, a.persist.Offsite.SentFrom, a.persist.Offsite.LastSnapshot = finished, started, sum.SnapshotID
	due := finished.Sub(a.persist.Offsite.LastRecordAt) >= time.Hour || recovered
	if due {
		a.persist.Offsite.LastRecordAt = finished
	}
	a.saveLocked()
	a.mu.Unlock()
	removed := a.cleanupWAL(sent, dirs)
	a.kickHeartbeat()
	a.log.Debug("Offsite WAL copy finished", "snapshot", sum.SnapshotID, "files", len(files), "data_added", sum.DataAdded, "removed_local", removed)
	if due {
		a.record(ctx, state.Run{Kind: RecordWAL, Status: state.StatusOK, StartedAt: started.UTC(), FinishedAt: finished.UTC(),
			Bytes: state.Int(sum.TotalBytesProcessed), SnapshotID: state.Text(sum.SnapshotID),
			Detail: map[string]any{"files": len(files), "data_added": sum.DataAdded, "removed_local": removed}})
	}
}

func (a *Agent) cleanupWAL(sent map[string]bool, dirs []string) int {
	a.walMu.Lock()
	defer a.walMu.Unlock()
	a.mu.Lock()
	var base state.Base
	if a.persist.Base != nil {
		base = *a.persist.Base
	}
	a.mu.Unlock()
	start, ok := wal.ParseSegment(base.StartWAL)
	if base.SnapshotID == "" || !ok {
		return 0
	}
	files, err := wal.List(a.walDir())
	if err != nil {
		return 0
	}
	names := map[string]bool{}
	for _, f := range files {
		if sent[f.Path()] {
			names[f.Name] = true
		}
	}
	removed := 0
	for _, f := range wal.Obsolete(files, names, start) {
		if err := os.Remove(f.Path()); err == nil {
			removed++
		}
	}
	for _, dir := range dirs {
		if dir == a.walDir() {
			continue
		}
		if at, ok := detachedAt(dir); ok && at.Before(base.StartedAt) {
			if err := os.RemoveAll(dir); err == nil {
				a.log.Info("Removed detached WAL that is already offsite", "path", filepath.Base(dir))
			}
		}
	}
	return removed
}

func (a *Agent) runBase(ctx context.Context, repo Repository) {
	started := a.now()
	out, err := a.baseBackup(ctx, repo, started)
	a.finish(ctx, JobBase, JobBase, started, out, err)
	if err == nil {
		a.mu.Lock()
		a.enqueueFrontLocked(JobFiles, JobForget)
		a.mu.Unlock()
	}
}

func (a *Agent) awaitStreaming(ctx context.Context) error {
	deadline := a.now().Add(a.opts.BaseWait)
	for {
		a.mu.Lock()
		streaming := a.streaming
		a.mu.Unlock()
		if streaming {
			c, cancel := context.WithTimeout(ctx, a.opts.RequestTimeout)
			slot, err := a.opts.Database.Slot(c)
			cancel()
			if err == nil && slot.Exists && slot.Reserved && !slot.Lost() {
				return nil
			}
		}
		if !a.now().Before(deadline) {
			return errors.New("WAL streaming belum berjalan, base backup ditunda (tanpa streaming WAL, pemulihan titik waktu dari base ini tidak lengkap)")
		}
		if !a.idle(ctx, a.opts.Tick, make(chan struct{})) {
			return ctx.Err()
		}
	}
}

func (a *Agent) baseSpace(ctx context.Context) (int64, error) {
	c, cancel := context.WithTimeout(ctx, a.opts.RequestTimeout)
	est, err := a.opts.Database.DatabaseBytes(c)
	cancel()
	a.mu.Lock()
	var local state.Base
	if a.persist.Base != nil {
		local = *a.persist.Base
	}
	a.mu.Unlock()
	if err != nil {
		if local.Bytes == 0 {
			return 0, describe("Ukuran database tidak bisa diperkirakan", err)
		}
		est = local.Bytes
	}
	need := est * 12 / 10
	usage, err := a.opts.Disk(a.opts.DataDir)
	if err != nil {
		return est, fmt.Errorf("ruang disk staging tidak bisa dibaca: %v", err)
	}
	if usage.Avail >= need {
		return est, nil
	}
	if local.Dir != "" && local.SnapshotID != "" && usage.Avail+local.Bytes >= need {
		if err := os.RemoveAll(local.Dir); err == nil {
			a.mu.Lock()
			if a.persist.Base != nil {
				a.persist.Base.Dir = ""
			}
			a.saveLocked()
			a.mu.Unlock()
			a.log.Info("Removed the previous local base backup to make room; it is already offsite", "label", local.Label)
			return est, nil
		}
	}
	return est, fmt.Errorf("Ruang disk staging tidak cukup untuk base backup: tersedia %s, dibutuhkan sekitar %s (ukuran database %s × 1,2)",
		human(usage.Avail), human(need), human(est))
}

func (a *Agent) baseBackup(ctx context.Context, repo Repository, started time.Time) (outcome, error) {
	if err := a.awaitStreaming(ctx); err != nil {
		return outcome{}, err
	}
	est, err := a.baseSpace(ctx)
	if err != nil {
		return outcome{}, err
	}
	label := "base-" + started.UTC().Format(stampLayout)
	dir := filepath.Join(a.baseRoot(), label)
	_ = os.RemoveAll(dir)
	discard := func(err error) (outcome, error) {
		_ = os.RemoveAll(dir)
		return outcome{detail: map[string]any{"label": label}}, err
	}
	if err := a.opts.Database.BaseBackup(ctx, dir, label); err != nil {
		return discard(describe("pg_basebackup gagal", err))
	}
	if err := a.opts.Database.VerifyBackup(ctx, dir); err != nil {
		return discard(describe("pg_verifybackup gagal", err))
	}
	raw, err := os.ReadFile(filepath.Join(dir, "backup_label"))
	if err != nil {
		return discard(fmt.Errorf("backup_label tidak ada di hasil pg_basebackup: %v", err))
	}
	start, err := wal.StartSegment(raw)
	if err != nil {
		return discard(err)
	}
	size, err := disk.Size(dir)
	if err != nil {
		return discard(err)
	}
	finished := a.now()
	sum, err := repo.Backup(ctx, restic.BackupRequest{Paths: []string{dir}, Tags: []string{restic.TagBase, label}})
	if err != nil {
		return discard(describe("Upload base backup ke repositori gagal", err))
	}
	a.mu.Lock()
	a.persist.Base = &state.Base{Label: label, Dir: dir, StartWAL: start.Name(), SnapshotID: sum.SnapshotID,
		StartedAt: started, FinishedAt: finished, Bytes: size}
	if a.persist.ResetAt.Before(started) {
		a.persist.NeedBase, a.persist.SlotLostAt = false, time.Time{}
	}
	a.saveLocked()
	a.mu.Unlock()
	a.removeBasesExcept(dir)
	a.kickHeartbeat()
	return outcome{bytes: state.Int(size), snapshot: sum.SnapshotID, detail: map[string]any{
		"label": label, "start_wal": start.Name(), "estimated_db_bytes": est, "data_added": sum.DataAdded,
		"backup_s": int64(finished.Sub(started).Seconds()), "verified": true,
	}}, nil
}

func (a *Agent) runFiles(ctx context.Context, repo Repository) {
	started := a.now()
	out, err := a.filesBackup(ctx, repo)
	a.finish(ctx, JobFiles, JobFiles, started, out, err)
}

func (a *Agent) filesBackup(ctx context.Context, repo Repository) (outcome, error) {
	if _, err := os.Stat(a.opts.StorageDir); err != nil {
		return outcome{}, fmt.Errorf("folder storage %s tidak bisa dibaca: %v", a.opts.StorageDir, err)
	}
	sum, err := repo.Backup(ctx, restic.BackupRequest{Paths: []string{a.opts.StorageDir}, Tags: []string{restic.TagFiles}})
	out := outcome{bytes: state.Int(sum.TotalBytesProcessed), snapshot: sum.SnapshotID,
		detail: map[string]any{"files": sum.TotalFilesProcessed, "data_added": sum.DataAdded}}
	if errors.Is(err, restic.ErrIncomplete) {
		return out, describe(fmt.Sprintf("Sebagian file storage tidak bisa dibaca (snapshot %s tetap dibuat)", sum.SnapshotID), err)
	}
	if err != nil {
		return outcome{}, describe("Backup file storage gagal", err)
	}
	return out, nil
}

func (a *Agent) runRetention(ctx context.Context, repo Repository, prune bool) {
	started := a.now()
	a.mu.Lock()
	r := a.current.Retention
	a.mu.Unlock()
	job := JobForget
	if prune {
		job = JobPrune
	}
	removed := map[string]int{}
	out := outcome{detail: map[string]any{"prune": prune, "removed": removed}}
	err := func() error {
		policies := []restic.Policy{
			{Tag: restic.TagBase, KeepDaily: r.Daily, KeepWeekly: r.Weekly, KeepMonthly: r.Monthly},
			{Tag: restic.TagFiles, KeepDaily: r.Daily, KeepWeekly: r.Weekly, KeepMonthly: r.Monthly},
			{Tag: restic.TagWAL, KeepWithin: fmt.Sprintf("%dd", r.WALDays)},
		}
		for _, p := range policies {
			n, err := repo.Forget(ctx, p)
			if err != nil {
				return describe("restic forget "+p.Tag+" gagal", err)
			}
			removed[p.Tag] = n
		}
		if prune {
			return describe("restic prune gagal", repo.Prune(ctx))
		}
		return nil
	}()
	a.finish(ctx, job, JobPrune, started, out, err)
}

func (a *Agent) runCheck(ctx context.Context, repo Repository) {
	started := a.now()
	err := describe("restic check menemukan masalah", repo.Check(ctx, checkSubset))
	a.finish(ctx, JobCheck, JobCheck, started, outcome{detail: map[string]any{"read_data_subset": checkSubset}}, err)
}

func (a *Agent) runRestoreTest(ctx context.Context, repo Repository) {
	started := a.now()
	c, cancel := context.WithTimeout(ctx, a.opts.RestoreTestTimeout)
	defer cancel()
	a.runOffsite(c, repo)
	out, err := a.restoreTest(c, repo)
	if err != nil && ctx.Err() == nil && errors.Is(c.Err(), context.DeadlineExceeded) {
		err = fmt.Errorf("uji restore melewati batas waktu %s: %w", a.opts.RestoreTestTimeout, err)
	}
	a.finish(ctx, JobRestoreTest, JobRestoreTest, started, out, err)
}

func (a *Agent) restoreTest(ctx context.Context, repo Repository) (outcome, error) {
	root := a.restoreRoot()
	_ = os.RemoveAll(root)
	defer func() {
		if err := os.RemoveAll(root); err != nil {
			a.log.Error("Could not remove the restore test folder", "error", err)
		}
	}()
	out := outcome{detail: map[string]any{}}
	snaps, err := repo.Snapshots(ctx, "")
	if err != nil {
		return out, describe("Daftar snapshot tidak bisa dibaca", err)
	}
	plan, err := restore.Choose(snaps, time.Time{})
	if err != nil {
		return out, err
	}
	out.snapshot = plan.Base.ID
	out.detail["base_label"] = plan.Base.Label()
	out.detail["base_snapshot"] = plan.Base.Short()
	if plan.WAL != nil {
		out.detail["wal_snapshot"] = plan.WAL.Short()
	}
	usage, err := a.opts.Disk(a.opts.DataDir)
	if err != nil {
		return out, fmt.Errorf("ruang disk staging tidak bisa dibaca: %v", err)
	}
	if need := plan.Bytes() * 12 / 10; usage.Avail < need {
		return out, fmt.Errorf("Ruang disk staging tidak cukup untuk uji restore: tersedia %s, dibutuhkan sekitar %s", human(usage.Avail), human(need))
	}
	srv := restore.NewServer(root)
	prepared, err := restore.Prepare(ctx, repo, plan, srv.DataDir)
	out.detail["start_wal"] = prepared.StartWAL
	out.detail["wal_segments"] = prepared.Segments
	if err != nil {
		return out, err
	}
	out.bytes = state.Int(prepared.Bytes)
	if err := a.opts.Database.VerifyBackup(ctx, srv.DataDir, restore.WALDir); err != nil {
		return out, describe("pg_verifybackup pada hasil restore gagal", err)
	}
	if err := os.WriteFile(filepath.Join(srv.DataDir, "recovery.signal"), nil, 0o600); err != nil {
		return out, err
	}
	if err := restore.WriteServerConfig(srv); err != nil {
		return out, err
	}
	result, err := restore.Probe(ctx, a.opts.Database, srv, a.opts.ProbePoll)
	if err != nil {
		return out, err
	}
	out.detail["recovered_until"] = result.RecoveredUntil
	out.detail["last_message_at"] = result.LastMessageAt
	out.detail["tables"] = result.Tables
	return out, nil
}

func sentence(text string) string {
	r, size := utf8.DecodeRuneInString(text)
	if r == utf8.RuneError {
		return text
	}
	return string(unicode.ToUpper(r)) + text[size:]
}
