package server

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"olt-social/dummy-olt/internal/tokens"
	"olt-social/dummy-olt/internal/users"
)

func newTestServer(t *testing.T, cfg Config) (*httptest.Server, *tokens.Issuer) {
	t.Helper()
	if cfg.TokenTTL == 0 {
		cfg.TokenTTL = time.Hour
	}
	if cfg.HeartbeatInterval == 0 {
		cfg.HeartbeatInterval = time.Hour
	}
	issuer := tokens.NewIssuer("rahasia-test")
	srv := httptest.NewServer(New(users.Default(), issuer, cfg, slog.New(slog.NewTextHandler(io.Discard, nil))).Handler())
	t.Cleanup(srv.Close)
	return srv, issuer
}

// wsCall membuka koneksi, memastikan welcome diterima, mengirim req, dan
// mengembalikan pesan pertama bertipe want.
func wsCall(t *testing.T, srv *httptest.Server, req map[string]any, want string) map[string]any {
	t.Helper()
	conn, _, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(srv.URL, "http")+"/ws", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	_ = conn.SetReadDeadline(time.Now().Add(5 * time.Second))

	var welcome map[string]any
	if err := conn.ReadJSON(&welcome); err != nil || welcome["type"] != "welcome" {
		t.Fatalf("pesan pertama harus welcome: %v %v", welcome, err)
	}
	if err := conn.WriteJSON(req); err != nil {
		t.Fatal(err)
	}
	for {
		var msg map[string]any
		if err := conn.ReadJSON(&msg); err != nil {
			t.Fatalf("menunggu %s: %v", want, err)
		}
		if msg["type"] == want {
			return msg
		}
	}
}

func login(method string, payload map[string]any) map[string]any {
	return map[string]any{"type": "login", "request_id": "r1", "method": method, "payload": payload}
}

func errCode(msg map[string]any) string {
	e, _ := msg["error"].(map[string]any)
	code, _ := e["code"].(string)
	return code
}

func TestPasswordLoginThenTokenLogin(t *testing.T) {
	srv, _ := newTestServer(t, Config{})

	res := wsCall(t, srv, login("password", map[string]any{"username": "BUDI_SANTOSO", "password": users.DefaultPassword}), "login_result")
	if res["status"] != "OK" || res["request_id"] != "r1" {
		t.Fatalf("login password: %v", res)
	}
	data := res["data"].(map[string]any)
	token := data["token"].(string)
	user := data["user"].(map[string]any)
	if user["id"] != float64(1001) || user["username"] != "budi_santoso" || user["full_name"] != "Budi Santoso" {
		t.Fatalf("user = %v", user)
	}

	res = wsCall(t, srv, login("token", map[string]any{"token": token}), "login_result")
	if res["status"] != "OK" || res["data"].(map[string]any)["user"].(map[string]any)["email"] != "budi@olt.test" {
		t.Fatalf("login token: %v", res)
	}
}

func TestLoginByEmailAndFailures(t *testing.T) {
	srv, issuer := newTestServer(t, Config{})

	if res := wsCall(t, srv, login("password", map[string]any{"email": "sari@olt.test", "password": users.DefaultPassword}), "login_result"); res["status"] != "OK" {
		t.Fatalf("login email: %v", res)
	}
	cases := map[string]struct {
		req  map[string]any
		code string
	}{
		"password salah":    {login("password", map[string]any{"username": "budi_santoso", "password": "salah"}), CodeInvalidCredentials},
		"akun tidak ada":    {login("password", map[string]any{"username": "tidak_ada", "password": users.DefaultPassword}), CodeInvalidCredentials},
		"akun ditangguhkan": {login("password", map[string]any{"username": "akun_suspend", "password": users.DefaultPassword}), CodeAccountSuspended},
		"token sembarang":   {login("token", map[string]any{"token": "olt_x.y"}), CodeInvalidToken},
		"method salah":      {login("sms", nil), CodeBadRequest},
	}
	for name, c := range cases {
		res := wsCall(t, srv, c.req, "login_result")
		if res["status"] != "FAILED" || errCode(res) != c.code {
			t.Errorf("%s: %v, want %s", name, res, c.code)
		}
	}

	suspendedToken, _, _ := issuer.Issue("1009", time.Hour)
	if res := wsCall(t, srv, login("token", map[string]any{"token": suspendedToken}), "login_result"); errCode(res) != CodeAccountSuspended {
		t.Errorf("token akun ditangguhkan: %v", res)
	}
	expired, _, _ := issuer.Issue("1001", -time.Minute)
	if res := wsCall(t, srv, login("token", map[string]any{"token": expired}), "login_result"); errCode(res) != CodeTokenExpired {
		t.Errorf("token kedaluwarsa: %v", res)
	}
}

func TestLogoutRevokesToken(t *testing.T) {
	srv, issuer := newTestServer(t, Config{})
	token, _, _ := issuer.Issue("1002", time.Hour)

	res := wsCall(t, srv, map[string]any{"type": "logout", "request_id": "r2", "payload": map[string]any{"token": token}}, "logout_result")
	if res["status"] != "OK" {
		t.Fatalf("logout: %v", res)
	}
	if res := wsCall(t, srv, login("token", map[string]any{"token": token}), "login_result"); errCode(res) != CodeTokenRevoked {
		t.Fatalf("token setelah logout: %v", res)
	}
}

func TestMockTokens(t *testing.T) {
	on, _ := newTestServer(t, Config{AcceptMockTokens: true})
	res := wsCall(t, on, login("token", map[string]any{"token": "mock:1001:budi_santoso"}), "login_result")
	if res["status"] != "OK" || res["data"].(map[string]any)["user"].(map[string]any)["full_name"] != "Budi Santoso" {
		t.Fatalf("mock token diizinkan: %v", res)
	}
	res = wsCall(t, on, login("token", map[string]any{"token": "mock:abc:user_baru:User Baru"}), "login_result")
	if user := res["data"].(map[string]any)["user"].(map[string]any); user["id"] != "abc" || user["full_name"] != "User Baru" {
		t.Fatalf("mock token user baru: %v", res)
	}

	off, _ := newTestServer(t, Config{AcceptMockTokens: false})
	if res := wsCall(t, off, login("token", map[string]any{"token": "mock:1001:budi_santoso"}), "login_result"); errCode(res) != CodeInvalidToken {
		t.Fatalf("mock token dimatikan: %v", res)
	}
}

func TestSlowAccount(t *testing.T) {
	srv, issuer := newTestServer(t, Config{SlowDelay: 300 * time.Millisecond})
	token, _, _ := issuer.Issue("1010", time.Hour)
	start := time.Now()
	res := wsCall(t, srv, login("token", map[string]any{"token": token}), "login_result")
	if res["status"] != "OK" || time.Since(start) < 300*time.Millisecond {
		t.Fatalf("akun lambat harus menunggu SlowDelay: %v (%v)", res, time.Since(start))
	}
}

func TestHeartbeatAndPing(t *testing.T) {
	srv, _ := newTestServer(t, Config{HeartbeatInterval: 50 * time.Millisecond})
	conn, _, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(srv.URL, "http")+"/ws", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	_ = conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	_ = conn.WriteJSON(map[string]any{"type": "ping"})
	seen := map[string]bool{}
	for !(seen["heartbeat"] && seen["pong"]) {
		var msg map[string]any
		if err := conn.ReadJSON(&msg); err != nil {
			t.Fatalf("seen=%v err=%v", seen, err)
		}
		seen[msg["type"].(string)] = true
	}
}

func TestHTTPHelpers(t *testing.T) {
	srv, _ := newTestServer(t, Config{})
	post := func(path, body string) (int, map[string]any) {
		resp, err := http.Post(srv.URL+path, "application/json", bytes.NewBufferString(body))
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		var out map[string]any
		_ = json.NewDecoder(resp.Body).Decode(&out)
		return resp.StatusCode, out
	}

	status, out := post("/api/login", `{"username":"andi_trader","password":"olt12345"}`)
	if status != 200 || !strings.HasPrefix(out["token"].(string), tokens.Prefix) {
		t.Fatalf("login HTTP: %d %v", status, out)
	}
	if status, _ := post("/api/login", `{"username":"andi_trader","password":"salah"}`); status != 401 {
		t.Errorf("password salah: %d", status)
	}
	if status, _ := post("/api/login", `{"username":"akun_suspend","password":"olt12345"}`); status != 403 {
		t.Errorf("akun ditangguhkan: %d", status)
	}
	status, out = post("/api/dev/token", `{"user":"akun_suspend","ttl":"-1m"}`)
	if status != 200 || out["user"].(map[string]any)["id"] != float64(1009) {
		t.Errorf("dev token: %d %v", status, out)
	}
	if status, _ := post("/api/logout", `{"token":"bukan-token"}`); status != 400 {
		t.Errorf("logout token rusak: %d", status)
	}
}
