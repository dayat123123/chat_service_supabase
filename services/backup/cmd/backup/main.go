package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"text/tabwriter"
	"time"
	_ "time/tzdata"

	"olt-social/backup/internal/agent"
	"olt-social/backup/internal/config"
	"olt-social/backup/internal/disk"
	"olt-social/backup/internal/metrics"
	"olt-social/backup/internal/pg"
	"olt-social/backup/internal/restic"
	"olt-social/backup/internal/restore"
	"olt-social/backup/internal/runner"
	"olt-social/backup/internal/settings"
	"olt-social/backup/internal/store"
)

const (
	version     = "0.2.0"
	pingTimeout = 5 * time.Second
	systemPath  = "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
	usage       = `Usage:
  backup [run]          run the backup service (default)
  backup healthcheck    check /healthz for the container healthcheck
  backup snapshots      list snapshots in the repository (credentials from RESTIC_* env (+ AWS_* for S3) or from the database)
  backup restore --target-time <RFC3339|latest> --data-dir <folder> [--owner 100:101] [--wipe]
`
)

func main() {
	args := os.Args[1:]
	command := "run"
	if len(args) > 0 {
		command, args = args[0], args[1:]
	}
	switch command {
	case "run":
		os.Exit(serve())
	case "healthcheck":
		os.Exit(healthcheck())
	case "snapshots":
		os.Exit(snapshots(args, os.Stdout))
	case "restore":
		os.Exit(restoreCommand(args, os.Stdout))
	default:
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
}

func serviceEnv(dataDir string) []string {
	return []string{systemPath, "HOME=" + dataDir, "TMPDIR=" + filepath.Join(dataDir, "tmp"), "TZ=UTC", "LANG=C.UTF-8", "LC_ALL=C.UTF-8"}
}

func cliEnv() []string {
	tmp := os.TempDir()
	if dir := os.Getenv("DATA_DIR"); dir != "" {
		if info, err := os.Stat(filepath.Join(dir, "tmp")); err == nil && info.IsDir() {
			tmp = filepath.Join(dir, "tmp")
		}
	}
	return []string{systemPath, "HOME=" + tmp, "TMPDIR=" + tmp, "TZ=UTC", "LANG=C.UTF-8", "LC_ALL=C.UTF-8"}
}

func serve() int {
	startedAt := time.Now()
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "invalid configuration:\n%v\n", err)
		return 1
	}
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.LogLevel}))
	if err := run(cfg, log, startedAt); err != nil {
		log.Error("Backup stopped with an error", "error", err)
		return 1
	}
	return 0
}

func run(cfg config.Config, log *slog.Logger, startedAt time.Time) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	exec := runner.Exec{WaitDelay: 30 * time.Second}
	base := serviceEnv(cfg.DataDir)
	db := pg.Tools{Runner: exec, Base: base, Conn: pg.Conn{Host: cfg.PGHost, Port: cfg.PGPort, User: cfg.PGUser,
		Password: cfg.PGPassword, Database: cfg.PGDatabase}}
	rest := store.NewPostgREST(cfg.PostgRESTURL, cfg.JWTSecret, cfg.JWTIssuer, cfg.RequestTimeout)
	cache := "RESTIC_CACHE_DIR=" + filepath.Join(cfg.DataDir, "cache")
	a := agent.New(agent.Options{
		Store:    rest,
		Database: db,
		Repository: func(c restic.Credentials) agent.Repository {
			return &restic.Client{Runner: exec, Env: runner.Env(base, append(c.Env(), cache)...), RetryLock: 5 * time.Minute}
		},
		Log:                log,
		Instance:           cfg.InstanceID,
		Version:            version,
		StartedAt:          startedAt,
		DataDir:            cfg.DataDir,
		StorageDir:         cfg.StorageDir,
		LocalRepoDir:       cfg.LocalRepoDir,
		ConfigPoll:         cfg.ConfigPoll,
		HeartbeatInterval:  cfg.HeartbeatInterval,
		RequestTimeout:     cfg.RequestTimeout,
		RestoreTestTimeout: cfg.RestoreTestTimeout,
	})

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), pingTimeout)
		defer cancel()
		if err := rest.Ping(ctx); err != nil {
			http.Error(w, "postgrest unavailable", http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("ok"))
	})
	mux.Handle("GET /metrics", metrics.Handler(a.Metrics))

	server := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	errCh := make(chan error, 1)
	go func() {
		log.Info("Backup listening", "port", cfg.Port, "instance", cfg.InstanceID, "version", version)
		errCh <- server.ListenAndServe()
	}()
	done := make(chan struct{})
	go func() {
		a.Run(ctx)
		close(done)
	}()

	var serveErr error
	select {
	case serveErr = <-errCh:
		stop()
	case <-ctx.Done():
		log.Info("Shutting down; stopping child processes")
	}
	select {
	case <-done:
	case <-time.After(cfg.ShutdownTimeout):
		log.Warn("Shutdown timeout reached; exiting while child processes are still stopping", "timeout", cfg.ShutdownTimeout.String())
	}
	shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdown); err != nil && serveErr == nil {
		serveErr = err
	}
	if serveErr != nil && !errors.Is(serveErr, http.ErrServerClosed) {
		return serveErr
	}
	log.Info("Backup stopped")
	return nil
}

func healthcheck() int {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get("http://127.0.0.1:" + port + "/healthz")
	if err != nil {
		return 1
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}

func resticEnvFromDatabase(ctx context.Context) ([]string, error) {
	cfg, err := config.Load()
	if err != nil {
		return nil, errors.New("set RESTIC_REPOSITORY and RESTIC_PASSWORD(_FILE), or run inside the backup container so the credentials are read from the database")
	}
	s, err := store.NewPostgREST(cfg.PostgRESTURL, cfg.JWTSecret, cfg.JWTIssuer, cfg.RequestTimeout).Config(ctx, settings.UnknownRevision)
	if err != nil {
		return nil, fmt.Errorf("could not read the backup settings from the database: %v", err)
	}
	if !s.Configured {
		return nil, errors.New("backup is not configured in the Hub yet")
	}
	if err := s.Validate(cfg.LocalRepoDir); err != nil {
		return nil, fmt.Errorf("invalid backup settings: %v", err)
	}
	return s.Credentials().Env(), nil
}

func snapshots(args []string, out io.Writer) int {
	fs := flag.NewFlagSet("snapshots", flag.ContinueOnError)
	asJSON := fs.Bool("json", false, "print the restic JSON")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	var creds []string
	var err error
	if os.Getenv("RESTIC_REPOSITORY") != "" || os.Getenv("RESTIC_REPOSITORY_FILE") != "" {
		creds, err = restic.FromEnv(os.Getenv)
	} else {
		creds, err = resticEnvFromDatabase(ctx)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		return 1
	}
	client := &restic.Client{Runner: runner.Exec{}, Env: runner.Env(cliEnv(), creds...), NoCache: true}
	snaps, err := client.Snapshots(ctx, "")
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not read snapshots:", runner.Detail(err))
		return 1
	}
	if *asJSON {
		enc := json.NewEncoder(out)
		enc.SetIndent("", "  ")
		_ = enc.Encode(snaps)
		return 0
	}
	printSnapshots(out, snaps)
	return 0
}

func wib() *time.Location {
	loc, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		return time.UTC
	}
	return loc
}

func printSnapshots(out io.Writer, snaps []restic.Snapshot) {
	loc := wib()
	tw := tabwriter.NewWriter(out, 2, 4, 2, ' ', 0)
	fmt.Fprintln(tw, "TIME\tID\tKIND\tSIZE\tNOTE")
	var firstBase, lastBase, lastWAL time.Time
	for _, s := range snaps {
		kind, note := "other", strings.Join(s.Paths, ",")
		switch {
		case s.Has(restic.TagBase):
			kind, note = "base", s.Label()
			if firstBase.IsZero() {
				firstBase = s.Time
			}
			lastBase = s.Time
		case s.Has(restic.TagWAL):
			kind, note = "wal", fmt.Sprintf("%d file", fileCount(s))
			lastWAL = s.Time
		case s.Has(restic.TagFiles):
			kind, note = "files", fmt.Sprintf("%d file", fileCount(s))
		}
		fmt.Fprintf(tw, "%s\t%s\t%s\t%s\t%s\n", s.Time.In(loc).Format(time.RFC3339), s.Short(), kind, size(s.Bytes()), note)
	}
	_ = tw.Flush()
	fmt.Fprintln(out)
	if firstBase.IsZero() {
		fmt.Fprintln(out, "No base backup yet: nothing can be restored.")
		return
	}
	fmt.Fprintf(out, "Base backups: %s to %s\n", firstBase.In(loc).Format(time.RFC3339), lastBase.In(loc).Format(time.RFC3339))
	if lastWAL.IsZero() || lastWAL.Before(firstBase) {
		fmt.Fprintln(out, "No WAL uploaded after the base yet: restore only to the base point (--target-time latest).")
		return
	}
	fmt.Fprintf(out, "Point-in-time restore (--target-time) is possible between %s and %s (WAL within retention), or latest.\n",
		firstBase.In(loc).Format(time.RFC3339), lastWAL.In(loc).Format(time.RFC3339))
}

func fileCount(s restic.Snapshot) int64 {
	if s.Summary == nil {
		return 0
	}
	return s.Summary.TotalFilesProcessed
}

func size(n int64) string {
	const unit = 1024
	if n < unit {
		return fmt.Sprintf("%d B", n)
	}
	div, exp := int64(unit), 0
	for m := n / unit; m >= unit; m /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %ciB", float64(n)/float64(div), "KMGTPE"[exp])
}

func restoreCommand(args []string, out io.Writer) int {
	fs := flag.NewFlagSet("restore", flag.ContinueOnError)
	target := fs.String("target-time", "", "target time in RFC3339 (e.g. 2026-11-03T10:00:00+07:00) or latest")
	dataDir := fs.String("data-dir", "", "target PostgreSQL data directory (empty, or use --wipe)")
	owner := fs.String("owner", "100:101", "uid:gid owner of the data dir (the postgres user in the supabase/postgres image)")
	wipe := fs.Bool("wipe", false, "delete the target data dir contents first (refused when postmaster.pid exists)")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if *target == "" || *dataDir == "" || !filepath.IsAbs(*dataDir) {
		fmt.Fprint(os.Stderr, usage)
		return 2
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := restoreTo(ctx, out, *target, filepath.Clean(*dataDir), *owner, *wipe); err != nil {
		fmt.Fprintln(os.Stderr, "Restore failed:", err)
		return 1
	}
	return 0
}

func restoreTo(ctx context.Context, out io.Writer, targetText, dataDir, ownerText string, wipe bool) error {
	target, err := restore.ParseTarget(targetText)
	if err != nil {
		return err
	}
	uid, gid, err := restore.ParseOwner(ownerText)
	if err != nil {
		return err
	}
	euid := os.Geteuid()
	if euid != 0 && euid != uid {
		return fmt.Errorf("run as root (docker run --user 0:0) so the data dir owner can be changed to %s", ownerText)
	}
	creds, err := restic.FromEnv(os.Getenv)
	if err != nil {
		return err
	}
	env := runner.Env(cliEnv(), creds...)
	exec := runner.Exec{WaitDelay: 30 * time.Second}
	client := &restic.Client{Runner: exec, Env: env, NoCache: true}
	loc := wib()
	fmt.Fprintln(out, "Reading snapshots from the repository...")
	snaps, err := client.Snapshots(ctx, "")
	if err != nil {
		return fmt.Errorf("could not read snapshots: %s", runner.Detail(err))
	}
	plan, err := restore.Choose(snaps, target)
	if err != nil {
		return err
	}
	fmt.Fprintf(out, "Base : %s (snapshot %s, %s, %s)\n", plan.Base.Label(), plan.Base.Short(), plan.Base.Time.In(loc).Format(time.RFC3339), size(plan.Base.Bytes()))
	if plan.WAL != nil {
		fmt.Fprintf(out, "WAL  : snapshot %s (%s, %s)\n", plan.WAL.Short(), plan.WAL.Time.In(loc).Format(time.RFC3339), size(plan.WAL.Bytes()))
	} else {
		fmt.Fprintln(out, "WAL  : no WAL uploads; restore only up to the end of the base")
	}
	if err := restore.EnsureEmpty(dataDir, wipe); err != nil {
		return err
	}
	if usage, err := disk.Stat(dataDir); err == nil {
		if need := plan.Bytes() * 11 / 10; usage.Avail < need {
			return fmt.Errorf("not enough disk space in %s: %s available, about %s needed", dataDir, size(usage.Avail), size(need))
		}
	}
	fmt.Fprintf(out, "Restoring base and WAL to %s ...\n", dataDir)
	started := time.Now()
	prepared, err := restore.Prepare(ctx, client, plan, dataDir)
	if err != nil {
		return err
	}
	tools := pg.Tools{Runner: exec, Base: cliEnv()}
	if err := tools.VerifyBackup(ctx, dataDir, restore.WALDir); err != nil {
		return fmt.Errorf("pg_verifybackup rejected the restored data: %s", runner.Detail(err))
	}
	if err := restore.WriteRecovery(dataDir, target); err != nil {
		return err
	}
	if euid == 0 {
		if err := restore.Chown(dataDir, uid, gid); err != nil {
			return fmt.Errorf("could not change the data dir owner: %v", err)
		}
	}
	if err := os.Chmod(dataDir, 0o700); err != nil {
		return err
	}
	goal := "end of the available WAL (latest)"
	if !target.IsZero() {
		goal = target.In(loc).Format(time.RFC3339)
	}
	fmt.Fprintf(out, `
Done in %s. Data dir ready (%s, owner %s).
  Base verified with pg_verifybackup, WAL starts at %s, %d WAL files (%s) in %s/.
  Recovery target: %s (recovery_target_action = promote).

Next steps:
  1. Start the database (make restore-pitr does this automatically) and watch the log until
     "archive recovery complete" and then "database system is ready to accept connections" appear.
     If "recovery ended before configured recovery target was reached" appears, there were no
     transactions after the target time: run the restore again with --target-time latest.
  2. Clear the recovery settings and the restored WAL:
       ALTER SYSTEM RESET restore_command; ALTER SYSTEM RESET recovery_target_time;
       ALTER SYSTEM RESET recovery_target_action; ALTER SYSTEM RESET recovery_target_timeline;
       SELECT pg_reload_conf();
     then delete the %s folder in the data dir.
  3. Start all services. The backup service creates a new replication slot and a new base backup automatically.
  4. New server: the Vault key (db-config volume) is not part of the backup. Upload the Firebase key again and
     save the backup target (S3 or local folder + password) again from the Hub.
`, time.Since(started).Round(time.Second), dataDir, ownerText, prepared.StartWAL, prepared.Segments, size(prepared.WALBytes),
		restore.WALDir, goal, restore.WALDir)
	return nil
}
