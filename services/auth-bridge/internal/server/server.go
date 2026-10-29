// Package server berisi HTTP handler auth-bridge.
//
//	GET  /health    status service
//	POST /exchange  {"token":"<token OLT>"} -> JWT Supabase
package server

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"net/netip"
	"strconv"
	"strings"
	"time"

	"olt-social/auth-bridge/internal/exchange"
	"olt-social/auth-bridge/internal/olt"
	"olt-social/auth-bridge/internal/token"
)

// Resolver memverifikasi token OLT dan mengembalikan identitas user.
type Resolver interface {
	Resolve(ctx context.Context, oltToken string) (exchange.Identity, bool, error)
}

// TokenIssuer menerbitkan JWT user.
type TokenIssuer interface {
	UserToken(u token.User) (string, time.Time, error)
}

// RateLimiter membatasi request per kunci.
type RateLimiter interface {
	Allow(key string) (bool, time.Duration)
}

// Options adalah dependensi Server.
type Options struct {
	Log            *slog.Logger
	Resolver       Resolver
	Issuer         TokenIssuer
	Limiter        RateLimiter
	TrustedProxies []netip.Prefix
	OLTMode        string
}

// Server menyatukan dependensi handler HTTP.
type Server struct {
	opts Options
}

// New membuat Server baru.
func New(opts Options) *Server {
	return &Server{opts: opts}
}

// Handler mengembalikan router HTTP lengkap dengan middleware.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", s.handleHealth)
	mux.HandleFunc("POST /exchange", s.handleExchange)
	return s.withRequestID(s.withRecover(s.withLogging(mux)))
}

func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "olt_mode": s.opts.OLTMode})
}

type exchangeRequest struct {
	Token string `json:"token"`
}

type exchangeResponse struct {
	AccessToken string           `json:"access_token"`
	TokenType   string           `json:"token_type"`
	ExpiresIn   int64            `json:"expires_in"`
	ExpiresAt   int64            `json:"expires_at"`
	User        exchange.Profile `json:"user"`
}

func (s *Server) handleExchange(w http.ResponseWriter, r *http.Request) {
	ip := s.clientIP(r)
	if ok, retry := s.opts.Limiter.Allow(ip); !ok {
		w.Header().Set("Retry-After", strconv.Itoa(int(retry.Seconds())+1))
		writeError(w, http.StatusTooManyRequests, "rate_limited", "Terlalu banyak permintaan, coba lagi nanti")
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, 8<<10)
	var req exchangeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", `Body harus JSON {"token":"..."}`)
		return
	}
	req.Token = strings.TrimSpace(req.Token)
	if req.Token == "" || len(req.Token) > 4096 {
		writeError(w, http.StatusBadRequest, "invalid_request", "token wajib diisi")
		return
	}

	id, cached, err := s.opts.Resolver.Resolve(r.Context(), req.Token)
	switch {
	case errors.Is(err, olt.ErrInvalidToken):
		s.logger(r).Info("exchange ditolak", "reason", err.Error(), "client_ip", ip)
		writeError(w, http.StatusUnauthorized, "invalid_token", "Sesi OLT tidak valid, silakan login ulang")
		return
	case errors.Is(err, olt.ErrUnavailable):
		s.logger(r).Warn("server OLT tidak tersedia", "error", err.Error())
		writeError(w, http.StatusServiceUnavailable, "olt_unavailable", "Server OLT sedang tidak dapat dihubungi")
		return
	case err != nil:
		s.logger(r).Error("exchange gagal", "error", err.Error())
		writeError(w, http.StatusBadGateway, "exchange_failed", "Gagal menyiapkan sesi sosial")
		return
	}

	jwt, exp, err := s.opts.Issuer.UserToken(token.User{
		ID:        id.Profile.ID,
		OLTUserID: id.Profile.OLTUserID,
		Username:  id.Profile.Username,
		Email:     id.Email,
	})
	if err != nil {
		s.logger(r).Error("gagal menandatangani JWT", "error", err.Error())
		writeError(w, http.StatusInternalServerError, "internal_error", "Terjadi kesalahan")
		return
	}

	s.logger(r).Info("exchange berhasil", "user_id", id.Profile.ID, "cached", cached)
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, exchangeResponse{
		AccessToken: jwt,
		TokenType:   "bearer",
		ExpiresIn:   int64(time.Until(exp).Round(time.Second).Seconds()),
		ExpiresAt:   exp.Unix(),
		User:        id.Profile,
	})
}

// clientIP mengambil IP klien. X-Forwarded-For hanya dipercaya bila request
// datang dari proxy tepercaya (Kong/Caddy); diambil IP paling kanan yang
// bukan proxy tepercaya.
func (s *Server) clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	remote, err := netip.ParseAddr(host)
	if err != nil || !s.trusted(remote) {
		return host
	}
	hops := strings.Split(r.Header.Get("X-Forwarded-For"), ",")
	for i := len(hops) - 1; i >= 0; i-- {
		addr, err := netip.ParseAddr(strings.TrimSpace(hops[i]))
		if err != nil {
			break
		}
		if !s.trusted(addr) {
			return addr.String()
		}
	}
	return host
}

func (s *Server) trusted(addr netip.Addr) bool {
	addr = addr.Unmap()
	for _, p := range s.opts.TrustedProxies {
		if p.Contains(addr) {
			return true
		}
	}
	return false
}

// ---------------------------------------------------------------------------
// Middleware
// ---------------------------------------------------------------------------

type ctxKey int

const requestIDKey ctxKey = iota

func (s *Server) withRequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("X-Request-Id")
		if id == "" || len(id) > 64 {
			var b [8]byte
			_, _ = rand.Read(b[:])
			id = hex.EncodeToString(b[:])
		}
		w.Header().Set("X-Request-Id", id)
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), requestIDKey, id)))
	})
}

func (s *Server) withRecover(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				s.logger(r).Error("panic", "panic", rec)
				writeError(w, http.StatusInternalServerError, "internal_error", "Terjadi kesalahan")
			}
		}()
		next.ServeHTTP(w, r)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

func (s *Server) withLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)

		// Healthcheck Docker berjalan tiap beberapa detik; jangan banjiri log.
		level := slog.LevelInfo
		if r.URL.Path == "/health" && rec.status == http.StatusOK {
			level = slog.LevelDebug
		}
		s.logger(r).Log(r.Context(), level, "http request",
			"method", r.Method,
			"path", r.URL.Path,
			"status", rec.status,
			"duration_ms", time.Since(start).Milliseconds(),
			"client_ip", s.clientIP(r),
		)
	})
}

func (s *Server) logger(r *http.Request) *slog.Logger {
	if id, ok := r.Context().Value(requestIDKey).(string); ok {
		return s.opts.Log.With("request_id", id)
	}
	return s.opts.Log
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]string{"error": code, "message": message})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
