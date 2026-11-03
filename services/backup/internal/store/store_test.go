package store

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"

	"olt-social/backup/internal/settings"
	"olt-social/backup/internal/state"
)

type captured struct {
	path, contentProfile, acceptProfile string
	claims                              map[string]any
	args                                map[string]any
}

func serviceClaims(t *testing.T, header string, secret []byte) map[string]any {
	t.Helper()
	parts := strings.Split(strings.TrimPrefix(header, "Bearer "), ".")
	if len(parts) != 3 {
		t.Fatalf("authorization = %q", header)
	}
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(parts[0] + "." + parts[1]))
	if base64.RawURLEncoding.EncodeToString(mac.Sum(nil)) != parts[2] {
		t.Fatal("service token signature mismatch")
	}
	payload, _ := base64.RawURLEncoding.DecodeString(parts[1])
	var claims map[string]any
	_ = json.Unmarshal(payload, &claims)
	return claims
}

func fakePostgREST(t *testing.T, status int, reply string, seen *captured) *PostgREST {
	t.Helper()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusOK)
			return
		}
		seen.path = r.URL.Path
		seen.contentProfile = r.Header.Get("Content-Profile")
		seen.acceptProfile = r.Header.Get("Accept-Profile")
		seen.claims = serviceClaims(t, r.Header.Get("Authorization"), []byte("secret"))
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &seen.args)
		w.WriteHeader(status)
		_, _ = w.Write([]byte(reply))
	}))
	t.Cleanup(server.Close)
	p := NewPostgREST(server.URL, []byte("secret"), "supabase", 5*time.Second)
	p.now = func() time.Time { return time.Unix(1_800_000_000, 0) }
	return p
}

func TestConfigSendsKnownRevisionAndDecodes(t *testing.T) {
	var seen captured
	p := fakePostgREST(t, 200, `{"revision":5,"configured":true,"repository":"s3:http://s3:8333/b","s3":{"access_key_id":"k","secret_access_key":"s","region":"r1"},"password":"pw",
"schedule":{"base_time":"02:00","timezone":"Asia/Jakarta","offsite_minutes":5,"restore_test_weekday":0,"restore_test_time":"04:00"},"retention":{"daily":7,"weekly":4,"monthly":6,"wal_days":7},"restore_test":true}`, &seen)
	s, err := p.Config(context.Background(), 4)
	if err != nil {
		t.Fatal(err)
	}
	if s.Revision != 5 || s.Password != "pw" || s.Region() != "r1" || s.Retention.Monthly != 6 {
		t.Fatalf("s = %#v", s)
	}
	if seen.path != "/rpc/backup_config" || seen.args["p_revision"] != float64(4) || seen.contentProfile != "public" || seen.acceptProfile != "public" {
		t.Fatalf("seen = %+v", seen)
	}
	want := map[string]any{"iss": "supabase", "role": "service_role", "iat": float64(1_800_000_000), "exp": float64(1_800_000_060)}
	if !reflect.DeepEqual(seen.claims, want) {
		t.Fatalf("claims = %v", seen.claims)
	}
	if _, err := p.Config(context.Background(), settings.UnknownRevision); err != nil {
		t.Fatal(err)
	}
	if v, ok := seen.args["p_revision"]; !ok || v != nil {
		t.Fatalf("unknown revision must be sent as null: %v", seen.args)
	}
}

func TestConfigUnchangedAndUnconfigured(t *testing.T) {
	var seen captured
	s, err := fakePostgREST(t, 200, `{"revision":5,"unchanged":true}`, &seen).Config(context.Background(), 5)
	if err != nil || !s.Unchanged || s.Revision != 5 {
		t.Fatalf("s = %#v err = %v", s, err)
	}
	s, err = fakePostgREST(t, 200, `{"revision":0,"configured":false}`, &seen).Config(context.Background(), settings.UnknownRevision)
	if err != nil || s.Configured || s.Unchanged {
		t.Fatalf("s = %#v err = %v", s, err)
	}
}

func TestHeartbeatSendsStateAndReturnsRequests(t *testing.T) {
	var seen captured
	p := fakePostgREST(t, 200, `{"requests":["base","restore_test"]}`, &seen)
	started := time.Date(2026, 11, 3, 1, 0, 0, 0, time.FixedZone("WIB", 7*3600))
	report := state.Report{RepositoryReady: true, WAL: state.WAL{Streaming: true}, Busy: state.Text("offsite")}
	reqs, err := p.Heartbeat(context.Background(), Beat{Instance: "backup-1", Version: "0.1.0", StartedAt: started, ConfigRevision: 7, State: report})
	if err != nil || !reflect.DeepEqual(reqs, []string{"base", "restore_test"}) {
		t.Fatalf("reqs = %v err = %v", reqs, err)
	}
	if seen.path != "/rpc/backup_heartbeat" || seen.args["p_instance"] != "backup-1" || seen.args["p_version"] != "0.1.0" ||
		seen.args["p_started_at"] != "2026-11-02T18:00:00Z" || seen.args["p_config_revision"] != float64(7) {
		t.Fatalf("args = %v", seen.args)
	}
	st := seen.args["p_state"].(map[string]any)
	if st["repository_ready"] != true || st["busy"] != "offsite" || st["wal"].(map[string]any)["streaming"] != true {
		t.Fatalf("state = %v", st)
	}
	_, _ = p.Heartbeat(context.Background(), Beat{Instance: "backup-1", ConfigRevision: settings.UnknownRevision})
	if v, ok := seen.args["p_config_revision"]; !ok || v != nil {
		t.Fatalf("args = %v", seen.args)
	}
}

func TestRecordSendsRun(t *testing.T) {
	var seen captured
	p := fakePostgREST(t, 204, "", &seen)
	at := time.Date(2026, 11, 3, 1, 0, 0, 0, time.UTC)
	err := p.Record(context.Background(), "backup-1", state.Run{Kind: "wal", Status: state.StatusFailed, StartedAt: at, FinishedAt: at, Error: state.Text("boom")})
	if err != nil {
		t.Fatal(err)
	}
	run := seen.args["p_run"].(map[string]any)
	if seen.path != "/rpc/backup_record" || seen.args["p_instance"] != "backup-1" || run["kind"] != "wal" || run["status"] != "failed" ||
		run["error"] != "boom" || run["bytes"] != nil || !reflect.DeepEqual(run["detail"], map[string]any{}) {
		t.Fatalf("args = %v", seen.args)
	}
}

func TestErrorsCarryPostgRESTMessage(t *testing.T) {
	var seen captured
	p := fakePostgREST(t, 400, `{"code":"invalid_backup_run","message":"Jenis atau status backup tidak valid","details":null,"hint":null}`, &seen)
	err := p.Record(context.Background(), "i", state.Run{Kind: "x", Status: "ok"})
	if err == nil || !strings.Contains(err.Error(), "status 400: Jenis atau status backup tidak valid (invalid_backup_run)") {
		t.Fatalf("err = %v", err)
	}
	if err := p.Ping(context.Background()); err != nil {
		t.Fatal(err)
	}
}
