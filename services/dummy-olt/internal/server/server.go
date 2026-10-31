package server

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"

	"olt-social/dummy-olt/internal/tokens"
	"olt-social/dummy-olt/internal/users"
)

const (
	CodeBadRequest         = "BAD_REQUEST"
	CodeInvalidCredentials = "INVALID_CREDENTIALS"
	CodeAccountSuspended   = "ACCOUNT_SUSPENDED"
	CodeInvalidToken       = "INVALID_TOKEN"
	CodeTokenExpired       = "TOKEN_EXPIRED"
	CodeTokenRevoked       = "TOKEN_REVOKED"
	CodeUnknownType        = "UNKNOWN_TYPE"
)

type Config struct {
	TokenTTL          time.Duration
	AcceptMockTokens  bool
	SlowDelay         time.Duration
	HeartbeatInterval time.Duration
}

type Server struct {
	users    *users.Directory
	tokens   *tokens.Issuer
	cfg      Config
	log      *slog.Logger
	upgrader websocket.Upgrader
}

func New(dir *users.Directory, issuer *tokens.Issuer, cfg Config, log *slog.Logger) *Server {
	return &Server{
		users:  dir,
		tokens: issuer,
		cfg:    cfg,
		log:    log,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(*http.Request) bool { return true },
		},
	}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("GET /ws", s.handleWebSocket)
	mux.HandleFunc("POST /api/login", s.handleHTTPLogin)
	mux.HandleFunc("POST /api/logout", s.handleHTTPLogout)
	mux.HandleFunc("POST /api/dev/token", s.handleDevToken)
	mux.HandleFunc("GET /api/users", s.handleUsers)
	return mux
}

type request struct {
	Type      string          `json:"type"`
	RequestID string          `json:"request_id,omitempty"`
	Method    string          `json:"method,omitempty"`
	Payload   json.RawMessage `json:"payload,omitempty"`
}

type credentials struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
	Token    string `json:"token"`
}

type userJSON struct {
	ID       any    `json:"id"`
	Username string `json:"username"`
	Email    string `json:"email"`
	FullName string `json:"full_name"`
}

type loginData struct {
	Token     string   `json:"token"`
	ExpiresAt string   `json:"expires_at,omitempty"`
	User      userJSON `json:"user"`
}

type apiError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

type message struct {
	Type       string    `json:"type"`
	RequestID  string    `json:"request_id,omitempty"`
	Status     string    `json:"status,omitempty"`
	Data       any       `json:"data,omitempty"`
	Error      *apiError `json:"error,omitempty"`
	Server     string    `json:"server,omitempty"`
	ServerTime string    `json:"server_time,omitempty"`
}

func result(kind, requestID string, data *loginData, e *apiError) message {
	if e != nil {
		return message{Type: kind, RequestID: requestID, Status: "FAILED", Error: e}
	}
	m := message{Type: kind, RequestID: requestID, Status: "OK"}
	if data != nil {
		m.Data = data
	}
	return m
}

func toUserJSON(u *users.User) userJSON {
	return userJSON{ID: u.ID, Username: u.Username, Email: u.Email, FullName: u.FullName}
}

func (s *Server) passwordLogin(c credentials) (*loginData, *apiError) {
	identifier := c.Username
	if identifier == "" {
		identifier = c.Email
	}
	if identifier == "" || c.Password == "" {
		return nil, &apiError{CodeBadRequest, "username/email dan password wajib diisi"}
	}
	u, err := s.users.Authenticate(identifier, c.Password)
	switch {
	case errors.Is(err, users.ErrSuspended):
		s.log.Info("login password ditolak", "identifier", identifier, "code", CodeAccountSuspended)
		return nil, &apiError{CodeAccountSuspended, "Akun ditangguhkan"}
	case err != nil:
		s.log.Info("login password ditolak", "identifier", identifier, "code", CodeInvalidCredentials)
		return nil, &apiError{CodeInvalidCredentials, "Username/email atau password salah"}
	}
	token, exp, err := s.tokens.Issue(strconv.FormatInt(u.ID, 10), s.cfg.TokenTTL)
	if err != nil {
		return nil, &apiError{CodeBadRequest, "gagal membuat token"}
	}
	s.log.Info("login password berhasil", "user_id", u.ID)
	return &loginData{Token: token, ExpiresAt: exp.UTC().Format(time.RFC3339), User: toUserJSON(u)}, nil
}

func (s *Server) tokenLogin(ctx context.Context, token string) (*loginData, *apiError) {
	if token == "" {
		return nil, &apiError{CodeBadRequest, "token wajib diisi"}
	}

	if strings.HasPrefix(token, "mock:") {
		return s.mockTokenLogin(token)
	}

	claims, err := s.tokens.Verify(token)
	switch {
	case errors.Is(err, tokens.ErrExpired):
		return nil, s.reject(CodeTokenExpired, "Sesi kedaluwarsa, silakan login ulang")
	case errors.Is(err, tokens.ErrRevoked):
		return nil, s.reject(CodeTokenRevoked, "Sesi sudah logout")
	case err != nil:
		return nil, s.reject(CodeInvalidToken, "Token tidak valid")
	}

	u, ok := s.users.Find(claims.UserID)
	if !ok {
		return nil, s.reject(CodeInvalidToken, "Token tidak valid")
	}
	if u.Status == users.StatusSuspended {
		return nil, s.reject(CodeAccountSuspended, "Akun ditangguhkan")
	}
	if u.SlowLogin {
		select {
		case <-time.After(s.cfg.SlowDelay):
		case <-ctx.Done():
			return nil, &apiError{CodeBadRequest, "koneksi ditutup"}
		}
	}
	s.log.Info("login token berhasil", "user_id", u.ID)
	return &loginData{
		Token:     token,
		ExpiresAt: time.Unix(claims.ExpiresAt, 0).UTC().Format(time.RFC3339),
		User:      toUserJSON(u),
	}, nil
}

func (s *Server) mockTokenLogin(token string) (*loginData, *apiError) {
	if !s.cfg.AcceptMockTokens {
		return nil, s.reject(CodeInvalidToken, "Token mock tidak diizinkan")
	}
	parts := strings.SplitN(token, ":", 4)
	if len(parts) < 3 || parts[1] == "" || parts[2] == "" {
		return nil, s.reject(CodeInvalidToken, "Token tidak valid")
	}
	if u, ok := s.users.Find(parts[1]); ok && u.Status == users.StatusActive {
		return &loginData{Token: token, User: toUserJSON(u)}, nil
	}
	user := userJSON{ID: parts[1], Username: parts[2], FullName: parts[2]}
	if n, err := strconv.ParseInt(parts[1], 10, 64); err == nil {
		user.ID = n
	}
	if len(parts) == 4 {
		user.FullName = parts[3]
	}
	return &loginData{Token: token, User: user}, nil
}

func (s *Server) reject(code, msg string) *apiError {
	s.log.Info("login token ditolak", "code", code)
	return &apiError{code, msg}
}

func (s *Server) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()

	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()

	var writeMu sync.Mutex
	send := func(m message) {
		writeMu.Lock()
		defer writeMu.Unlock()
		_ = conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
		_ = conn.WriteJSON(m)
	}
	now := func() string { return time.Now().UTC().Format(time.RFC3339) }

	send(message{Type: "welcome", Server: "dummy-olt", ServerTime: now()})

	go func() {
		ticker := time.NewTicker(s.cfg.HeartbeatInterval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				send(message{Type: "heartbeat", ServerTime: now()})
			}
		}
	}()

	for {
		_, data, err := conn.ReadMessage()
		if err != nil {
			return
		}
		var req request
		if err := json.Unmarshal(data, &req); err != nil {
			send(message{Type: "error", Error: &apiError{CodeBadRequest, "pesan harus JSON"}})
			continue
		}
		var creds credentials
		if len(req.Payload) > 0 {
			_ = json.Unmarshal(req.Payload, &creds)
		}

		switch req.Type {
		case "login":
			go func(req request, creds credentials) {
				var (
					login *loginData
					e     *apiError
				)
				switch req.Method {
				case "password":
					login, e = s.passwordLogin(creds)
				case "token":
					login, e = s.tokenLogin(ctx, creds.Token)
				default:
					e = &apiError{CodeBadRequest, "method harus password atau token"}
				}
				if ctx.Err() == nil {
					send(result("login_result", req.RequestID, login, e))
				}
			}(req, creds)
		case "logout":
			if err := s.tokens.Revoke(creds.Token); err != nil {
				send(result("logout_result", req.RequestID, nil, &apiError{CodeInvalidToken, "Token tidak valid"}))
			} else {
				send(result("logout_result", req.RequestID, nil, nil))
			}
		case "ping":
			send(message{Type: "pong", RequestID: req.RequestID, ServerTime: now()})
		default:
			send(message{Type: "error", RequestID: req.RequestID, Error: &apiError{CodeUnknownType, "type tidak dikenal"}})
		}
	}
}

func statusFor(code string) int {
	switch code {
	case CodeBadRequest:
		return http.StatusBadRequest
	case CodeAccountSuspended:
		return http.StatusForbidden
	default:
		return http.StatusUnauthorized
	}
}

func (s *Server) handleHTTPLogin(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 8<<10)).Decode(&c); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": apiError{CodeBadRequest, "body harus JSON"}})
		return
	}
	data, e := s.passwordLogin(c)
	if e != nil {
		writeJSON(w, statusFor(e.Code), map[string]any{"error": e})
		return
	}
	writeJSON(w, http.StatusOK, data)
}

func (s *Server) handleHTTPLogout(w http.ResponseWriter, r *http.Request) {
	var c credentials
	_ = json.NewDecoder(http.MaxBytesReader(w, r.Body, 8<<10)).Decode(&c)
	if err := s.tokens.Revoke(c.Token); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": apiError{CodeInvalidToken, "Token tidak valid"}})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleDevToken(w http.ResponseWriter, r *http.Request) {
	var body struct {
		User string `json:"user"`
		TTL  string `json:"ttl"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 8<<10)).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": apiError{CodeBadRequest, "body harus JSON"}})
		return
	}
	u, ok := s.users.Find(body.User)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": apiError{CodeBadRequest, "user tidak dikenal"}})
		return
	}
	ttl := s.cfg.TokenTTL
	if body.TTL != "" {
		parsed, err := time.ParseDuration(body.TTL)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": apiError{CodeBadRequest, "ttl tidak valid"}})
			return
		}
		ttl = parsed
	}
	token, exp, err := s.tokens.Issue(strconv.FormatInt(u.ID, 10), ttl)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": apiError{CodeBadRequest, err.Error()}})
		return
	}
	writeJSON(w, http.StatusOK, loginData{Token: token, ExpiresAt: exp.UTC().Format(time.RFC3339), User: toUserJSON(u)})
}

func (s *Server) handleUsers(w http.ResponseWriter, _ *http.Request) {
	type row struct {
		userJSON
		Status    users.Status `json:"status"`
		SlowLogin bool         `json:"slow_login"`
	}
	var rows []row
	for _, u := range s.users.All() {
		rows = append(rows, row{userJSON: toUserJSON(&u), Status: u.Status, SlowLogin: u.SlowLogin})
	}
	writeJSON(w, http.StatusOK, map[string]any{"password": users.DefaultPassword, "users": rows})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
