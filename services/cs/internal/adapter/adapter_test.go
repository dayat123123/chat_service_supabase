package adapter

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"olt-social/cs/internal/metrics"
	"olt-social/cs/internal/olt"
	"olt-social/cs/internal/postgrest"
	"olt-social/cs/internal/token"
)

const secret = "rahasia-jwt-uji-minimal-tiga-puluh-dua-karakter"

type apiCall struct {
	bearer string
	fn     string
	args   map[string]any
}

type fakeAPI struct {
	calls     []apiCall
	responses map[string]any
	errs      map[string]error
}

func (f *fakeAPI) CallAs(_ context.Context, bearer, fn string, args, out any) error {
	f.calls = append(f.calls, apiCall{bearer: bearer, fn: fn, args: args.(map[string]any)})
	if err := f.errs[fn]; err != nil {
		return err
	}
	if resp, ok := f.responses[fn]; ok && out != nil {
		data, _ := json.Marshal(resp)
		return json.Unmarshal(data, out)
	}
	return nil
}

func (f *fakeAPI) Call(ctx context.Context, fn string, args, out any) error {
	return f.CallAs(ctx, "service", fn, args, out)
}

type oltCall struct {
	kind    string
	payload map[string]any
}

type fakeOLT struct {
	calls []oltCall
	data  map[string]any
	err   error
}

func (f *fakeOLT) Call(_ context.Context, kind string, payload, out any) error {
	f.calls = append(f.calls, oltCall{kind: kind, payload: payload.(map[string]any)})
	if f.err != nil {
		return f.err
	}
	raw, _ := json.Marshal(f.data[kind])
	return json.Unmarshal(raw, out)
}

var discard = slog.New(slog.NewTextHandler(io.Discard, nil))

func agentToken(t *testing.T, exp time.Time) string {
	t.Helper()
	tok, err := token.Sign(map[string]any{"sub": "s1", "role": "authenticated", "aal": "aal2", "exp": exp.Unix()}, []byte(secret))
	if err != nil {
		t.Fatal(err)
	}
	return tok
}

func newServer(api *fakeAPI, client *fakeOLT) http.Handler {
	return NewServer(api, client, secret, discard, NewMetrics(metrics.NewRegistry())).Handler()
}

func do(t *testing.T, h http.Handler, method, path, bearer, body string) (int, map[string]any) {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	var out map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &out)
	return rec.Code, out
}

const session = "8b6f2d64-6a2a-4b7e-9f3c-2c1d0e9a7b11"

func TestAgentProfileIsAuthorizedAuditedAndMasked(t *testing.T) {
	api := &fakeAPI{responses: map[string]any{
		"agent_customer_access": map[string]string{"olt_user_id": "1001", "correlation_id": session + "/CS-0001"},
	}}
	client := &fakeOLT{data: map[string]any{"customer_profile": map[string]any{
		"name": "Budi Santoso", "nik": "3174012501900001", "phone": "081234567789", "email": "budi@olt.test",
		"address": "Jl. Melati 5, Jakarta Selatan", "birth_date": "1990-01-25",
		"rdn": map[string]any{"bank": "BCA", "number": "1234567890"},
	}}}
	tok := agentToken(t, time.Now().Add(time.Minute))
	code, body := do(t, newServer(api, client), http.MethodGet, "/v1/agent/sessions/"+session+"/customer/profile", tok, "")
	if code != http.StatusOK || body["available"] != true {
		t.Fatalf("status %d: %v", code, body)
	}
	if api.calls[0].bearer != tok || api.calls[0].fn != "agent_customer_access" ||
		api.calls[0].args["p_session_id"] != session || api.calls[0].args["p_kind"] != "profile" {
		t.Fatalf("izin harus diperiksa database dengan token agen: %+v", api.calls[0])
	}
	if client.calls[0].payload["user_id"] != "1001" || client.calls[0].payload["correlation_id"] != session+"/CS-0001" {
		t.Fatalf("payload OLT: %v", client.calls[0].payload)
	}
	data := body["data"].(map[string]any)
	want := map[string]string{
		"nik": "3174********0001", "phone": "0812*****789", "email": "bu***@olt.test",
		"address": "***, Jakarta Selatan", "birth_date": "1990-**-**", "name": "Budi Santoso",
	}
	for k, v := range want {
		if data[k] != v {
			t.Errorf("%s = %v, ingin %s", k, data[k], v)
		}
	}
	if data["rdn"].(map[string]any)["number"] != "******7890" {
		t.Errorf("nomor RDN tidak tersamar: %v", data["rdn"])
	}
}

func TestAuthenticationAndValidation(t *testing.T) {
	api := &fakeAPI{}
	h := newServer(api, &fakeOLT{})
	expired := agentToken(t, time.Now().Add(-time.Minute))
	valid := agentToken(t, time.Now().Add(time.Minute))
	cases := []struct {
		name, method, path, bearer, body string
		status                           int
		code                             string
	}{
		{"tanpa token", "GET", "/v1/agent/sessions/" + session + "/customer/profile", "", "", 401, "missing_token"},
		{"token kedaluwarsa", "GET", "/v1/agent/sessions/" + session + "/customer/profile", expired, "", 401, "invalid_token"},
		{"token palsu", "GET", "/v1/me/orders", "a.b.c", "", 401, "invalid_token"},
		{"sesi bukan UUID", "GET", "/v1/agent/sessions/123/customer/profile", valid, "", 400, "invalid_session"},
		{"data di luar daftar", "GET", "/v1/agent/sessions/" + session + "/customer/portfolio", valid, "", 404, ""},
		{"limit di luar batas", "GET", "/v1/me/orders?limit=500", valid, "", 400, "invalid_query"},
		{"status order asing", "GET", "/v1/me/orders?status=hilang", valid, "", 400, "invalid_query"},
		{"tanggal bukan RFC 3339", "GET", "/v1/me/cash-transactions?from=kemarin", valid, "", 400, "invalid_query"},
		{"field reveal asing", "POST", "/v1/agent/sessions/" + session + "/customer/reveal", valid, `{"field":"pin","reason":"x"}`, 400, "invalid_body"},
	}
	for _, c := range cases {
		code, body := do(t, h, c.method, c.path, c.bearer, c.body)
		if code != c.status || (c.code != "" && body["code"] != c.code) {
			t.Errorf("%s: %d %v, ingin %d %s", c.name, code, body, c.status, c.code)
		}
	}
	if len(api.calls) != 0 {
		t.Fatalf("request yang ditolak tidak boleh sampai ke database: %v", api.calls)
	}
}

func TestDatabaseDecisionsArePassedThrough(t *testing.T) {
	api := &fakeAPI{errs: map[string]error{"agent_customer_access": &postgrest.Error{
		Status: 403, Code: "customer_data_forbidden", Message: "Anda tidak berwenang"}}}
	client := &fakeOLT{}
	code, body := do(t, newServer(api, client), "GET", "/v1/agent/sessions/"+session+"/customer/security",
		agentToken(t, time.Now().Add(time.Minute)), "")
	if code != 403 || body["code"] != "customer_data_forbidden" || len(client.calls) != 0 {
		t.Fatalf("%d %v, OLT dipanggil %d kali", code, body, len(client.calls))
	}

	limited := &fakeAPI{errs: map[string]error{"agent_customer_access": &postgrest.Error{
		Status: 429, Code: "rate_limited", Message: "Batas", RetryAfter: "300"}}}
	req := httptest.NewRequest("GET", "/v1/agent/sessions/"+session+"/customer/profile", nil)
	req.Header.Set("Authorization", "Bearer "+agentToken(t, time.Now().Add(time.Minute)))
	rec := httptest.NewRecorder()
	newServer(limited, client).ServeHTTP(rec, req)
	if rec.Code != 429 || rec.Header().Get("Retry-After") != "300" {
		t.Fatalf("rate limit: %d %v", rec.Code, rec.Header())
	}
}

func TestOLTFailuresAreExplicit(t *testing.T) {
	api := &fakeAPI{responses: map[string]any{"customer_data_access": map[string]string{"olt_user_id": "1001"}}}
	tok := agentToken(t, time.Now().Add(time.Minute))
	cases := []struct {
		err    error
		status int
		code   string
	}{
		{olt.ErrUnavailable, 503, "olt_unavailable"},
		{&olt.Error{Code: "NOT_FOUND", Message: "tidak ada"}, 404, "not_found"},
		{&olt.Error{Code: "UNAUTHORIZED", Message: "kredensial"}, 502, "olt_rejected"},
	}
	for _, c := range cases {
		code, body := do(t, newServer(api, &fakeOLT{err: c.err}), "GET", "/v1/me/orders/O-1", tok, "")
		if code != c.status || body["code"] != c.code {
			t.Errorf("%v: %d %v", c.err, code, body)
		}
		if c.status == 503 && body["available"] != false {
			t.Errorf("OLT mati harus available=false: %v", body)
		}
	}
}

func TestCustomerOrdersUseOwnIdentity(t *testing.T) {
	api := &fakeAPI{responses: map[string]any{"customer_data_access": map[string]string{"olt_user_id": "1001"}}}
	client := &fakeOLT{data: map[string]any{"customer_orders": map[string]any{"orders": []any{}, "next_cursor": nil}}}
	code, _ := do(t, newServer(api, client), "GET", "/v1/me/orders?status=rejected,open&code=bbca&limit=10",
		agentToken(t, time.Now().Add(time.Minute)), "")
	if code != 200 || api.calls[0].args["p_kind"] != "orders" {
		t.Fatalf("%d %+v", code, api.calls)
	}
	p := client.calls[0].payload
	if p["user_id"] != "1001" || p["code"] != "BBCA" || p["limit"] != 10 || len(p["status"].([]string)) != 2 {
		t.Fatalf("filter tidak diteruskan dengan benar: %v", p)
	}
	if _, ok := p["correlation_id"]; ok {
		t.Fatal("akses nasabah sendiri tidak membawa ID korelasi agen")
	}
}

func TestRevealIsAuthorizedFirst(t *testing.T) {
	api := &fakeAPI{responses: map[string]any{"agent_reveal_access": map[string]any{
		"olt_user_id": "1001", "correlation_id": session + "/CS-0001", "valid_seconds": 300}}}
	client := &fakeOLT{data: map[string]any{"customer_reveal": map[string]string{"field": "phone", "value": "081234567789"}}}
	code, body := do(t, newServer(api, client), "POST", "/v1/agent/sessions/"+session+"/customer/reveal",
		agentToken(t, time.Now().Add(time.Minute)), `{"field":"phone","reason":"identity_verification"}`)
	data, _ := body["data"].(map[string]any)
	if code != 200 || data["value"] != "081234567789" || data["valid_seconds"] != float64(300) {
		t.Fatalf("%d %v", code, body)
	}
	if api.calls[0].args["p_session_id"] != session || api.calls[0].args["p_field"] != "phone" ||
		api.calls[0].args["p_reason"] != "identity_verification" {
		t.Fatalf("alasan tidak diteruskan ke database: %v", api.calls[0].args)
	}
}

func TestMaskingIsIdempotent(t *testing.T) {
	cases := map[string]func(string) string{"nik": profileMasks["nik"], "email": maskEmail, "address": maskAddress, "ip": maskIP}
	inputs := map[string]string{"nik": "3174012501900001", "email": "budi@olt.test", "address": "Jl. A, Bandung", "ip": "182.1.20.33"}
	for name, mask := range cases {
		once := mask(inputs[name])
		if once == inputs[name] || mask(once) != once {
			t.Errorf("%s: %q -> %q -> %q", name, inputs[name], once, mask(once))
		}
	}
	if keepEdges(4, 4)("12345") != "*****" {
		t.Error("nilai pendek harus tersamar seluruhnya")
	}
	if maskEmail("a@x.id") != "***@x.id" {
		t.Errorf("email satu huruf: %s", maskEmail("a@x.id"))
	}
}

func TestSecureAccountRecordsOutcome(t *testing.T) {
	grant := map[string]any{"olt_user_id": "1001", "actions": []string{"logout_all", "lock_trading"},
		"idempotency_key": "cs-secure:" + session, "correlation_id": session + "/CS-0001"}
	cases := []struct {
		name    string
		results map[string]string
		err     error
		status  int
		ok      any
	}{
		{"semua berhasil", map[string]string{"logout_all": "OK", "lock_trading": "OK"}, nil, 200, true},
		{"sebagian gagal", map[string]string{"logout_all": "OK", "lock_trading": "FAILED"}, nil, 200, false},
		{"ditolak OLT", nil, &olt.Error{Code: "NOT_FOUND"}, 200, false},
		{"OLT mati", nil, olt.ErrUnavailable, 503, nil},
	}
	for _, c := range cases {
		api := &fakeAPI{responses: map[string]any{"agent_secure_account": grant}}
		client := &fakeOLT{err: c.err, data: map[string]any{"secure_account": map[string]any{"results": c.results}}}
		code, body := do(t, newServer(api, client), "POST", "/v1/agent/sessions/"+session+"/customer/secure-account",
			agentToken(t, time.Now().Add(time.Minute)), "")
		if code != c.status {
			t.Errorf("%s: %d %v", c.name, code, body)
		}
		var reported any
		for _, call := range api.calls {
			if call.fn == "agent_secure_account_result" {
				reported = call.args["p_ok"]
			}
		}
		if reported != c.ok {
			t.Errorf("%s: dicatat %v, ingin %v", c.name, reported, c.ok)
		}
		if client.calls[0].payload["idempotency_key"] != "cs-secure:"+session {
			t.Errorf("%s: kunci idempoten tidak dikirim", c.name)
		}
	}

	denied := &fakeAPI{errs: map[string]error{"agent_secure_account": &postgrest.Error{Status: 403, Code: "not_handling"}}}
	client := &fakeOLT{}
	code, _ := do(t, newServer(denied, client), "POST", "/v1/agent/sessions/"+session+"/customer/secure-account",
		agentToken(t, time.Now().Add(time.Minute)), "")
	if code != 403 || len(client.calls) != 0 {
		t.Fatalf("agen yang tidak menangani sesi tidak boleh mengamankan akun: %d, OLT %d", code, len(client.calls))
	}
}
