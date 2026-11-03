package moderation

import (
	"bytes"
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

func at(v float64) *float64 {
	return &v
}

func TestDecide(t *testing.T) {
	th := Thresholds{Revision: 3, Limits: map[string]Limit{
		"porn":   {Hold: at(0.45), Block: at(0.9)},
		"hentai": {Hold: at(0.55), Block: at(0.95)},
		"sexy":   {Hold: at(0.75)},
	}}
	cases := []struct {
		scores   map[string]float64
		verdict  Verdict
		category string
	}{
		{map[string]float64{"neutral": 0.99, "porn": 0.01}, Allow, "porn"},
		{map[string]float64{"porn": 0.45}, Hold, "porn"},
		{map[string]float64{"porn": 0.5, "sexy": 0.8}, Hold, "sexy"},
		{map[string]float64{"porn": 0.92, "hentai": 0.96}, Block, "hentai"},
		{map[string]float64{"porn": 0.91, "sexy": 0.99}, Block, "porn"},
		{map[string]float64{"sexy": 1}, Hold, "sexy"},
		{map[string]float64{"neutral": 1}, Allow, ""},
	}
	for _, tc := range cases {
		d := Decide(tc.scores, th)
		if d.Verdict != tc.verdict || d.Category != tc.category {
			t.Fatalf("%v: %+v", tc.scores, d)
		}
	}
	if d := Decide(map[string]float64{"porn": 1}, Thresholds{}); d.Verdict != Allow {
		t.Fatalf("no thresholds: %+v", d)
	}
}

func TestClassifyMapsReplies(t *testing.T) {
	var got struct {
		mime, id string
		body     []byte
	}
	reply := func(w http.ResponseWriter, r *http.Request) {}
	var mu sync.Mutex
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		mu.Lock()
		got.mime, got.id, got.body = r.Header.Get("Content-Type"), r.Header.Get("X-Request-Id"), body
		handler := reply
		mu.Unlock()
		if r.URL.Path != "/classify" || r.Method != http.MethodPost {
			w.WriteHeader(404)
			return
		}
		handler(w, r)
	}))
	defer srv.Close()
	c := NewClient(srv.URL, time.Second, 2)
	set := func(status int, body string) {
		mu.Lock()
		reply = func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(status)
			_, _ = w.Write([]byte(body))
		}
		mu.Unlock()
	}

	set(200, `{"model":"m@1","labels":["neutral","porn"],"scores":{"neutral":0.9,"porn":0.1}}`)
	r, err := c.Classify(context.Background(), "image/png", []byte("img"), "req-1")
	mu.Lock()
	if err != nil || r.Model != "m@1" || r.Scores["porn"] != 0.1 || got.mime != "image/png" || got.id != "req-1" ||
		!bytes.Equal(got.body, []byte("img")) {
		t.Fatalf("r = %+v err = %v got = %+v", r, err, got)
	}
	mu.Unlock()
	cases := map[string]struct {
		status int
		body   string
		want   error
	}{
		"model missing": {503, `{"code":"model_missing","message":"x"}`, ErrModelMissing},
		"busy":          {503, `{"code":"busy"}`, ErrUnavailable},
		"unreadable":    {422, `{"code":"invalid_image"}`, ErrUnreadable},
		"unsupported":   {415, `{"code":"unsupported_type"}`, ErrUnreadable},
		"server error":  {500, `oops`, ErrUnavailable},
		"bad json":      {200, `{`, ErrUnavailable},
		"no scores":     {200, `{"model":"m","scores":{}}`, ErrUnavailable},
		"bad score":     {200, `{"model":"m","scores":{"porn":1.5}}`, ErrUnavailable},
	}
	for name, tc := range cases {
		set(tc.status, tc.body)
		if _, err := c.Classify(context.Background(), "image/png", []byte("img"), "r"); !errors.Is(err, tc.want) {
			t.Fatalf("%s: err = %v", name, err)
		}
	}
	mu.Lock()
	reply = func(w http.ResponseWriter, r *http.Request) { <-r.Context().Done() }
	mu.Unlock()
	slow := NewClient(srv.URL, 50*time.Millisecond, 2)
	if _, err := slow.Classify(context.Background(), "image/png", []byte("img"), "r"); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("timeout: err = %v", err)
	}
	srv.Close()
	if _, err := c.Classify(context.Background(), "image/png", []byte("img"), "r"); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("closed: err = %v", err)
	}
	if err := c.Ping(context.Background()); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("ping closed: err = %v", err)
	}
}

func TestPing(t *testing.T) {
	var mu sync.Mutex
	status, body := 200, `{"model":"m"}`
	set := func(s int, b string) {
		mu.Lock()
		status, body = s, b
		mu.Unlock()
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/status" {
			w.WriteHeader(404)
			return
		}
		mu.Lock()
		s, b := status, body
		mu.Unlock()
		w.WriteHeader(s)
		_, _ = w.Write([]byte(b))
	}))
	defer srv.Close()
	c := NewClient(srv.URL, time.Second, 2)
	if err := c.Ping(context.Background()); err != nil {
		t.Fatal(err)
	}
	set(503, `{"code":"model_missing"}`)
	if err := c.Ping(context.Background()); !errors.Is(err, ErrModelMissing) {
		t.Fatalf("err = %v", err)
	}
	set(500, ``)
	if err := c.Ping(context.Background()); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("err = %v", err)
	}
}

type fakeStore struct {
	mu      sync.Mutex
	known   []int64
	replies []Config
	err     error
}

func (f *fakeStore) ModerationConfig(_ context.Context, known int64) (Config, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.known = append(f.known, known)
	if f.err != nil {
		return Config{}, f.err
	}
	r := f.replies[0]
	if len(f.replies) > 1 {
		f.replies = f.replies[1:]
	}
	return r, nil
}

func TestPolicyLoadsAndFollowsRevisions(t *testing.T) {
	var logs bytes.Buffer
	store := &fakeStore{err: errors.New("rest down")}
	changed := 0
	p := NewPolicy(store, slog.New(slog.NewJSONHandler(&logs, nil)), time.Hour, func() { changed++ })
	if _, ok := p.Current(); ok {
		t.Fatal("nothing loaded yet")
	}
	p.Refresh(context.Background())
	p.Refresh(context.Background())
	if _, ok := p.Current(); ok || strings.Count(logs.String(), "could not be loaded") != 1 {
		t.Fatalf("logs = %s", logs.String())
	}
	store.err = nil
	store.replies = []Config{
		{Revision: 4, Limits: map[string]Limit{"porn": {Block: at(0.9)}}},
		{Revision: 4, Unchanged: true},
		{Revision: 5, Limits: map[string]Limit{"porn": {Block: at(0.8)}}},
	}
	p.Refresh(context.Background())
	th, ok := p.Current()
	if !ok || th.Revision != 4 || *th.Limits["porn"].Block != 0.9 || changed != 1 {
		t.Fatalf("th = %+v changed = %d", th, changed)
	}
	p.Refresh(context.Background())
	p.Refresh(context.Background())
	th, _ = p.Current()
	if th.Revision != 5 || *th.Limits["porn"].Block != 0.8 || changed != 1 {
		t.Fatalf("th = %+v changed = %d", th, changed)
	}
	if want := []int64{UnknownRevision, UnknownRevision, UnknownRevision, 4, 4}; len(store.known) != len(want) {
		t.Fatalf("known = %v", store.known)
	} else {
		for i := range want {
			if store.known[i] != want[i] {
				t.Fatalf("known = %v", store.known)
			}
		}
	}
	store.err = errors.New("rest down again")
	p.Refresh(context.Background())
	if th, ok := p.Current(); !ok || th.Revision != 5 {
		t.Fatal("the last thresholds stay in use while the database is unreachable")
	}
}

func TestPolicyRunStopsWithTheContext(t *testing.T) {
	store := &fakeStore{replies: []Config{{Revision: 1, Limits: map[string]Limit{}}}}
	p := NewPolicy(store, slog.New(slog.NewJSONHandler(io.Discard, nil)), 10*time.Millisecond, nil)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		p.Run(ctx)
		close(done)
	}()
	time.Sleep(50 * time.Millisecond)
	cancel()
	<-done
	store.mu.Lock()
	defer store.mu.Unlock()
	if len(store.known) < 2 {
		t.Fatalf("refreshes = %d", len(store.known))
	}
}
