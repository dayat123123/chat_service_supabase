package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/redis/go-redis/v9"

	"olt-social/auth-bridge/internal/breaker"
	"olt-social/auth-bridge/internal/config"
	"olt-social/auth-bridge/internal/exchange"
	"olt-social/auth-bridge/internal/heartbeat"
	"olt-social/auth-bridge/internal/metrics"
	"olt-social/auth-bridge/internal/olt"
	"olt-social/auth-bridge/internal/postgrest"
	"olt-social/auth-bridge/internal/ratelimit"
	"olt-social/auth-bridge/internal/server"
	"olt-social/auth-bridge/internal/token"
)

const (
	version = "0.6.0"
	service = "auth-bridge"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		os.Exit(healthcheck())
	}

	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "konfigurasi tidak valid:\n%v\n", err)
		os.Exit(1)
	}

	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.LogLevel}))
	if err := run(cfg, log); err != nil {
		log.Error("server berhenti dengan error", "error", err)
		os.Exit(1)
	}
}

func run(cfg config.Config, log *slog.Logger) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	startedAt := time.Now()
	reg := metrics.NewRegistry()

	verifier, err := newVerifier(cfg)
	if err != nil {
		return err
	}
	brk := breaker.New(cfg.BreakerThreshold, cfg.BreakerCooldown)
	reg.GaugeFunc("olt_auth_bridge_olt_breaker_open",
		"1 bila circuit breaker ke server OLT terbuka (verifikasi baru langsung ditolak)",
		func() float64 {
			if brk.State() == breaker.Open {
				return 1
			}
			return 0
		})

	issuer := token.NewIssuer(cfg.JWTSecret, cfg.JWTTTL, cfg.JWTIssuer)
	store := postgrest.NewClient(cfg.PostgRESTURL, issuer)

	deps := newSharedState(cfg, log, reg)
	defer deps.close()

	s := server.New(server.Options{
		Log:            log,
		Resolver:       exchange.NewService(olt.WithBreaker(verifier, brk), store, deps.cache, cfg.VerifyCacheTTL),
		Issuer:         issuer,
		Limiter:        deps.ipLimiter,
		UserLimiter:    deps.userLimiter,
		TrustedProxies: cfg.TrustedProxies,
		OLTMode:        string(cfg.OLT.Mode),
		ReadyChecks: append([]server.ReadyCheck{
			{Name: "postgrest", Check: store.Ping},
			{Name: "olt", Optional: true, Check: func(context.Context) error {
				if brk.State() == breaker.Open {
					return errors.New("circuit breaker terbuka")
				}
				return nil
			}},
		}, deps.readyChecks...),
		Metrics: server.NewMetrics(reg),
	})

	beats := heartbeat.New(heartbeat.Options{
		Store:     store,
		Log:       log,
		Service:   service,
		Instance:  cfg.InstanceID,
		Version:   version,
		StartedAt: startedAt,
		Interval:  cfg.HeartbeatInterval,
		Report:    bridgeReport(cfg, verifier, brk),
	})
	reg.GaugeFunc("olt_auth_bridge_last_heartbeat_timestamp_seconds",
		"Waktu heartbeat terakhir yang berhasil ke database (detik Unix, 0 bila belum pernah)",
		func() float64 {
			if last := beats.LastSuccess(); !last.IsZero() {
				return float64(last.Unix())
			}
			return 0
		})

	servers := []*http.Server{{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           s.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      cfg.OLT.Timeout + 15*time.Second,
		IdleTimeout:       60 * time.Second,
	}}
	if cfg.OpsPort > 0 {
		servers = append(servers, &http.Server{
			Addr:              fmt.Sprintf(":%d", cfg.OpsPort),
			Handler:           s.OpsHandler(reg.Handler()),
			ReadHeaderTimeout: 5 * time.Second,
			ReadTimeout:       10 * time.Second,
			WriteTimeout:      10 * time.Second,
			IdleTimeout:       60 * time.Second,
		})
	}

	log.Info("auth-bridge berjalan", "version", version, "instance", cfg.InstanceID,
		"port", cfg.Port, "ops_port", cfg.OpsPort, "app_env", cfg.AppEnv, "olt_mode", cfg.OLT.Mode,
		"jwt_ttl_s", cfg.JWTTTL.Seconds(), "cache_ttl_s", cfg.VerifyCacheTTL.Seconds(),
		"valkey", cfg.ValkeyAddr != "")
	if cfg.OLT.Mode == config.OLTModeMock {
		log.Warn("OLT_MODE=mock: token dummy diterima. Jangan dipakai di produksi.")
	}

	go beats.Run(ctx)

	errCh := make(chan error, len(servers))
	for _, srv := range servers {
		go func() {
			if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
				errCh <- fmt.Errorf("listen %s: %w", srv.Addr, err)
			}
		}()
	}

	var runErr error
	select {
	case runErr = <-errCh:
	case <-ctx.Done():
		log.Info("menerima sinyal stop, shutdown...")
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	errs := []error{runErr}
	for _, srv := range servers {
		errs = append(errs, srv.Shutdown(shutdownCtx))
	}
	return errors.Join(errs...)
}

type sharedState struct {
	ipLimiter   server.RateLimiter
	userLimiter server.RateLimiter
	cache       exchange.Cache
	readyChecks []server.ReadyCheck
	close       func()
}

func newSharedState(cfg config.Config, log *slog.Logger, reg *metrics.Registry) sharedState {
	if cfg.ValkeyAddr == "" {
		log.Warn("VALKEY_ADDR kosong: rate limit & cache in-memory per instance (hanya untuk development satu replika)")
		return sharedState{
			ipLimiter:   ratelimit.New(cfg.RateLimitPerMinute, time.Minute),
			userLimiter: ratelimit.New(cfg.RateLimitPerUserPerMinute, time.Minute),
			cache:       exchange.NewMemoryCache(),
			close:       func() {},
		}
	}

	client := redis.NewClient(&redis.Options{
		Addr:         cfg.ValkeyAddr,
		Password:     cfg.ValkeyPassword,
		DB:           cfg.ValkeyDB,
		DialTimeout:  2 * time.Second,
		ReadTimeout:  500 * time.Millisecond,
		WriteTimeout: 500 * time.Millisecond,
		PoolTimeout:  time.Second,
	})

	errorsTotal := reg.Counter("olt_auth_bridge_valkey_errors_total",
		"Error Valkey (rate limit memakai fallback in-memory, cache dilewati)", "op")
	warn := throttled(time.Minute)
	onError := func(op string) func(error) {
		return func(err error) {
			errorsTotal.Inc(op)
			warn(func() { log.Warn("valkey bermasalah, memakai fallback", "op", op, "error", err.Error()) })
		}
	}

	const rlPrefix = "bridge:rl:exchange:"
	ipLimiter := ratelimit.NewValkey(client, rlPrefix, cfg.RateLimitPerMinute, time.Minute)
	ipLimiter.OnError = onError("ratelimit")
	userLimiter := ratelimit.NewValkey(client, rlPrefix, cfg.RateLimitPerUserPerMinute, time.Minute)
	userLimiter.OnError = onError("ratelimit")
	cache := exchange.NewValkeyCache(client, "bridge:verify:")
	cache.OnError = onError("cache")

	return sharedState{
		ipLimiter:   ipLimiter,
		userLimiter: userLimiter,
		cache:       cache,
		readyChecks: []server.ReadyCheck{{Name: "valkey", Optional: true, Check: func(ctx context.Context) error {
			return client.Ping(ctx).Err()
		}}},
		close: func() { _ = client.Close() },
	}
}

func throttled(every time.Duration) func(fn func()) {
	var last atomic.Int64
	return func(fn func()) {
		now := time.Now().UnixNano()
		prev := last.Load()
		if now-prev < int64(every) || !last.CompareAndSwap(prev, now) {
			return
		}
		fn()
	}
}

func bridgeReport(cfg config.Config, verifier olt.Verifier, brk *breaker.Breaker) func() heartbeat.Report {
	info := heartbeat.Bridge{
		AppEnv:   cfg.AppEnv,
		OLTMode:  string(cfg.OLT.Mode),
		Issuer:   cfg.OLT.JWTIssuer,
		Audience: cfg.OLT.JWTAudience,
		MaxTTL:   cfg.OLT.JWTMaxTTL,
	}
	if keyed, ok := verifier.(interface{ Keys() []olt.KeyInfo }); ok {
		info.Keys = keyed.Keys()
	}
	detail := info.Detail()
	return func() heartbeat.Report {
		if brk.State() == breaker.Open {
			return heartbeat.Report{Status: heartbeat.StatusDegraded, Error: "circuit breaker OLT terbuka", Detail: detail}
		}
		return heartbeat.Report{Status: heartbeat.StatusOK, Detail: detail}
	}
}

func newVerifier(cfg config.Config) (olt.Verifier, error) {
	switch cfg.OLT.Mode {
	case config.OLTModeJWT:
		return olt.NewJWTVerifier(cfg.OLT.JWKS, olt.JWTOptions{
			Issuer:        cfg.OLT.JWTIssuer,
			Audience:      cfg.OLT.JWTAudience,
			MaxTTL:        cfg.OLT.JWTMaxTTL,
			Leeway:        cfg.OLT.JWTLeeway,
			RejectDevKeys: cfg.IsProduction(),
		})
	case config.OLTModeWebSocket:
		return olt.NewWebSocketVerifier(cfg.OLT)
	default:
		return olt.MockVerifier{}, nil
	}
}

func healthcheck() int {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	client := http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://127.0.0.1:" + port + "/health")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		fmt.Fprintln(os.Stderr, "status", resp.StatusCode)
		return 1
	}
	return 0
}
