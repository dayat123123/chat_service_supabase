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

	"olt-social/classifier/internal/config"
	"olt-social/classifier/internal/heartbeat"
	"olt-social/classifier/internal/metrics"
	"olt-social/classifier/internal/model"
	"olt-social/classifier/internal/onnx"
	"olt-social/classifier/internal/server"
	"olt-social/classifier/internal/store"
)

const (
	service = "classifier"
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
		log.Error("Classifier stopped with an error", "error", err)
		os.Exit(1)
	}
}

func load(cfg config.Config, log *slog.Logger) (*server.Engine, string) {
	manifest, path, err := model.Load(cfg.ModelDir)
	if err != nil {
		log.Error("Model is not available; classification requests will be refused", "error", err, "model_dir", cfg.ModelDir)
		return nil, err.Error()
	}
	if err := onnx.Init(cfg.RuntimeLibrary); err != nil {
		log.Error("ONNX Runtime is not available; classification requests will be refused", "error", err)
		return nil, err.Error()
	}
	session, err := onnx.Open(path, manifest, cfg.Threads)
	if err != nil {
		log.Error("Model could not be opened; classification requests will be refused", "error", err)
		return nil, err.Error()
	}
	log.Info("Model loaded", "model", manifest.ID, "sha256", manifest.SHA256, "labels", manifest.Labels,
		"input", manifest.Shape, "threads", cfg.Threads)
	return &server.Engine{Manifest: manifest, Model: session}, ""
}

func run(cfg config.Config, log *slog.Logger, startedAt time.Time) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	engine, missing := load(cfg, log)
	defer onnx.Shutdown()
	var beats *heartbeat.Loop
	classifier := server.New(server.Options{
		Log:            log,
		Engine:         engine,
		Missing:        missing,
		MaxConcurrent:  cfg.MaxConcurrent,
		QueueWait:      cfg.QueueWait,
		RequestTimeout: cfg.RequestTimeout,
		Notify:         func() { beats.Kick() },
	})
	beats = heartbeat.New(heartbeat.Options{
		Store:     store.NewPostgREST(cfg.PostgRESTURL, cfg.JWTSecret, cfg.JWTIssuer),
		Log:       log,
		Service:   service,
		Instance:  cfg.InstanceID,
		Version:   version,
		StartedAt: startedAt,
		Interval:  cfg.HeartbeatInterval,
		Report:    classifier.Report,
	})

	var stopping atomic.Bool
	ops := http.NewServeMux()
	ops.HandleFunc("GET /livez", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("ok"))
	})
	ops.HandleFunc("GET /readyz", func(w http.ResponseWriter, _ *http.Request) {
		switch {
		case stopping.Load():
			http.Error(w, "shutting down", http.StatusServiceUnavailable)
		case !classifier.Ready():
			http.Error(w, "model missing", http.StatusServiceUnavailable)
		default:
			_, _ = w.Write([]byte("ok"))
		}
	})
	ops.Handle("GET /metrics", metrics.Handler(func() metrics.Snapshot {
		snapshot := classifier.Metrics()
		snapshot.LastHeartbeat = beats.LastSuccess()
		return snapshot
	}))

	api := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           classifier,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       cfg.RequestTimeout + 5*time.Second,
		WriteTimeout:      cfg.RequestTimeout + 10*time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    16 << 10,
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
	log.Info("Classifier listening", "port", cfg.Port, "ops_port", cfg.OpsPort, "instance", cfg.InstanceID,
		"version", version, "max_concurrent", cfg.MaxConcurrent, "model_loaded", engine != nil)

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
		log.Info("Shutting down; finishing the classifications in flight")
	}
	stopping.Store(true)
	shutdown, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	if err := api.Shutdown(shutdown); err != nil {
		log.Warn("Shutdown timeout reached; closing requests still in flight", "timeout", cfg.ShutdownTimeout.String())
		_ = api.Close()
	}
	stopBeats()
	wg.Wait()
	opsDone, cancelOps := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancelOps()
	_ = opsServer.Shutdown(opsDone)
	if engine != nil {
		_ = engine.Model.Close()
	}
	if failure != nil {
		return failure
	}
	log.Info("Classifier stopped")
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
