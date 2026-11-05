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

type Resolver interface {
	Resolve(ctx context.Context, oltToken string) (exchange.Identity, bool, error)
}

type TokenIssuer interface {
	UserToken(u token.User) (string, time.Time, error)
}

type RateLimiter interface {
	Allow(key string) (bool, time.Duration)
}

type Options struct {
	Log            *slog.Logger
	Resolver       Resolver
	Issuer         TokenIssuer
	Limiter        RateLimiter
	UserLimiter    RateLimiter
	TrustedProxies []netip.Prefix
	OLTMode        string
	ReadyChecks    []ReadyCheck
	Metrics        *Metrics
}

type ReadyCheck struct {
	Name     string
	Check    func(context.Context) error
	Optional bool
}

type Metrics struct {
	Requests     *metrics.CounterVec
	Duration     *metrics.HistogramVec
	Exchanges    *metrics.CounterVec
	AccountLinks *metrics.CounterVec
}

func NewMetrics(r *metrics.Registry) *Metrics {
	return &Metrics{
		Requests: r.Counter("olt_auth_bridge_http_requests_total", "HTTP requests", "path", "status"),
		Duration: r.Histogram("olt_auth_bridge_http_request_duration_seconds", "HTTP request duration",
			[]float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10}, "path"),
		Exchanges: r.Counter("olt_auth_bridge_exchanges_total",
			"Token exchange results (ok, cached, invalid_token, olt_unavailable, banned, rate_limited_ip, rate_limited_user, error)",
			"result"),
		AccountLinks: r.Counter("olt_auth_bridge_account_links_total",
			"Stored accounts claims from social tokens (ok, malformed, error)", "result"),
	}
}

type Server struct {
	opts Options
}

func New(opts Options) *Server {
	return &Server{opts: opts}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", s.handleHealth)
	mux.HandleFunc("POST /exchange", s.handleExchange)
	return s.withRequestID(s.withRecover(s.withLogging(mux)))
}

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
			s.logger(r).Warn("readiness: optional dependency degraded", "check", c.Name, "error", err.Error())
		default:
			checks[c.Name] = "fail"
			status, state = http.StatusServiceUnavailable, "not_ready"
			s.logger(r).Warn("readiness failed", "check", c.Name, "error", err.Error())
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
	if err == nil || errors.Is(err, exchange.ErrBanned) {
		s.recordAccounts(r, id)
	}
	switch {
	case errors.Is(err, olt.ErrInvalidToken):
		s.countExchange("invalid_token")
		s.logger(r).Info("exchange rejected", "reason", err.Error(), "client_ip", ip)
		writeError(w, http.StatusUnauthorized, "invalid_token", "Sesi OLT tidak valid, silakan login ulang")
		return
	case errors.Is(err, olt.ErrUnavailable):
		s.countExchange("olt_unavailable")
		s.logger(r).Warn("OLT server unavailable", "error", err.Error())
		writeError(w, http.StatusServiceUnavailable, "olt_unavailable", "Server OLT sedang tidak dapat dihubungi")
		return
	case errors.Is(err, exchange.ErrBanned):
		s.countExchange("banned")
		s.logger(r).Info("exchange rejected: user banned", "user_id", id.Profile.ID)
		writeError(w, http.StatusForbidden, "user_banned", "Akun Anda diblokir dari fitur sosial")
		return
	case err != nil:
		s.countExchange("error")
		s.logger(r).Error("exchange failed", "error", err.Error())
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
		s.logger(r).Error("failed to sign JWT", "error", err.Error())
		writeError(w, http.StatusInternalServerError, "internal_error", "Terjadi kesalahan")
		return
	}

	if cached {
		s.countExchange("cached")
	} else {
		s.countExchange("ok")
	}
	s.logger(r).Info("exchange succeeded", "user_id", id.Profile.ID, "cached", cached)
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, exchangeResponse{
		AccessToken: jwt,
		TokenType:   "bearer",
		ExpiresIn:   int64(time.Until(exp).Round(time.Second).Seconds()),
		ExpiresAt:   exp.Unix(),
		User:        id.Profile,
	})
}

func (s *Server) recordAccounts(r *http.Request, id exchange.Identity) {
	links := id.Accounts
	if !links.Present {
		return
	}
	result := "ok"
	log := s.logger(r).With("user_id", id.Profile.ID)
	switch {
	case links.Malformed:
		result = "malformed"
		log.Warn("accounts claim is not an array, account links unchanged")
	case links.Err != nil:
		result = "error"
		log.Warn("failed to store account links", "error", links.Err.Error())
	case links.Ignored > 0:
		log.Info("some accounts claim entries ignored", "accounts", links.Linked, "accounts_ignored", links.Ignored)
	default:
		log.Debug("account links updated", "accounts", links.Linked)
	}
	if m := s.opts.Metrics; m != nil && m.AccountLinks != nil {
		m.AccountLinks.Inc(result)
	}
}

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
