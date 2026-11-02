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

	"olt-social/janitor/internal/cleaner"
	"olt-social/janitor/internal/config"
	"olt-social/janitor/internal/metrics"
	"olt-social/janitor/internal/storage"
	"olt-social/janitor/internal/store"
)

const (
	version     = "0.1.0"
	pingTimeout = 5 * time.Second
)

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
	if err := run(cfg, log); err != nil {
		log.Error("Janitor stopped with an error", "error", err)
		os.Exit(1)
	}
}

func run(cfg config.Config, log *slog.Logger) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	queue := store.NewPostgREST(cfg.PostgRESTURL, cfg.JWTSecret, cfg.JWTIssuer, cfg.RequestTimeout)
	objects := storage.New(cfg.StorageURL, cfg.JWTSecret, cfg.JWTIssuer, cfg.RequestTimeout)
	c := cleaner.New(cleaner.Options{
		Store:           queue,
		Storage:         objects,
		Log:             log,
		Instance:        cfg.InstanceID,
		BatchSize:       cfg.BatchSize,
		ObjectsPerEntry: cfg.ObjectsPerEntry,
		DeleteChunk:     cfg.DeleteChunk,
		Concurrency:     cfg.Concurrency,
		Lease:           cfg.Lease,
		PollInterval:    cfg.PollInterval,
		RequestTimeout:  cfg.RequestTimeout,
		ShutdownTimeout: cfg.ShutdownTimeout,
	})

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), pingTimeout)
		defer cancel()
		if err := queue.Ping(ctx); err != nil {
			http.Error(w, "postgrest unavailable", http.StatusServiceUnavailable)
			return
		}
		if err := objects.Ping(ctx); err != nil {
			http.Error(w, "storage unavailable", http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("ok"))
	})
	mux.Handle("GET /metrics", metrics.Handler(c.Metrics))

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
		log.Info("Janitor listening", "port", cfg.Port, "instance", cfg.InstanceID, "version", version)
		errCh <- server.ListenAndServe()
	}()
	done := make(chan struct{})
	go func() {
		c.Run(ctx)
		close(done)
	}()

	select {
	case err := <-errCh:
		stop()
		<-done
		return err
	case <-ctx.Done():
		log.Info("Shutting down; finishing the deletes in flight")
	}
	<-done
	shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdown); err != nil {
		return err
	}
	log.Info("Janitor stopped")
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
