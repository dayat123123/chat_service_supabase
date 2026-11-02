package gateway

import (
	"bytes"
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

type integrationStatus struct {
	csadmin.Effective
	PublicKey     string `json:"public_key"`
	KeyConfigured bool   `json:"key_configured"`
	Configured    bool   `json:"configured"`
}

func integrationRoute(method, path string) bool {
	return (method == http.MethodGet && path == integrationPath) ||
		(method == http.MethodPost && path == integrationTestPath)
}

func (g *Gateway) serveIntegration(w http.ResponseWriter, r *http.Request, path string) {
	userID, err := g.authenticate(r)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "unauthorized", "Console session is missing or expired")
		return
	}
	if g.opts.Admins == nil {
		writeError(w, http.StatusForbidden, "permission_denied", "Only Super Admins can manage the customer admin integration")
		return
	}
	admin, err := g.opts.Admins.IsSuperAdmin(r.Context(), userID)
	if err != nil {
		g.opts.Log.Error("Failed to check Super Admin access", "error", err)
		writeError(w, http.StatusServiceUnavailable, "access_unavailable", "Console access check is unavailable")
		return
	}
	if !admin {
		writeError(w, http.StatusForbidden, "permission_denied", "Only Super Admins can manage the customer admin integration")
		return
	}
	effective := g.opts.Upstream.Effective(r.Context())
	if path == integrationPath {
		key := g.opts.Upstream.PublicKey()
		writeJSON(w, http.StatusOK, integrationStatus{
			Effective:     effective,
			PublicKey:     key,
			KeyConfigured: key != "",
			Configured:    key != "" && effective.URL != "",
		})
		return
	}
	settings, rejection := testSettings(r, effective)
	if rejection != nil {
		writeError(w, rejection.Status, rejection.Code, rejection.Message)
		return
	}
	result := g.opts.Upstream.Check(r.Context(), settings)
	g.opts.Log.Info("Customer admin connection tested", "result", result.Result, "status", result.Status,
		"duration_ms", result.DurationMS)
	writeJSON(w, http.StatusOK, result)
}

func testSettings(r *http.Request, effective csadmin.Effective) (csadmin.Settings, *Rejection) {
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
	settings := csadmin.Settings{URL: strings.TrimSpace(body.URL), ClientID: strings.TrimSpace(body.ClientID)}
	switch {
	case settings.URL == "":
		settings.URL = effective.URL
	case !csadmin.ValidURL(settings.URL):
		return settings, &Rejection{Status: http.StatusBadRequest, Code: "invalid_csadmin_url", Message: "Customer admin address is not a plain http(s) URL"}
	}
	switch {
	case settings.ClientID == "":
		settings.ClientID = effective.ClientID
	case !csadmin.ClientIDPattern.MatchString(settings.ClientID):
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
