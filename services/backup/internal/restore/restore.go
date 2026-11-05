package restore

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"olt-social/backup/internal/disk"
	"olt-social/backup/internal/pg"
	"olt-social/backup/internal/restic"
	"olt-social/backup/internal/wal"
)

const (
	WALDir     = "restore_wal"
	stagingDir = ".olt-restore-staging"
	timeLayout = "2006-01-02 15:04:05.999999-07"
)

type Repository interface {
	Restore(ctx context.Context, spec, target string) error
}

type Plan struct {
	Base   restic.Snapshot
	WAL    *restic.Snapshot
	Target time.Time
}

func (p Plan) Bytes() int64 {
	n := p.Base.Bytes()
	if p.WAL != nil {
		n += p.WAL.Bytes()
	}
	return n
}

func Choose(snaps []restic.Snapshot, target time.Time) (Plan, error) {
	var bases, wals []restic.Snapshot
	for _, s := range snaps {
		switch {
		case s.Has(restic.TagBase) && len(s.Paths) > 0:
			bases = append(bases, s)
		case s.Has(restic.TagWAL):
			wals = append(wals, s)
		}
	}
	if len(bases) == 0 {
		return Plan{}, errors.New("belum ada base backup di repositori")
	}
	if target.IsZero() {
		plan := Plan{Base: bases[len(bases)-1]}
		if len(wals) > 0 {
			plan.WAL = &wals[len(wals)-1]
		}
		return plan, nil
	}
	plan := Plan{Target: target}
	found := false
	for _, b := range bases {
		if b.Time.Before(target) {
			plan.Base, found = b, true
		}
	}
	if !found {
		return Plan{}, fmt.Errorf("no base backup before %s; the oldest base is %s",
			target.UTC().Format(time.RFC3339), bases[0].Time.UTC().Format(time.RFC3339))
	}
	for i := range wals {
		if !wals[i].Time.Before(target) {
			plan.WAL = &wals[i]
			break
		}
	}
	if plan.WAL == nil {
		newest := "none"
		if len(wals) > 0 {
			newest = wals[len(wals)-1].Time.UTC().Format(time.RFC3339)
		}
		return Plan{}, fmt.Errorf("target time %s is after the newest WAL upload (%s); choose an earlier time or latest",
			target.UTC().Format(time.RFC3339), newest)
	}
	return plan, nil
}

type Prepared struct {
	StartWAL string
	Segments int
	WALBytes int64
	Promoted []string
	Bytes    int64
}

func Prepare(ctx context.Context, repo Repository, plan Plan, dataDir string) (Prepared, error) {
	var out Prepared
	if err := os.MkdirAll(dataDir, 0o700); err != nil {
		return out, err
	}
	if err := repo.Restore(ctx, plan.Base.ID+":"+plan.Base.Paths[0], dataDir); err != nil {
		return out, fmt.Errorf("restore base %s gagal: %w", plan.Base.Short(), err)
	}
	label, err := os.ReadFile(filepath.Join(dataDir, "backup_label"))
	if err != nil {
		return out, fmt.Errorf("snapshot %s bukan base backup (backup_label tidak ada)", plan.Base.Short())
	}
	start, err := wal.StartSegment(label)
	if err != nil {
		return out, err
	}
	out.StartWAL = start.Name()
	walDir := filepath.Join(dataDir, WALDir)
	if err := os.MkdirAll(walDir, 0o700); err != nil {
		return out, err
	}
	if plan.WAL != nil {
		staging := filepath.Join(dataDir, stagingDir)
		if err := repo.Restore(ctx, plan.WAL.ID, staging); err != nil {
			return out, fmt.Errorf("restore WAL %s gagal: %w", plan.WAL.Short(), err)
		}
		if _, err := wal.Collect(staging, walDir); err != nil {
			return out, err
		}
		if err := os.RemoveAll(staging); err != nil {
			return out, err
		}
	}
	if out.Promoted, err = wal.PromotePartials(walDir); err != nil {
		return out, err
	}
	restored, err := wal.List(walDir)
	if err != nil {
		return out, err
	}
	shipped, err := wal.List(filepath.Join(dataDir, "pg_wal"))
	if err != nil {
		return out, err
	}
	out.Segments, out.WALBytes = len(restored), wal.Bytes(restored)
	if missing := wal.Missing(append(restored, shipped...), start, plan.Target, 5); len(missing) > 0 {
		return out, fmt.Errorf("rantai WAL terputus: segmen %s tidak ada di backup (mulai dari %s)", strings.Join(missing, ", "), start.Name())
	}
	if err := os.Chmod(dataDir, 0o700); err != nil {
		return out, err
	}
	out.Bytes, err = disk.Size(dataDir)
	return out, err
}

func EnsureEmpty(dir string, wipe bool) error {
	entries, err := os.ReadDir(dir)
	if errors.Is(err, fs.ErrNotExist) {
		return os.MkdirAll(dir, 0o700)
	}
	if err != nil {
		return err
	}
	if len(entries) == 0 {
		return nil
	}
	if _, err := os.Stat(filepath.Join(dir, "postmaster.pid")); err == nil {
		return errors.New("postmaster.pid exists: the database is still running or was not shut down cleanly; stop the database first")
	}
	if !wipe {
		return fmt.Errorf("directory %s is not empty; add --wipe to delete its contents", dir)
	}
	for _, e := range entries {
		if err := os.RemoveAll(filepath.Join(dir, e.Name())); err != nil {
			return err
		}
	}
	return nil
}

func quote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}

func RecoverySettings(target time.Time) []string {
	lines := []string{
		"restore_command = " + quote(pg.RestoreCommand),
		"recovery_target_timeline = 'latest'",
		"recovery_target_action = 'promote'",
	}
	if !target.IsZero() {
		lines = append(lines, "recovery_target_time = "+quote(target.UTC().Format(timeLayout)))
	}
	return lines
}

func WriteRecovery(dataDir string, target time.Time) error {
	f, err := os.OpenFile(filepath.Join(dataDir, "postgresql.auto.conf"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return err
	}
	_, err = f.WriteString("\n" + strings.Join(RecoverySettings(target), "\n") + "\n")
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dataDir, "recovery.signal"), nil, 0o600)
}

func ParseOwner(text string) (int, int, error) {
	u, g, ok := strings.Cut(text, ":")
	uid, err1 := strconv.Atoi(u)
	gid, err2 := strconv.Atoi(g)
	if !ok || err1 != nil || err2 != nil || uid < 0 || gid < 0 {
		return 0, 0, fmt.Errorf("owner %q must be uid:gid", text)
	}
	return uid, gid, nil
}

func Chown(dir string, uid, gid int) error {
	return filepath.WalkDir(dir, func(path string, _ fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		return os.Lchown(path, uid, gid)
	})
}

func ParseTarget(text string) (time.Time, error) {
	if text == "latest" {
		return time.Time{}, nil
	}
	t, err := time.Parse(time.RFC3339, text)
	if err != nil {
		return time.Time{}, fmt.Errorf("--target-time must be RFC3339 (e.g. 2026-11-03T10:00:00+07:00) or latest")
	}
	return t, nil
}
