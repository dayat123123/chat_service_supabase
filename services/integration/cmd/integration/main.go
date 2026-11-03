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

	"olt-social/integration/internal/clientip"
	"olt-social/integration/internal/config"
	"olt-social/integration/internal/heartbeat"
	"olt-social/integration/internal/keys"
	"olt-social/integration/internal/metrics"
	"olt-social/integration/internal/server"
	"olt-social/integration/internal/store"
)

const (
	service = "integration"
	version = "0.2.0"
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
		log.Error("Integration stopped with an error", "error", err)
		os.Exit(1)
	}
}

func run(cfg config.Config, log *slog.Logger, startedAt time.Time) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	rest := store.NewPostgREST(cfg.PostgRESTURL, cfg.JWTSecret, cfg.JWTIssuer, cfg.RequestTimeout)
	keyCache := keys.NewCache(rest, cfg.KeyCacheTTL)
	var beats *heartbeat.Loop
	api := server.New(server.Options{
		Log:                   log,
		Store:                 rest,
		Keys:                  keyCache,
		ClientIP:              clientip.New(cfg.TrustedProxies).Of,
		MaxBodyBytes:          cfg.MaxBodyBytes,
		MaxConcurrent:         cfg.MaxConcurrent,
		AuthFailuresPerMinute: cfg.AuthFailuresPerMinute,
		RequestTimeout:        cfg.RequestTimeout,
		Notify:                func() { beats.Kick() },
	})
	beats = heartbeat.New(heartbeat.Options{
		Store:     rest,
		Log:       log,
		Service:   service,
		Instance:  cfg.InstanceID,
		Version:   version,
		StartedAt: startedAt,
		Interval:  cfg.HeartbeatInterval,
		Report:    api.Report,
	})

	var ready atomic.Bool
	ready.Store(true)
	ops := http.NewServeMux()
	ops.HandleFunc("GET /livez", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("ok"))
	})
	ops.HandleFunc("GET /readyz", func(w http.ResponseWriter, _ *http.Request) {
		if !ready.Load() {
			http.Error(w, "shutting down", http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("ok"))
	})
	ops.Handle("GET /metrics", metrics.Handler(func() metrics.Snapshot {
		snapshot := api.Metrics()
		snapshot.LastHeartbeat = beats.LastSuccess()
		return snapshot
	}))

	apiServer := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           api,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      cfg.RequestTimeout + 15*time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    32 << 10,
	}
	opsServer := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.OpsPort),
		Handler:           ops,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	errCh := make(chan error, 2)
	for _, srv := range []*http.Server{apiServer, opsServer} {
		go func() {
			if err := srv.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
				errCh <- err
			}
		}()
	}
	log.Info("Integration listening", "port", cfg.Port, "ops_port", cfg.OpsPort, "instance", cfg.InstanceID,
		"version", version, "max_concurrent", cfg.MaxConcurrent, "key_cache_ttl", cfg.KeyCacheTTL.String())

	beatCtx, stopBeats := context.WithCancel(context.Background())
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		beats.Run(beatCtx)
	}()

	var failure error
	select {
	case failure = <-errCh:
	case <-ctx.Done():
		log.Info("Shutting down; finishing the requests in flight")
	}
	ready.Store(false)
	shutdown, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	if err := apiServer.Shutdown(shutdown); err != nil {
		log.Warn("Shutdown timeout reached; closing requests still in flight", "timeout", cfg.ShutdownTimeout.String())
		_ = apiServer.Close()
	}
	stopBeats()
	wg.Wait()
	opsDone, cancelOps := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancelOps()
	_ = opsServer.Shutdown(opsDone)
	if failure != nil {
		return failure
	}
	log.Info("Integration stopped")
	return nil
}

func healthcheck() int {
	port := os.Getenv("OPS_PORT")
	if _, err := strconv.Atoi(port); err != nil {
		port = "9100"
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
