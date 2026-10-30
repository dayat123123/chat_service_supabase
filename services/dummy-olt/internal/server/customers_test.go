package server

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

const customerToken = "token-layanan-nasabah-uji"

func serviceCall(t *testing.T, srv *httptest.Server, credential string, kind string, payload map[string]any) map[string]any {
	t.Helper()
	header := http.Header{}
	if credential != "" {
		header.Set("Authorization", "Bearer "+credential)
	}
	conn, _, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(srv.URL, "http")+"/ws", header)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	_ = conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	if err := conn.WriteJSON(map[string]any{"v": 1, "type": kind, "request_id": "r1", "payload": payload}); err != nil {
		t.Fatal(err)
	}
	for {
		var msg map[string]any
		if err := conn.ReadJSON(&msg); err != nil {
			t.Fatalf("menunggu %s_result: %v", kind, err)
		}
		if msg["type"] == kind+"_result" && msg["request_id"] == "r1" {
			return msg
		}
	}
}

func errorCode(msg map[string]any) string {
	if e, ok := msg["error"].(map[string]any); ok {
		return e["code"].(string)
	}
	return ""
}

func TestCustomerDataNeedsServiceCredential(t *testing.T) {
	srv, _ := newTestServer(t, Config{CustomerToken: customerToken})
	for _, credential := range []string{"", "token-salah"} {
		msg := serviceCall(t, srv, credential, "customer_profile", map[string]any{"user_id": "1001"})
		if msg["status"] != "ERROR" || errorCode(msg) != CodeUnauthorized {
			t.Fatalf("kredensial %q harus ditolak: %v", credential, msg)
		}
	}
	unset, _ := newTestServer(t, Config{})
	if msg := serviceCall(t, unset, customerToken, "customer_profile", map[string]any{"user_id": "1001"}); errorCode(msg) != CodeUnauthorized {
		t.Fatalf("tanpa token terkonfigurasi semua ditolak: %v", msg)
	}
}

func TestProfileIsMaskedAndRevealReturnsOneField(t *testing.T) {
	srv, _ := newTestServer(t, Config{CustomerToken: customerToken})
	msg := serviceCall(t, srv, customerToken, "customer_profile", map[string]any{"user_id": "1001", "correlation_id": "CC-1/CS-0001"})
	data := msg["data"].(map[string]any)
	if data["name"] != "Budi Santoso" || !strings.Contains(data["nik"].(string), "********") ||
		!strings.HasPrefix(data["email"].(string), "bu***@") || data["rdn"].(map[string]any)["number"] == "8800031031" {
		t.Fatalf("profil harus tersamar secara default: %v", data)
	}
	reveal := serviceCall(t, srv, customerToken, "customer_reveal", map[string]any{"user_id": "1001", "field": "phone"})
	if v := reveal["data"].(map[string]any)["value"].(string); strings.Contains(v, "*") || !strings.HasPrefix(v, "0812") {
		t.Fatalf("reveal harus memberi nilai asli satu field: %v", reveal)
	}
	if msg := serviceCall(t, srv, customerToken, "customer_reveal", map[string]any{"user_id": "1001", "field": "pin"}); errorCode(msg) != CodeInvalidRequest {
		t.Fatalf("field rahasia tidak bisa dibuka: %v", msg)
	}
	if msg := serviceCall(t, srv, customerToken, "customer_profile", map[string]any{"user_id": "9999"}); errorCode(msg) != CodeNotFound {
		t.Fatalf("nasabah tidak dikenal: %v", msg)
	}
}

func TestOrdersFilterPaginateAndDetail(t *testing.T) {
	srv, _ := newTestServer(t, Config{CustomerToken: customerToken})
	all := serviceCall(t, srv, customerToken, "customer_orders", map[string]any{"user_id": "1001", "limit": 4})
	page := all["data"].(map[string]any)
	if len(page["orders"].([]any)) != 4 || page["next_cursor"] != "4" {
		t.Fatalf("halaman pertama: %v", page)
	}
	rejected := serviceCall(t, srv, customerToken, "customer_orders", map[string]any{"user_id": "1001", "status": []string{"rejected"}})
	orders := rejected["data"].(map[string]any)["orders"].([]any)
	if len(orders) == 0 {
		t.Fatal("harus ada order ditolak")
	}
	first := orders[0].(map[string]any)
	if first["status"] != "rejected" || first["reject_code"] == "" {
		t.Fatalf("order ditolak harus membawa kode: %v", first)
	}
	detail := serviceCall(t, srv, customerToken, "customer_order", map[string]any{"user_id": "1001", "order_id": first["order_id"]})
	if detail["data"].(map[string]any)["history"] == nil {
		t.Fatalf("detail order membawa riwayat: %v", detail)
	}
	if msg := serviceCall(t, srv, customerToken, "customer_order", map[string]any{"user_id": "1001", "order_id": "O-0"}); errorCode(msg) != CodeNotFound {
		t.Fatalf("order tidak ada: %v", msg)
	}
	if msg := serviceCall(t, srv, customerToken, "customer_orders", map[string]any{"user_id": "1001", "from": "kemarin"}); errorCode(msg) != CodeInvalidRequest {
		t.Fatalf("tanggal tidak valid: %v", msg)
	}
	txs := serviceCall(t, srv, customerToken, "customer_cash_transactions", map[string]any{"user_id": "1001"})
	list := txs["data"].(map[string]any)["transactions"].([]any)
	id := list[0].(map[string]any)["id"]
	if one := serviceCall(t, srv, customerToken, "customer_cash_transaction", map[string]any{"user_id": "1001", "transaction_id": id}); one["status"] != "OK" {
		t.Fatalf("detail transaksi: %v", one)
	}
}

func TestSecureAccountIsIdempotent(t *testing.T) {
	srv, _ := newTestServer(t, Config{CustomerToken: customerToken})
	payload := map[string]any{"user_id": "1002", "actions": []string{"logout_all", "lock_trading"}, "idempotency_key": "T1"}
	first := serviceCall(t, srv, customerToken, "secure_account", payload)
	results := first["data"].(map[string]any)["results"].(map[string]any)
	if results["logout_all"] != "OK" || results["lock_trading"] != "OK" {
		t.Fatalf("aksi darurat: %v", first)
	}
	security := serviceCall(t, srv, customerToken, "customer_security", map[string]any{"user_id": "1002"})
	if security["data"].(map[string]any)["trading_locked"] != true {
		t.Fatalf("transaksi harus terkunci: %v", security)
	}
	sessions := serviceCall(t, srv, customerToken, "customer_sessions", map[string]any{"user_id": "1002"})
	if s := sessions["data"].(map[string]any)["sessions"]; s != nil && len(s.([]any)) != 0 {
		t.Fatalf("semua sesi harus keluar: %v", s)
	}
	again := serviceCall(t, srv, customerToken, "secure_account", payload)
	if again["data"].(map[string]any)["results"].(map[string]any)["lock_trading"] != "OK" {
		t.Fatalf("permintaan ulang dengan kunci yang sama memberi hasil yang sama: %v", again)
	}
}
