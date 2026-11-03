package server

import (
	"bytes"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"

	"olt-social/dummy-olt/internal/users"
)

func socialClaims(t *testing.T, token string) map[string]any {
	t.Helper()
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Fatalf("token sosial bukan JWT: %q", token)
	}
	sig, _ := base64.RawURLEncoding.DecodeString(parts[2])
	if !ed25519.Verify(testSigningKey.Public().(ed25519.PublicKey), []byte(parts[0]+"."+parts[1]), sig) {
		t.Fatal("tanda tangan token sosial tidak valid")
	}
	raw, _ := base64.RawURLEncoding.DecodeString(parts[1])
	var claims map[string]any
	if err := json.Unmarshal(raw, &claims); err != nil {
		t.Fatal(err)
	}
	return claims
}

func postJSON(t *testing.T, srv *httptest.Server, path string, body any) (int, map[string]any) {
	t.Helper()
	b, _ := json.Marshal(body)
	resp, err := http.Post(srv.URL+path, "application/json", bytes.NewReader(b))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp.StatusCode, out
}

func TestLoginReturnsASocialTokenForTheUser(t *testing.T) {
	srv, _ := newTestServer(t, Config{})
	status, body := postJSON(t, srv, "/api/login", map[string]any{"username": "budi_santoso", "password": users.DefaultPassword})
	if status != http.StatusOK {
		t.Fatalf("status = %d, body = %v", status, body)
	}
	claims := socialClaims(t, body["social_token"].(string))
	if claims["sub"] != "1001" || claims["preferred_username"] != "budi_santoso" || claims["aud"] != "olt-social" ||
		claims["name"] != "Budi Santoso" || claims["email"] != "budi@olt.test" {
		t.Fatalf("claims = %v", claims)
	}
	if body["social_token_expires_at"] == "" {
		t.Fatalf("social_token_expires_at kosong: %v", body)
	}

	res := wsCall(t, srv, login("password", map[string]any{"username": "sari_invest", "password": users.DefaultPassword}), "login_result")
	data := res["data"].(map[string]any)
	if socialClaims(t, data["social_token"].(string))["sub"] != "1002" {
		t.Fatalf("login WebSocket tanpa token sosial yang benar: %v", data)
	}
}

func TestSocialTokenEndpointRenewsTokensForAnActiveSession(t *testing.T) {
	srv, issuer := newTestServer(t, Config{})
	session, _, _ := issuer.Issue("1003", 0)
	status, body := postJSON(t, srv, "/api/social-token", map[string]any{"token": session})
	if status != http.StatusUnauthorized {
		t.Fatalf("sesi kedaluwarsa harus ditolak, status = %d", status)
	}

	session, _, _ = issuer.Issue("1003", 3600_000_000_000)
	status, body = postJSON(t, srv, "/api/social-token", map[string]any{"token": session})
	if status != http.StatusOK || socialClaims(t, body["token"].(string))["sub"] != "1003" || body["expires_at"] == "" {
		t.Fatalf("status = %d, body = %v", status, body)
	}

	res := wsCall(t, srv, map[string]any{"type": "social_token", "request_id": "s1", "payload": map[string]any{"token": session}}, "social_token_result")
	if res["status"] != "OK" || res["request_id"] != "s1" {
		t.Fatalf("social_token via WebSocket: %v", res)
	}
	if socialClaims(t, res["data"].(map[string]any)["token"].(string))["sub"] != "1003" {
		t.Fatalf("token sosial salah: %v", res)
	}
}

func TestSocialTokenIsRefusedForSuspendedOrInvalidSessions(t *testing.T) {
	srv, issuer := newTestServer(t, Config{})
	suspended, _, _ := issuer.Issue("1009", 3600_000_000_000)
	status, body := postJSON(t, srv, "/api/social-token", map[string]any{"token": suspended})
	if status != http.StatusForbidden || errCode(body) != CodeAccountSuspended {
		t.Fatalf("akun ditangguhkan: status = %d, body = %v", status, body)
	}
	status, body = postJSON(t, srv, "/api/social-token", map[string]any{"token": "olt_palsu.abc"})
	if status != http.StatusUnauthorized || errCode(body) != CodeInvalidToken {
		t.Fatalf("token palsu: status = %d, body = %v", status, body)
	}
}

func TestSocialTokenConvertsMockTokensWhenAllowed(t *testing.T) {
	srv, _ := newTestServer(t, Config{AcceptMockTokens: true})
	status, body := postJSON(t, srv, "/api/social-token", map[string]any{"token": "mock:2001:uji_baru:Uji Baru"})
	if status != http.StatusOK {
		t.Fatalf("status = %d, body = %v", status, body)
	}
	claims := socialClaims(t, body["token"].(string))
	if claims["sub"] != "2001" || claims["preferred_username"] != "uji_baru" || claims["name"] != "Uji Baru" {
		t.Fatalf("claims = %v", claims)
	}

	strict, _ := newTestServer(t, Config{})
	if status, _ := postJSON(t, strict, "/api/social-token", map[string]any{"token": "mock:2001:uji_baru"}); status != http.StatusUnauthorized {
		t.Fatalf("token mock harus ditolak bila tidak diizinkan, status = %d", status)
	}
}

func TestDevTokenCanIssueSocialTokensForTests(t *testing.T) {
	srv, _ := newTestServer(t, Config{})
	status, body := postJSON(t, srv, "/api/dev/token", map[string]any{"user": "akun_suspend", "kind": "social", "ttl": "-1m", "audience": "olt-trading"})
	if status != http.StatusOK {
		t.Fatalf("status = %d, body = %v", status, body)
	}
	claims := socialClaims(t, body["token"].(string))
	if claims["sub"] != "1009" || claims["aud"] != "olt-trading" {
		t.Fatalf("claims = %v", claims)
	}
}

func TestSocialTokenCarriesTheAccountsOwnedByTheLogin(t *testing.T) {
	srv, _ := newTestServer(t, Config{AcceptMockTokens: true})
	cases := map[string]struct {
		login map[string]any
		want  any
	}{
		"nasabah dengan dua rekening":  {map[string]any{"username": "budi_santoso", "password": users.DefaultPassword}, []any{"W137", "C1626"}},
		"nasabah dengan satu rekening": {map[string]any{"email": "sari@olt.test", "password": users.DefaultPassword}, []any{"S2001"}},
		"login tanpa rekening":         {map[string]any{"username": "olt_official", "password": users.DefaultPassword}, []any{}},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			status, body := postJSON(t, srv, "/api/login", tc.login)
			if status != http.StatusOK {
				t.Fatalf("status = %d, body = %v", status, body)
			}
			if got := socialClaims(t, body["social_token"].(string))["accounts"]; !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("accounts = %#v, want %#v", got, tc.want)
			}
		})
	}

	status, body := postJSON(t, srv, "/api/social-token", map[string]any{"token": "mock:2001:uji_baru"})
	if status != http.StatusOK {
		t.Fatalf("status = %d", status)
	}
	if _, present := socialClaims(t, body["token"].(string))["accounts"]; present {
		t.Fatal("user di luar direktori dummy tidak membawa klaim accounts (seperti OLT lama)")
	}
}

func TestDevTokenCanOverrideAccounts(t *testing.T) {
	srv, _ := newTestServer(t, Config{})
	status, body := postJSON(t, srv, "/api/dev/token", map[string]any{"user": "budi_santoso", "kind": "social", "accounts": []string{"X9"}})
	if status != http.StatusOK || !reflect.DeepEqual(socialClaims(t, body["token"].(string))["accounts"], []any{"X9"}) {
		t.Fatalf("status = %d, body = %v", status, body)
	}
	status, body = postJSON(t, srv, "/api/dev/token", map[string]any{"user": "budi_santoso", "kind": "social", "accounts": nil})
	if _, present := socialClaims(t, body["token"].(string))["accounts"]; status != http.StatusOK || present {
		t.Fatalf("accounts null harus menghilangkan klaim: status = %d", status)
	}
	if status, _ := postJSON(t, srv, "/api/dev/token", map[string]any{"user": "budi_santoso", "kind": "social", "accounts": "W137"}); status != http.StatusBadRequest {
		t.Fatalf("accounts bukan array harus ditolak, status = %d", status)
	}
	status, body = postJSON(t, srv, "/api/dev/token", map[string]any{"user": "budi_santoso", "kind": "social"})
	if status != http.StatusOK || !reflect.DeepEqual(socialClaims(t, body["token"].(string))["accounts"], []any{"W137", "C1626"}) {
		t.Fatalf("tanpa accounts harus memakai rekening direktori: status = %d", status)
	}
}

func TestUsersListShowsAccounts(t *testing.T) {
	srv, _ := newTestServer(t, Config{})
	resp, err := http.Get(srv.URL + "/api/users")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var out struct {
		Users []struct {
			Username string   `json:"username"`
			Accounts []string `json:"accounts"`
		} `json:"users"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		t.Fatal(err)
	}
	for _, u := range out.Users {
		if u.Accounts == nil {
			t.Fatalf("%s: accounts harus array (boleh kosong)", u.Username)
		}
		if u.Username == "budi_santoso" && !reflect.DeepEqual(u.Accounts, []string{"W137", "C1626"}) {
			t.Fatalf("budi accounts = %v", u.Accounts)
		}
	}
}
