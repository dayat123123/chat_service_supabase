package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"olt-social/dummy-olt/internal/server"
	"olt-social/dummy-olt/internal/social"
	"olt-social/dummy-olt/internal/tokens"
	"olt-social/dummy-olt/internal/users"
)

const defaultSecret = "dummy-olt-dev-secret-jangan-dipakai-di-produksi"

func main() {
	cmd, args := "serve", os.Args[1:]
	if len(args) > 0 {
		cmd, args = args[0], args[1:]
	}
	switch cmd {
	case "serve":
		os.Exit(serve())
	case "token":
		os.Exit(mintToken(args))
	case "healthcheck":
		os.Exit(healthcheck())
	default:
		fmt.Fprintln(os.Stderr, "pemakaian: dummy-olt [serve | token <user> [-ttl 24h] [-social] | healthcheck]")
		os.Exit(2)
	}
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func durationEnv(key, def string) (time.Duration, error) {
	d, err := time.ParseDuration(env(key, def))
	if err != nil {
		return 0, fmt.Errorf("%s: %w", key, err)
	}
	return d, nil
}

func socialSigner() (*social.Signer, error) {
	path := os.Getenv("DUMMY_OLT_SIGNING_KEY_FILE")
	if path == "" {
		return nil, errors.New("DUMMY_OLT_SIGNING_KEY_FILE wajib diisi (kunci Ed25519 dev, dibuat make gen-secrets)")
	}
	pemBytes, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("DUMMY_OLT_SIGNING_KEY_FILE: %w", err)
	}
	key, err := social.ParsePrivateKey(pemBytes)
	if err != nil {
		return nil, fmt.Errorf("DUMMY_OLT_SIGNING_KEY_FILE: %w", err)
	}
	return social.NewSigner(key, env("DUMMY_OLT_SIGNING_KID", "dev-olt-1"), env("DUMMY_OLT_SOCIAL_ISSUER", "olt"),
		env("DUMMY_OLT_SOCIAL_AUDIENCE", "olt-social")), nil
}

func serve() int {
	var level slog.Level
	_ = level.UnmarshalText([]byte(env("LOG_LEVEL", "info")))
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: level}))

	ttl, err1 := durationEnv("DUMMY_OLT_TOKEN_TTL", "24h")
	slow, err2 := durationEnv("DUMMY_OLT_SLOW_DELAY", "8s")
	heartbeat, err3 := durationEnv("DUMMY_OLT_HEARTBEAT", "15s")
	acceptMock, err4 := strconv.ParseBool(env("DUMMY_OLT_ACCEPT_MOCK_TOKENS", "true"))
	socialTTL, err5 := durationEnv("DUMMY_OLT_SOCIAL_TTL", "10m")
	signer, err6 := socialSigner()
	if err := errors.Join(err1, err2, err3, err4, err5, err6); err != nil {
		fmt.Fprintln(os.Stderr, "konfigurasi tidak valid:", err)
		return 1
	}

	srv := server.New(users.Default(), tokens.NewIssuer(env("DUMMY_OLT_SECRET", defaultSecret)), signer, server.Config{
		TokenTTL:          ttl,
		SocialTTL:         socialTTL,
		SocialAudience:    env("DUMMY_OLT_SOCIAL_AUDIENCE", "olt-social"),
		AcceptMockTokens:  acceptMock,
		SlowDelay:         slow,
		HeartbeatInterval: heartbeat,
	}, log)

	httpServer := &http.Server{
		Addr:              ":" + env("PORT", "8090"),
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = httpServer.Shutdown(shutdown)
	}()

	log.Warn("dummy-olt berjalan: server OLT TIRUAN untuk development/testing, jangan dipakai di produksi",
		"addr", httpServer.Addr, "accept_mock_tokens", acceptMock, "token_ttl", ttl.String(), "social_ttl", socialTTL.String())
	if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Error("server berhenti", "error", err)
		return 1
	}
	return 0
}

func mintToken(args []string) int {
	if len(args) == 0 || args[0] == "" || args[0][0] == '-' {
		fmt.Fprintln(os.Stderr, "pemakaian: dummy-olt token <id|username|email> [-ttl 24h] [-social]")
		return 2
	}
	identifier := args[0]
	fs := flag.NewFlagSet("token", flag.ContinueOnError)
	ttl := fs.Duration("ttl", 24*time.Hour, "masa berlaku token (negatif = sudah kedaluwarsa; token sosial default DUMMY_OLT_SOCIAL_TTL)")
	socialToken := fs.Bool("social", false, "cetak token sosial (JWT) untuk ditukar di auth-bridge")
	if err := fs.Parse(args[1:]); err != nil {
		return 2
	}

	u, ok := users.Default().Find(identifier)
	if !ok {
		fmt.Fprintf(os.Stderr, "akun %q tidak dikenal (lihat services/dummy-olt/README.md)\n", identifier)
		return 1
	}
	if *socialToken {
		ttlSet := false
		fs.Visit(func(f *flag.Flag) { ttlSet = ttlSet || f.Name == "ttl" })
		if !ttlSet {
			socialTTL, err := durationEnv("DUMMY_OLT_SOCIAL_TTL", "10m")
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
				return 1
			}
			*ttl = socialTTL
		}
		signer, err := socialSigner()
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		token, _, err := signer.Sign(social.Identity{ID: strconv.FormatInt(u.ID, 10), Username: u.Username, Name: u.FullName,
			Email: u.Email, Accounts: u.Accounts}, *ttl)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		fmt.Println(token)
		return 0
	}
	token, _, err := tokens.NewIssuer(env("DUMMY_OLT_SECRET", defaultSecret)).Issue(strconv.FormatInt(u.ID, 10), *ttl)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	fmt.Println(token)
	return 0
}

func healthcheck() int {
	client := http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://127.0.0.1:" + env("PORT", "8090") + "/health")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
