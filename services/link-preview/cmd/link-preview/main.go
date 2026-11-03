package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"olt-social/link-preview/internal/config"
	"olt-social/link-preview/internal/heartbeat"
	"olt-social/link-preview/internal/metrics"
	"olt-social/link-preview/internal/safehttp"
	"olt-social/link-preview/internal/storage"
	"olt-social/link-preview/internal/store"
	"olt-social/link-preview/internal/worker"
)

const (
	service     = "link-preview"
	version     = "0.1.0"
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
		log.Error("Link preview stopped with an error", "error", err)
		os.Exit(1)
	}
}

func run(cfg config.Config, log *slog.Logger, startedAt time.Time) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	queue := store.NewPostgREST(cfg.PostgRESTURL, cfg.JWTSecret, cfg.JWTIssuer, cfg.RequestTimeout)
	objects := storage.New(cfg.StorageURL, cfg.JWTSecret, cfg.JWTIssuer, cfg.RequestTimeout)
	fetcher := safehttp.New(safehttp.Options{Policy: safehttp.DefaultPolicy(), Timeout: cfg.FetchTimeout, UserAgent: cfg.UserAgent})
	w := worker.New(worker.Options{
		Store:           queue,
		Fetcher:         fetcher,
		Uploader:        objects,
		Log:             log,
		Instance:        cfg.InstanceID,
		BatchSize:       cfg.BatchSize,
		Concurrency:     cfg.Concurrency,
		Lease:           cfg.Lease,
		PollInterval:    cfg.PollInterval,
		FetchTimeout:    cfg.FetchTimeout,
		RequestTimeout:  cfg.RequestTimeout,
		ShutdownTimeout: cfg.ShutdownTimeout,
		MaxHTMLBytes:    cfg.MaxHTMLBytes,
		MaxImageBytes:   cfg.MaxImageBytes,
	})
	beats := heartbeat.New(heartbeat.Options{
		Store:     queue,
		Log:       log,
		Service:   service,
		Instance:  cfg.InstanceID,
		Version:   version,
		StartedAt: startedAt,
		Interval:  cfg.HeartbeatInterval,
		Report:    w.Report,
	})

	var ready atomic.Bool
	ready.Store(true)
	mux := http.NewServeMux()
	mux.HandleFunc("GET /livez", func(rw http.ResponseWriter, _ *http.Request) {
		_, _ = rw.Write([]byte("ok"))
	})
	mux.HandleFunc("GET /readyz", func(rw http.ResponseWriter, r *http.Request) {
		if !ready.Load() {
			http.Error(rw, "shutting down", http.StatusServiceUnavailable)
			return
		}
		ping, cancel := context.WithTimeout(r.Context(), pingTimeout)
		defer cancel()
		if err := queue.Ping(ping); err != nil {
			http.Error(rw, "postgrest unavailable", http.StatusServiceUnavailable)
			return
		}
		if err := objects.Ping(ping); err != nil {
			http.Error(rw, "storage unavailable", http.StatusServiceUnavailable)
			return
		}
		_, _ = rw.Write([]byte("ok"))
	})
	mux.Handle("GET /metrics", metrics.Handler(func() metrics.Snapshot {
		snapshot := w.Metrics()
		snapshot.LastHeartbeat = beats.LastSuccess()
		return snapshot
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
		if err := server.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
	}()
	log.Info("Link preview listening", "port", cfg.Port, "instance", cfg.InstanceID, "version", version,
		"concurrency", cfg.Concurrency, "fetch_timeout", cfg.FetchTimeout.String())

	beatCtx, stopBeats := context.WithCancel(context.Background())
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		beats.Run(beatCtx)
	}()
	done := make(chan struct{})
	go func() {
		defer wg.Done()
		w.Run(ctx)
		close(done)
	}()

	var failure error
	select {
	case failure = <-errCh:
		stop()
	case <-ctx.Done():
		log.Info("Shutting down; finishing the links in flight")
	}
	ready.Store(false)
	<-done
	stopBeats()
	wg.Wait()
	shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = server.Shutdown(shutdown)
	if failure != nil {
		return failure
	}
	log.Info("Link preview stopped")
	return nil
}

func healthcheck() int {
	port := os.Getenv("PORT")
	if _, err := strconv.Atoi(port); err != nil {
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
