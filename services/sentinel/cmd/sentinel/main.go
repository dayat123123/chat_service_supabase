package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"olt-social/sentinel/internal/config"
	"olt-social/sentinel/internal/dispatch"
	"olt-social/sentinel/internal/email"
	"olt-social/sentinel/internal/jwt"
	"olt-social/sentinel/internal/metrics"
	"olt-social/sentinel/internal/monitor"
	"olt-social/sentinel/internal/outage"
	"olt-social/sentinel/internal/probe"
	"olt-social/sentinel/internal/scrape"
	"olt-social/sentinel/internal/store"
	"olt-social/sentinel/internal/telegram"
)

const (
	version     = "0.3.0"
	userAgent   = "olt-sentinel/" + version
	pingTimeout = 5 * time.Second
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		os.Exit(healthcheck())
	}
	startedAt := time.Now()
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "invalid configuration:\n%v\n", err)
		os.Exit(1)
	}
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.LogLevel}))
	if err := run(cfg, log, startedAt); err != nil {
		log.Error("Sentinel stopped with an error", "error", err)
		os.Exit(1)
	}
}

func run(cfg config.Config, log *slog.Logger, startedAt time.Time) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	detector := outage.New(cfg.DBDownAfter, time.Now, store.Unreachable)
	db := store.NewPostgREST(store.Options{
		BaseURL: cfg.PostgRESTURL,
		Secret:  cfg.JWTSecret,
		Issuer:  cfg.JWTIssuer,
		Timeout: cfg.RequestTimeout,
		Observe: detector.Observe,
	})
	mon := monitor.New(monitor.Options{
		Store:  db,
		Prober: probe.New(cfg.ProbeTimeout, userAgent),
		Scraper: scrape.New(scrape.Options{
			Timeout:   cfg.ProbeTimeout,
			UserAgent: userAgent,
			Password:  cfg.StatsPassword,
			Token: func() (string, error) {
				return jwt.ServiceRole(cfg.JWTSecret, cfg.JWTIssuer, time.Now())
			},
		}),
		Sources:        cfg.Metrics,
		Log:            log,
		Probes:         cfg.Probes,
		Disks:          cfg.Disks,
		Interval:       cfg.ReportInterval,
		RequestTimeout: cfg.RequestTimeout,
		Instance:       cfg.InstanceID,
		Version:        version,
		StartedAt:      startedAt,
	})
	d := dispatch.New(dispatch.Options{
		Store:           db,
		Telegram:        telegram.New(cfg.TelegramAPIURL, cfg.RequestTimeout, userAgent),
		Email:           email.New(email.Options{Timeout: cfg.SMTPTimeout}),
		Outages:         detector,
		Log:             log,
		Instance:        cfg.InstanceID,
		BatchSize:       cfg.BatchSize,
		Lease:           cfg.Lease,
		PollInterval:    cfg.AlertPoll,
		SendTimeout:     max(cfg.SMTPTimeout, cfg.RequestTimeout),
		ShutdownTimeout: cfg.ShutdownTimeout,
		FailingProbes:   mon.Failing,
	})

	mux := http.NewServeMux()
	mux.HandleFunc("GET /livez", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), pingTimeout)
		defer cancel()
		if err := db.Ping(ctx); err != nil {
			http.Error(w, "postgrest unavailable", http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("ok"))
	})
	mux.Handle("GET /metrics", metrics.Handler(func() metrics.Snapshot {
		health := mon.Snapshot()
		alerts := d.Metrics()
		state := detector.State()
		return metrics.Snapshot{
			Probes:             health.Probes,
			Disks:              health.Disks,
			Scrapes:            health.Metrics,
			Reports:            health.Reports,
			LastReport:         health.LastReport,
			Alerts:             alerts.Alerts,
			Notices:            alerts.Notices,
			ChannelsRevision:   alerts.Revision,
			TelegramConfigured: alerts.TelegramConfigured,
			EmailConfigured:    alerts.EmailConfigured,
			DatabaseReachable:  state.Reachable,
			DatabaseDown:       state.Down,
			Outages:            state.Outages,
		}
	}))

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
		log.Info("Sentinel listening", "port", cfg.Port, "instance", cfg.InstanceID, "version", version,
			"probes", len(cfg.Probes), "disks", len(cfg.Disks), "metrics_sources", len(cfg.Metrics))
		errCh <- server.ListenAndServe()
	}()
	monitorDone := make(chan struct{})
	go func() {
		mon.Run(ctx)
		close(monitorDone)
	}()
	dispatchDone := make(chan struct{})
	go func() {
		d.Run(ctx)
		close(dispatchDone)
	}()

	var serveErr error
	select {
	case serveErr = <-errCh:
		stop()
	case <-ctx.Done():
		log.Info("Shutting down; finishing the alerts in flight")
	}
	<-monitorDone
	<-dispatchDone
	if serveErr != nil {
		return serveErr
	}
	shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdown); err != nil {
		return err
	}
	log.Info("Sentinel stopped")
	return nil
}

func healthcheck() int {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get("http://127.0.0.1:" + port + "/livez")
	if err != nil {
		return 1
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
