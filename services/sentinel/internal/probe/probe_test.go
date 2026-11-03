package probe

import (
	"context"
	"encoding/json"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestParseAcceptsHTTPAndTCPTargets(t *testing.T) {
	targets, err := Parse("storage=http://storage:5000/status, db=tcp://db:5432, secure=https://x.test/health?deep=1#frag")
	if err != nil {
		t.Fatal(err)
	}
	if len(targets) != 3 {
		t.Fatalf("targets = %+v", targets)
	}
	if targets[0] != (Target{Name: "storage", URL: "http://storage:5000/status", Kind: HTTP}) ||
		targets[1] != (Target{Name: "db", URL: "tcp://db:5432", Kind: TCP, Addr: "db:5432"}) ||
		targets[2] != (Target{Name: "secure", URL: "https://x.test/health?deep=1", Kind: HTTP}) {
		t.Fatalf("targets = %+v", targets)
	}
	if empty, err := Parse("  "); err != nil || len(empty) != 0 {
		t.Fatalf("empty spec: %v %v", empty, err)
	}
}

func TestParseRejectsBadTargets(t *testing.T) {
	for _, spec := range []string{
		"storage", "=http://x/", "UPPER=http://x/", strings.Repeat("a", 61) + "=http://x/", "a=http://x/,a=http://y/",
		"a=tcp://db", "a=tcp://db:0", "a=tcp://db:5432/path", "a=ftp://x/", "a=http://user:secret@x/", "a=http:///nohost",
	} {
		if _, err := Parse(spec); err == nil {
			t.Errorf("Parse(%q) accepted", spec)
		} else if strings.Contains(err.Error(), "secret") {
			t.Errorf("error leaks URL credentials: %v", err)
		}
	}
	var many []string
	for i := range MaxTargets + 1 {
		many = append(many, "p"+strings.Repeat("x", i%5)+string(rune('a'+i%26))+strings.Repeat("y", i/26)+"=tcp://h:1")
	}
	if _, err := Parse(strings.Join(many, ",")); err == nil || !strings.Contains(err.Error(), "at most") {
		t.Fatalf("too many probes: %v", err)
	}
}

func TestHTTPProbeCountsEveryStatusBelow500AsUp(t *testing.T) {
	var redirected atomic.Int32
	mux := http.NewServeMux()
	mux.HandleFunc("/ok", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || !strings.HasPrefix(r.Header.Get("User-Agent"), "olt-sentinel") {
			t.Errorf("request = %s %q", r.Method, r.Header.Get("User-Agent"))
		}
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("/auth", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusUnauthorized) })
	mux.HandleFunc("/moved", func(w http.ResponseWriter, r *http.Request) { http.Redirect(w, r, "/target", http.StatusFound) })
	mux.HandleFunc("/target", func(w http.ResponseWriter, _ *http.Request) { redirected.Add(1) })
	mux.HandleFunc("/broken", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusInternalServerError) })
	mux.HandleFunc("/unavailable", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusServiceUnavailable) })
	server := httptest.NewServer(mux)
	defer server.Close()

	targets := []Target{
		{Name: "ok", URL: server.URL + "/ok", Kind: HTTP},
		{Name: "auth", URL: server.URL + "/auth", Kind: HTTP},
		{Name: "missing", URL: server.URL + "/missing", Kind: HTTP},
		{Name: "moved", URL: server.URL + "/moved", Kind: HTTP},
		{Name: "broken", URL: server.URL + "/broken", Kind: HTTP},
		{Name: "unavailable", URL: server.URL + "/unavailable", Kind: HTTP},
	}
	results := New(2*time.Second, "olt-sentinel/test").Run(context.Background(), targets)
	want := []struct {
		ok     bool
		status int
		err    string
	}{{true, 200, ""}, {true, 401, ""}, {true, 404, ""}, {true, 302, ""}, {false, 500, "HTTP 500"}, {false, 503, "HTTP 503"}}
	for i, r := range results {
		if r.Name != targets[i].Name || r.Target != targets[i].URL || r.OK != want[i].ok || r.Status == nil ||
			*r.Status != want[i].status || r.LatencyMS < 0 {
			t.Errorf("result %d = %+v", i, r)
		}
		if got := deref(r.Error); got != want[i].err {
			t.Errorf("result %d error = %q, want %q", i, got, want[i].err)
		}
	}
	if redirected.Load() != 0 {
		t.Fatal("redirects must not be followed")
	}
}

func TestResultsEncodeToTheContractShape(t *testing.T) {
	status, text := 200, "HTTP 503"
	data, _ := json.Marshal([]Result{
		{Name: "storage", Target: "http://storage:5000/status", OK: true, Status: &status, LatencyMS: 12},
		{Name: "db", Target: "tcp://db:5432", OK: false, LatencyMS: 5000, Error: &text},
	})
	want := `[{"name":"storage","target":"http://storage:5000/status","ok":true,"status":200,"latency_ms":12,"error":null},` +
		`{"name":"db","target":"tcp://db:5432","ok":false,"status":null,"latency_ms":5000,"error":"HTTP 503"}]`
	if string(data) != want {
		t.Fatalf("json = %s", data)
	}
}

func TestHTTPProbeTimesOut(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-r.Context().Done():
		case <-time.After(5 * time.Second):
		}
	}))
	defer server.Close()

	start := time.Now()
	r := New(200*time.Millisecond, "test").Check(context.Background(), Target{Name: "slow", URL: server.URL, Kind: HTTP})
	if r.OK || r.Status != nil || deref(r.Error) != "waktu habis setelah 200ms" {
		t.Fatalf("result = %+v error=%q", r, deref(r.Error))
	}
	if elapsed := time.Since(start); elapsed > 2*time.Second {
		t.Fatalf("probe took %v", elapsed)
	}
}

func TestTCPProbe(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	go func() {
		for {
			conn, err := ln.Accept()
			if err != nil {
				return
			}
			conn.Close()
		}
	}()
	open := ln.Addr().String()
	closedLn, _ := net.Listen("tcp", "127.0.0.1:0")
	closed := closedLn.Addr().String()
	closedLn.Close()
	defer ln.Close()

	p := New(time.Second, "test")
	up := p.Check(context.Background(), Target{Name: "db", URL: "tcp://" + open, Kind: TCP, Addr: open})
	if !up.OK || up.Status != nil || up.Error != nil {
		t.Fatalf("open port = %+v", up)
	}
	down := p.Check(context.Background(), Target{Name: "db", URL: "tcp://" + closed, Kind: TCP, Addr: closed})
	if down.OK || down.Status != nil || deref(down.Error) != "koneksi ditolak" {
		t.Fatalf("closed port = %+v error=%q", down, deref(down.Error))
	}
}

func TestUnknownHostIsDescribed(t *testing.T) {
	r := New(2*time.Second, "test").Check(context.Background(), Target{Name: "x", URL: "http://no-such-host.invalid/", Kind: HTTP})
	if r.OK || r.Error == nil || *r.Error == "" {
		t.Fatalf("result = %+v", r)
	}
}

func TestProbesRunInParallel(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		time.Sleep(150 * time.Millisecond)
	}))
	defer server.Close()
	var targets []Target
	for _, name := range []string{"a", "b", "c", "d", "e", "f"} {
		targets = append(targets, Target{Name: name, URL: server.URL, Kind: HTTP})
	}
	start := time.Now()
	results := New(2*time.Second, "test").Run(context.Background(), targets)
	if elapsed := time.Since(start); elapsed > 600*time.Millisecond {
		t.Fatalf("six probes took %v; they must run in parallel", elapsed)
	}
	for i, r := range results {
		if r.Name != targets[i].Name || !r.OK {
			t.Fatalf("result %d = %+v", i, r)
		}
	}
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
