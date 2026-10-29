// Command auth-bridge menukar token login OLT menjadi JWT Supabase.
//
// Pemakaian:
//
//	auth-bridge              menjalankan HTTP server
//	auth-bridge healthcheck  cek /health server lokal (dipakai Docker healthcheck)
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

	"olt-social/auth-bridge/internal/config"
	"olt-social/auth-bridge/internal/exchange"
	"olt-social/auth-bridge/internal/olt"
	"olt-social/auth-bridge/internal/postgrest"
	"olt-social/auth-bridge/internal/ratelimit"
	"olt-social/auth-bridge/internal/server"
	"olt-social/auth-bridge/internal/token"
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

	verifier, err := newVerifier(cfg)
	if err != nil {
		return err
	}
	issuer := token.NewIssuer(cfg.JWTSecret, cfg.JWTTTL, cfg.JWTIssuer)
	store := postgrest.NewClient(cfg.PostgRESTURL, issuer)

	handler := server.New(server.Options{
		Log:            log,
		Resolver:       exchange.NewService(verifier, store, cfg.VerifyCacheTTL),
		Issuer:         issuer,
		Limiter:        ratelimit.New(cfg.RateLimitPerMinute, time.Minute),
		TrustedProxies: cfg.TrustedProxies,
		OLTMode:        string(cfg.OLT.Mode),
	}).Handler()

	srv := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      cfg.OLT.Timeout + 15*time.Second,
		IdleTimeout:       60 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		log.Info("auth-bridge berjalan",
			"port", cfg.Port, "app_env", cfg.AppEnv, "olt_mode", cfg.OLT.Mode,
			"jwt_ttl_s", cfg.JWTTTL.Seconds(), "cache_ttl_s", cfg.VerifyCacheTTL.Seconds())
		if cfg.OLT.Mode == config.OLTModeMock {
			log.Warn("OLT_MODE=mock: token dummy diterima. Jangan dipakai di produksi.")
		}
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
		close(errCh)
	}()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
	}

	log.Info("menerima sinyal stop, shutdown...")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	return srv.Shutdown(shutdownCtx)
}

func newVerifier(cfg config.Config) (olt.Verifier, error) {
	if cfg.OLT.Mode == config.OLTModeWebSocket {
		return olt.NewWebSocketVerifier(cfg.OLT)
	}
	return olt.MockVerifier{}, nil
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
