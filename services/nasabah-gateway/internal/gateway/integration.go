package gateway

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"

	"olt-social/nasabah-gateway/internal/csadmin"
)

const (
	integrationPath     = "/integration"
	integrationTestPath = "/integration/test"
	maxIntegrationBody  = 4 << 10
)

type Integrations interface {
	IsSuperAdmin(ctx context.Context, userID string) (bool, error)
	Integration(ctx context.Context) (csadmin.Record, error)
	SaveIntegration(ctx context.Context, userID string, settings csadmin.Settings) (csadmin.Record, error)
	ClearIntegration(ctx context.Context, userID string) (csadmin.Record, error)
}

type integrationStatus struct {
	csadmin.Record
	PublicKey     string `json:"public_key"`
	KeyConfigured bool   `json:"key_configured"`
}

type integrationSave struct {
	Saved  bool                `json:"saved"`
	Check  csadmin.CheckResult `json:"check"`
	Status integrationStatus   `json:"status"`
}

func integrationRoute(method, path string) bool {
	switch path {
	case integrationPath:
		return method == http.MethodGet || method == http.MethodPut || method == http.MethodDelete
	case integrationTestPath:
		return method == http.MethodPost
	}
	return false
}

func (g *Gateway) serveIntegration(w http.ResponseWriter, r *http.Request, path string) {
	userID, err := g.authenticate(r)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "unauthorized", "Console session is missing or expired")
		return
	}
	store := g.opts.Integrations
	if store == nil {
		writeError(w, http.StatusForbidden, "permission_denied", "Only Super Admins can manage the customer admin integration")
		return
	}
	admin, err := store.IsSuperAdmin(r.Context(), userID)
	if err != nil {
		g.unavailable(w, "Failed to check Super Admin access", err)
		return
	}
	if !admin {
		writeError(w, http.StatusForbidden, "permission_denied", "Only Super Admins can manage the customer admin integration")
		return
	}

	switch {
	case r.Method == http.MethodGet:
		record, err := store.Integration(r.Context())
		if err != nil {
			g.unavailable(w, "Failed to read the customer admin integration", err)
			return
		}
		writeJSON(w, http.StatusOK, g.status(record))
	case r.Method == http.MethodDelete:
		record, err := store.ClearIntegration(r.Context(), userID)
		if err != nil {
			g.unavailable(w, "Failed to clear the customer admin integration", err)
			return
		}
		g.opts.Upstream.Refresh(r.Context())
		g.opts.Log.Info("Customer admin integration cleared")
		writeJSON(w, http.StatusOK, g.status(record))
	case path == integrationTestPath:
		settings, rejection := integrationSettings(r)
		if rejection != nil {
			writeError(w, rejection.Status, rejection.Code, rejection.Message)
			return
		}
		writeJSON(w, http.StatusOK, g.check(r.Context(), settings))
	default:
		settings, rejection := integrationSettings(r)
		if rejection != nil {
			writeError(w, rejection.Status, rejection.Code, rejection.Message)
			return
		}
		check := g.check(r.Context(), settings)
		if check.Result != csadmin.CheckOK {
			record, err := store.Integration(r.Context())
			if err != nil {
				g.unavailable(w, "Failed to read the customer admin integration", err)
				return
			}
			writeJSON(w, http.StatusOK, integrationSave{Check: check, Status: g.status(record)})
			return
		}
		record, err := store.SaveIntegration(r.Context(), userID, settings)
		if err != nil {
			g.unavailable(w, "Failed to save the customer admin integration", err)
			return
		}
		g.opts.Upstream.Refresh(r.Context())
		g.opts.Log.Info("Customer admin integration saved", "url", settings.URL, "client_id", settings.ClientID)
		writeJSON(w, http.StatusOK, integrationSave{Saved: true, Check: check, Status: g.status(record)})
	}
}

func (g *Gateway) status(record csadmin.Record) integrationStatus {
	key := g.opts.Upstream.PublicKey()
	return integrationStatus{Record: record, PublicKey: key, KeyConfigured: key != ""}
}

func (g *Gateway) check(ctx context.Context, settings csadmin.Settings) csadmin.CheckResult {
	result := g.opts.Upstream.Check(ctx, settings)
	g.opts.Log.Info("Customer admin connection tested", "result", result.Result, "status", result.Status,
		"duration_ms", result.DurationMS)
	return result
}

func (g *Gateway) unavailable(w http.ResponseWriter, message string, err error) {
	g.opts.Log.Error(message, "error", err)
	writeError(w, http.StatusServiceUnavailable, "access_unavailable", "Console access check is unavailable")
}

func integrationSettings(r *http.Request) (csadmin.Settings, *Rejection) {
	raw, err := io.ReadAll(io.LimitReader(r.Body, maxIntegrationBody+1))
	if err != nil || len(raw) > maxIntegrationBody {
		return csadmin.Settings{}, &Rejection{Status: http.StatusBadRequest, Code: "invalid_body", Message: "Request body is too large"}
	}
	var body struct {
		URL      string `json:"url"`
		ClientID string `json:"client_id"`
	}
	if len(bytes.TrimSpace(raw)) > 0 && json.Unmarshal(raw, &body) != nil {
		return csadmin.Settings{}, &Rejection{Status: http.StatusBadRequest, Code: "invalid_body", Message: "Request body must be a JSON object"}
	}
	settings := csadmin.Settings{
		URL:      strings.TrimSuffix(strings.TrimSpace(body.URL), "/"),
		ClientID: strings.TrimSpace(body.ClientID),
	}
	if !csadmin.ValidURL(settings.URL) {
		return settings, &Rejection{Status: http.StatusBadRequest, Code: "invalid_csadmin_url", Message: "Customer admin address must be a plain http(s) URL"}
	}
	if !csadmin.ClientIDPattern.MatchString(settings.ClientID) {
		return settings, &Rejection{Status: http.StatusBadRequest, Code: "invalid_csadmin_client_id", Message: "Client id must be 1-50 letters, digits, dots, dashes or underscores"}
	}
	return settings, nil
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
