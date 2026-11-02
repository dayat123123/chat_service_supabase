package gateway

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/nasabah-gateway/internal/access"
	"olt-social/nasabah-gateway/internal/csadmin"
	"olt-social/nasabah-gateway/internal/jwt"
)

var (
	now       = time.Unix(1_800_000_000, 0)
	jwtSecret = []byte("supabase-secret")
)

type auditEntry struct {
	user, action string
	details      map[string]any
}

type fakeStore struct {
	grants map[string]*access.Grant
	admins map[string]bool
	mu     sync.Mutex
	audits []auditEntry
}

func (s *fakeStore) Grant(_ context.Context, userID string) (*access.Grant, error) {
	return s.grants[userID], nil
}

func (s *fakeStore) IsSuperAdmin(_ context.Context, userID string) (bool, error) {
	return s.admins[userID], nil
}

func (s *fakeStore) Audit(_ context.Context, userID, action string, details map[string]any) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.audits = append(s.audits, auditEntry{userID, action, details})
	return nil
}

type upstreamCall struct {
	method, path, query, contentType, token string
	body                                    map[string]any
}

type upstream struct {
	mu        sync.Mutex
	calls     []upstreamCall
	exchanges int
	status    int
	reply     string
	reject    int
	public    ed25519.PublicKey
}

func (u *upstream) validAssertion(assertion string) bool {
	parts := strings.Split(assertion, ".")
	if len(parts) != 3 {
		return false
	}
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	return err == nil && ed25519.Verify(u.public, []byte(parts[0]+"."+parts[1]), sig)
}

func (u *upstream) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	u.mu.Lock()
	defer u.mu.Unlock()
	if r.URL.Path == "/csAdmin/integration/token" {
		var body map[string]string
		_ = json.NewDecoder(r.Body).Decode(&body)
		if !u.validAssertion(body["Assertion"]) {
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte(`{"message":"Invalid client assertion.","data":{}}`))
			return
		}
		u.exchanges++
		_, _ = fmt.Fprintf(w, `{"message":"Successfully issued integration token.","data":{"Token":"legacy-token-%d","ClientId":"web-cs"}}`, u.exchanges)
		return
	}
	call := upstreamCall{method: r.Method, path: r.URL.Path, query: r.URL.RawQuery, contentType: r.Header.Get("Content-Type"),
		token: strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")}
	raw, _ := io.ReadAll(r.Body)
	if len(raw) > 0 {
		_ = json.Unmarshal(raw, &call.body)
	}
	u.calls = append(u.calls, call)
	if u.reject > 0 {
		u.reject--
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"message":"Your session has expired. Please log in again to continue.","data":{}}`))
		return
	}
	w.WriteHeader(u.status)
	_, _ = w.Write([]byte(u.reply))
}

func setup(t *testing.T, status int, reply string) (*Gateway, *fakeStore, *upstream) {
	t.Helper()
	public, key, _ := ed25519.GenerateKey(rand.Reader)
	up := &upstream{status: status, reply: reply, public: public}
	server := httptest.NewServer(up)
	t.Cleanup(server.Close)
	store := &fakeStore{grants: map[string]*access.Grant{
		"nadia": {AgentCode: "CS-0045", Permissions: []string{"online_user.view", "online_user.create"}},
		"bima":  {AgentCode: "CS-0046", Permissions: []string{"online_user.view"}},
	}, admins: map[string]bool{"sinta": true}}
	g := New(Options{
		Routes: []Route{
			{Method: http.MethodGet, Path: "/online/get-list-online-user", Action: "list", Permissions: []string{"online_user.view"}},
			{Method: http.MethodPost, Path: "/online/create-approval-login", Action: "create", Permissions: []string{"online_user.create"},
				ActorFields: []string{"CreatedBy"}, SubjectFields: []string{"LoginId"}, Audit: true},
		},
		Grants:    store,
		Admins:    store,
		JWTSecret: jwtSecret,
		Upstream:  provider(server.URL+"/csAdmin/", key),
		Now:       func() time.Time { return now },
	})
	return g, store, up
}

func provider(url string, key ed25519.PrivateKey) *csadmin.Provider {
	return csadmin.NewProvider(csadmin.ProviderOptions{Server: csadmin.Settings{URL: url, ClientID: "web-cs"}, Key: key})
}

func session(t *testing.T, sub string, mutate func(map[string]any)) string {
	t.Helper()
	claims := map[string]any{"sub": sub, "role": "authenticated", "aud": "authenticated", "exp": now.Add(time.Hour).Unix()}
	if mutate != nil {
		mutate(claims)
	}
	token, err := jwt.Sign(map[string]any{"alg": "HS256", "typ": "JWT"}, claims, jwtSecret)
	if err != nil {
		t.Fatal(err)
	}
	return token
}

func do(g *Gateway, method, target, token, body string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, target, strings.NewReader(body))
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	g.ServeHTTP(rec, req)
	return rec
}

func errorCode(t *testing.T, rec *httptest.ResponseRecorder) string {
	t.Helper()
	var body map[string]string
	_ = json.Unmarshal(rec.Body.Bytes(), &body)
	return body["code"]
}

func TestRejectsRoutesOutsideTheAllowList(t *testing.T) {
	g, _, up := setup(t, 200, `{}`)
	for _, target := range []string{"/api-nasabah/cs/get-list-customer-service", "/api-nasabah/auto-update/get-binary-file?fileName=../config", "/online/get-list-online-user"} {
		rec := do(g, http.MethodGet, target, session(t, "nadia", nil), "")
		if rec.Code != http.StatusNotFound || errorCode(t, rec) != "route_not_found" {
			t.Errorf("%s: status %d code %q", target, rec.Code, errorCode(t, rec))
		}
	}
	if len(up.calls) != 0 || up.exchanges != 0 {
		t.Fatalf("upstream must not be called, got %d calls %d exchanges", len(up.calls), up.exchanges)
	}
}

func TestRejectsMissingForeignOrNonUserSessions(t *testing.T) {
	g, _, _ := setup(t, 200, `{}`)
	foreign, _ := jwt.Sign(map[string]any{"alg": "HS256"}, map[string]any{"sub": "nadia", "role": "authenticated", "aud": "authenticated", "exp": now.Add(time.Hour).Unix()}, []byte("other"))
	cases := map[string]string{
		"missing":      "",
		"foreign key":  foreign,
		"expired":      session(t, "nadia", func(c map[string]any) { c["exp"] = now.Add(-time.Minute).Unix() }),
		"anon role":    session(t, "nadia", func(c map[string]any) { c["role"] = "anon" }),
		"service role": session(t, "", func(c map[string]any) { c["role"] = "service_role" }),
	}
	for name, token := range cases {
		rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", token, "")
		if rec.Code != http.StatusUnauthorized {
			t.Errorf("%s: status %d", name, rec.Code)
		}
	}
}

func TestRequiresCustomerAccessWithThePermission(t *testing.T) {
	g, _, up := setup(t, 200, `{}`)
	if rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "sinta", nil), ""); rec.Code != http.StatusForbidden || errorCode(t, rec) != "no_access" {
		t.Errorf("no access: status %d code %q", rec.Code, errorCode(t, rec))
	}
	if rec := do(g, http.MethodPost, "/api-nasabah/online/create-approval-login", session(t, "bima", nil), `{"LoginId":"budi"}`); rec.Code != http.StatusForbidden || errorCode(t, rec) != "permission_denied" {
		t.Errorf("no permission: status %d code %q", rec.Code, errorCode(t, rec))
	}
	if len(up.calls) != 0 {
		t.Fatalf("upstream must not be called, got %d calls", len(up.calls))
	}
}

func TestForwardsReadsWithTheIntegrationToken(t *testing.T) {
	g, store, up := setup(t, 200, `{"message":"ok","data":[{"LoginId":"budi"}]}`)
	for range 2 {
		rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user?page=2&keyword=bud", session(t, "bima", nil), "")
		if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"LoginId":"budi"`) {
			t.Fatalf("status %d body %s", rec.Code, rec.Body.String())
		}
		if rec.Header().Get("Cache-Control") != "no-store" {
			t.Error("responses must not be cached")
		}
	}
	if up.exchanges != 1 {
		t.Fatalf("the integration token must be exchanged once, exchanges = %d", up.exchanges)
	}
	call := up.calls[0]
	if call.path != "/csAdmin/online/get-list-online-user" || call.query != "keyword=bud&page=2" || call.contentType != "application/json" || call.token != "legacy-token-1" {
		t.Fatalf("upstream call = %+v", call)
	}
	if len(store.audits) != 0 {
		t.Fatal("plain reads are not audited")
	}
}

func TestExchangesAgainWhenTheLegacyTokenIsRejected(t *testing.T) {
	g, _, up := setup(t, 200, `{"message":"ok","data":[]}`)
	up.reject = 1
	rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "bima", nil), "")
	if rec.Code != http.StatusOK || up.exchanges != 2 || up.calls[1].token != "legacy-token-2" {
		t.Fatalf("status %d exchanges %d calls %+v", rec.Code, up.exchanges, up.calls)
	}
}

func TestReportsARefusedIntegrationKey(t *testing.T) {
	g, _, up := setup(t, 200, `{}`)
	up.public, _, _ = ed25519.GenerateKey(rand.Reader)
	rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "bima", nil), "")
	if rec.Code != http.StatusServiceUnavailable || errorCode(t, rec) != "integration_refused" {
		t.Fatalf("status %d code %q", rec.Code, errorCode(t, rec))
	}
}

func TestOverridesActorFieldsAndAuditsSuccessfulWrites(t *testing.T) {
	g, store, up := setup(t, 200, `{"message":"created"}`)
	rec := do(g, http.MethodPost, "/api-nasabah/online/create-approval-login", session(t, "nadia", nil), `{"LoginId":"budi","CreatedBy":"superadmin","Password":"secret"}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
	body := up.calls[0].body
	if body["CreatedBy"] != "CS-0045" || body["LoginId"] != "budi" {
		t.Fatalf("forwarded body = %v", body)
	}
	if len(store.audits) != 1 {
		t.Fatalf("audits = %d", len(store.audits))
	}
	entry := store.audits[0]
	if entry.user != "nadia" || entry.action != "nasabah.create" {
		t.Fatalf("audit = %+v", entry)
	}
	encoded, _ := json.Marshal(entry.details)
	if strings.Contains(string(encoded), "secret") || !strings.Contains(string(encoded), `"subject":{"LoginId":"budi"}`) {
		t.Fatalf("audit details must name the customer and never copy values like passwords: %s", encoded)
	}
}

func TestGuardsCanRejectOrRewriteRequestsUsingUpstreamLookups(t *testing.T) {
	g, store, up := setup(t, 200, `{"message":"ok","data":[{"LoginId":"budi","Email":"budi@olt.test"}]}`)
	route := g.routes["POST /online/create-approval-login"]
	route.Guard = func(ctx context.Context, call Caller, req *Request) error {
		status, payload, err := call.Get(ctx, "/online/get-list-online-user", url.Values{"loginId": {req.Fields["LoginId"].(string)}})
		if err != nil || status != http.StatusOK {
			return err
		}
		if req.Fields["LoginId"] == "ghost" {
			return &Rejection{Status: http.StatusNotFound, Code: "customer_not_found", Message: "Customer not found"}
		}
		req.Fields["Email"] = string(payload[strings.Index(string(payload), "budi@"):][:13])
		return nil
	}
	g.routes["POST /online/create-approval-login"] = route

	rec := do(g, http.MethodPost, "/api-nasabah/online/create-approval-login", session(t, "nadia", nil), `{"LoginId":"ghost"}`)
	if rec.Code != http.StatusNotFound || errorCode(t, rec) != "customer_not_found" || len(store.audits) != 0 {
		t.Fatalf("status %d code %q audits %d", rec.Code, errorCode(t, rec), len(store.audits))
	}
	do(g, http.MethodPost, "/api-nasabah/online/create-approval-login", session(t, "nadia", nil), `{"LoginId":"budi","Email":"attacker@evil.test"}`)
	last := up.calls[len(up.calls)-1]
	if last.method != http.MethodPost || last.body["Email"] != "budi@olt.test" {
		t.Fatalf("guard must rewrite the email, got %+v", last)
	}
	if up.calls[0].method != http.MethodGet || up.calls[0].query != "loginId=ghost" {
		t.Fatalf("guard lookup = %+v", up.calls[0])
	}
}

func TestDoesNotAuditFailedWritesAndPassesUpstreamErrors(t *testing.T) {
	g, store, _ := setup(t, 409, `{"message":"LoginId already exists"}`)
	rec := do(g, http.MethodPost, "/api-nasabah/online/create-approval-login", session(t, "nadia", nil), `{"LoginId":"budi"}`)
	if rec.Code != http.StatusConflict || !strings.Contains(rec.Body.String(), "already exists") {
		t.Fatalf("status %d body %s", rec.Code, rec.Body.String())
	}
	if len(store.audits) != 0 {
		t.Fatal("failed writes are not audited")
	}
}

func TestRejectsNonObjectBodies(t *testing.T) {
	g, _, up := setup(t, 200, `{}`)
	rec := do(g, http.MethodPost, "/api-nasabah/online/create-approval-login", session(t, "nadia", nil), `["x"]`)
	if rec.Code != http.StatusBadRequest || len(up.calls) != 0 {
		t.Fatalf("status %d calls %d", rec.Code, len(up.calls))
	}
}

func TestAnswersNotConfiguredWithoutUpstreamSettings(t *testing.T) {
	g, _, _ := setup(t, 200, `{}`)
	_, key, _ := ed25519.GenerateKey(rand.Reader)
	g.opts.Upstream = provider("", key)
	rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "nadia", nil), "")
	if rec.Code != http.StatusServiceUnavailable || errorCode(t, rec) != "not_configured" {
		t.Fatalf("status %d code %q", rec.Code, errorCode(t, rec))
	}
}

func TestReportsAnUnreachableUpstream(t *testing.T) {
	g, _, _ := setup(t, 200, `{}`)
	_, key, _ := ed25519.GenerateKey(rand.Reader)
	g.opts.Upstream = provider("http://127.0.0.1:1", key)
	rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "nadia", nil), "")
	if rec.Code != http.StatusBadGateway || errorCode(t, rec) != "upstream_unavailable" {
		t.Fatalf("status %d code %q", rec.Code, errorCode(t, rec))
	}
}

func TestQueryRulesDropUnknownAndRejectUnsafeValues(t *testing.T) {
	g, _, up := setup(t, 200, `{"message":"ok","data":[]}`)
	route := g.routes["GET /online/get-list-online-user"]
	route.Query = map[string]*regexp.Regexp{"page": regexp.MustCompile(`^[0-9]+$`), "loginId": regexp.MustCompile(`^[a-z]+$`)}
	g.routes["GET /online/get-list-online-user"] = route

	do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user?page=1&loginId=&email=x%27--&evil=1", session(t, "bima", nil), "")
	if got := up.calls[0].query; got != "page=1" {
		t.Fatalf("forwarded query = %q", got)
	}
	rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user?page=1&loginId=a%27%20OR%201=1--", session(t, "bima", nil), "")
	if rec.Code != http.StatusBadRequest || errorCode(t, rec) != "invalid_query" || len(up.calls) != 1 {
		t.Fatalf("status %d code %q calls %d", rec.Code, errorCode(t, rec), len(up.calls))
	}
}

func TestReportsAnOutdatedUpstreamWhenARouteIsMissing(t *testing.T) {
	g, store, _ := setup(t, http.StatusNotFound, "")
	rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "bima", nil), "")
	if rec.Code != http.StatusBadGateway || errorCode(t, rec) != "upstream_outdated" || len(store.audits) != 0 {
		t.Fatalf("status %d code %q", rec.Code, errorCode(t, rec))
	}
	g2, _, _ := setup(t, http.StatusNotFound, `{"message":"Online user not found.","data":null}`)
	rec = do(g2, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "bima", nil), "")
	if rec.Code != http.StatusNotFound || !strings.Contains(rec.Body.String(), "Online user not found") {
		t.Fatalf("a JSON 404 from csAdmin must pass through, got %d %s", rec.Code, rec.Body.String())
	}
}
