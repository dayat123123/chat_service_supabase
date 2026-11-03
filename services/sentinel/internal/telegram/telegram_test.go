package telegram

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
	"unicode/utf16"
)

const token = "123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw"

type sent struct {
	path, contentType string
	body              map[string]any
}

func fakeBot(t *testing.T, reply func(chat string) (int, string, http.Header)) (*httptest.Server, func() []sent) {
	t.Helper()
	var mu sync.Mutex
	var calls []sent
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		var body map[string]any
		_ = json.Unmarshal(raw, &body)
		mu.Lock()
		calls = append(calls, sent{path: r.URL.Path, contentType: r.Header.Get("Content-Type"), body: body})
		mu.Unlock()
		status, text, header := reply(body["chat_id"].(string))
		for k, v := range header {
			w.Header()[k] = v
		}
		w.WriteHeader(status)
		_, _ = w.Write([]byte(text))
	}))
	t.Cleanup(server.Close)
	return server, func() []sent {
		mu.Lock()
		defer mu.Unlock()
		return append([]sent(nil), calls...)
	}
}

func TestSendPostsPlainTextWithoutPreview(t *testing.T) {
	server, calls := fakeBot(t, func(string) (int, string, http.Header) {
		return 200, `{"ok":true,"result":{"message_id":1}}`, nil
	})
	client := New(server.URL+"/", 5*time.Second, "olt-sentinel/test")
	if err := client.Send(context.Background(), token, "-100123", "🔴 KRITIS — db"); err != nil {
		t.Fatal(err)
	}
	got := calls()
	if len(got) != 1 || got[0].path != "/bot"+token+"/sendMessage" || got[0].contentType != "application/json" {
		t.Fatalf("calls = %+v", got)
	}
	want := map[string]any{"chat_id": "-100123", "text": "🔴 KRITIS — db", "disable_web_page_preview": true}
	if len(got[0].body) != len(want) || got[0].body["chat_id"] != want["chat_id"] || got[0].body["text"] != want["text"] ||
		got[0].body["disable_web_page_preview"] != true {
		t.Fatalf("body = %v", got[0].body)
	}
}

func TestErrorsAreClassified(t *testing.T) {
	cases := []struct {
		name       string
		status     int
		body       string
		header     http.Header
		retry      bool
		retryAfter time.Duration
		migrateTo  string
		text       string
	}{
		{"429 retry_after", 429, `{"ok":false,"error_code":429,"description":"Too Many Requests: retry after 30","parameters":{"retry_after":30}}`,
			nil, true, 30 * time.Second, "", "Telegram 429: Too Many Requests: retry after 30"},
		{"429 header", 429, `{"ok":false}`, http.Header{"Retry-After": {"7"}}, true, 7 * time.Second, "", "Telegram 429"},
		{"429 bare", 429, ``, nil, true, time.Second, "", "Telegram 429"},
		{"400 chat not found", 400, `{"ok":false,"error_code":400,"description":"Bad Request: chat not found"}`,
			nil, false, 0, "", "Telegram 400: Bad Request: chat not found"},
		{"403 blocked", 403, `{"ok":false,"error_code":403,"description":"Forbidden: bot was kicked from the group chat"}`,
			nil, false, 0, "", "Telegram 403: Forbidden: bot was kicked from the group chat"},
		{"400 migrated", 400, `{"ok":false,"error_code":400,"description":"Bad Request: group chat was upgraded to a supergroup chat","parameters":{"migrate_to_chat_id":-1001234567890}}`,
			nil, false, 0, "-1001234567890", "Telegram 400: Bad Request: group chat was upgraded to a supergroup chat"},
		{"401 token", 401, `{"ok":false,"error_code":401,"description":"Unauthorized"}`, nil, true, 0, "", "Telegram 401: Unauthorized"},
		{"404 token", 404, `{"ok":false,"error_code":404,"description":"Not Found"}`, nil, true, 0, "", "Telegram 404: Not Found"},
		{"500", 500, `{"ok":false,"error_code":500,"description":"Internal Server Error"}`, nil, true, 0, "", "Telegram 500: Internal Server Error"},
		{"502 html", 502, `<html>bad gateway</html>`, nil, true, 0, "", "Telegram 502"},
		{"200 not ok", 200, `{"ok":false}`, nil, true, 0, "", "Telegram 200"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			server, _ := fakeBot(t, func(string) (int, string, http.Header) { return tc.status, tc.body, tc.header })
			err := New(server.URL, 5*time.Second, "test").Send(context.Background(), token, "-1", "x")
			var e *Error
			if !errors.As(err, &e) {
				t.Fatalf("err = %v", err)
			}
			if e.Status != tc.status || e.Retry != tc.retry || e.RetryAfter != tc.retryAfter || e.MigrateTo != tc.migrateTo || e.Error() != tc.text {
				t.Fatalf("error = %+v (%q)", e, e.Error())
			}
		})
	}
}

func TestTokenNeverAppearsInErrors(t *testing.T) {
	server, _ := fakeBot(t, func(string) (int, string, http.Header) {
		return 400, `{"ok":false,"error_code":400,"description":"Bad Request: token ` + token + ` echoed"}`, nil
	})
	client := New(server.URL, time.Second, "test")
	err := client.Send(context.Background(), token, "-1", "x")
	if err == nil || strings.Contains(err.Error(), token) || strings.Contains(err.Error(), "AAHdq") {
		t.Fatalf("err = %v", err)
	}

	server.Close()
	err = client.Send(context.Background(), token, "-1", "x")
	var e *Error
	if !errors.As(err, &e) || !e.Retry || e.Status != 0 || !strings.HasPrefix(err.Error(), "Telegram tidak bisa dihubungi: ") {
		t.Fatalf("transport err = %v", err)
	}
	if strings.Contains(err.Error(), token) || strings.Contains(err.Error(), "/bot") || strings.Contains(err.Error(), "AAHdq") {
		t.Fatalf("transport error leaks the URL: %v", err)
	}

	slow := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.ReadAll(r.Body)
		select {
		case <-r.Context().Done():
		case <-time.After(5 * time.Second):
		}
	}))
	defer slow.Close()
	err = New(slow.URL, 100*time.Millisecond, "test").Send(context.Background(), token, "-1", "x")
	if !errors.As(err, &e) || !e.Retry || strings.Contains(err.Error(), token) || strings.Contains(err.Error(), "/bot") {
		t.Fatalf("timeout err = %v", err)
	}
}

func TestInvalidTokenIsNotSent(t *testing.T) {
	server, calls := fakeBot(t, func(string) (int, string, http.Header) { return 200, `{"ok":true}`, nil })
	for _, bad := range []string{"", "abc", "123/../x:AAAAAAAAAAAAAAAAAAAAAAAA", "123:short", "123:AAAAAAAAAAAAAAAAAAAAAAAA?x=1"} {
		err := New(server.URL, time.Second, "test").Send(context.Background(), bad, "-1", "x")
		var e *Error
		if !errors.As(err, &e) || !e.Retry || (bad != "" && strings.Contains(err.Error(), bad)) {
			t.Fatalf("token %q: err = %v", bad, err)
		}
	}
	if len(calls()) != 0 {
		t.Fatal("an invalid token must not reach the network")
	}
}

func TestClipKeepsTelegramsUTF16Limit(t *testing.T) {
	if Clip("short") != "short" {
		t.Fatal("short text changed")
	}
	long := strings.Repeat("🔴", 3000)
	clipped := Clip(long)
	if n := len(utf16.Encode([]rune(clipped))); n > MaxText || !strings.HasSuffix(clipped, "…") {
		t.Fatalf("clipped to %d UTF-16 units", n)
	}
	exact := strings.Repeat("a", MaxText)
	if Clip(exact) != exact {
		t.Fatal("text at the limit must stay intact")
	}
}
