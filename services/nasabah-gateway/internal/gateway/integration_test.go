package gateway

import (
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"

	"testing"

	"olt-social/nasabah-gateway/internal/csadmin"
)

func decode(t *testing.T, body string) map[string]any {
	t.Helper()
	var out map[string]any
	if err := json.Unmarshal([]byte(body), &out); err != nil {
		t.Fatalf("body %q: %v", body, err)
	}
	return out
}

func TestIntegrationEndpointsAreForSuperAdminsOnly(t *testing.T) {
	g, store, up := setup(t, 200, `{}`)
	cases := map[string]struct {
		token  string
		status int
		code   string
	}{
		"no session":   {"", http.StatusUnauthorized, "unauthorized"},
		"cs agent":     {session(t, "nadia", nil), http.StatusForbidden, "permission_denied"},
		"service role": {session(t, "", func(c map[string]any) { c["role"] = "service_role" }), http.StatusUnauthorized, "unauthorized"},
	}
	for name, c := range cases {
		for _, req := range [][2]string{
			{http.MethodGet, "/api-nasabah/integration"},
			{http.MethodPut, "/api-nasabah/integration"},
			{http.MethodDelete, "/api-nasabah/integration"},
			{http.MethodPost, "/api-nasabah/integration/test"},
		} {
			rec := do(g, req[0], req[1], c.token, `{"url":"http://10.0.0.5:8080","client_id":"web-cs"}`)
			if rec.Code != c.status || errorCode(t, rec) != c.code {
				t.Errorf("%s %s %s: status %d code %q", name, req[0], req[1], rec.Code, errorCode(t, rec))
			}
		}
	}
	if rec := do(g, http.MethodPost, "/api-nasabah/integration/token", session(t, "sinta", nil), `{}`); rec.Code != http.StatusNotFound {
		t.Errorf("the csAdmin token route must never be proxied, status %d", rec.Code)
	}
	if up.exchanges != 0 || len(up.calls) != 0 || len(store.saved) != 0 {
		t.Fatalf("nothing may reach csAdmin or the settings, exchanges %d calls %d saved %d",
			up.exchanges, len(up.calls), len(store.saved))
	}
}

func TestIntegrationStatusStartsEmptyAndShowsTheKeyForCSAdmin(t *testing.T) {
	g, store, up := setup(t, 200, `{}`)
	g.opts.Upstream = csadmin.NewProvider(csadmin.ProviderOptions{Source: store, Key: up.key})
	rec := do(g, http.MethodGet, "/api-nasabah/integration", session(t, "sinta", nil), "")
	if rec.Code != http.StatusOK || rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("status %d headers %v", rec.Code, rec.Header())
	}
	body := decode(t, rec.Body.String())
	if body["url"] != "" || body["client_id"] != "" || body["configured"] != false || body["key_configured"] != true {
		t.Fatalf("there must be no default address or client id, got %v", body)
	}
	der, err := base64.RawStdEncoding.DecodeString(body["public_key"].(string))
	if err != nil {
		t.Fatal(err)
	}
	public, err := x509.ParsePKIXPublicKey(der)
	if err != nil || !up.public.Equal(public) {
		t.Fatalf("public key must match the signing key: %v", err)
	}
	if rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "bima", nil), ""); rec.Code != http.StatusServiceUnavailable || errorCode(t, rec) != "not_configured" {
		t.Fatalf("customer requests must wait for the integration, status %d code %q", rec.Code, errorCode(t, rec))
	}
}

func TestSavingRequiresASuccessfulConnectionTest(t *testing.T) {
	g, store, up := setup(t, 200, `{"message":"ok","data":[]}`)
	address := g.opts.Upstream.Session(t.Context()).BaseURL()
	g.opts.Upstream = csadmin.NewProvider(csadmin.ProviderOptions{Source: store, Key: up.key})
	sinta := session(t, "sinta", nil)

	for body, code := range map[string]string{
		`{"client_id":"web-cs"}`:                                      "invalid_csadmin_url",
		fmt.Sprintf(`{"url":%q}`, address):                            "invalid_csadmin_client_id",
		`{"url":"http://admin:secret@10.0.0.5","client_id":"web-cs"}`: "invalid_csadmin_url",
		`["x"]`: "invalid_body",
	} {
		rec := do(g, http.MethodPut, "/api-nasabah/integration", sinta, body)
		if rec.Code != http.StatusBadRequest || errorCode(t, rec) != code {
			t.Errorf("%s: status %d code %q", body, rec.Code, errorCode(t, rec))
		}
	}

	rec := do(g, http.MethodPut, "/api-nasabah/integration", sinta, `{"url":"http://127.0.0.1:1","client_id":"web-cs"}`)
	body := decode(t, rec.Body.String())
	if rec.Code != http.StatusOK || body["saved"] != false || body["check"].(map[string]any)["result"] != "unreachable" || len(store.saved) != 0 {
		t.Fatalf("a failed test must not save: status %d body %v saved %v", rec.Code, body, store.saved)
	}

	rec = do(g, http.MethodPut, "/api-nasabah/integration", sinta, fmt.Sprintf(`{"url":"%s/","client_id":" web-cs "}`, address))
	body = decode(t, rec.Body.String())
	status := body["status"].(map[string]any)
	if body["saved"] != true || status["configured"] != true || status["url"] != address || status["client_id"] != "web-cs" {
		t.Fatalf("a passing test must save and activate, got %v", body)
	}
	if len(store.saved) != 1 || store.saved[0].URL != address {
		t.Fatalf("saved = %+v", store.saved)
	}
	if rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "bima", nil), ""); rec.Code != http.StatusOK {
		t.Fatalf("customer requests must work right after saving, status %d", rec.Code)
	}

	rec = do(g, http.MethodDelete, "/api-nasabah/integration", sinta, "")
	if body := decode(t, rec.Body.String()); rec.Code != http.StatusOK || body["configured"] != false {
		t.Fatalf("clearing must deactivate, status %d body %v", rec.Code, body)
	}
	if rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "bima", nil), ""); rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("customer requests must stop after clearing, status %d", rec.Code)
	}
	if up.exchanges < 2 {
		t.Fatalf("the save test and the request must exchange tokens, exchanges %d", up.exchanges)
	}
}

func TestConnectionTestUsesTheTypedValuesWithoutSaving(t *testing.T) {
	g, store, _ := setup(t, 200, `{}`)
	address := g.opts.Upstream.Session(t.Context()).BaseURL()
	sinta := session(t, "sinta", nil)

	rec := do(g, http.MethodPost, "/api-nasabah/integration/test", sinta, fmt.Sprintf(`{"url":%q,"client_id":"web-cs"}`, address))
	if body := decode(t, rec.Body.String()); rec.Code != http.StatusOK || body["result"] != "ok" {
		t.Fatalf("status %d body %v", rec.Code, body)
	}
	rec = do(g, http.MethodPost, "/api-nasabah/integration/test", sinta, `{"url":"http://127.0.0.1:1","client_id":"web-cs"}`)
	if body := decode(t, rec.Body.String()); body["result"] != "unreachable" {
		t.Fatalf("typed address must be tested, got %v", body)
	}
	if rec := do(g, http.MethodPost, "/api-nasabah/integration/test", sinta, `{"url":"http://10.0.0.5:8080"}`); rec.Code != http.StatusBadRequest || errorCode(t, rec) != "invalid_csadmin_client_id" {
		t.Fatalf("client id is required, status %d code %q", rec.Code, errorCode(t, rec))
	}
	if len(store.saved) != 0 {
		t.Fatal("testing must never save")
	}
}
