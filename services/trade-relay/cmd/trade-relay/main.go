package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"olt-social/trade-relay/internal/config"
	"olt-social/trade-relay/internal/metrics"
	"olt-social/trade-relay/internal/relay"
	"olt-social/trade-relay/internal/store"
	"olt-social/trade-relay/internal/zsock"
)

const version = "0.1.0"

func main() {
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		os.Exit(healthcheck())
	}
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "invalid configuration:\n%v\n", err)
		os.Exit(1)
	}
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.LogLevel}))
	err = run(cfg, log)
	switch {
	case errors.Is(err, relay.ErrRestart):
		log.Info("Trade relay exiting for a restart requested from Hub")
		os.Exit(0)
	case err != nil:
		log.Error("Trade relay stopped with an error", "error", err)
		os.Exit(1)
	}
}

func run(cfg config.Config, log *slog.Logger) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	r := relay.New(relay.Options{
		Store:           store.New(cfg.PostgRESTURL, cfg.JWTSecret, cfg.JWTIssuer, cfg.RequestTimeout),
		Dial:            zsock.Dial,
		Log:             log,
		Instance:        cfg.InstanceID,
		Version:         version,
		ConfigInterval:  cfg.ConfigInterval,
		StatusInterval:  cfg.StatusInterval,
		FlushInterval:   cfg.FlushInterval,
		BatchSize:       cfg.BatchSize,
		BufferSize:      cfg.BufferSize,
		RecvQueue:       cfg.RecvQueue,
		RecvHWM:         cfg.RecvHWM,
		RecvTimeout:     cfg.RecvTimeout,
		SilentReconnect: cfg.SilentReconnect,
		RequestTimeout:  cfg.RequestTimeout,
		RestartFlush:    cfg.RestartFlush,
	})

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		if ok, reason := r.Healthy(cfg.WatchdogTimeout); !ok {
			http.Error(w, reason, http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("ok"))
	})
	mux.Handle("GET /metrics", metrics.Handler(r.Counters().Snapshot, r.Gauges))
	server := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	serverErr := make(chan error, 1)
	go func() {
		log.Info("Trade relay listening", "port", cfg.Port, "instance", cfg.InstanceID, "version", version)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
		}
	}()

	go watchdog(ctx, r, cfg.WatchdogTimeout, log)

	runErr := make(chan error, 1)
	go func() { runErr <- r.Run(ctx) }()
	var result error
	select {
	case result = <-runErr:
	case err := <-serverErr:
		stop()
		<-runErr
		result = err
	}
	shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = server.Shutdown(shutdown)
	log.Info("Trade relay stopped")
	return result
}

func watchdog(ctx context.Context, r *relay.Relay, timeout time.Duration, log *slog.Logger) {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	var since time.Time
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
		ok, reason := r.Healthy(timeout)
		if ok {
			since = time.Time{}
			continue
		}
		if since.IsZero() {
			since = time.Now()
			log.Warn("Trade relay unhealthy", "reason", reason)
			continue
		}
		if time.Since(since) > timeout {
			log.Error("Trade relay watchdog expired; exiting so Docker restarts the container", "reason", reason)
			os.Exit(2)
		}
	}
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
