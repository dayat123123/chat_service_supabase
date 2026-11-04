package store

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/sentinel/internal/disk"
	"olt-social/sentinel/internal/probe"
	"olt-social/sentinel/internal/scrape"
)

const secret = "0123456789abcdef0123456789abcdef"

type captured struct {
	method, path, contentProfile, acceptProfile, contentType string
	claims                                                   map[string]any
	raw                                                      string
	args                                                     map[string]any
}

func serviceClaims(t *testing.T, header string) map[string]any {
	t.Helper()
	parts := strings.Split(strings.TrimPrefix(header, "Bearer "), ".")
	if len(parts) != 3 {
		t.Fatalf("authorization = %q", header)
	}
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(parts[0] + "." + parts[1]))
	if base64.RawURLEncoding.EncodeToString(mac.Sum(nil)) != parts[2] {
		t.Fatal("service token signature mismatch")
	}
	payload, _ := base64.RawURLEncoding.DecodeString(parts[1])
	var claims map[string]any
	_ = json.Unmarshal(payload, &claims)
	return claims
}

type fakePostgREST struct {
	t     *testing.T
	mu    sync.Mutex
	calls []captured
	reply func(fn string, args map[string]any) (int, string)
}

func newFake(t *testing.T, reply func(fn string, args map[string]any) (int, string)) (*fakePostgREST, *httptest.Server) {
	f := &fakePostgREST{t: t, reply: reply}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		seen := captured{
			method:         r.Method,
			path:           r.URL.Path,
			contentProfile: r.Header.Get("Content-Profile"),
			acceptProfile:  r.Header.Get("Accept-Profile"),
			contentType:    r.Header.Get("Content-Type"),
			claims:         serviceClaims(t, r.Header.Get("Authorization")),
			raw:            string(body),
		}
		_ = json.Unmarshal(body, &seen.args)
		f.mu.Lock()
		f.calls = append(f.calls, seen)
		f.mu.Unlock()
		status, text := f.reply(strings.TrimPrefix(r.URL.Path, "/rpc/"), seen.args)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		_, _ = w.Write([]byte(text))
	}))
	t.Cleanup(server.Close)
	return f, server
}

func (f *fakePostgREST) last() captured {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.calls[len(f.calls)-1]
}

func newStore(url string, observe func(error)) *PostgREST {
	p := NewPostgREST(Options{BaseURL: url, Secret: []byte(secret), Issuer: "supabase", Timeout: 5 * time.Second, Observe: observe})
	p.now = func() time.Time { return time.Unix(1_800_000_000, 0) }
	return p
}

func TestHealthReportSendsTheContractPayload(t *testing.T) {
	fake, server := newFake(t, func(string, map[string]any) (int, string) {
		return 200, `{"evaluated_at":"2027-01-15T08:00:00.123456+00:00"}`
	})
	status, text := 200, "waktu habis setelah 5s"
	evaluated, err := newStore(server.URL, nil).HealthReport(context.Background(), Health{
		Instance:  "sentinel-1",
		Version:   "0.1.0",
		StartedAt: time.Date(2027, 1, 15, 14, 0, 0, 0, time.FixedZone("WIB", 7*3600)),
		Probes: []probe.Result{
			{Name: "storage", Target: "http://storage:5000/status", OK: true, Status: &status, LatencyMS: 12},
			{Name: "db", Target: "tcp://db:5432", LatencyMS: 5000, Error: &text},
		},
		Disks: []disk.Usage{{Name: "data", TotalBytes: 100, FreeBytes: 40, AvailBytes: 30}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if !evaluated.Equal(time.Date(2027, 1, 15, 8, 0, 0, 123456000, time.UTC)) {
		t.Fatalf("evaluated = %v", evaluated)
	}
	seen := fake.last()
	if seen.method != http.MethodPost || seen.path != "/rpc/health_report" || seen.contentProfile != "public" ||
		seen.acceptProfile != "public" || seen.contentType != "application/json" {
		t.Fatalf("request = %+v", seen)
	}
	if seen.claims["role"] != "service_role" || seen.claims["iss"] != "supabase" ||
		seen.claims["exp"].(float64)-seen.claims["iat"].(float64) != 60 {
		t.Fatalf("claims = %v", seen.claims)
	}
	want := map[string]any{
		"p_instance":   "sentinel-1",
		"p_version":    "0.1.0",
		"p_started_at": "2027-01-15T07:00:00Z",
		"p_probes": []any{
			map[string]any{"name": "storage", "target": "http://storage:5000/status", "ok": true, "status": float64(200), "latency_ms": float64(12), "error": nil},
			map[string]any{"name": "db", "target": "tcp://db:5432", "ok": false, "status": nil, "latency_ms": float64(5000), "error": "waktu habis setelah 5s"},
		},
		"p_disks": []any{map[string]any{"name": "data", "total_bytes": float64(100), "free_bytes": float64(40), "avail_bytes": float64(30)}},
	}
	if !reflect.DeepEqual(seen.args, want) {
		t.Fatalf("args = %#v", seen.args)
	}
}

func TestHealthReportSendsMetricsOnlyWhenSourcesAreConfigured(t *testing.T) {
	fake, server := newFake(t, func(string, map[string]any) (int, string) { return 200, `{"evaluated_at":null}` })
	db := newStore(server.URL, nil)
	if _, err := db.HealthReport(context.Background(), Health{Instance: "s", Version: "v"}); err != nil {
		t.Fatal(err)
	}
	if _, ok := fake.last().args["p_metrics"]; ok {
		t.Fatal("p_metrics must be left out without metrics sources")
	}
	failure := "koneksi ditolak"
	_, err := db.HealthReport(context.Background(), Health{Instance: "s", Version: "v", Metrics: []scrape.Result{
		{Source: "rest", Instance: "10.0.0.4", OK: true, Values: map[string]float64{"pgrst_db_pool_waiting": 2}},
		{Source: "pgbouncer", Instance: "10.0.0.5", Error: &failure, Values: map[string]float64{}},
	}})
	if err != nil {
		t.Fatal(err)
	}
	want := []any{
		map[string]any{"source": "rest", "instance": "10.0.0.4", "ok": true, "error": nil, "values": map[string]any{"pgrst_db_pool_waiting": float64(2)}},
		map[string]any{"source": "pgbouncer", "instance": "10.0.0.5", "ok": false, "error": "koneksi ditolak", "values": map[string]any{}},
	}
	if got := fake.last().args["p_metrics"]; !reflect.DeepEqual(got, want) {
		t.Fatalf("p_metrics = %#v", got)
	}
}

func TestHealthReportSendsEmptyArraysNotNull(t *testing.T) {
	fake, server := newFake(t, func(string, map[string]any) (int, string) { return 200, `{"evaluated_at":null}` })
	if _, err := newStore(server.URL, nil).HealthReport(context.Background(), Health{Instance: "s", Version: "v"}); err != nil {
		t.Fatal(err)
	}
	if raw := fake.last().raw; !strings.Contains(raw, `"p_probes":[]`) || !strings.Contains(raw, `"p_disks":[]`) {
		t.Fatalf("body = %s", raw)
	}
}

func TestChannelsAsksWithNullThenWithTheKnownRevision(t *testing.T) {
	fake, server := newFake(t, func(_ string, args map[string]any) (int, string) {
		if args["p_revision"] == float64(7) {
			return 200, `{"revision":7,"unchanged":true}`
		}
		return 200, `{"revision":7,
		  "telegram":{"bot_token":"123456:ABCDEFGHIJKLMNOPQRSTUVWXYZ","chat_ids":["-100123", 42, " "]},
		  "email":{"host":" smtp.x ","port":587,"security":"STARTTLS","username":null,"password":" p w ","from":"ops@x","to":["a@x","b@x"]}}`
	})
	s := newStore(server.URL, nil)

	first, err := s.Channels(context.Background(), UnknownRevision)
	if err != nil {
		t.Fatal(err)
	}
	if raw := fake.last().raw; raw != `{"p_revision":null}` {
		t.Fatalf("first body = %s", raw)
	}
	want := Channels{
		Revision: 7,
		Telegram: &Telegram{BotToken: "123456:ABCDEFGHIJKLMNOPQRSTUVWXYZ", ChatIDs: []string{"-100123", "42"}},
		Email:    &Email{Host: "smtp.x", Port: 587, Security: "starttls", Password: " p w ", From: "ops@x", To: []string{"a@x", "b@x"}},
	}
	if !reflect.DeepEqual(first, want) {
		t.Fatalf("channels = %#v", first)
	}

	again, err := s.Channels(context.Background(), 7)
	if err != nil {
		t.Fatal(err)
	}
	if raw := fake.last().raw; raw != `{"p_revision":7}` {
		t.Fatalf("second body = %s", raw)
	}
	if !reflect.DeepEqual(again, Channels{Revision: 7, Unchanged: true}) {
		t.Fatalf("unchanged = %#v", again)
	}
}

func TestChannelsWithBothChannelsDisabled(t *testing.T) {
	_, server := newFake(t, func(string, map[string]any) (int, string) {
		return 200, `{"revision":1,"telegram":null,"email":null}`
	})
	got, err := newStore(server.URL, nil).Channels(context.Background(), UnknownRevision)
	if err != nil || !reflect.DeepEqual(got, Channels{Revision: 1}) {
		t.Fatalf("channels = %#v, err = %v", got, err)
	}
}

func TestSecretsNeverPrintThroughFmtOrSlog(t *testing.T) {
	channels := Channels{
		Revision: 3,
		Telegram: &Telegram{BotToken: "123456:SECRET-TOKEN-VALUE-XXXXXXXX", ChatIDs: []string{"-1"}},
		Email:    &Email{Host: "smtp.x", Port: 465, Security: "tls", Username: "ops", Password: "SECRET-PASSWORD", From: "a@x", To: []string{"b@x"}},
	}
	var buf bytes.Buffer
	log := slog.New(slog.NewJSONHandler(&buf, nil))
	log.Info("channels", "telegram", *channels.Telegram, "email", *channels.Email)
	text := fmt.Sprintf("%v %+v %#v %v %+v %#v %s", *channels.Telegram, *channels.Telegram, *channels.Telegram,
		*channels.Email, *channels.Email, *channels.Email, buf.String())
	if strings.Contains(text, "SECRET") {
		t.Fatalf("secret printed: %s", text)
	}
	if !strings.Contains(text, "smtp.x") || !strings.Contains(buf.String(), `"chats":1`) {
		t.Fatalf("summary missing: %s", text)
	}
}

func TestClaimAndReportRoundTrip(t *testing.T) {
	fake, server := newFake(t, func(fn string, _ map[string]any) (int, string) {
		if fn == "alert_claim" {
			return 200, `[{"id":123,"channel":"telegram","subject":"[OLT] KRITIS: db","text":"🔴 KRITIS — db"},
			              {"id":124,"channel":"email","subject":"s","text":"t"}]`
		}
		return 200, `2`
	})
	s := newStore(server.URL, nil)

	alerts, err := s.Claim(context.Background(), "sentinel-1", 20, 59500*time.Millisecond)
	if err != nil {
		t.Fatal(err)
	}
	if args := fake.last().args; !reflect.DeepEqual(args, map[string]any{"p_instance": "sentinel-1", "p_limit": float64(20), "p_lease_seconds": float64(60)}) {
		t.Fatalf("claim args = %v", args)
	}
	want := []Alert{{ID: 123, Channel: "telegram", Subject: "[OLT] KRITIS: db", Text: "🔴 KRITIS — db"}, {ID: 124, Channel: "email", Subject: "s", Text: "t"}}
	if !reflect.DeepEqual(alerts, want) {
		t.Fatalf("alerts = %+v", alerts)
	}

	updated, err := s.Report(context.Background(), "sentinel-1", []Result{
		{ID: 123, OK: true},
		{ID: 124, Error: "SMTP RCPT TO a@x ditolak: 550 no such user", Retry: false},
		{ID: 125, Error: "Telegram tidak bisa dihubungi", Retry: true},
		{ID: 126, Error: strings.Repeat("é", 600), Retry: true},
	})
	if err != nil || updated != 2 {
		t.Fatalf("updated = %d, err = %v", updated, err)
	}
	seen := fake.last()
	if seen.path != "/rpc/alert_report" {
		t.Fatalf("path = %s", seen.path)
	}
	wantRaw := `{"p_instance":"sentinel-1","p_results":[{"id":123,"ok":true},` +
		`{"id":124,"ok":false,"error":"SMTP RCPT TO a@x ditolak: 550 no such user","retry":false},` +
		`{"id":125,"ok":false,"error":"Telegram tidak bisa dihubungi","retry":true},` +
		`{"id":126,"ok":false,"error":"` + strings.Repeat("é", 500) + `","retry":true}]}`
	if seen.raw != wantRaw {
		t.Fatalf("report body = %s", seen.raw)
	}
}

func TestClaimWithNothingQueued(t *testing.T) {
	_, server := newFake(t, func(string, map[string]any) (int, string) { return 200, `[]` })
	alerts, err := newStore(server.URL, nil).Claim(context.Background(), "s", 20, time.Minute)
	if err != nil || len(alerts) != 0 {
		t.Fatalf("alerts = %v, err = %v", alerts, err)
	}
}

func TestErrorsAreTypedAndClassified(t *testing.T) {
	status := http.StatusNotFound
	_, server := newFake(t, func(string, map[string]any) (int, string) {
		return status, `{"code":"PGRST202","message":"Could not find the function public.alert_claim","details":null,"hint":null}`
	})
	var observed []error
	s := newStore(server.URL, func(err error) { observed = append(observed, err) })

	_, err := s.Claim(context.Background(), "s", 1, time.Minute)
	var rpcErr *Error
	if !errors.As(err, &rpcErr) || rpcErr.Status != 404 || rpcErr.Code != "PGRST202" ||
		err.Error() != "rpc alert_claim: status 404 PGRST202: Could not find the function public.alert_claim" {
		t.Fatalf("err = %v", err)
	}
	if Unreachable(err) {
		t.Fatal("a 404 means the API answered")
	}
	status = http.StatusServiceUnavailable
	_, err = s.Claim(context.Background(), "s", 1, time.Minute)
	if !Unreachable(err) {
		t.Fatalf("503 must count as unreachable: %v", err)
	}
	server.Close()
	_, err = s.Claim(context.Background(), "s", 1, time.Minute)
	if !Unreachable(err) || !strings.HasPrefix(err.Error(), "rpc alert_claim: ") {
		t.Fatalf("transport error = %v", err)
	}
	if len(observed) != 3 || observed[0] == nil || observed[2] == nil {
		t.Fatalf("observed = %v", observed)
	}
	if Unreachable(nil) {
		t.Fatal("nil is reachable")
	}
}

func TestObserverSeesSuccessButNotCancellation(t *testing.T) {
	_, server := newFake(t, func(string, map[string]any) (int, string) { return 200, `[]` })
	var observed []error
	s := newStore(server.URL, func(err error) { observed = append(observed, err) })
	if _, err := s.Claim(context.Background(), "s", 1, time.Minute); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := s.Claim(ctx, "s", 1, time.Minute); err == nil {
		t.Fatal("cancelled call succeeded")
	}
	if len(observed) != 1 || observed[0] != nil {
		t.Fatalf("observed = %v", observed)
	}
}

func TestPingReportsPostgRESTAvailability(t *testing.T) {
	status := http.StatusOK
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodHead || r.URL.Path != "/" {
			t.Errorf("ping = %s %s", r.Method, r.URL.Path)
		}
		w.WriteHeader(status)
	}))
	defer server.Close()
	s := newStore(server.URL, nil)
	if err := s.Ping(context.Background()); err != nil {
		t.Fatal(err)
	}
	status = http.StatusBadGateway
	if err := s.Ping(context.Background()); err == nil {
		t.Fatal("expected an error for 502")
	}
}
