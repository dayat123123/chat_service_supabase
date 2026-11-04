package scrape

import (
	"context"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestParse(t *testing.T) {
	sources, err := Parse(" rest=http://rest:3001/metrics , realtime=jwt+http://realtime:4000/metrics,pgbouncer=pgbouncer://pgbouncer:6432,other=pgbouncer://watch@10.0.0.5:6432")
	if err != nil {
		t.Fatal(err)
	}
	if len(sources) != 4 {
		t.Fatalf("got %d sources", len(sources))
	}
	rest, rt, pgb, other := sources[0], sources[1], sources[2], sources[3]
	if rest.Kind != Prometheus || rest.JWT || rest.Port != "3001" || rest.Target != "http://rest:3001/metrics" {
		t.Fatalf("rest: %+v", rest)
	}
	if rt.Kind != Prometheus || !rt.JWT || rt.URL.Scheme != "http" || rt.Target != "jwt+http://realtime:4000/metrics" {
		t.Fatalf("realtime: %+v", rt)
	}
	if pgb.Kind != PgBouncer || pgb.User != DefaultStatsUser || pgb.Host != "pgbouncer" || pgb.Port != "6432" {
		t.Fatalf("pgbouncer: %+v", pgb)
	}
	if other.User != "watch" || other.Target != "pgbouncer://watch@10.0.0.5:6432" {
		t.Fatalf("other: %+v", other)
	}
	if !NeedsPgBouncerPassword(sources) || NeedsPgBouncerPassword(sources[:2]) {
		t.Fatal("NeedsPgBouncerPassword is wrong")
	}
	if got, _ := Parse(""); len(got) != 0 {
		t.Fatal("empty spec must give no sources")
	}
}

func TestParseRejects(t *testing.T) {
	for _, spec := range []string{
		"rest",
		"Rest=http://rest:3001/metrics",
		"a=http://rest:3001/metrics,a=http://rest:3002/metrics",
		"a=ftp://rest/metrics",
		"a=http://user:secret@rest:3001/metrics",
		"a=http://user@rest:3001/metrics",
		"a=pgbouncer://olt_stats:secret@pgbouncer:6432",
		"a=pgbouncer://pgbouncer",
		"a=pgbouncer://pgbouncer:6432/db",
		"a=tcp://pgbouncer:6432",
	} {
		if _, err := Parse(spec); err == nil {
			t.Errorf("%q was accepted", spec)
		}
	}
	var many []string
	for i := range MaxSources + 1 {
		many = append(many, "s"+string(rune('a'+i))+"=http://rest:3001/")
	}
	if _, err := Parse(strings.Join(many, ",")); err == nil {
		t.Error("too many sources were accepted")
	}
}

func TestParseText(t *testing.T) {
	text := `# HELP pgrst_db_pool_waiting Requests waiting to acquire a pool connection
# TYPE pgrst_db_pool_waiting gauge
pgrst_db_pool_waiting 3.0
pgrst_db_pool_timeouts_total 7.0
pgrst_db_pool_available 4
pgrst_jwt_cache_hits_total 99
realtime_channel_global_events{host="a",id="realtime@a",region="us-east-1"} 100
realtime_channel_global_events{host="b",id="x}y \"z\"",region="us-east-1"} 50 1730000000000
realtime_channel_global_events{host="c"} NaN
realtime_channel_global_events{broken="x" 5
pgrst_db_pool_max
`
	values, err := ParseText(strings.NewReader(text))
	if err != nil {
		t.Fatal(err)
	}
	want := map[string]float64{
		"pgrst_db_pool_waiting":          3,
		"pgrst_db_pool_timeouts_total":   7,
		"pgrst_db_pool_available":        4,
		"realtime_channel_global_events": 150,
	}
	if len(values) != len(want) {
		t.Fatalf("got %v", values)
	}
	for k, v := range want {
		if values[k] != v {
			t.Errorf("%s = %v, want %v", k, values[k], v)
		}
	}
}

func TestPrometheusScrape(t *testing.T) {
	var mu sync.Mutex
	var auth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/metrics" {
			http.NotFound(w, r)
			return
		}
		mu.Lock()
		auth = r.Header.Get("Authorization")
		mu.Unlock()
		_, _ = w.Write([]byte("realtime_channel_global_events{tenant=\"t\"} 42\n"))
	}))
	defer srv.Close()
	u, _ := url.Parse(srv.URL)
	sources, err := Parse("realtime=jwt+http://realtime.internal:" + u.Port() + "/metrics,missing=http://realtime.internal:" + u.Port() + "/nope")
	if err != nil {
		t.Fatal(err)
	}
	s := New(Options{
		Timeout: 2 * time.Second,
		Token:   func() (string, error) { return "signed", nil },
		Lookup: func(_ context.Context, host string) ([]string, error) {
			if host != "realtime.internal" {
				t.Errorf("looked up %q", host)
			}
			return []string{"127.0.0.1", "127.0.0.1"}, nil
		},
	})
	results := s.Run(context.Background(), sources)
	if len(results) != 2 {
		t.Fatalf("got %+v", results)
	}
	missing, rt := results[0], results[1]
	if !rt.OK || rt.Source != "realtime" || rt.Instance != "127.0.0.1" || rt.Values["realtime_channel_global_events"] != 42 {
		t.Fatalf("realtime: %+v", rt)
	}
	if auth != "Bearer signed" {
		t.Fatalf("authorization %q", auth)
	}
	if missing.OK || missing.Error == nil || *missing.Error != "HTTP 404" {
		t.Fatalf("missing: %+v", missing)
	}
}

func TestBearerOnlyForJWTSources(t *testing.T) {
	seen := map[string]string{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen[r.URL.Path] = r.Header.Get("Authorization")
		_, _ = w.Write([]byte("pgrst_db_pool_waiting 0\n"))
	}))
	defer srv.Close()
	sources, _ := Parse("a=jwt+" + srv.URL + "/a")
	plain, _ := Parse("b=" + srv.URL + "/b")
	s := New(Options{Timeout: time.Second, Token: func() (string, error) { return "tok", nil }})
	s.Run(context.Background(), sources)
	s.Run(context.Background(), plain)
	if seen["/a"] != "Bearer tok" || seen["/b"] != "" {
		t.Fatalf("headers %v", seen)
	}
	failing := New(Options{Timeout: time.Second, Token: func() (string, error) { return "", errors.New("no key") }})
	if r := failing.Run(context.Background(), sources); r[0].OK || !strings.Contains(*r[0].Error, "no key") {
		t.Fatalf("got %+v", r)
	}
}

func TestLookupFailure(t *testing.T) {
	sources, _ := Parse("rest=http://rest:3001/metrics")
	s := New(Options{Timeout: time.Second, Lookup: func(context.Context, string) ([]string, error) {
		return nil, &net.DNSError{Err: "no such host", Name: "rest", IsNotFound: true}
	}})
	results := s.Run(context.Background(), sources)
	if len(results) != 1 || results[0].OK || results[0].Instance != "" || *results[0].Error != "nama host tidak ditemukan" {
		t.Fatalf("got %+v", results)
	}
	if results[0].Values == nil {
		t.Fatal("values must be an empty object, not null")
	}
	if got := s.Run(context.Background(), nil); got == nil || len(got) != 0 {
		t.Fatalf("no sources must give an empty slice, got %#v", got)
	}
}

func TestUnreachable(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	addr := ln.Addr().String()
	ln.Close()
	sources, _ := Parse("rest=http://" + addr + "/metrics")
	results := New(Options{Timeout: time.Second}).Run(context.Background(), sources)
	if results[0].OK || *results[0].Error != "koneksi ditolak" {
		t.Fatalf("got %+v", results[0])
	}
}
