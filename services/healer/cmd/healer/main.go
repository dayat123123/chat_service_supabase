package main

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"olt-social/healer/internal/config"
	"olt-social/healer/internal/docker"
	"olt-social/healer/internal/healer"
	"olt-social/healer/internal/state"
)

const version = "0.1.0"

func main() {
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		os.Exit(healthcheck(time.Now()))
	}
	startedAt := time.Now()
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "invalid configuration:\n%v\n", err)
		os.Exit(1)
	}
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.LogLevel}))
	run(cfg, log, startedAt)
}

func run(cfg config.Config, log *slog.Logger, startedAt time.Time) {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	initial, err := state.Load(cfg.StateFile)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		log.Warn("Could not read the previous state; starting with an empty history", "path", cfg.StateFile, "error", err)
	}
	hostname, _ := os.Hostname()
	h := healer.New(healer.Options{
		Docker:           docker.New(docker.Options{Socket: cfg.Socket}),
		Log:              log,
		Project:          cfg.Project,
		Hostname:         hostname,
		Enabled:          cfg.Enabled,
		Interval:         cfg.Interval,
		UnhealthyFor:     cfg.UnhealthyFor,
		MinUptime:        cfg.MinUptime,
		MaxRestarts:      cfg.MaxRestarts,
		GlobalCooldown:   cfg.GlobalCooldown,
		SystemicFraction: cfg.SystemicFraction,
		Version:          version,
		StartedAt:        startedAt,
		StateFile:        cfg.StateFile,
		Initial:          initial,
	})
	log.Info("Healer started", "version", version, "enabled", cfg.Enabled, "project", cfg.Project,
		"interval_seconds", int(cfg.Interval.Seconds()), "unhealthy_seconds", int(cfg.UnhealthyFor.Seconds()),
		"min_uptime_seconds", int(cfg.MinUptime.Seconds()), "max_restarts_per_hour", cfg.MaxRestarts,
		"global_cooldown_seconds", int(cfg.GlobalCooldown.Seconds()), "systemic_fraction", cfg.SystemicFraction)
	h.Run(ctx)
	log.Info("Healer stopped")
}

func healthcheck(now time.Time) int {
	cfg, err := config.Load()
	if err != nil {
		return 1
	}
	s, err := state.Load(cfg.StateFile)
	if err != nil {
		return 1
	}
	if now.Sub(s.CheckedAt) > max(3*cfg.Interval, 30*time.Second) {
		return 1
	}
	return 0
}
