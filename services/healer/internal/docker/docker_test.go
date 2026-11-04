package docker

import (
	"context"
	"encoding/json"
	"net"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

type seen struct {
	method, path, filters string
}

func fakeEngine(t *testing.T, handler func(w http.ResponseWriter, r *http.Request)) (*Client, *[]seen) {
	t.Helper()
	var mu sync.Mutex
	var calls []seen
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		calls = append(calls, seen{r.Method, r.URL.Path, r.URL.Query().Get("filters")})
		mu.Unlock()
		handler(w, r)
	}))
	t.Cleanup(server.Close)
	return New(Options{BaseURL: server.URL, Transport: http.DefaultTransport}), &calls
}

const fullID = "3f1c0b7e9a2d4c5b6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5"

func TestListFiltersByLabelsAndKeepsOnlyValidIDs(t *testing.T) {
	client, calls := fakeEngine(t, func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`[
			{"Id":"` + fullID + `","Names":["/olt-social-rest-1"],"Labels":{"com.docker.compose.project":"olt-social","com.docker.compose.service":"rest","olt.autoheal":"true"}},
			{"Id":"../../etc","Names":["/evil"],"Labels":{}}
		]`))
	})
	got, err := client.List(context.Background(), "com.docker.compose.project=olt-social")
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 1 || got[0].ID != fullID || got[0].Name != "olt-social-rest-1" || got[0].Service != "rest" || got[0].Labels["olt.autoheal"] != "true" {
		t.Fatalf("containers = %+v", got)
	}
	c := (*calls)[0]
	var filters map[string][]string
	if err := json.Unmarshal([]byte(c.filters), &filters); err != nil {
		t.Fatal(err)
	}
	if c.method != http.MethodGet || c.path != "/containers/json" || len(filters["label"]) != 1 || filters["label"][0] != "com.docker.compose.project=olt-social" {
		t.Fatalf("call = %+v filters = %v", c, filters)
	}
}

func TestInspectReadsHealthStartTimeAndLastCheck(t *testing.T) {
	client, calls := fakeEngine(t, func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"Id":"` + fullID + `","Name":"/olt-social-rest-1",
			"State":{"Running":true,"StartedAt":"2026-11-04T03:00:00.123456789Z",
			  "Health":{"Status":"unhealthy","Log":[{"ExitCode":0,"Output":"ok"},{"ExitCode":1,"Output":"  connection\nrefused  "}]}},
			"Config":{"Labels":{"com.docker.compose.service":"rest","com.docker.compose.project":"olt-social"}}}`))
	})
	d, err := client.Inspect(context.Background(), fullID)
	if err != nil {
		t.Fatal(err)
	}
	if d.Name != "olt-social-rest-1" || d.Service != "rest" || !d.Running || d.Health != "unhealthy" ||
		d.Output != "connection refused" || !d.StartedAt.Equal(time.Date(2026, 11, 4, 3, 0, 0, 123456789, time.UTC)) {
		t.Fatalf("detail = %+v", d)
	}
	if got := (*calls)[0].path; got != "/containers/"+fullID+"/json" {
		t.Fatalf("path = %s", got)
	}
}

func TestInspectWithoutHealthcheck(t *testing.T) {
	client, _ := fakeEngine(t, func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"Id":"` + fullID + `","Name":"/x","State":{"Running":true,"StartedAt":"0001-01-01T00:00:00Z"},"Config":{"Labels":null}}`))
	})
	d, err := client.Inspect(context.Background(), "3f1c0b7e9a2d")
	if err != nil {
		t.Fatal(err)
	}
	if d.Health != "" || d.Output != "" {
		t.Fatalf("detail = %+v", d)
	}
}

func TestInspectRejectsUnsafeReferences(t *testing.T) {
	client, calls := fakeEngine(t, func(http.ResponseWriter, *http.Request) {})
	for _, ref := range []string{"", "../images/json", "a/b", "x?y", strings.Repeat("a", 200)} {
		if _, err := client.Inspect(context.Background(), ref); err == nil {
			t.Fatalf("reference %q accepted", ref)
		}
	}
	if len(*calls) != 0 {
		t.Fatalf("calls = %+v", *calls)
	}
}

func TestRestartPostsAndAcceptsNoContent(t *testing.T) {
	client, calls := fakeEngine(t, func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})
	if err := client.Restart(context.Background(), fullID); err != nil {
		t.Fatal(err)
	}
	c := (*calls)[0]
	if c.method != http.MethodPost || c.path != "/containers/"+fullID+"/restart" {
		t.Fatalf("call = %+v", c)
	}
	if err := client.Restart(context.Background(), "olt-social-rest-1"); err == nil {
		t.Fatal("restart by name accepted; only full ids are restarted")
	}
}

func TestErrorsCarryStatusAndEngineMessage(t *testing.T) {
	client, _ := fakeEngine(t, func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(`{"message":"No such container: abc"}`))
	})
	_, err := client.Inspect(context.Background(), fullID)
	if !NotFound(err) || !strings.Contains(err.Error(), "status 404: No such container") {
		t.Fatalf("err = %v", err)
	}
	if NotFound(nil) {
		t.Fatal("nil is not found")
	}
}

func TestOversizedResponsesAreRejected(t *testing.T) {
	client, _ := fakeEngine(t, func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("[" + strings.Repeat(" ", maxResponse+10) + "]"))
	})
	if _, err := client.List(context.Background()); err == nil || !strings.Contains(err.Error(), "larger than") {
		t.Fatalf("err = %v", err)
	}
}

func TestTalksOverAUnixSocket(t *testing.T) {
	socket := filepath.Join(t.TempDir(), "docker.sock")
	listener, err := net.Listen("unix", socket)
	if err != nil {
		t.Skipf("unix sockets unavailable: %v", err)
	}
	server := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/containers/json" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		_, _ = w.Write([]byte(`[]`))
	}), ReadHeaderTimeout: time.Second}
	go func() { _ = server.Serve(listener) }()
	t.Cleanup(func() { _ = server.Close() })
	client := New(Options{Socket: socket, RequestTimeout: 2 * time.Second})
	got, err := client.List(context.Background(), "a=b")
	if err != nil || len(got) != 0 {
		t.Fatalf("got = %v err = %v", got, err)
	}
}
