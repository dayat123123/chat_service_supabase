package fcm

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"olt-social/notifier/internal/push"
)

type fcmRequest struct {
	path, auth string
	body       map[string]any
}

type fcmServer struct {
	*httptest.Server
	mu       sync.Mutex
	requests []fcmRequest
	respond  func(n int, w http.ResponseWriter, r *http.Request)
}

func newFCMServer(t *testing.T, respond func(n int, w http.ResponseWriter, r *http.Request)) *fcmServer {
	t.Helper()
	fs := &fcmServer{respond: respond}
	fs.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		var body map[string]any
		_ = json.Unmarshal(raw, &body)
		fs.mu.Lock()
		fs.requests = append(fs.requests, fcmRequest{path: r.URL.Path, auth: r.Header.Get("Authorization"), body: body})
		n := len(fs.requests)
		fs.mu.Unlock()
		fs.respond(n, w, r)
	}))
	t.Cleanup(fs.Close)
	return fs
}

func (fs *fcmServer) seen() []fcmRequest {
	fs.mu.Lock()
	defer fs.mu.Unlock()
	return append([]fcmRequest(nil), fs.requests...)
}

func reply(status int, body string) func(int, http.ResponseWriter, *http.Request) {
	return func(_ int, w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(status)
		_, _ = w.Write([]byte(body))
	}
}

func configuredClient(t *testing.T, tokenURL, fcmURL string) *Client {
	t.Helper()
	dir := t.TempDir()
	write(t, filepath.Join(dir, "key.json"), accountJSON(t, map[string]any{"token_uri": tokenURL}), time.Now())
	client := newTestClient(dir, fcmURL)
	client.channelID = "chat"
	if status, _ := client.Reload(); !status.Configured || status.Problem != "" {
		t.Fatalf("status = %+v", status)
	}
	return client
}

var androidJob = push.Job{ID: 9, Token: "device-token-abcdef", Platform: push.Android, Kind: "chat.message", Title: "Rina", Priority: "high", TTLSeconds: 60}

func TestSendDeliversThroughFCM(t *testing.T) {
	tokens := newTokenServer(t)
	server := newFCMServer(t, reply(200, `{"name":"projects/demo-project/messages/0:1"}`))
	client := configuredClient(t, tokens.URL+"/token", server.URL)

	d := client.Send(context.Background(), androidJob)
	if d != (push.Delivery{Result: push.Result{ID: 9, Outcome: push.Sent}, Healthy: true}) {
		t.Fatalf("delivery = %+v", d)
	}
	requests := server.seen()
	if len(requests) != 1 || requests[0].path != "/v1/projects/demo-project/messages:send" || requests[0].auth != "Bearer tok-1" {
		t.Fatalf("requests = %+v", requests)
	}
	message := requests[0].body["message"].(map[string]any)
	if message["token"] != "device-token-abcdef" || message["data"].(map[string]any)["push_id"] != "9" ||
		message["android"].(map[string]any)["notification"].(map[string]any)["channel_id"] != "chat" {
		t.Fatalf("message = %v", message)
	}
}

func TestSendRefreshesARejectedAccessTokenOnce(t *testing.T) {
	tokens := newTokenServer(t)
	server := newFCMServer(t, func(n int, w http.ResponseWriter, r *http.Request) {
		if n == 1 {
			w.WriteHeader(401)
			_, _ = w.Write([]byte(fcmError("UNAUTHENTICATED", "", "Request had invalid authentication credentials.")))
			return
		}
		_, _ = w.Write([]byte(`{"name":"x"}`))
	})
	client := configuredClient(t, tokens.URL+"/token", server.URL)

	d := client.Send(context.Background(), androidJob)
	if d.Result.Outcome != push.Sent || d.Systemic || !d.Healthy {
		t.Fatalf("delivery = %+v", d)
	}
	requests := server.seen()
	if len(requests) != 2 || requests[0].auth != "Bearer tok-1" || requests[1].auth != "Bearer tok-2" || tokens.fetches.Load() != 2 {
		t.Fatalf("requests = %+v fetches = %d", requests, tokens.fetches.Load())
	}
}

func TestSendTreatsARepeated401AsSystemic(t *testing.T) {
	tokens := newTokenServer(t)
	server := newFCMServer(t, reply(401, fcmError("UNAUTHENTICATED", "", "Request had invalid authentication credentials.")))
	client := configuredClient(t, tokens.URL+"/token", server.URL)

	d := client.Send(context.Background(), androidJob)
	want := "Firebase menolak akses: Request had invalid authentication credentials."
	if !d.Systemic || d.Problem != want || d.Result.Outcome != push.Release || d.Healthy {
		t.Fatalf("delivery = %+v", d)
	}
	if len(server.seen()) != 2 || tokens.fetches.Load() != 2 {
		t.Fatalf("requests = %d fetches = %d", len(server.seen()), tokens.fetches.Load())
	}
}

func TestSendClassifiesFCMReplies(t *testing.T) {
	tokens := newTokenServer(t)
	server := newFCMServer(t, reply(404, fcmError("NOT_FOUND", "UNREGISTERED", "Requested entity was not found.")))
	client := configuredClient(t, tokens.URL+"/token", server.URL)

	first := client.Send(context.Background(), androidJob)
	if first.Result.Outcome != push.Invalid || first.Result.ID != 9 || !first.Healthy || first.Systemic {
		t.Fatalf("first = %+v", first)
	}
	second := client.Send(context.Background(), androidJob)
	if second.Result.Outcome != push.Invalid || second.Healthy {
		t.Fatalf("a cached token is not a fresh sign of health: %+v", second)
	}
}

func TestSendReportsServiceProblems(t *testing.T) {
	rejecting := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(400)
		_, _ = w.Write([]byte(`{"error":"invalid_grant","error_description":"Invalid JWT Signature."}`))
	}))
	defer rejecting.Close()
	tokens := newTokenServer(t)
	down := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	down.Close()
	slow := newFCMServer(t, func(_ int, w http.ResponseWriter, r *http.Request) {
		select {
		case <-r.Context().Done():
		case <-time.After(2 * time.Second):
		}
	})
	healthy := newFCMServer(t, reply(200, `{}`))

	cases := []struct {
		name     string
		tokenURL string
		fcmURL   string
		timeout  time.Duration
		want     string
	}{
		{"credentials rejected", rejecting.URL, healthy.URL, time.Second, "Firebase menolak kredensial: Invalid JWT Signature."},
		{"token endpoint unreachable", down.URL, healthy.URL, time.Second, "Tidak bisa menghubungi Google untuk token Firebase"},
		{"fcm unreachable", tokens.URL, down.URL, time.Second, "Tidak bisa menghubungi Firebase"},
		{"fcm timeout", tokens.URL, slow.URL, 100 * time.Millisecond, "Tidak bisa menghubungi Firebase"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			client := configuredClient(t, tc.tokenURL, tc.fcmURL)
			client.sendTimeout = tc.timeout
			d := client.Send(context.Background(), androidJob)
			if !d.Systemic || d.Problem != tc.want || d.Result.Outcome != push.Release || d.Result.ID != 9 || d.Healthy {
				t.Fatalf("delivery = %+v", d)
			}
		})
	}
}

func TestSendReleasesWithoutBlamingFirebaseWhenStopped(t *testing.T) {
	tokens := newTokenServer(t)
	server := newFCMServer(t, func(_ int, w http.ResponseWriter, r *http.Request) {
		<-r.Context().Done()
	})
	client := configuredClient(t, tokens.URL+"/token", server.URL)
	ctx, cancel := context.WithCancel(context.Background())
	time.AfterFunc(50*time.Millisecond, cancel)

	d := client.Send(ctx, androidJob)
	if d.Systemic || d.Problem != "" || d.Result.Outcome != push.Release || d.Result.Error != errorStopped {
		t.Fatalf("delivery = %+v", d)
	}
}

func TestSendWithoutCredentialsReleasesTheJob(t *testing.T) {
	client := newTestClient(filepath.Join(t.TempDir(), "absent"), "http://fcm.invalid")
	client.Reload()

	d := client.Send(context.Background(), androidJob)
	if d.Systemic || d.Result.Outcome != push.Release || d.Result.Error != errorNotConfigured {
		t.Fatalf("delivery = %+v", d)
	}
}

func TestSendFailsJobsForUnknownPlatforms(t *testing.T) {
	tokens := newTokenServer(t)
	server := newFCMServer(t, reply(200, `{}`))
	client := configuredClient(t, tokens.URL+"/token", server.URL)
	job := androidJob
	job.Platform = "blackberry"

	d := client.Send(context.Background(), job)
	if d.Result.Outcome != push.Failed || d.Systemic || len(server.seen()) != 0 {
		t.Fatalf("delivery = %+v", d)
	}
}
