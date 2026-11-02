package gateway

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"strings"
	"testing"
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
	g, _, up := setup(t, 200, `{}`)
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
		for _, req := range [][2]string{{http.MethodGet, "/api-nasabah/integration"}, {http.MethodPost, "/api-nasabah/integration/test"}} {
			rec := do(g, req[0], req[1], c.token, `{}`)
			if rec.Code != c.status || errorCode(t, rec) != c.code {
				t.Errorf("%s %s %s: status %d code %q", name, req[0], req[1], rec.Code, errorCode(t, rec))
			}
		}
	}
	if rec := do(g, http.MethodPost, "/api-nasabah/integration/token", session(t, "sinta", nil), `{}`); rec.Code != http.StatusNotFound {
		t.Errorf("the csAdmin token route must never be proxied, status %d", rec.Code)
	}
	if up.exchanges != 0 || len(up.calls) != 0 {
		t.Fatalf("csAdmin must not be called, exchanges %d calls %d", up.exchanges, len(up.calls))
	}
}

func TestIntegrationStatusShowsTheAddressAndThePublicKeyToPasteIntoCSAdmin(t *testing.T) {
	g, _, up := setup(t, 200, `{}`)
	rec := do(g, http.MethodGet, "/api-nasabah/integration", session(t, "sinta", nil), "")
	if rec.Code != http.StatusOK || rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("status %d headers %v", rec.Code, rec.Header())
	}
	body := decode(t, rec.Body.String())
	if !strings.HasSuffix(body["url"].(string), "/csAdmin") || body["url_source"] != "server" ||
		body["client_id"] != "web-cs" || body["configured"] != true || body["key_configured"] != true {
		t.Fatalf("status = %v", body)
	}
	der, err := base64.RawStdEncoding.DecodeString(body["public_key"].(string))
	if err != nil {
		t.Fatal(err)
	}
	public, err := x509.ParsePKIXPublicKey(der)
	if err != nil || !up.public.Equal(public) {
		t.Fatalf("public key must match the signing key: %v", err)
	}

	_, key, _ := ed25519.GenerateKey(rand.Reader)
	g.opts.Upstream = provider("", key)
	body = decode(t, do(g, http.MethodGet, "/api-nasabah/integration", session(t, "sinta", nil), "").Body.String())
	if body["configured"] != false || body["url_source"] != "none" || body["key_configured"] != true {
		t.Fatalf("an unconfigured gateway must still answer its status, got %v", body)
	}
}

func TestIntegrationTestExchangesATokenWithTheCurrentOrTypedAddress(t *testing.T) {
	g, _, up := setup(t, 200, `{}`)
	rec := do(g, http.MethodPost, "/api-nasabah/integration/test", session(t, "sinta", nil), `{}`)
	if body := decode(t, rec.Body.String()); rec.Code != http.StatusOK || body["result"] != "ok" || up.exchanges != 1 {
		t.Fatalf("status %d body %v exchanges %d", rec.Code, body, up.exchanges)
	}

	rec = do(g, http.MethodPost, "/api-nasabah/integration/test", session(t, "sinta", nil), `{"url":"http://127.0.0.1:1"}`)
	if body := decode(t, rec.Body.String()); body["result"] != "unreachable" {
		t.Fatalf("typed address must be tested, got %v", body)
	}

	for body, code := range map[string]string{
		`{"url":"http://admin:secret@10.0.0.5"}`: "invalid_csadmin_url",
		`{"url":"file:///etc/passwd"}`:           "invalid_csadmin_url",
		`{"client_id":"web cs"}`:                 "invalid_csadmin_client_id",
		`["x"]`:                                  "invalid_body",
	} {
		rec := do(g, http.MethodPost, "/api-nasabah/integration/test", session(t, "sinta", nil), body)
		if rec.Code != http.StatusBadRequest || errorCode(t, rec) != code {
			t.Errorf("%s: status %d code %q", body, rec.Code, errorCode(t, rec))
		}
	}
	if up.exchanges != 1 {
		t.Fatalf("rejected input must not reach csAdmin, exchanges %d", up.exchanges)
	}
}
