// Package server berisi HTTP handler auth-bridge.
//
// Port publik (diteruskan Kong di /bridge/v1/):
//
//	GET  /health    status service (dipakai healthcheck Docker)
//	POST /exchange  {"token":"<token OLT>"} -> JWT Supabase
//
// Port ops (internal, tidak diteruskan Kong):
//
//	GET  /metrics   metrik Prometheus
//	GET  /livez     proses hidup
//	GET  /readyz    dependensi siap
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
	"olt-social/auth-bridge/internal/metrics"
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
	Log      *slog.Logger
	Resolver Resolver
	Issuer   TokenIssuer
	// Limiter membatasi /exchange per IP klien; UserLimiter per user OLT
	// (diperiksa setelah token terverifikasi). UserLimiter boleh nil.
	Limiter        RateLimiter
	UserLimiter    RateLimiter
	TrustedProxies []netip.Prefix
	OLTMode        string
	// ReadyChecks dijalankan berurutan oleh /readyz. Boleh kosong.
	ReadyChecks []ReadyCheck
	// Metrics boleh nil (tidak mencatat metrik).
	Metrics *Metrics
}

// ReadyCheck adalah satu pemeriksaan /readyz. Kegagalan pemeriksaan Optional
// hanya dilaporkan "degraded" (layanan tetap jalan dengan fallback) dan tidak
// membuat instance dianggap tidak siap: kalau Valkey mati, semua replika akan
// gagal bersamaan, dan menariknya dari rotasi justru memadamkan layanan.
type ReadyCheck struct {
	Name     string
	Check    func(context.Context) error
	Optional bool
}

// Metrics adalah metrik HTTP & exchange yang dicatat handler.
type Metrics struct {
	Requests  *metrics.CounterVec   // label: path, status
	Duration  *metrics.HistogramVec // label: path
	Exchanges *metrics.CounterVec   // label: result
}

// NewMetrics mendaftarkan metrik server ke registry.
func NewMetrics(r *metrics.Registry) *Metrics {
	return &Metrics{
		Requests: r.Counter("olt_auth_bridge_http_requests_total", "Jumlah request HTTP", "path", "status"),
		Duration: r.Histogram("olt_auth_bridge_http_request_duration_seconds", "Durasi request HTTP",
			[]float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10}, "path"),
		Exchanges: r.Counter("olt_auth_bridge_exchanges_total",
			"Hasil exchange token (ok, cached, invalid_token, olt_unavailable, banned, rate_limited_ip, rate_limited_user, error)",
			"result"),
	}
}

// Server menyatukan dependensi handler HTTP.
type Server struct {
	opts Options
}

// New membuat Server baru.
func New(opts Options) *Server {
	return &Server{opts: opts}
}

// Handler mengembalikan router HTTP publik lengkap dengan middleware.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", s.handleHealth)
	mux.HandleFunc("POST /exchange", s.handleExchange)
	return s.withRequestID(s.withRecover(s.withLogging(mux)))
}

// OpsHandler mengembalikan router port ops: /metrics, /livez, /readyz.
// Tidak dicatat ke log/metrik per request (di-scrape berkala).
func (s *Server) OpsHandler(metricsHandler http.Handler) http.Handler {
	mux := http.NewServeMux()
	mux.Handle("GET /metrics", metricsHandler)
	mux.HandleFunc("GET /livez", s.handleLive)
	mux.HandleFunc("GET /readyz", s.handleReady)
	return s.withRecover(mux)
}

func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "olt_mode": s.opts.OLTMode})
}

func (s *Server) handleLive(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// handleReady memeriksa dependensi: 200 "ready"/"degraded", atau 503
// "not_ready" bila pemeriksaan wajib gagal. Detail error hanya ke log.
func (s *Server) handleReady(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	status, state, checks := http.StatusOK, "ready", map[string]string{}
	for _, c := range s.opts.ReadyChecks {
		err := c.Check(ctx)
		switch {
		case err == nil:
			checks[c.Name] = "ok"
		case c.Optional:
			checks[c.Name] = "degraded"
			if state == "ready" {
				state = "degraded"
			}
			s.logger(r).Warn("readiness: dependensi opsional bermasalah", "check", c.Name, "error", err.Error())
		default:
			checks[c.Name] = "fail"
			status, state = http.StatusServiceUnavailable, "not_ready"
			s.logger(r).Warn("readiness gagal", "check", c.Name, "error", err.Error())
		}
	}
	writeJSON(w, status, map[string]any{"status": state, "checks": checks})
}

func (s *Server) countExchange(result string) {
	if s.opts.Metrics != nil {
		s.opts.Metrics.Exchanges.Inc(result)
	}
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
	if ok, retry := s.opts.Limiter.Allow("ip:" + ip); !ok {
		s.countExchange("rate_limited_ip")
		s.logger(r).Warn("rate limit exchange (IP)", "client_ip", ip)
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
		s.countExchange("invalid_token")
		s.logger(r).Info("exchange ditolak", "reason", err.Error(), "client_ip", ip)
		writeError(w, http.StatusUnauthorized, "invalid_token", "Sesi OLT tidak valid, silakan login ulang")
		return
	case errors.Is(err, olt.ErrUnavailable):
		s.countExchange("olt_unavailable")
		s.logger(r).Warn("server OLT tidak tersedia", "error", err.Error())
		writeError(w, http.StatusServiceUnavailable, "olt_unavailable", "Server OLT sedang tidak dapat dihubungi")
		return
	case errors.Is(err, exchange.ErrBanned):
		s.countExchange("banned")
		s.logger(r).Info("exchange ditolak: user di-ban", "user_id", id.Profile.ID)
		writeError(w, http.StatusForbidden, "user_banned", "Akun Anda diblokir dari fitur sosial")
		return
	case err != nil:
		s.countExchange("error")
		s.logger(r).Error("exchange gagal", "error", err.Error())
		writeError(w, http.StatusBadGateway, "exchange_failed", "Gagal menyiapkan sesi sosial")
		return
	}

	if s.opts.UserLimiter != nil {
		if ok, retry := s.opts.UserLimiter.Allow("user:" + id.Profile.OLTUserID); !ok {
			s.countExchange("rate_limited_user")
			s.logger(r).Warn("rate limit exchange (user)", "user_id", id.Profile.ID)
			w.Header().Set("Retry-After", strconv.Itoa(int(retry.Seconds())+1))
			writeError(w, http.StatusTooManyRequests, "rate_limited", "Terlalu banyak permintaan, coba lagi nanti")
			return
		}
	}

	jwt, exp, err := s.opts.Issuer.UserToken(token.User{ID: id.Profile.ID})
	if err != nil {
		s.countExchange("error")
		s.logger(r).Error("gagal menandatangani JWT", "error", err.Error())
		writeError(w, http.StatusInternalServerError, "internal_error", "Terjadi kesalahan")
		return
	}

	if cached {
		s.countExchange("cached")
	} else {
		s.countExchange("ok")
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
// datang dari proxy tepercaya (Kong/Traefik); diambil IP paling kanan yang
// bukan proxy tepercaya. Bila semua hop tepercaya (klien di jaringan privat,
// mis. dev atau service internal), dipakai hop valid paling kiri, bukan IP
// proxy, agar klien-klien itu tidak berbagi satu kuota rate limit.
func (s *Server) clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	remote, err := netip.ParseAddr(host)
	if err != nil || !s.trusted(remote) {
		return host
	}
	client := host
	hops := strings.Split(r.Header.Get("X-Forwarded-For"), ",")
	for i := len(hops) - 1; i >= 0; i-- {
		addr, err := netip.ParseAddr(strings.TrimSpace(hops[i]))
		if err != nil {
			break
		}
		if !s.trusted(addr) {
			return addr.String()
		}
		client = addr.String()
	}
	return client
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

		path := metricPath(r.URL.Path)
		if m := s.opts.Metrics; m != nil {
			m.Requests.Inc(path, strconv.Itoa(rec.status))
			m.Duration.Observe(time.Since(start).Seconds(), path)
		}

		// Healthcheck Docker berjalan tiap beberapa detik; jangan banjiri log.
		level := slog.LevelInfo
		if path == "/health" && rec.status == http.StatusOK {
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

// metricPath membatasi label path ke rute yang dikenal (kardinalitas rendah).
func metricPath(p string) string {
	switch p {
	case "/exchange", "/health":
		return p
	}
	return "other"
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
