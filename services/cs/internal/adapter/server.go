package adapter

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"olt-social/cs/internal/metrics"
	"olt-social/cs/internal/olt"
	"olt-social/cs/internal/ops"
	"olt-social/cs/internal/postgrest"
	"olt-social/cs/internal/token"
)

var (
	uuidPattern   = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)
	refPattern    = regexp.MustCompile(`^[A-Za-z0-9._:-]{1,64}$`)
	stockPattern  = regexp.MustCompile(`^[A-Z0-9-]{1,12}$`)
	orderStatuses = map[string]bool{"open": true, "partial": true, "filled": true, "rejected": true, "cancelled": true, "expired": true}
	revealFields  = map[string]bool{
		"nik": true, "phone": true, "email": true, "client_code": true, "sid": true,
		"address": true, "birth_date": true, "rdn_number": true, "bank_account": true,
	}
)

type API interface {
	CallAs(ctx context.Context, bearer, fn string, args, out any) error
}

type OLT interface {
	Call(ctx context.Context, kind string, payload, out any) error
}

type Metrics struct {
	Requests  *metrics.CounterVec
	Duration  *metrics.HistogramVec
	OLTErrors *metrics.CounterVec
}

func NewMetrics(r *metrics.Registry) *Metrics {
	return &Metrics{
		Requests: r.Counter("olt_customer_adapter_http_requests_total", "Jumlah request HTTP", "route", "status"),
		Duration: r.Histogram("olt_customer_adapter_http_request_duration_seconds", "Durasi request HTTP",
			[]float64{0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10}, "route"),
		OLTErrors: r.Counter("olt_customer_adapter_olt_errors_total", "Kegagalan permintaan ke OLT", "kind", "reason"),
	}
}

type Server struct {
	api     API
	olt     OLT
	secret  []byte
	log     *slog.Logger
	metrics *Metrics
	now     func() time.Time
}

func NewServer(api API, client OLT, jwtSecret string, log *slog.Logger, m *Metrics) *Server {
	return &Server{api: api, olt: client, secret: []byte(jwtSecret), log: log, metrics: m, now: time.Now}
}

type access struct {
	OLTUserID     string `json:"olt_user_id"`
	CorrelationID string `json:"correlation_id"`
	ValidSeconds  int    `json:"valid_seconds"`
}

type route struct {
	kind      string
	oltKind   string
	params    func(r *http.Request) (map[string]any, error)
	transform func(json.RawMessage) (any, error)
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		ops.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	agent := map[string]route{
		"GET /v1/agent/sessions/{session}/customer/profile":                 {"profile", "customer_profile", noParams, maskProfile},
		"GET /v1/agent/sessions/{session}/customer/orders":                  {"orders", "customer_orders", orderFilters, passthrough},
		"GET /v1/agent/sessions/{session}/customer/orders/{ref}":            {"order", "customer_order", refParam("order_id"), passthrough},
		"GET /v1/agent/sessions/{session}/customer/cash-transactions":       {"cash_transactions", "customer_cash_transactions", periodFilters, passthrough},
		"GET /v1/agent/sessions/{session}/customer/cash-transactions/{ref}": {"cash_transaction", "customer_cash_transaction", refParam("transaction_id"), passthrough},
		"GET /v1/agent/sessions/{session}/customer/sessions":                {"sessions", "customer_sessions", noParams, maskSessions},
		"GET /v1/agent/sessions/{session}/customer/security":                {"security", "customer_security", noParams, passthrough},
	}
	for pattern, rt := range agent {
		mux.Handle(pattern, s.instrument(pattern, s.agentRead(rt)))
	}
	reveal := "POST /v1/agent/sessions/{session}/customer/reveal"
	mux.Handle(reveal, s.instrument(reveal, http.HandlerFunc(s.reveal)))
	secure := "POST /v1/agent/sessions/{session}/customer/secure-account"
	mux.Handle(secure, s.instrument(secure, http.HandlerFunc(s.secureAccount)))

	customer := map[string]route{
		"GET /v1/me/orders":            {"orders", "customer_orders", orderFilters, passthrough},
		"GET /v1/me/orders/{ref}":      {"order", "customer_order", refParam("order_id"), passthrough},
		"GET /v1/me/cash-transactions": {"cash_transactions", "customer_cash_transactions", periodFilters, passthrough},
	}
	for pattern, rt := range customer {
		mux.Handle(pattern, s.instrument(pattern, s.customerRead(rt)))
	}
	return mux
}

func (s *Server) agentRead(rt route) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bearer, session, ok := s.authenticateSession(w, r)
		if !ok {
			return
		}
		params, err := rt.params(r)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid_query", err.Error())
			return
		}
		var grant access
		if err := s.api.CallAs(r.Context(), bearer, "agent_customer_access",
			map[string]any{"p_session_id": session, "p_kind": rt.kind}, &grant); err != nil {
			s.writeAPIError(w, err)
			return
		}
		s.respond(w, r, rt, grant, params)
	})
}

func (s *Server) customerRead(rt route) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bearer, ok := s.authenticate(w, r)
		if !ok {
			return
		}
		params, err := rt.params(r)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid_query", err.Error())
			return
		}
		var grant access
		if err := s.api.CallAs(r.Context(), bearer, "customer_data_access", map[string]any{"p_kind": rt.kind}, &grant); err != nil {
			s.writeAPIError(w, err)
			return
		}
		s.respond(w, r, rt, grant, params)
	})
}

func (s *Server) respond(w http.ResponseWriter, r *http.Request, rt route, grant access, params map[string]any) {
	params["user_id"] = grant.OLTUserID
	if grant.CorrelationID != "" {
		params["correlation_id"] = grant.CorrelationID
	}
	var raw json.RawMessage
	if err := s.olt.Call(r.Context(), rt.oltKind, params, &raw); err != nil {
		s.writeOLTError(w, rt.oltKind, err)
		return
	}
	data, err := rt.transform(raw)
	if err != nil {
		s.metrics.OLTErrors.Inc(rt.oltKind, "invalid_response")
		writeError(w, http.StatusBadGateway, "olt_invalid_response", "Respons OLT tidak bisa dibaca")
		return
	}
	ops.WriteJSON(w, http.StatusOK, map[string]any{"available": true, "data": data})
}

func (s *Server) reveal(w http.ResponseWriter, r *http.Request) {
	bearer, session, ok := s.authenticateSession(w, r)
	if !ok {
		return
	}
	var body struct {
		Field  string `json:"field"`
		Reason string `json:"reason"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<10)).Decode(&body); err != nil || !revealFields[body.Field] {
		writeError(w, http.StatusBadRequest, "invalid_body", "Isi field dan alasan yang valid")
		return
	}
	var grant access
	if err := s.api.CallAs(r.Context(), bearer, "agent_reveal_access",
		map[string]any{"p_session_id": session, "p_field": body.Field, "p_reason": body.Reason}, &grant); err != nil {
		s.writeAPIError(w, err)
		return
	}
	var result struct {
		Field string `json:"field"`
		Value string `json:"value"`
	}
	if err := s.olt.Call(r.Context(), "customer_reveal", map[string]any{
		"user_id": grant.OLTUserID, "field": body.Field, "reason": body.Reason, "correlation_id": grant.CorrelationID,
	}, &result); err != nil {
		s.writeOLTError(w, "customer_reveal", err)
		return
	}
	ops.WriteJSON(w, http.StatusOK, map[string]any{
		"available": true,
		"data":      map[string]any{"field": body.Field, "value": result.Value, "valid_seconds": grant.ValidSeconds},
	})
}

func (s *Server) secureAccount(w http.ResponseWriter, r *http.Request) {
	bearer, session, ok := s.authenticateSession(w, r)
	if !ok {
		return
	}
	var grant struct {
		OLTUserID      string   `json:"olt_user_id"`
		Actions        []string `json:"actions"`
		IdempotencyKey string   `json:"idempotency_key"`
		CorrelationID  string   `json:"correlation_id"`
	}
	if err := s.api.CallAs(r.Context(), bearer, "agent_secure_account", map[string]any{"p_session_id": session}, &grant); err != nil {
		s.writeAPIError(w, err)
		return
	}
	var result struct {
		Results map[string]string `json:"results"`
	}
	err := s.olt.Call(r.Context(), "secure_account", map[string]any{
		"user_id":         grant.OLTUserID,
		"actions":         grant.Actions,
		"reason":          "customer_emergency",
		"idempotency_key": grant.IdempotencyKey,
		"correlation_id":  grant.CorrelationID,
	}, &result)
	var protocol *olt.Error
	if err != nil && !errors.As(err, &protocol) {
		s.writeOLTError(w, "secure_account", err)
		return
	}
	results := result.Results
	if protocol != nil {
		s.metrics.OLTErrors.Inc("secure_account", "rejected")
		results = map[string]string{"error": protocol.Code}
	}
	done := protocol == nil && len(grant.Actions) > 0
	for _, action := range grant.Actions {
		if results[action] != "OK" {
			done = false
		}
	}
	if !done {
		s.log.Error("aksi amankan akun di OLT tidak lengkap", "session_id", session)
	}
	if err := s.api.CallAs(r.Context(), bearer, "agent_secure_account_result",
		map[string]any{"p_session_id": session, "p_ok": done, "p_results": results}, nil); err != nil {
		s.log.Error("hasil amankan akun gagal dicatat, aman diulang karena idempoten", "session_id", session, "error", err)
		writeError(w, http.StatusBadGateway, "record_failed", "Aksi sudah dikirim ke OLT tetapi hasilnya gagal dicatat, ulangi")
		return
	}
	ops.WriteJSON(w, http.StatusOK, map[string]any{"available": true, "data": map[string]any{"ok": done, "results": results}})
}

func (s *Server) authenticateSession(w http.ResponseWriter, r *http.Request) (string, string, bool) {
	bearer, ok := s.authenticate(w, r)
	if !ok {
		return "", "", false
	}
	session := r.PathValue("session")
	if !uuidPattern.MatchString(session) {
		writeError(w, http.StatusBadRequest, "invalid_session", "ID sesi tidak valid")
		return "", "", false
	}
	return bearer, session, true
}

func (s *Server) authenticate(w http.ResponseWriter, r *http.Request) (string, bool) {
	header := r.Header.Get("Authorization")
	bearer, found := strings.CutPrefix(header, "Bearer ")
	if !found || bearer == "" {
		writeError(w, http.StatusUnauthorized, "missing_token", "Butuh token login")
		return "", false
	}
	if _, err := token.Verify(bearer, s.secret, s.now()); err != nil {
		writeError(w, http.StatusUnauthorized, "invalid_token", "Token login tidak valid atau kedaluwarsa")
		return "", false
	}
	return bearer, true
}

func (s *Server) writeAPIError(w http.ResponseWriter, err error) {
	e, ok := postgrest.AsError(err)
	if !ok {
		s.log.Error("gagal memeriksa izin ke database", "error", err)
		writeError(w, http.StatusBadGateway, "database_unavailable", "Layanan sedang sibuk, coba lagi")
		return
	}
	if e.Status >= 500 {
		s.log.Error("database menolak pemeriksaan izin", "status", e.Status, "code", e.Code)
		writeError(w, http.StatusBadGateway, "database_unavailable", "Layanan sedang sibuk, coba lagi")
		return
	}
	if e.RetryAfter != "" {
		w.Header().Set("Retry-After", e.RetryAfter)
	}
	writeError(w, e.Status, e.Code, e.Message)
}

func (s *Server) writeOLTError(w http.ResponseWriter, kind string, err error) {
	var protocol *olt.Error
	switch {
	case errors.As(err, &protocol) && protocol.Code == "NOT_FOUND":
		s.metrics.OLTErrors.Inc(kind, "not_found")
		writeError(w, http.StatusNotFound, "not_found", "Data tidak ditemukan di OLT")
	case errors.As(err, &protocol) && protocol.Code == "INVALID_REQUEST":
		s.metrics.OLTErrors.Inc(kind, "invalid_request")
		writeError(w, http.StatusBadRequest, "invalid_request", protocol.Message)
	case errors.As(err, &protocol):
		s.metrics.OLTErrors.Inc(kind, "rejected")
		s.log.Error("OLT menolak permintaan adapter", "kind", kind, "code", protocol.Code)
		writeError(w, http.StatusBadGateway, "olt_rejected", "OLT menolak permintaan")
	default:
		s.metrics.OLTErrors.Inc(kind, "unavailable")
		s.log.Warn("OLT tidak tersedia", "kind", kind, "error", err)
		ops.WriteJSON(w, http.StatusServiceUnavailable, map[string]any{
			"available": false, "code": "olt_unavailable", "message": "Data OLT sedang tidak tersedia",
		})
	}
}

func (s *Server) instrument(route string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := s.now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		defer func() {
			if p := recover(); p != nil {
				s.log.Error("panic di handler", "route", route, "panic", fmt.Sprint(p))
				writeError(rec, http.StatusInternalServerError, "internal", "Terjadi kesalahan")
			}
			s.metrics.Requests.Inc(route, strconv.Itoa(rec.status))
			s.metrics.Duration.Observe(s.now().Sub(start).Seconds(), route)
		}()
		next.ServeHTTP(rec, r)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	ops.WriteJSON(w, status, map[string]string{"code": code, "message": message})
}

func noParams(*http.Request) (map[string]any, error) {
	return map[string]any{}, nil
}

func refParam(key string) func(*http.Request) (map[string]any, error) {
	return func(r *http.Request) (map[string]any, error) {
		ref := r.PathValue("ref")
		if !refPattern.MatchString(ref) {
			return nil, errors.New("ID tidak valid")
		}
		return map[string]any{key: ref}, nil
	}
}

func periodFilters(r *http.Request) (map[string]any, error) {
	q := r.URL.Query()
	params := map[string]any{"limit": 20}
	for _, key := range []string{"from", "to"} {
		if v := q.Get(key); v != "" {
			t, err := time.Parse(time.RFC3339, v)
			if err != nil {
				return nil, fmt.Errorf("%s harus RFC 3339", key)
			}
			params[key] = t.UTC().Format(time.RFC3339)
		}
	}
	if v := q.Get("limit"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > 50 {
			return nil, errors.New("limit harus 1–50")
		}
		params["limit"] = n
	}
	if v := q.Get("cursor"); v != "" {
		if len(v) > 200 {
			return nil, errors.New("cursor tidak valid")
		}
		params["cursor"] = v
	}
	return params, nil
}

func orderFilters(r *http.Request) (map[string]any, error) {
	params, err := periodFilters(r)
	if err != nil {
		return nil, err
	}
	q := r.URL.Query()
	if v := q.Get("code"); v != "" {
		code := strings.ToUpper(v)
		if !stockPattern.MatchString(code) {
			return nil, errors.New("kode saham tidak valid")
		}
		params["code"] = code
	}
	if v := q.Get("status"); v != "" {
		statuses := strings.Split(v, ",")
		for _, st := range statuses {
			if !orderStatuses[st] {
				return nil, fmt.Errorf("status order %q tidak dikenal", st)
			}
		}
		params["status"] = statuses
	}
	return params, nil
}
