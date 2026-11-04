package agent

import (
	"context"
	"errors"
	"time"

	"olt-social/backup/internal/disk"
	"olt-social/backup/internal/restic"
	"olt-social/backup/internal/settings"
	"olt-social/backup/internal/state"
)

const (
	retryFirst = 15 * time.Minute
	retryMax   = 6 * time.Hour
)

func RetryDelay(failures int) time.Duration {
	d := retryFirst
	for i := 1; i < failures && d < retryMax; i++ {
		d *= 2
	}
	return min(d, retryMax)
}

func retryAllowed(j state.Job, now time.Time) bool {
	return j.Failures == 0 || !now.Before(j.LastAttempt.Add(RetryDelay(j.Failures)))
}

func weeklyDue(p state.Persisted, t settings.Timetable, job string, now time.Time) bool {
	anchor := p.Job(job).LastAttempt
	if anchor.IsZero() {
		anchor = p.WeeklyFrom
	}
	return !anchor.IsZero() && !t.NextWeekly(anchor).After(now)
}

func Due(p state.Persisted, t settings.Timetable, restoreTest bool, now time.Time) []string {
	var due []string
	base := p.Job(JobBase)
	if (p.NeedBase || p.Base == nil || !t.NextBase(base.LastOK).After(now)) && retryAllowed(base, now) {
		due = append(due, JobBase)
	}
	files := p.Job(JobFiles)
	if !t.NextBase(files.LastOK).After(now) && retryAllowed(files, now) {
		due = append(due, JobFiles)
	}
	for _, job := range []string{JobPrune, JobCheck} {
		if weeklyDue(p, t, job, now) {
			due = append(due, job)
		}
	}
	if restoreTest && p.Base != nil && weeklyDue(p, t, JobRestoreTest, now) {
		due = append(due, JobRestoreTest)
	}
	return due
}

func (a *Agent) jobLoop(ctx context.Context) {
	for ctx.Err() == nil {
		if a.ensureRepository(ctx) {
			now := a.now()
			a.schedule(now)
			if job, ok := a.next(now); ok {
				a.execute(ctx, job)
				continue
			}
		}
		a.idle(ctx, a.opts.Tick, a.wakeJob)
	}
}

func (a *Agent) schedule(now time.Time) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.persist.WeeklyFrom.IsZero() {
		a.persist.WeeklyFrom = now
		a.saveLocked()
	}
	a.enqueueLocked(Due(a.persist, a.table, a.current.RestoreTest, now)...)
}

func (a *Agent) next(now time.Time) (string, bool) {
	a.mu.Lock()
	defer a.mu.Unlock()
	last := a.persist.Offsite.LastStartedAt
	if last.IsZero() || !now.Before(last.Add(a.table.Offsite)) {
		return JobOffsite, true
	}
	if len(a.queue) == 0 {
		return "", false
	}
	job := a.queue[0]
	a.queue = a.queue[1:]
	return job, true
}

func (a *Agent) execute(ctx context.Context, job string) {
	a.mu.Lock()
	a.running = job
	repo := a.repo
	a.mu.Unlock()
	a.kickHeartbeat()
	defer func() {
		a.mu.Lock()
		a.running = ""
		a.mu.Unlock()
		a.kickHeartbeat()
	}()
	switch job {
	case JobOffsite:
		a.runOffsite(ctx, repo)
	case JobBase:
		a.runBase(ctx, repo)
	case JobFiles:
		a.runFiles(ctx, repo)
	case JobForget:
		a.runRetention(ctx, repo, false)
	case JobPrune:
		a.runRetention(ctx, repo, true)
	case JobCheck:
		a.runCheck(ctx, repo)
	case JobRestoreTest:
		a.runRestoreTest(ctx, repo)
	}
}

func (a *Agent) ensureRepository(ctx context.Context) bool {
	a.mu.Lock()
	configured, dirty, ready, checked, creds := a.configured, a.repoDirty, a.repoReady, a.repoAt, a.creds
	local := a.current.Local()
	a.mu.Unlock()
	if !configured {
		return false
	}
	if ready && !dirty {
		return true
	}
	if !dirty && !checked.IsZero() && a.now().Sub(checked) < a.opts.RepositoryRetry {
		return false
	}
	repo := a.opts.Repository(creds)
	c, cancel := context.WithTimeout(ctx, 5*time.Minute)
	var err error
	if local {
		err = a.opts.LocalCheck(creds.Repository)
	}
	if err == nil {
		open, stopOpen := context.WithTimeout(c, a.opts.OpenTimeout)
		err = repo.Open(open)
		stopOpen()
	}
	created := false
	if errors.Is(err, restic.ErrNoRepository) {
		if err = repo.Init(c); err == nil {
			created = true
		}
	}
	if err == nil {
		if uerr := repo.Unlock(c); uerr != nil {
			a.log.Warn("Could not remove stale repository locks", "error", uerr)
		}
	}
	cancel()
	if ctx.Err() != nil {
		return false
	}
	a.mu.Lock()
	if a.creds != creds || !a.configured {
		a.mu.Unlock()
		return false
	}
	a.repoAt, a.repoDirty = a.now(), false
	before := a.repoErr
	if err != nil {
		a.repoReady, a.repo, a.repoErr = false, nil, repositoryError(err)
	} else {
		a.repoReady, a.repo, a.repoErr = true, repo, ""
		if a.persist.Repository != creds.Repository || created {
			a.persist.Repository = creds.Repository
			a.persist.NeedBase = true
			a.persist.Offsite = state.Offsite{}
			a.persist.SetJob(JobFiles, state.Job{})
			if a.persist.Base != nil {
				a.persist.Base.SnapshotID = ""
			}
			a.saveLocked()
		}
	}
	after := a.repoErr
	a.mu.Unlock()
	switch {
	case err != nil && after != before:
		a.log.Warn("Backup repository cannot be used", "error", after)
	case err == nil && created:
		a.log.Info("Backup repository created", "repository", settings.SafeRepository(creds.Repository))
	case err == nil:
		a.log.Info("Backup repository opened", "repository", settings.SafeRepository(creds.Repository))
	}
	a.kickHeartbeat()
	notify(a.wakeRecv)
	return err == nil
}

func repositoryError(err error) string {
	switch {
	case errors.Is(err, disk.ErrNotDirectory), errors.Is(err, disk.ErrNotMounted):
		return clip("Folder repositori lokal belum di-mount ke container backup (BACKUP_LOCAL_REPO_DIR): " + err.Error())
	case errors.Is(err, disk.ErrNotWritable):
		return clip("Folder repositori lokal tidak bisa ditulis layanan backup; jadikan pemiliknya uid 10001: " + err.Error())
	case errors.Is(err, restic.ErrWrongPassword):
		return "Password enkripsi salah: repositori di alamat ini sudah ada dengan password lain"
	case errors.Is(err, restic.ErrLocked):
		return clip("Repositori sedang dikunci proses lain: " + errDetail(err))
	default:
		return clip("Repositori backup tidak bisa dibuka: " + errDetail(err))
	}
}
