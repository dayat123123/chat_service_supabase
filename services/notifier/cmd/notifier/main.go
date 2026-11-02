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

	"olt-social/notifier/internal/config"
	"olt-social/notifier/internal/fcm"
	"olt-social/notifier/internal/metrics"
	"olt-social/notifier/internal/store"
	"olt-social/notifier/internal/worker"
)

const version = "0.1.0"

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
		log.Error("Notifier stopped with an error", "error", err)
		os.Exit(1)
	}
}

func run(cfg config.Config, log *slog.Logger, startedAt time.Time) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	queue := store.NewPostgREST(cfg.PostgRESTURL, cfg.JWTSecret, cfg.JWTIssuer)
	sender := fcm.New(fcm.Options{
		Path:        cfg.FirebaseCredentials,
		BaseURL:     cfg.FCMBaseURL,
		ChannelID:   cfg.AndroidChannelID,
		SendTimeout: cfg.SendTimeout,
		Log:         log,
	})
	w := worker.New(worker.Options{
		Store:             queue,
		Sender:            sender,
		Log:               log,
		Instance:          cfg.InstanceID,
		Version:           version,
		StartedAt:         startedAt,
		BatchSize:         cfg.BatchSize,
		Concurrency:       cfg.Concurrency,
		Lease:             cfg.Lease,
		PollInterval:      cfg.PollInterval,
		HeartbeatInterval: cfg.HeartbeatInterval,
		ReloadInterval:    cfg.CredentialsReload,
		SendTimeout:       cfg.SendTimeout,
		ShutdownTimeout:   cfg.ShutdownTimeout,
	})

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if err := queue.Ping(r.Context()); err != nil {
			http.Error(w, "postgrest unavailable", http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("ok"))
	})
	mux.Handle("GET /metrics", metrics.Handler(w.Metrics))

	server := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	errCh := make(chan error, 1)
	go func() {
		log.Info("Notifier listening", "port", cfg.Port, "instance", cfg.InstanceID, "version", version)
		errCh <- server.ListenAndServe()
	}()
	done := make(chan struct{})
	go func() {
		w.Run(ctx)
		close(done)
	}()

	select {
	case err := <-errCh:
		stop()
		<-done
		return err
	case <-ctx.Done():
		log.Info("Shutting down; finishing the batch in flight")
	}
	<-done
	shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdown); err != nil {
		return err
	}
	log.Info("Notifier stopped")
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
