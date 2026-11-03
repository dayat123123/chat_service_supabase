package store

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"

	"olt-social/classifier/internal/heartbeat"
)

func TestHeartbeatCallsServiceHeartbeat(t *testing.T) {
	var args map[string]any
	var headers http.Header
	var path string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path, headers = r.URL.Path, r.Header.Clone()
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &args)
		w.WriteHeader(http.StatusNoContent)
	}))
	defer srv.Close()
	p := NewPostgREST(srv.URL, []byte(strings.Repeat("s", 40)), "supabase")
	p.now = func() time.Time { return time.Unix(1_800_000_000, 0) }
	started := time.Date(2026, 11, 3, 8, 0, 0, 0, time.FixedZone("WIB", 7*3600))

	for _, tc := range []struct {
		errorText string
		want      any
	}{{"", nil}, {"Storage tidak bisa dihubungi (3 kali berturut-turut)", "Storage tidak bisa dihubungi (3 kali berturut-turut)"}} {
		err := p.Heartbeat(context.Background(), heartbeat.Beat{
			Service: "classifier", Instance: "classifier-1", Version: "0.1.0", StartedAt: started, Status: "ok", Error: tc.errorText,
			Detail: map[string]any{"accepted": uint64(2), "rejected": uint64(1), "metadata_removed": uint64(1)},
		})
		if err != nil {
			t.Fatal(err)
		}
		want := map[string]any{
			"p_service": "classifier", "p_instance": "classifier-1", "p_version": "0.1.0", "p_started_at": "2026-11-03T01:00:00Z",
			"p_status": "ok", "p_error": tc.want,
			"p_detail": map[string]any{"accepted": float64(2), "rejected": float64(1), "metadata_removed": float64(1)},
		}
		if path != "/rpc/service_heartbeat" || !reflect.DeepEqual(args, want) {
			t.Fatalf("%s %v", path, args)
		}
	}
	if headers.Get("Content-Profile") != "public" || headers.Get("Content-Type") != "application/json" {
		t.Fatalf("headers = %v", headers)
	}
	tok, _ := strings.CutPrefix(headers.Get("Authorization"), "Bearer ")
	raw, _ := base64.RawURLEncoding.DecodeString(strings.Split(tok, ".")[1])
	var claims map[string]any
	_ = json.Unmarshal(raw, &claims)
	if claims["role"] != "service_role" || claims["exp"] != float64(1_800_000_060) {
		t.Fatalf("claims = %v", claims)
	}
}

func TestHeartbeatSendsAnEmptyDetailObject(t *testing.T) {
	var args map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewDecoder(r.Body).Decode(&args)
		_, _ = w.Write([]byte("null"))
	}))
	defer srv.Close()
	if err := NewPostgREST(srv.URL, []byte("k"), "supabase").Heartbeat(context.Background(), heartbeat.Beat{Status: "ok"}); err != nil {
		t.Fatal(err)
	}
	if detail, ok := args["p_detail"].(map[string]any); !ok || len(detail) != 0 {
		t.Fatalf("p_detail = %v", args["p_detail"])
	}
}

func TestHeartbeatReportsPostgRESTErrors(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(`{"code":"PGRST202","message":"Could not find the function public.service_heartbeat","details":null,"hint":null}`))
	}))
	defer srv.Close()
	err := NewPostgREST(srv.URL, []byte("k"), "supabase").Heartbeat(context.Background(), heartbeat.Beat{})
	if err == nil || !strings.Contains(err.Error(), "status 404: PGRST202 Could not find the function") {
		t.Fatalf("err = %v", err)
	}
}
