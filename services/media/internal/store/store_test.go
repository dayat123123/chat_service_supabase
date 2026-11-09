package store

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"

	"olt-social/media/internal/heartbeat"
	"olt-social/media/internal/moderation"
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
			Service: "media", Instance: "media-1", Version: "0.1.0", StartedAt: started, Status: "ok", Error: tc.errorText,
			Detail: map[string]any{"accepted": uint64(2), "rejected": uint64(1), "metadata_removed": uint64(1)},
		})
		if err != nil {
			t.Fatal(err)
		}
		want := map[string]any{
			"p_service": "media", "p_instance": "media-1", "p_version": "0.1.0", "p_started_at": "2026-11-03T01:00:00Z",
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

func rpcServer(t *testing.T, status int, reply string, seen *map[string]any, path *string) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		*path = r.URL.Path
		*seen = nil
		_ = json.NewDecoder(r.Body).Decode(seen)
		w.WriteHeader(status)
		_, _ = w.Write([]byte(reply))
	}))
	t.Cleanup(srv.Close)
	return srv
}

func TestModerationConfig(t *testing.T) {
	var args map[string]any
	var path string
	srv := rpcServer(t, 200, `{"revision":4,"thresholds":{"porn":{"hold":0.45,"block":0.9},"sexy":{"hold":0.75}}}`, &args, &path)
	p := NewPostgREST(srv.URL, []byte(strings.Repeat("s", 40)), "supabase")
	cfg, err := p.ModerationConfig(context.Background(), moderation.UnknownRevision)
	if err != nil || path != "/rpc/media_moderation_config" || args["p_revision"] != nil || cfg.Revision != 4 ||
		*cfg.Limits["porn"].Hold != 0.45 || *cfg.Limits["porn"].Block != 0.9 || cfg.Limits["sexy"].Block != nil {
		t.Fatalf("cfg = %+v err = %v args = %v", cfg, err, args)
	}
	srv2 := rpcServer(t, 200, `{"revision":4,"unchanged":true}`, &args, &path)
	cfg, err = NewPostgREST(srv2.URL, []byte("k"), "supabase").ModerationConfig(context.Background(), 4)
	if err != nil || !cfg.Unchanged || args["p_revision"] != float64(4) {
		t.Fatalf("cfg = %+v err = %v args = %v", cfg, err, args)
	}
	srv3 := rpcServer(t, 200, `{"revision":5}`, &args, &path)
	if _, err := NewPostgREST(srv3.URL, []byte("k"), "supabase").ModerationConfig(context.Background(), 4); err == nil {
		t.Fatal("a reply without thresholds must fail")
	}
}

func TestRecordAndCancelHold(t *testing.T) {
	var args map[string]any
	var path string
	srv := rpcServer(t, 200, `41`, &args, &path)
	p := NewPostgREST(srv.URL, []byte("k"), "supabase")
	id, err := p.RecordHold(context.Background(), moderation.HoldRequest{
		Bucket: "attachments", Path: "posts/u/a.png", Uploader: "u", Model: "m@1",
		Scores: map[string]float64{"porn": 0.5}, Category: "porn", Score: 0.5, Revision: 3,
	})
	want := map[string]any{
		"p_bucket": "attachments", "p_name": "posts/u/a.png", "p_uploader": "u", "p_model": "m@1",
		"p_scores": map[string]any{"porn": 0.5}, "p_category": "porn", "p_score": 0.5, "p_revision": float64(3),
	}
	if err != nil || id != 41 || path != "/rpc/media_hold" || !reflect.DeepEqual(args, want) {
		t.Fatalf("id = %d err = %v args = %v", id, err, args)
	}
	srv2 := rpcServer(t, 200, `true`, &args, &path)
	if err := NewPostgREST(srv2.URL, []byte("k"), "supabase").CancelHold(context.Background(), 41); err != nil ||
		path != "/rpc/media_hold_cancel" || args["p_id"] != float64(41) {
		t.Fatalf("err = %v path = %s args = %v", err, path, args)
	}
	srv3 := rpcServer(t, 409, `{"code":"PT409","message":"already_exists","details":"x"}`, &args, &path)
	_, err = NewPostgREST(srv3.URL, []byte("k"), "supabase").RecordHold(context.Background(), moderation.HoldRequest{})
	var rpcErr *RPCError
	if !errors.As(err, &rpcErr) || rpcErr.Status != 409 || rpcErr.Message != "already_exists" || rpcErr.Code != "PT409" {
		t.Fatalf("err = %v", err)
	}
}

func TestAttachmentPolicy(t *testing.T) {
	var args map[string]any
	var path string
	srv := rpcServer(t, 200, `{"documents":{"enabled":true,"bucket":"cs-documents","max_bytes":10485760,"formats":[{"code":"pdf","mime":"application/pdf","ext":"pdf"},{"code":"csv","mime":"text/csv","ext":"csv"}]},`+
		`"images":{"enabled":true,"bucket":"attachments","max_bytes":5242880,"formats":[{"code":"jpeg","mime":"image/jpeg","ext":"jpg"}]},`+
		`"videos":{"enabled":false,"bucket":"cs-videos","max_bytes":26214400,"max_seconds":120,"formats":[]}}`, &args, &path)
	policy, err := NewPostgREST(srv.URL, []byte("k"), "supabase").AttachmentPolicy(context.Background())
	if err != nil || path != "/rpc/media_attachment_policy" || len(args) != 0 {
		t.Fatalf("err = %v path = %s args = %v", err, path, args)
	}
	docs, videos := policy["documents"], policy["videos"]
	if !docs.Enabled || docs.MaxBytes != 10<<20 || !docs.Allows("csv") || docs.Formats[0].MIME != "application/pdf" ||
		videos.Enabled || videos.MaxSeconds != 120 || len(videos.Formats) != 0 {
		t.Fatalf("policy = %+v", policy)
	}
	for _, reply := range []string{`{}`, `null`, `{"documents":{"enabled":true}}`} {
		srv := rpcServer(t, 200, reply, &args, &path)
		if _, err := NewPostgREST(srv.URL, []byte("k"), "supabase").AttachmentPolicy(context.Background()); err == nil {
			t.Fatalf("reply %s must fail", reply)
		}
	}
}
