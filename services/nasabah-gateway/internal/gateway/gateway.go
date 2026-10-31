package gateway

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"maps"
	"net/http"
	"net/url"
	"regexp"
	"slices"
	"strings"
	"time"

	"olt-social/nasabah-gateway/internal/access"
	"olt-social/nasabah-gateway/internal/csadmin"
	"olt-social/nasabah-gateway/internal/jwt"
)

const (
	Prefix          = "/api-nasabah"
	maxRequestBody  = 1 << 20
	maxResponseBody = 16 << 20
)

const (
	ActorAgent   = "agent"
	ActorService = "service"
)

type Request struct {
	Grant  *access.Grant
	Actor  string
	Query  url.Values
	Fields map[string]any
}

type Caller interface {
	Get(ctx context.Context, path string, query url.Values) (int, []byte, error)
	Do(ctx context.Context, method, path string, query url.Values, body any) (int, []byte, error)
}

type Guard func(ctx context.Context, call Caller, req *Request) error

type After func(ctx context.Context, call Caller, req *Request, payload []byte) ([]byte, error)

type Rejection struct {
	Status  int
	Code    string
	Message string
}

func (r *Rejection) Error() string { return r.Message }

type Route struct {
	Method        string
	Path          string
	Action        string
	Permissions   []string
	ActorFields   []string
	ActorQuery    []string
	SubjectFields []string
	Query         map[string]*regexp.Regexp
	Guard         Guard
	After         After
	Audit         bool
}

type Options struct {
	Routes    []Route
	Grants    access.Store
	JWTSecret []byte
	Upstream  *csadmin.Session
	ActorMode string
	Client    *http.Client
	Log       *slog.Logger
	Now       func() time.Time
}

type Gateway struct {
	opts   Options
	routes map[string]Route
}

func New(opts Options) *Gateway {
	if opts.Client == nil {
		opts.Client = &http.Client{Timeout: 15 * time.Second}
	}
	if opts.Now == nil {
		opts.Now = time.Now
	}
	if opts.Log == nil {
		opts.Log = slog.New(slog.DiscardHandler)
	}
	if opts.ActorMode == "" {
		opts.ActorMode = ActorAgent
	}
	routes := make(map[string]Route, len(opts.Routes))
	for _, r := range opts.Routes {
		routes[r.Method+" "+r.Path] = r
	}
	return &Gateway{opts: opts, routes: routes}
}

func (g *Gateway) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	started := g.opts.Now()
	path := strings.TrimPrefix(r.URL.Path, Prefix)
	if r.Method == http.MethodGet && r.URL.Path == Prefix+"/gateway/info" {
		g.info(w, r)
		return
	}
	route, ok := g.routes[r.Method+" "+path]
	if !strings.HasPrefix(r.URL.Path, Prefix+"/") || !ok {
		writeError(w, http.StatusNotFound, "route_not_found", "Route is not available through the gateway")
		return
	}
	if !g.opts.Upstream.Configured() {
		writeError(w, http.StatusServiceUnavailable, "not_configured", "Customer admin service is not configured")
		return
	}
	userID, err := g.authenticate(r)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "unauthorized", "Console session is missing or expired")
		return
	}
	grant, err := g.opts.Grants.Grant(r.Context(), userID)
	if err != nil {
		g.opts.Log.Error("Failed to load customer access", "action", route.Action, "error", err)
		writeError(w, http.StatusServiceUnavailable, "access_unavailable", "Customer access check is unavailable")
		return
	}
	if grant == nil {
		writeError(w, http.StatusForbidden, "no_access", "Console account has no customer access")
		return
	}
	if !grant.Allows(route.Permissions) {
		writeError(w, http.StatusForbidden, "permission_denied", "Console account lacks permission for this action")
		return
	}

	fields, err := readFields(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_body", err.Error())
		return
	}
	query, err := filterQuery(route, r.URL.Query())
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_query", err.Error())
		return
	}
	req := &Request{Grant: grant, Actor: g.actor(grant), Query: query, Fields: fields}
	for _, f := range route.ActorQuery {
		req.Query.Set(f, req.Actor)
	}
	if req.Fields != nil {
		for _, f := range route.ActorFields {
			req.Fields[f] = req.Actor
		}
	}
	if route.Guard != nil {
		if err := route.Guard(r.Context(), g, req); err != nil {
			g.fail(w, route, err)
			return
		}
	}
	var body []byte
	if fields != nil {
		if body, err = json.Marshal(req.Fields); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_body", "Request body could not be encoded")
			return
		}
	}
	status, payload, err := g.call(r.Context(), r.Method, path, req.Query.Encode(), body)
	if err != nil {
		g.fail(w, route, err)
		return
	}
	if route.After != nil && status < 300 {
		if payload, err = route.After(r.Context(), g, req, payload); err != nil {
			g.opts.Log.Error("Follow-up step failed after a successful request", "action", route.Action, "error", err)
		}
	}
	if route.Audit && status < 300 {
		g.audit(userID, route, req)
	}
	g.opts.Log.Info("Customer request proxied", "action", route.Action, "agent_code", grant.AgentCode,
		"status", status, "duration_ms", g.opts.Now().Sub(started).Milliseconds())

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_, _ = w.Write(payload)
}

func (g *Gateway) info(w http.ResponseWriter, r *http.Request) {
	userID, err := g.authenticate(r)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "unauthorized", "Console session is missing or expired")
		return
	}
	grant, err := g.opts.Grants.Grant(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "access_unavailable", "Customer access check is unavailable")
		return
	}
	if grant == nil {
		writeError(w, http.StatusForbidden, "no_access", "Console account has no customer access")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"configured":       g.opts.Upstream.Configured(),
		"service_login_id": g.opts.Upstream.LoginID(),
		"actor":            g.actor(grant),
		"actor_mode":       g.opts.ActorMode,
	})
}

func (g *Gateway) ServiceLoginID() string { return g.opts.Upstream.LoginID() }

func (g *Gateway) Get(ctx context.Context, path string, query url.Values) (int, []byte, error) {
	return g.call(ctx, http.MethodGet, path, query.Encode(), nil)
}

func (g *Gateway) Do(ctx context.Context, method, path string, query url.Values, body any) (int, []byte, error) {
	var raw []byte
	if body != nil {
		var err error
		if raw, err = json.Marshal(body); err != nil {
			return 0, nil, err
		}
	}
	return g.call(ctx, method, path, query.Encode(), raw)
}

func filterQuery(route Route, in url.Values) (url.Values, error) {
	if route.Query == nil {
		return in, nil
	}
	out := url.Values{}
	for key, pattern := range route.Query {
		value := strings.TrimSpace(in.Get(key))
		if value == "" {
			continue
		}
		if !pattern.MatchString(value) {
			return nil, errors.New("query parameter " + key + " has an invalid value")
		}
		out.Set(key, value)
	}
	return out, nil
}

func (g *Gateway) actor(grant *access.Grant) string {
	if g.opts.ActorMode == ActorService || grant.AgentCode == "" {
		return g.opts.Upstream.LoginID()
	}
	return grant.AgentCode
}

func (g *Gateway) fail(w http.ResponseWriter, route Route, err error) {
	var rejection *Rejection
	switch {
	case errors.As(err, &rejection):
		writeError(w, rejection.Status, rejection.Code, rejection.Message)
	case errors.Is(err, csadmin.ErrLoginFailed):
		g.opts.Log.Error("Customer admin service rejected the gateway account", "action", route.Action, "error", err)
		writeError(w, http.StatusServiceUnavailable, "upstream_login_failed", "Customer admin service rejected the gateway account")
	default:
		g.opts.Log.Error("Customer admin service is unreachable", "action", route.Action, "error", err)
		writeError(w, http.StatusBadGateway, "upstream_unavailable", "Customer admin service is unreachable")
	}
}

func (g *Gateway) authenticate(r *http.Request) (string, error) {
	token, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
	if !ok || token == "" {
		return "", errors.New("missing bearer token")
	}
	claims, err := jwt.Verify(token, g.opts.JWTSecret, g.opts.Now())
	if err != nil {
		return "", err
	}
	sub, _ := claims["sub"].(string)
	if claims["role"] != "authenticated" || !jwt.HasAudience(claims, "authenticated") || sub == "" {
		return "", errors.New("token is not an authenticated user session")
	}
	return sub, nil
}

func readFields(r *http.Request) (map[string]any, error) {
	if r.Method == http.MethodGet || r.Method == http.MethodHead {
		return nil, nil
	}
	raw, err := io.ReadAll(io.LimitReader(r.Body, maxRequestBody+1))
	if err != nil {
		return nil, errors.New("request body could not be read")
	}
	if len(raw) > maxRequestBody {
		return nil, errors.New("request body is too large")
	}
	fields := map[string]any{}
	if len(bytes.TrimSpace(raw)) > 0 {
		if err := json.Unmarshal(raw, &fields); err != nil || fields == nil {
			return nil, errors.New("request body must be a JSON object")
		}
	}
	return fields, nil
}

func (g *Gateway) call(ctx context.Context, method, path, rawQuery string, body []byte) (int, []byte, error) {
	ctx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	for attempt := 0; ; attempt++ {
		token, err := g.opts.Upstream.Token(ctx)
		if err != nil {
			return 0, nil, err
		}
		status, payload, err := g.send(ctx, method, path, rawQuery, body, token)
		if err != nil {
			return 0, nil, err
		}
		if status == http.StatusUnauthorized && attempt == 0 {
			g.opts.Upstream.Invalidate(token)
			continue
		}
		return status, payload, nil
	}
}

func (g *Gateway) send(ctx context.Context, method, path, rawQuery string, body []byte, token string) (int, []byte, error) {
	target := g.opts.Upstream.BaseURL() + path
	if rawQuery != "" {
		target += "?" + rawQuery
	}
	var reader io.Reader
	if body != nil {
		reader = bytes.NewReader(body)
	}
	req, err := http.NewRequestWithContext(ctx, method, target, reader)
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	resp, err := g.opts.Client.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	payload, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseBody))
	if err != nil {
		return 0, nil, err
	}
	return resp.StatusCode, payload, nil
}

func (g *Gateway) audit(userID string, route Route, req *Request) {
	details := map[string]any{"path": route.Path}
	subject := map[string]any{}
	for _, f := range route.SubjectFields {
		if v := req.Query.Get(f); v != "" {
			subject[f] = v
		}
		if v, ok := req.Fields[f]; ok {
			subject[f] = v
		}
	}
	if len(subject) > 0 {
		details["subject"] = subject
	}
	if len(req.Fields) > 0 {
		details["fields"] = slices.Sorted(maps.Keys(req.Fields))
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := g.opts.Grants.Audit(ctx, userID, "nasabah."+route.Action, details); err != nil {
		g.opts.Log.Error("Failed to write customer audit entry", "action", route.Action, "error", err)
	}
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"code": code, "message": message})
}
