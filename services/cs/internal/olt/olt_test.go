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

	"olt-social/cs/internal/breaker"
)

type request struct {
	V         int             `json:"v"`
	Type      string          `json:"type"`
	RequestID string          `json:"request_id"`
	Payload   json.RawMessage `json:"payload"`
}

func server(t *testing.T, handle func(conn *websocket.Conn, req request)) string {
	t.Helper()
	upgrader := websocket.Upgrader{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer rahasia-layanan" {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		defer conn.Close()
		_ = conn.WriteJSON(map[string]any{"type": "welcome"})
		var req request
		if err := conn.ReadJSON(&req); err != nil {
			return
		}
		handle(conn, req)
		_, _, _ = conn.ReadMessage()
	}))
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http")
}

func client(url string, threshold int) *Client {
	return New(Config{URL: url, Token: "rahasia-layanan", Timeout: 500 * time.Millisecond}, breaker.New(threshold, time.Minute))
}

func TestCallSuccessIgnoresOtherMessages(t *testing.T) {
	url := server(t, func(conn *websocket.Conn, req request) {
		if req.V != 1 || req.Type != "customer_profile" || !strings.Contains(string(req.Payload), `"user_id":"1001"`) {
			t.Errorf("request salah: %+v %s", req, req.Payload)
		}
		_ = conn.WriteJSON(map[string]any{"type": "heartbeat"})
		_ = conn.WriteJSON(map[string]any{"type": "customer_profile_result", "request_id": "lain", "status": "OK"})
		_ = conn.WriteJSON(map[string]any{"type": "customer_profile_result", "request_id": req.RequestID, "status": "OK",
			"data": map[string]any{"name": "Budi"}})
	})
	var out struct {
		Name string `json:"name"`
	}
	if err := client(url, 1).Call(context.Background(), "customer_profile", map[string]any{"user_id": "1001"}, &out); err != nil {
		t.Fatal(err)
	}
	if out.Name != "Budi" {
		t.Fatalf("data: %+v", out)
	}
}

func TestProtocolErrorsAreNotOutages(t *testing.T) {
	url := server(t, func(conn *websocket.Conn, req request) {
		_ = conn.WriteJSON(map[string]any{"type": req.Type + "_result", "request_id": req.RequestID, "status": "ERROR",
			"error": map[string]string{"code": "NOT_FOUND", "message": "order tidak ada"}})
	})
	c := client(url, 1)
	for i := 0; i < 3; i++ {
		err := c.Call(context.Background(), "customer_order", map[string]any{}, nil)
		if !IsCode(err, "NOT_FOUND") {
			t.Fatalf("percobaan %d: dapat %v", i, err)
		}
	}
	if c.breaker.State() != breaker.Closed {
		t.Fatal("NOT_FOUND tidak boleh membuka circuit breaker")
	}
}

func TestTransientErrorsOpenBreaker(t *testing.T) {
	url := server(t, func(conn *websocket.Conn, req request) {
		_ = conn.WriteJSON(map[string]any{"type": req.Type + "_result", "request_id": req.RequestID, "status": "ERROR",
			"error": map[string]string{"code": "RATE_LIMITED", "message": "pelan-pelan"}})
	})
	c := client(url, 2)
	for i := 0; i < 2; i++ {
		if err := c.Call(context.Background(), "customer_orders", map[string]any{}, nil); !errors.Is(err, ErrUnavailable) {
			t.Fatalf("RATE_LIMITED harus dianggap tidak tersedia: %v", err)
		}
	}
	if err := c.Call(context.Background(), "customer_orders", map[string]any{}, nil); !errors.Is(err, ErrUnavailable) ||
		!strings.Contains(err.Error(), "circuit breaker") {
		t.Fatalf("breaker harus terbuka: %v", err)
	}
}

func TestTimeoutAndRejectedCredential(t *testing.T) {
	slow := server(t, func(*websocket.Conn, request) { time.Sleep(time.Second) })
	if err := client(slow, 5).Call(context.Background(), "customer_security", map[string]any{}, nil); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("timeout harus tidak tersedia: %v", err)
	}
	wrong := New(Config{URL: slow, Token: "salah", Timeout: time.Second}, breaker.New(5, time.Minute))
	if err := wrong.Call(context.Background(), "customer_security", map[string]any{}, nil); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("kredensial ditolak saat handshake: %v", err)
	}
	if err := New(Config{}, breaker.New(1, time.Minute)).Call(context.Background(), "x", nil, nil); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("tanpa URL harus tidak tersedia: %v", err)
	}
}

func TestUnknownTypeErrorIsReturned(t *testing.T) {
	url := server(t, func(conn *websocket.Conn, req request) {
		_ = conn.WriteJSON(map[string]any{"type": "error", "request_id": req.RequestID,
			"error": map[string]string{"code": "UNKNOWN_TYPE", "message": "type tidak dikenal"}})
	})
	if err := client(url, 1).Call(context.Background(), "customer_portfolio", map[string]any{}, nil); !IsCode(err, "UNKNOWN_TYPE") {
		t.Fatalf("dapat %v", err)
	}
}
