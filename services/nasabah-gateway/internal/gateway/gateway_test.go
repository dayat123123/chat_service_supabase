package gateway

import (
	"context"
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
	mu     sync.Mutex
	audits []auditEntry
}

func (s *fakeStore) Grant(_ context.Context, userID string) (*access.Grant, error) {
	return s.grants[userID], nil
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
	mu       sync.Mutex
	calls    []upstreamCall
	logins   int
	status   int
	reply    string
	reject   int
	password string
}

func (u *upstream) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	u.mu.Lock()
	defer u.mu.Unlock()
	if r.URL.Path == "/csAdmin/cs/login" {
		var body map[string]string
		_ = json.NewDecoder(r.Body).Decode(&body)
		if body["LoginId"] != "svc" || body["Password"] != u.password {
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte(`{"message":"Login failed","data":{}}`))
			return
		}
		u.logins++
		_, _ = fmt.Fprintf(w, `{"message":"Login successfully.","data":{"LoginId":"svc","Token":"legacy-token-%d"}}`, u.logins)
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
	up := &upstream{status: status, reply: reply, password: "pw"}
	server := httptest.NewServer(up)
	t.Cleanup(server.Close)
	store := &fakeStore{grants: map[string]*access.Grant{
		"nadia": {AgentCode: "CS-0045", Permissions: []string{"online_user.view", "online_user.create"}},
		"bima":  {AgentCode: "CS-0046", Permissions: []string{"online_user.view"}},
	}}
	g := New(Options{
		Routes: []Route{
			{Method: http.MethodGet, Path: "/online/get-list-online-user", Action: "list", Permissions: []string{"online_user.view"}},
			{Method: http.MethodPost, Path: "/online/create-approval-login", Action: "create", Permissions: []string{"online_user.create"},
				ActorFields: []string{"CreatedBy"}, SubjectFields: []string{"LoginId"}, Audit: true},
		},
		Grants:    store,
		JWTSecret: jwtSecret,
		Upstream:  csadmin.NewSession(server.URL+"/csAdmin/", "svc", "pw", nil),
		Now:       func() time.Time { return now },
	})
	return g, store, up
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
	if len(up.calls) != 0 || up.logins != 0 {
		t.Fatalf("upstream must not be called, got %d calls %d logins", len(up.calls), up.logins)
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

func TestForwardsReadsWithTheServiceAccountToken(t *testing.T) {
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
	if up.logins != 1 {
		t.Fatalf("service account must log in once, logins = %d", up.logins)
	}
	call := up.calls[0]
	if call.path != "/csAdmin/online/get-list-online-user" || call.query != "keyword=bud&page=2" || call.contentType != "application/json" || call.token != "legacy-token-1" {
		t.Fatalf("upstream call = %+v", call)
	}
	if len(store.audits) != 0 {
		t.Fatal("plain reads are not audited")
	}
}

func TestLogsInAgainWhenTheLegacyTokenIsRejected(t *testing.T) {
	g, _, up := setup(t, 200, `{"message":"ok","data":[]}`)
	up.reject = 1
	rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "bima", nil), "")
	if rec.Code != http.StatusOK || up.logins != 2 || up.calls[1].token != "legacy-token-2" {
		t.Fatalf("status %d logins %d calls %+v", rec.Code, up.logins, up.calls)
	}
}

func TestReportsARejectedServiceAccount(t *testing.T) {
	g, _, up := setup(t, 200, `{}`)
	up.password = "changed"
	rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "bima", nil), "")
	if rec.Code != http.StatusServiceUnavailable || errorCode(t, rec) != "upstream_login_failed" {
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

func TestServiceActorModeUsesTheServiceAccount(t *testing.T) {
	g, _, up := setup(t, 200, `{"message":"created"}`)
	g.opts.ActorMode = ActorService
	do(g, http.MethodPost, "/api-nasabah/online/create-approval-login", session(t, "nadia", nil), `{"LoginId":"budi"}`)
	if up.calls[0].body["CreatedBy"] != "svc" {
		t.Fatalf("forwarded body = %v", up.calls[0].body)
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
	g.opts.Upstream = csadmin.NewSession("", "svc", "pw", nil)
	rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "nadia", nil), "")
	if rec.Code != http.StatusServiceUnavailable || errorCode(t, rec) != "not_configured" {
		t.Fatalf("status %d code %q", rec.Code, errorCode(t, rec))
	}
}

func TestReportsAnUnreachableUpstream(t *testing.T) {
	g, _, _ := setup(t, 200, `{}`)
	g.opts.Upstream = csadmin.NewSession("http://127.0.0.1:1", "svc", "pw", nil)
	rec := do(g, http.MethodGet, "/api-nasabah/online/get-list-online-user", session(t, "nadia", nil), "")
	if rec.Code != http.StatusBadGateway || errorCode(t, rec) != "upstream_unavailable" {
		t.Fatalf("status %d code %q", rec.Code, errorCode(t, rec))
	}
}

func TestInfoNamesTheServiceAccountForLinkedConsoleUsers(t *testing.T) {
	g, _, up := setup(t, 200, `{}`)
	rec := do(g, http.MethodGet, "/api-nasabah/gateway/info", session(t, "bima", nil), "")
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"service_login_id":"svc"`) || !strings.Contains(rec.Body.String(), `"actor":"CS-0046"`) {
		t.Fatalf("status %d body %s", rec.Code, rec.Body.String())
	}
	if len(up.calls) != 0 || up.logins != 0 {
		t.Fatal("info must not call the customer admin service")
	}
	if rec := do(g, http.MethodGet, "/api-nasabah/gateway/info", session(t, "sinta", nil), ""); rec.Code != http.StatusForbidden {
		t.Fatalf("accounts without access: status %d", rec.Code)
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

func TestActorQueryAndAfterHooks(t *testing.T) {
	g, store, up := setup(t, 200, `{"data":{"LoginId":"rina"},"message":"ok"}`)
	g.routes["DELETE /cs/delete"] = Route{Method: http.MethodDelete, Path: "/cs/delete", Action: "cs_user.delete",
		Permissions: []string{"online_user.view"}, ActorQuery: []string{"modifiedBy"},
		Query: map[string]*regexp.Regexp{"loginId": regexp.MustCompile(`^[a-z]+$`)}, SubjectFields: []string{"loginId"}, Audit: true,
		After: func(_ context.Context, call Caller, req *Request, payload []byte) ([]byte, error) {
			_, _, err := call.Do(context.Background(), http.MethodPut, "/cs/after", nil, map[string]any{"by": req.Actor})
			return []byte(strings.Replace(string(payload), `"ok"`, `"done"`, 1)), err
		}}
	rec := do(g, http.MethodDelete, "/api-nasabah/cs/delete?loginId=rina&modifiedBy=someone", session(t, "bima", nil), "")
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"done"`) {
		t.Fatalf("status %d body %s", rec.Code, rec.Body.String())
	}
	if up.calls[0].query != "loginId=rina&modifiedBy=CS-0046" || up.calls[0].method != http.MethodDelete {
		t.Fatalf("delete call = %+v", up.calls[0])
	}
	if up.calls[1].path != "/csAdmin/cs/after" || up.calls[1].body["by"] != "CS-0046" {
		t.Fatalf("after call = %+v", up.calls[1])
	}
	if len(store.audits) != 1 || !strings.Contains(fmt.Sprint(store.audits[0].details["subject"]), "rina") {
		t.Fatalf("audits = %+v", store.audits)
	}
}

func TestGuardsSeeTheServiceAccount(t *testing.T) {
	g, _, _ := setup(t, 200, `{}`)
	route := g.routes["POST /online/create-approval-login"]
	var seen string
	route.Guard = func(_ context.Context, call Caller, _ *Request) error {
		seen = call.(interface{ ServiceLoginID() string }).ServiceLoginID()
		return nil
	}
	g.routes["POST /online/create-approval-login"] = route
	do(g, http.MethodPost, "/api-nasabah/online/create-approval-login", session(t, "nadia", nil), `{"LoginId":"budi"}`)
	if seen != "svc" {
		t.Fatalf("service login = %q", seen)
	}
}
