package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"olt-social/cs/internal/adapter"
	"olt-social/cs/internal/breaker"
	"olt-social/cs/internal/env"
	"olt-social/cs/internal/metrics"
	"olt-social/cs/internal/olt"
	"olt-social/cs/internal/ops"
	"olt-social/cs/internal/postgrest"
	"olt-social/cs/internal/token"
)

type config struct {
	appEnv           string
	logLevel         slog.Level
	port             int
	opsPort          int
	jwtSecret        string
	postgrestURL     string
	breakerThreshold int
	breakerCooldown  time.Duration
	olt              olt.Config
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		var r env.Reader
		os.Exit(ops.Healthcheck(r.String("OPS_PORT", "9100")))
	}
	cfg, err := loadConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "konfigurasi tidak valid:\n%v\n", err)
		os.Exit(1)
	}
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.logLevel}))
	if err := run(cfg, log); err != nil {
		log.Error("customer-adapter berhenti dengan error", "error", err)
		os.Exit(1)
	}
}

func loadConfig() (config, error) {
	var r env.Reader
	cfg := config{
		appEnv:           strings.ToLower(r.String("APP_ENV", "production")),
		logLevel:         r.LogLevel("LOG_LEVEL"),
		port:             r.Int("PORT", 8080, 1),
		opsPort:          r.Int("OPS_PORT", 9100, 1),
		jwtSecret:        r.Secret("JWT_SECRET"),
		postgrestURL:     strings.TrimRight(r.String("POSTGREST_URL", "http://rest:3000"), "/"),
		breakerThreshold: r.Int("BREAKER_FAILURE_THRESHOLD", 5, 1),
		breakerCooldown:  r.Seconds("BREAKER_COOLDOWN", 30),
		olt: olt.Config{
			URL:     r.String("OLT_WS_URL", ""),
			Token:   r.Secret("OLT_SERVICE_TOKEN"),
			Origin:  r.String("OLT_WS_ORIGIN", ""),
			Timeout: r.Seconds("OLT_WS_TIMEOUT", 5),
		},
	}
	if len(cfg.jwtSecret) < 32 {
		r.Fail(errors.New("JWT_SECRET wajib diisi, minimal 32 karakter"))
	}
	if cfg.port == cfg.opsPort {
		r.Fail(errors.New("OPS_PORT tidak boleh sama dengan PORT"))
	}
	if cfg.olt.URL != "" {
		u, err := url.Parse(cfg.olt.URL)
		if err != nil || (u.Scheme != "ws" && u.Scheme != "wss") {
			r.Fail(errors.New("OLT_WS_URL harus berupa URL ws:// atau wss://"))
		}
		if cfg.olt.Token == "" {
			r.Fail(errors.New("OLT_SERVICE_TOKEN wajib diisi bila OLT_WS_URL diisi"))
		}
	}
	if cfg.appEnv == "production" {
		if !strings.HasPrefix(cfg.olt.URL, "wss://") {
			r.Fail(errors.New("OLT_WS_URL wajib wss:// saat APP_ENV=production"))
		}
	}
	return cfg, r.Err()
}

func run(cfg config, log *slog.Logger) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	reg := metrics.NewRegistry()
	tokens := token.NewService(cfg.jwtSecret, "olt-customer-adapter")
	api := postgrest.New(cfg.postgrestURL, tokens, 10*time.Second)
	brk := breaker.New(cfg.breakerThreshold, cfg.breakerCooldown)
	client := olt.New(cfg.olt, brk)
	reg.GaugeFunc("olt_customer_adapter_olt_breaker_open",
		"1 bila circuit breaker ke OLT terbuka (data OLT tampil tidak tersedia)",
		func() float64 {
			if brk.State() == breaker.Open {
				return 1
			}
			return 0
		})

	server := adapter.NewServer(api, client, cfg.jwtSecret, log, adapter.NewMetrics(reg))
	servers := []*ops.Managed{
		{Name: "api", Server: ops.Server(cfg.port, server.Handler(), cfg.olt.Timeout+15*time.Second)},
		{Name: "ops", Server: ops.Server(cfg.opsPort, ops.Handler(reg, []ops.Check{
			{Name: "postgrest", Check: api.Ping},
			{Name: "olt", Optional: true, Check: func(context.Context) error {
				if cfg.olt.URL == "" {
					return errors.New("OLT_WS_URL belum diatur")
				}
				if brk.State() == breaker.Open {
					return errors.New("circuit breaker terbuka")
				}
				return nil
			}},
		}), 10*time.Second)},
	}

	if cfg.olt.URL == "" {
		log.Warn("OLT_WS_URL kosong: semua data OLT tampil tidak tersedia (hanya untuk development)")
	}
	log.Info("customer-adapter berjalan", "port", cfg.port, "ops_port", cfg.opsPort, "app_env", cfg.appEnv,
		"olt_configured", cfg.olt.URL != "")

	var wg sync.WaitGroup
	errCh := make(chan error, len(servers))
	for _, s := range servers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := ops.Serve(ctx, s.Server); err != nil {
				errCh <- fmt.Errorf("%s: %w", s.Name, err)
				cancel()
			}
		}()
	}
	<-ctx.Done()
	wg.Wait()
	close(errCh)
	var errs []error
	for err := range errCh {
		errs = append(errs, err)
	}
	return errors.Join(errs...)
}
