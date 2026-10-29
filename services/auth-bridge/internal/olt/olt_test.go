package olt

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"olt-social/auth-bridge/internal/config"
)

func TestMockVerifier(t *testing.T) {
	u, err := MockVerifier{}.Verify(context.Background(), "mock:1001:budi_santoso:Budi Santoso")
	if err != nil {
		t.Fatal(err)
	}
	if u.ID != "1001" || u.Username != "budi_santoso" || u.DisplayName != "Budi Santoso" {
		t.Fatalf("user = %+v", u)
	}
	for _, bad := range []string{"", "mock:", "mock:1001", "mock::budi", "real:1001:budi"} {
		if _, err := (MockVerifier{}).Verify(context.Background(), bad); !errors.Is(err, ErrInvalidToken) {
			t.Errorf("token %q harus ditolak, err = %v", bad, err)
		}
	}
}

func TestLookup(t *testing.T) {
	doc, _ := decodeJSON([]byte(`{"data":{"user":{"id":12345678901234567890,"name":"Budi","ok":true,"none":null},"list":[{"id":"x"}]}}`))
	cases := map[string]struct {
		want string
		ok   bool
	}{
		"data.user.id":   {"12345678901234567890", true}, // angka besar tidak kehilangan presisi
		"data.user.name": {"Budi", true},
		"data.user.ok":   {"true", true},
		"data.list.0.id": {"x", true},
		"data.user.none": {"", false},
		"data.missing":   {"", false},
		"data.list.9.id": {"", false},
		"":               {"", false},
	}
	for path, c := range cases {
		got, ok := Lookup(doc, path)
		if got != c.want || ok != c.ok {
			t.Errorf("Lookup(%q) = %q,%v want %q,%v", path, got, ok, c.want, c.ok)
		}
	}
}

// fakeOLT adalah server WebSocket OLT tiruan.
func fakeOLT(t *testing.T, handle func(conn *websocket.Conn, login map[string]any)) *httptest.Server {
	t.Helper()
	upgrader := websocket.Upgrader{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		defer conn.Close()
		var login map[string]any
		if err := conn.ReadJSON(&login); err != nil {
			return
		}
		handle(conn, login)
		// Tunggu client menutup koneksi.
		_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
		_, _, _ = conn.ReadMessage()
	}))
	t.Cleanup(srv.Close)
	return srv
}

func wsConfig(url string) config.OLTConfig {
	return config.OLTConfig{
		Mode:               config.OLTModeWebSocket,
		WebSocketURL:       "ws" + strings.TrimPrefix(url, "http"),
		Timeout:            2 * time.Second,
		LoginTemplate:      `{"type":"login","method":"token","payload":{"token":"{{token}}"}}`,
		ResponseMatchPath:  "type",
		ResponseMatchValue: "login_result",
		SuccessPath:        "status",
		SuccessValue:       "OK",
		ErrorMessagePath:   "error.message",
		UserIDPath:         "user.id",
		UsernamePath:       "user.username",
		EmailPath:          "user.email",
		DisplayNamePath:    "user.full_name",
	}
}

func TestWebSocketVerifierSuccess(t *testing.T) {
	const token = `abc"},"evil":"1`
	srv := fakeOLT(t, func(conn *websocket.Conn, login map[string]any) {
		payload, _ := login["payload"].(map[string]any)
		if login["type"] != "login" || payload["token"] != token || login["evil"] != nil {
			t.Errorf("pesan login tidak sesuai template: %v", login)
		}
		_ = conn.WriteMessage(websocket.TextMessage, []byte(`bukan json`))
		_ = conn.WriteJSON(map[string]any{"type": "heartbeat"})
		_ = conn.WriteJSON(map[string]any{
			"type":   "login_result",
			"status": "ok",
			"user":   map[string]any{"id": json.Number("1001"), "username": "budi", "email": "budi@olt.id", "full_name": "Budi S"},
		})
	})

	v, err := NewWebSocketVerifier(wsConfig(srv.URL))
	if err != nil {
		t.Fatal(err)
	}
	u, err := v.Verify(context.Background(), token)
	if err != nil {
		t.Fatal(err)
	}
	want := User{ID: "1001", Username: "budi", Email: "budi@olt.id", DisplayName: "Budi S"}
	if u != want {
		t.Fatalf("user = %+v, want %+v", u, want)
	}
}

func TestWebSocketVerifierRejected(t *testing.T) {
	srv := fakeOLT(t, func(conn *websocket.Conn, _ map[string]any) {
		_ = conn.WriteJSON(map[string]any{
			"type": "login_result", "status": "FAILED",
			"error": map[string]any{"message": "session expired"},
		})
	})
	v, _ := NewWebSocketVerifier(wsConfig(srv.URL))
	_, err := v.Verify(context.Background(), "token-lama")
	if !errors.Is(err, ErrInvalidToken) || !strings.Contains(err.Error(), "session expired") {
		t.Fatalf("err = %v, want ErrInvalidToken dengan alasan", err)
	}
}

func TestWebSocketVerifierTimeout(t *testing.T) {
	srv := fakeOLT(t, func(*websocket.Conn, map[string]any) {
		time.Sleep(800 * time.Millisecond) // tidak pernah menjawab sebelum timeout
	})
	cfg := wsConfig(srv.URL)
	cfg.Timeout = 300 * time.Millisecond
	v, _ := NewWebSocketVerifier(cfg)

	start := time.Now()
	_, err := v.Verify(context.Background(), "token")
	if !IsUnavailable(err) {
		t.Fatalf("err = %v, want ErrUnavailable", err)
	}
	if elapsed := time.Since(start); elapsed > time.Second {
		t.Fatalf("timeout tidak dihormati: %v", elapsed)
	}
}

func TestWebSocketVerifierUnreachable(t *testing.T) {
	cfg := wsConfig("http://127.0.0.1:1")
	cfg.Timeout = 500 * time.Millisecond
	v, _ := NewWebSocketVerifier(cfg)
	if _, err := v.Verify(context.Background(), "token"); !IsUnavailable(err) {
		t.Fatalf("err = %v, want ErrUnavailable", err)
	}
}
