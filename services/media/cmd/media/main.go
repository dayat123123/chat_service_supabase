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

	"olt-social/media/internal/attachments"
	"olt-social/media/internal/clamd"
	"olt-social/media/internal/config"
	"olt-social/media/internal/heartbeat"
	"olt-social/media/internal/metrics"
	"olt-social/media/internal/moderation"
	"olt-social/media/internal/server"
	"olt-social/media/internal/storage"
	"olt-social/media/internal/store"
	"olt-social/media/internal/video"
)

const (
	service = "media"
	version = "0.3.0"
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
		log.Error("Media stopped with an error", "error", err)
		os.Exit(1)
	}
}

func run(cfg config.Config, log *slog.Logger, startedAt time.Time) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	var beats *heartbeat.Loop
	db := store.NewPostgREST(cfg.PostgRESTURL, cfg.JWTSecret, cfg.JWTIssuer)
	policy := moderation.NewPolicy(db, log, cfg.ModerationRefresh, func() { beats.Kick() })
	rules := attachments.NewLoader(db, log, cfg.AttachmentRefresh, func() { beats.Kick() })
	uploads := server.New(server.Options{
		Log:         log,
		Secret:      cfg.JWTSecret,
		Storage:     storage.New(cfg.StorageURL, cfg.MaxConcurrent),
		Classifier:  moderation.NewClient(cfg.ClassifierURL, cfg.ClassifierTimeout, cfg.MaxConcurrent),
		Policy:      policy,
		Holds:       db,
		Attachments: rules,
		Scanner:     clamd.New(cfg.ClamdAddr, cfg.ScanTimeout),
		Video: video.New(video.Options{
			FFmpeg:      cfg.FFmpegPath,
			FFprobe:     cfg.FFprobePath,
			Concurrent:  cfg.VideoConcurrent,
			StepTimeout: cfg.VideoStepTimeout,
		}),
		AllowUnclassified: cfg.AllowUnclassified,
		MaxConcurrent:     cfg.MaxConcurrent,
		RequestTimeout:    cfg.RequestTimeout,
		Notify:            func() { beats.Kick() },
	})
	beats = heartbeat.New(heartbeat.Options{
		Store:     db,
		Log:       log,
		Service:   service,
		Instance:  cfg.InstanceID,
		Version:   version,
		StartedAt: startedAt,
		Interval:  cfg.HeartbeatInterval,
		Probe:     uploads.Probe,
		Report:    uploads.Report,
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
		snapshot := uploads.Metrics()
		snapshot.LastHeartbeat = beats.LastSuccess()
		return snapshot
	}))

	api := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           uploads,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       cfg.RequestTimeout + 5*time.Second,
		WriteTimeout:      cfg.RequestTimeout + 10*time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    64 << 10,
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
	for _, srv := range []*http.Server{api, opsServer} {
		go func() {
			if err := srv.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
				errCh <- err
			}
		}()
	}
	log.Info("Media listening", "port", cfg.Port, "ops_port", cfg.OpsPort, "instance", cfg.InstanceID,
		"version", version, "max_concurrent", cfg.MaxConcurrent, "video_concurrent", cfg.VideoConcurrent,
		"scanner", cfg.ClamdAddr)
	if cfg.AllowUnclassified {
		log.Warn("MODEL_MISSING_POLICY=allow: images are stored without a check while the classifier has no model")
	}

	beatCtx, stopBeats := context.WithCancel(context.Background())
	policy.Refresh(beatCtx)
	rules.Refresh(beatCtx)
	var wg sync.WaitGroup
	wg.Add(3)
	go func() {
		defer wg.Done()
		beats.Run(beatCtx)
	}()
	go func() {
		defer wg.Done()
		policy.Run(beatCtx)
	}()
	go func() {
		defer wg.Done()
		rules.Run(beatCtx)
	}()

	var failure error
	select {
	case failure = <-errCh:
	case <-ctx.Done():
		log.Info("Shutting down; finishing the uploads in flight")
	}
	ready.Store(false)
	shutdown, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	if err := api.Shutdown(shutdown); err != nil {
		log.Warn("Shutdown timeout reached; closing uploads still in flight", "timeout", cfg.ShutdownTimeout.String())
		_ = api.Close()
	}
	stopBeats()
	wg.Wait()
	opsDone, cancelOps := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancelOps()
	_ = opsServer.Shutdown(opsDone)
	if failure != nil {
		return failure
	}
	log.Info("Media stopped")
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
