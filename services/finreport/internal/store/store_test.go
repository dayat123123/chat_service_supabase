package store

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func server(t *testing.T, handler func(fn string, args map[string]any) (int, string)) *PostgREST {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Content-Profile") != "public" || !strings.HasPrefix(r.Header.Get("Authorization"), "Bearer ") {
			t.Errorf("headers = %v", r.Header)
		}
		var args map[string]any
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &args)
		status, out := handler(strings.TrimPrefix(r.URL.Path, "/rpc/"), args)
		w.WriteHeader(status)
		_, _ = w.Write([]byte(out))
	}))
	t.Cleanup(srv.Close)
	return NewPostgREST(srv.URL, []byte(strings.Repeat("s", 40)), "supabase", 5*time.Second)
}

func TestClaimRelatedAndComplete(t *testing.T) {
	var calls []string
	p := server(t, func(fn string, args map[string]any) (int, string) {
		calls = append(calls, fn)
		switch fn {
		case "finreport_claim":
			if args["p_instance"] != "w1" || args["p_lease_seconds"] != float64(120) {
				t.Errorf("claim args = %v", args)
			}
			return 200, `{"id":"f1","object_name":"api/x/report.zip","sha256":"ab","size_bytes":10,"attempts":2}`
		case "finreport_related":
			if args["p_entity"] != "ABCD" || args["p_period_start"] != "2026-01-01" || args["p_period_end"] != "2026-09-30" {
				t.Errorf("related args = %v", args)
			}
			return 200, `{"previous":{"id":"q2","period":"Q2","period_start":"2026-01-01","period_end":"2026-06-30","facts":{"current":{"Assets":5}}},"prior_year":null}`
		case "finreport_complete":
			if args["p_file"] != "f1" || args["p_report"].(map[string]any)["sha256"] != "ab" {
				t.Errorf("complete args = %v", args)
			}
			return 200, `{"status":"done"}`
		case "finreport_fail":
			if args["p_code"] != "not_zip" || args["p_retry"] != false {
				t.Errorf("fail args = %v", args)
			}
			return 200, `{"status":"rejected"}`
		}
		return 404, `{}`
	})
	ctx := context.Background()
	job, err := p.Claim(ctx, "w1", 2*time.Minute)
	if err != nil || job.ID != "f1" || job.Attempts != 2 || job.SizeBytes != 10 {
		t.Fatalf("claim = %+v, %v", job, err)
	}
	start, _ := time.Parse("2006-01-02", "2026-01-01")
	end, _ := time.Parse("2006-01-02", "2026-09-30")
	rel, err := p.Related(ctx, "ABCD", start, end)
	if err != nil || rel.PriorYear != nil || rel.Previous.ID != "q2" || rel.Previous.Facts["current"]["Assets"] != 5 {
		t.Fatalf("related = %+v, %v", rel, err)
	}
	if s, e, err := rel.Previous.Dates(); err != nil || s != start || e.Format("2006-01-02") != "2026-06-30" {
		t.Fatalf("dates %v %v %v", s, e, err)
	}
	if _, err := p.Complete(ctx, "f1", "w1", map[string]any{"sha256": "ab"}); err != nil {
		t.Fatal(err)
	}
	if err := p.Fail(ctx, "f1", "w1", "not_zip", "bad", false); err != nil {
		t.Fatal(err)
	}
	if strings.Join(calls, ",") != "finreport_claim,finreport_related,finreport_complete,finreport_fail" {
		t.Fatalf("calls = %v", calls)
	}
}

func TestEmptyClaimAndErrors(t *testing.T) {
	p := server(t, func(fn string, _ map[string]any) (int, string) {
		switch fn {
		case "finreport_claim":
			return 200, `null`
		case "finreport_submit":
			return 429, `{"code":"PT429","message":"rate_limited","details":"Maksimal 120 file"}`
		case "integration_authenticate":
			return 200, `null`
		}
		return 500, `{"code":"XX000","message":"boom"}`
	})
	ctx := context.Background()
	if job, err := p.Claim(ctx, "w1", time.Minute); job != nil || err != nil {
		t.Fatalf("empty claim = %+v, %v", job, err)
	}
	var api *APIError
	if _, err := p.Submit(ctx, "k", "ab", 10, "1.2.3.4"); !errors.As(err, &api) || api.Status != 429 ||
		api.Code != "rate_limited" || api.Detail != "Maksimal 120 file" {
		t.Fatalf("submit = %v", err)
	}
	if key, err := p.Authenticate(ctx, "hash", ""); key != nil || err != nil {
		t.Fatalf("unknown key = %+v, %v", key, err)
	}
	if _, err := p.File(ctx, "k", "id", ""); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("server error = %v", err)
	}
}
