package fcm

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
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
	client := newTestClient(tokenURL, fcmURL)
	client.channelID = "chat"
	if status := client.Load(accountJSON(t, nil)); !status.Configured || status.Problem != "" {
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
	client := newTestClient("http://google.invalid/token", "http://fcm.invalid")

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

func TestVerifyChecksTheKeyWithGoogleAndFCM(t *testing.T) {
	tokens := newTokenServer(t)
	server := newFCMServer(t, reply(400, fcmError("INVALID_ARGUMENT", "INVALID_ARGUMENT", "The registration token is not a valid FCM registration token")))
	client := configuredClient(t, tokens.URL+"/token", server.URL)

	if err := client.Verify(context.Background()); err != nil {
		t.Fatalf("err = %v", err)
	}
	requests := server.seen()
	if len(requests) != 1 || requests[0].auth != "Bearer tok-1" || requests[0].path != "/v1/projects/demo-project/messages:send" ||
		requests[0].body["validate_only"] != true || requests[0].body["message"].(map[string]any)["token"] != "olt-credentials-check" {
		t.Fatalf("requests = %+v", requests)
	}
}

func TestVerifyExplainsWhatIsWrong(t *testing.T) {
	rejecting := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(400)
		_, _ = w.Write([]byte(`{"error":"invalid_grant","error_description":"Invalid JWT Signature."}`))
	}))
	defer rejecting.Close()
	down := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	down.Close()
	tokens := newTokenServer(t)
	cases := []struct {
		name     string
		tokenURL string
		respond  func(int, http.ResponseWriter, *http.Request)
		want     string
	}{
		{"accepted", tokens.URL, reply(200, `{"name":"projects/demo-project/messages/fake"}`), ""},
		{"key revoked", rejecting.URL, reply(200, `{}`), "Firebase menolak kredensial: Invalid JWT Signature."},
		{"google unreachable", down.URL, reply(200, `{}`), "Tidak bisa menghubungi Google untuk token Firebase"},
		{"api disabled", tokens.URL, reply(403, fcmError("PERMISSION_DENIED", "", "Firebase Cloud Messaging API has not been used in project demo-project")),
			"Firebase menolak akses: Firebase Cloud Messaging API has not been used in project demo-project"},
		{"access token refused twice", tokens.URL, reply(401, fcmError("UNAUTHENTICATED", "", "Request had invalid authentication credentials.")),
			"Firebase menolak akses: Request had invalid authentication credentials."},
		{"fcm busy", tokens.URL, reply(503, fcmError("UNAVAILABLE", "UNAVAILABLE", "The service is currently unavailable.")),
			"Firebase sementara gagal (UNAVAILABLE): The service is currently unavailable."},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			server := newFCMServer(t, tc.respond)
			client := configuredClient(t, tc.tokenURL, server.URL)
			err := client.Verify(context.Background())
			if got := fmt.Sprint(err); (tc.want == "" && err != nil) || (tc.want != "" && got != tc.want) {
				t.Fatalf("err = %v, want %q", err, tc.want)
			}
		})
	}
}

func TestVerifyReportsAnUnreachableFCM(t *testing.T) {
	tokens := newTokenServer(t)
	down := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	down.Close()
	client := configuredClient(t, tokens.URL+"/token", down.URL)

	if err := client.Verify(context.Background()); fmt.Sprint(err) != "Tidak bisa menghubungi Firebase" {
		t.Fatalf("err = %v", err)
	}
}

func TestVerifyWithoutCredentials(t *testing.T) {
	client := newTestClient("http://google.invalid/token", "http://fcm.invalid")
	if err := client.Verify(context.Background()); fmt.Sprint(err) != errorNotConfigured {
		t.Fatalf("err = %v", err)
	}
}

func TestVerifyStopsQuietlyWhenCancelled(t *testing.T) {
	tokens := newTokenServer(t)
	server := newFCMServer(t, func(_ int, w http.ResponseWriter, r *http.Request) {
		<-r.Context().Done()
	})
	client := configuredClient(t, tokens.URL+"/token", server.URL)
	ctx, cancel := context.WithCancel(context.Background())
	time.AfterFunc(50*time.Millisecond, cancel)

	if err := client.Verify(ctx); !errors.Is(err, context.Canceled) {
		t.Fatalf("err = %v", err)
	}
}
