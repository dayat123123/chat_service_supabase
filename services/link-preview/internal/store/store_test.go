package store

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"olt-social/link-preview/internal/heartbeat"
)

type call struct {
	path string
	auth string
	body map[string]any
}

func server(t *testing.T, reply func(path string) (int, string)) (*PostgREST, *[]call) {
	t.Helper()
	var calls []call
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		var body map[string]any
		_ = json.Unmarshal(raw, &body)
		calls = append(calls, call{path: r.URL.Path, auth: r.Header.Get("Authorization"), body: body})
		status, text := reply(r.URL.Path)
		w.WriteHeader(status)
		_, _ = w.Write([]byte(text))
	}))
	t.Cleanup(srv.Close)
	return NewPostgREST(srv.URL, []byte(strings.Repeat("s", 40)), "supabase", 5*time.Second), &calls
}

func TestClaimSendsLeaseAndDecodesEntries(t *testing.T) {
	p, calls := server(t, func(string) (int, string) {
		return 200, `[{"url_hash":"ab","url":"https://example.com/","attempt":2}]`
	})
	entries, err := p.Claim(context.Background(), "lp-1", 8, 90*time.Second+time.Millisecond)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 || entries[0] != (Entry{URLHash: "ab", URL: "https://example.com/", Attempt: 2}) {
		t.Fatalf("entries = %+v", entries)
	}
	c := (*calls)[0]
	if c.path != "/rpc/link_preview_claim" || !strings.HasPrefix(c.auth, "Bearer ey") ||
		c.body["p_instance"] != "lp-1" || c.body["p_limit"] != float64(8) || c.body["p_lease_seconds"] != float64(91) {
		t.Fatalf("call = %+v", c)
	}
}

func TestReportClipsErrorsAndOmitsEmptyFields(t *testing.T) {
	p, calls := server(t, func(string) (int, string) { return 200, `1` })
	n, err := p.Report(context.Background(), "lp-1", []Result{{URLHash: "ab", Status: StatusFailed, Error: strings.Repeat("e", 400)}})
	if err != nil || n != 1 {
		t.Fatalf("n=%d err=%v", n, err)
	}
	rows := (*calls)[0].body["p_results"].([]any)
	row := rows[0].(map[string]any)
	if len(row["error"].(string)) != maxError || row["status"] != "failed" {
		t.Fatalf("row = %v", row)
	}
	for _, key := range []string{"title", "image_path", "image_width", "final_url"} {
		if _, present := row[key]; present {
			t.Fatalf("%s should be omitted: %v", key, row)
		}
	}
}

func TestErrorsCarryPostgRESTMessage(t *testing.T) {
	p, _ := server(t, func(string) (int, string) {
		return 400, `{"code":"PT400","message":"invalid_claim"}`
	})
	_, err := p.Claim(context.Background(), "lp-1", 0, time.Minute)
	if err == nil || !strings.Contains(err.Error(), "status 400: PT400 invalid_claim") {
		t.Fatalf("err = %v", err)
	}
}

func TestHeartbeatPayload(t *testing.T) {
	p, calls := server(t, func(string) (int, string) { return 204, `` })
	started := time.Date(2026, 11, 3, 1, 2, 3, 0, time.UTC)
	err := p.Heartbeat(context.Background(), heartbeat.Beat{Service: "link-preview", Instance: "lp-1", Version: "0.1.0",
		StartedAt: started, Status: heartbeat.StatusOK, Detail: map[string]any{"fetched": 3}})
	if err != nil {
		t.Fatal(err)
	}
	c := (*calls)[0]
	if c.path != "/rpc/service_heartbeat" || c.body["p_service"] != "link-preview" || c.body["p_started_at"] != "2026-11-03T01:02:03Z" ||
		c.body["p_error"] != nil || c.body["p_detail"].(map[string]any)["fetched"] != float64(3) {
		t.Fatalf("call = %+v", c)
	}
}
