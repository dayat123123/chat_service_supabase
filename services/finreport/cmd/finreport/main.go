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

	"olt-social/finreport/internal/api"
	"olt-social/finreport/internal/clamd"
	"olt-social/finreport/internal/clientip"
	"olt-social/finreport/internal/config"
	"olt-social/finreport/internal/heartbeat"
	"olt-social/finreport/internal/keys"
	"olt-social/finreport/internal/metrics"
	"olt-social/finreport/internal/storage"
	"olt-social/finreport/internal/store"
	"olt-social/finreport/internal/worker"
	"olt-social/finreport/internal/xbrl"
)

const (
	service = "finreport"
	version = "0.1.0"
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
		log.Error("Finreport stopped with an error", "error", err)
		os.Exit(1)
	}
}

func run(cfg config.Config, log *slog.Logger, startedAt time.Time) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	rest := store.NewPostgREST(cfg.PostgRESTURL, cfg.JWTSecret, cfg.JWTIssuer, cfg.RequestTimeout)
	objects := storage.New(cfg.StorageURL, cfg.JWTSecret, cfg.JWTIssuer, cfg.RequestTimeout)
	limits := xbrl.DefaultLimits()
	jobs := worker.New(worker.Options{
		Store:        rest,
		Objects:      objects,
		Scanner:      clamd.New(cfg.ClamdAddr, cfg.ScanTimeout),
		Log:          log,
		Instance:     cfg.InstanceID,
		PollInterval: cfg.PollInterval,
		Lease:        cfg.Lease,
		JobTimeout:   cfg.JobTimeout,
		MaxFileBytes: cfg.MaxFileBytes,
		Limits:       limits,
	})
	var beats *heartbeat.Loop
	gateway := api.New(api.Options{
		Log:                   log,
		Store:                 rest,
		Objects:               objects,
		Keys:                  keys.NewCache(rest, cfg.KeyCacheTTL),
		ClientIP:              clientip.New(cfg.TrustedProxies).Of,
		MaxFileBytes:          cfg.MaxFileBytes,
		MaxUploads:            cfg.MaxUploads,
		AuthFailuresPerMinute: cfg.AuthFailuresPerMinute,
		RequestTimeout:        cfg.RequestTimeout,
		Limits:                limits,
		Accepted:              jobs.Wake,
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
		Report: func() heartbeat.Report {
			report := jobs.Report()
			if snap := gateway.Snapshot(); snap.StoreFailures >= 3 && report.Status == heartbeat.StatusOK {
				report.Status = heartbeat.StatusDegraded
				report.Error = fmt.Sprintf("Storage or database API unreachable (%d consecutive failures): %s",
					snap.StoreFailures, snap.LastError)
			}
			return report
		},
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
		snap := gateway.Snapshot()
		reports, busy := jobs.Counts()
		requests := make(map[metrics.Request]uint64, len(snap.Requests))
		for k, v := range snap.Requests {
			requests[metrics.Request{Endpoint: k.Endpoint, Code: k.Code}] = v
		}
		return metrics.Snapshot{
			Requests:      requests,
			UploadedBytes: snap.Bytes,
			Inflight:      snap.Inflight,
			Capacity:      snap.Capacity,
			KeysCached:    snap.KeysCached,
			StoreFailures: snap.StoreFailures,
			Reports:       reports,
			WorkerBusy:    busy,
			LastHeartbeat: beats.LastSuccess(),
		}
	}))

	apiServer := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           gateway,
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
	log.Info("Finreport listening", "port", cfg.Port, "ops_port", cfg.OpsPort, "instance", cfg.InstanceID,
		"version", version, "max_uploads", cfg.MaxUploads, "max_file_bytes", cfg.MaxFileBytes)

	background, stopBackground := context.WithCancel(context.Background())
	var wg sync.WaitGroup
	for _, loop := range []func(context.Context){beats.Run, jobs.Run} {
		wg.Add(1)
		go func() {
			defer wg.Done()
			loop(background)
		}()
	}

	var failure error
	select {
	case failure = <-errCh:
	case <-ctx.Done():
		log.Info("Shutting down; finishing the uploads and the report in flight")
	}
	ready.Store(false)
	shutdown, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	if err := apiServer.Shutdown(shutdown); err != nil {
		log.Warn("Shutdown timeout reached; closing requests still in flight", "timeout", cfg.ShutdownTimeout.String())
		_ = apiServer.Close()
	}
	stopBackground()
	wg.Wait()
	opsDone, cancelOps := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancelOps()
	_ = opsServer.Shutdown(opsDone)
	if failure != nil {
		return failure
	}
	log.Info("Finreport stopped")
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
