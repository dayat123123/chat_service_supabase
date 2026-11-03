package dispatch

import (
	"context"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"

	"olt-social/sentinel/internal/email"
	"olt-social/sentinel/internal/store"
	"olt-social/sentinel/internal/telegram"
)

func TestChannelsAreLoadedOnceAndPolledByRevision(t *testing.T) {
	h := newHarness(t, channels())
	h.tick()
	h.tick()
	h.tick()
	if !reflect.DeepEqual(h.store.asked, []int64{store.UnknownRevision, 7, 7}) {
		t.Fatalf("asked = %v", h.store.asked)
	}
	if n := strings.Count(h.logs.String(), "Alert channels loaded"); n != 1 {
		t.Fatalf("loaded logged %d times", n)
	}
	m := h.d.Metrics()
	if m.Revision != 7 || !m.TelegramConfigured || !m.EmailConfigured {
		t.Fatalf("metrics = %+v", m)
	}

	next := channels()
	next.Revision, next.Email = 8, nil
	h.store.mu.Lock()
	h.store.channels = next
	h.store.mu.Unlock()
	h.tick()
	if m := h.d.Metrics(); m.Revision != 8 || m.EmailConfigured || !m.TelegramConfigured {
		t.Fatalf("metrics after change = %+v", m)
	}
}

func TestAlertsAreDeliveredAndReported(t *testing.T) {
	h := newHarness(t, channels())
	h.store.enqueue(
		store.Alert{ID: 1, Channel: "telegram", Subject: "[OLT] KRITIS: db", Text: "🔴 KRITIS — db"},
		store.Alert{ID: 2, Channel: "email", Subject: "[OLT] KRITIS: db", Text: "🔴 KRITIS — db\nSejak: x"},
		store.Alert{ID: 3, Channel: "sms", Subject: "s", Text: "t"},
		store.Alert{ID: 4, Channel: "email", Subject: "", Text: "first line\nsecond"},
	)
	h.tick()

	sends := h.telegram.sent()
	want := []telegramSend{{botToken, "-100111", "🔴 KRITIS — db"}, {botToken, "-100222", "🔴 KRITIS — db"}}
	if !reflect.DeepEqual(sends, want) {
		t.Fatalf("telegram = %+v", sends)
	}
	mails := h.email.sent()
	if len(mails) != 2 || mails[0].msg != (email.Message{Subject: "[OLT] KRITIS: db", Text: "🔴 KRITIS — db\nSejak: x"}) ||
		mails[1].msg.Subject != "first line" || mails[0].cfg.Password != "SMTP-PASSWORD-123" || mails[0].cfg.Security != "starttls" {
		t.Fatalf("email = %+v", mails)
	}
	report := h.store.lastReport()
	wantReport := []store.Result{
		{ID: 1, OK: true},
		{ID: 2, OK: true},
		{ID: 3, Error: "Kanal alert tidak dikenal: sms"},
		{ID: 4, OK: true},
	}
	if !reflect.DeepEqual(report, wantReport) {
		t.Fatalf("report = %+v", report)
	}
	m := h.d.Metrics()
	if m.Alerts["telegram"]["sent"] != 1 || m.Alerts["email"]["sent"] != 2 || m.Alerts["other"]["failed"] != 1 {
		t.Fatalf("metrics = %+v", m.Alerts)
	}
}

func TestAFullBatchIsClaimedAgainImmediately(t *testing.T) {
	h := newHarness(t, channels())
	var batch []store.Alert
	for i := range 20 {
		batch = append(batch, store.Alert{ID: int64(i + 1), Channel: "email", Subject: "s", Text: "t"})
	}
	h.store.enqueue(batch...)
	h.store.enqueue(store.Alert{ID: 99, Channel: "email", Subject: "s", Text: "t"})
	h.tick()
	if h.store.claims != 2 || len(h.email.sent()) != 21 {
		t.Fatalf("claims = %d, emails = %d", h.store.claims, len(h.email.sent()))
	}
}

func TestPartialTelegramDeliveryIsNotRepeated(t *testing.T) {
	h := newHarness(t, channels())
	h.telegram.reply("-100222", &telegram.Error{Status: 502, Retry: true})
	alert := store.Alert{ID: 5, Channel: "telegram", Text: "disk penuh"}
	h.store.enqueue(alert)
	h.tick()
	if r := h.store.lastReport(); len(r) != 1 || r[0].OK || !r[0].Retry || r[0].Error != "chat -100222: Telegram 502" {
		t.Fatalf("first report = %+v", r)
	}
	h.store.enqueue(alert)
	h.tick()
	if r := h.store.lastReport(); len(r) != 1 || !r[0].OK {
		t.Fatalf("second report = %+v", r)
	}
	var chats []string
	for _, s := range h.telegram.sent() {
		chats = append(chats, s.chat)
	}
	if !reflect.DeepEqual(chats, []string{"-100111", "-100222", "-100222"}) {
		t.Fatalf("chats = %v", chats)
	}
	if len(h.d.partial) != 0 {
		t.Fatalf("progress kept after success: %v", h.d.partial)
	}
}

func TestPermanentTelegramFailureStillTriesTheOtherChats(t *testing.T) {
	h := newHarness(t, channels())
	h.telegram.reply("-100111", &telegram.Error{Status: 400, Description: "Bad Request: chat not found"})
	h.store.enqueue(store.Alert{ID: 6, Channel: "telegram", Text: "x"})
	h.tick()
	r := h.store.lastReport()
	if len(r) != 1 || r[0].OK || r[0].Retry || r[0].Error != "chat -100111: Telegram 400: Bad Request: chat not found" {
		t.Fatalf("report = %+v", r)
	}
	if len(h.telegram.sent()) != 2 {
		t.Fatalf("sends = %+v", h.telegram.sent())
	}
	if !strings.Contains(h.logs.String(), "Alert delivery failed") {
		t.Fatal("failure not logged")
	}
}

func TestTelegramRetryAfterPausesFurtherSends(t *testing.T) {
	h := newHarness(t, channels())
	h.telegram.reply("-100111", &telegram.Error{Status: 429, Retry: true, RetryAfter: 30 * time.Second})
	h.store.enqueue(
		store.Alert{ID: 1, Channel: "telegram", Text: "a"},
		store.Alert{ID: 2, Channel: "telegram", Text: "b"},
	)
	h.tick()
	r := h.store.lastReport()
	if len(r) != 2 || r[0].OK || !r[0].Retry || !r[1].OK {
		t.Fatalf("report = %+v", r)
	}
	if !reflect.DeepEqual(h.slept, []time.Duration{30 * time.Second}) {
		t.Fatalf("slept = %v", h.slept)
	}
}

func TestTelegramPauseLongerThanTheLeaseReschedules(t *testing.T) {
	h := newHarness(t, channels())
	h.telegram.reply("-100111", &telegram.Error{Status: 429, Retry: true, RetryAfter: 2 * time.Minute})
	h.store.enqueue(
		store.Alert{ID: 1, Channel: "telegram", Text: "a"},
		store.Alert{ID: 2, Channel: "telegram", Text: "b"},
		store.Alert{ID: 3, Channel: "email", Subject: "s", Text: "c"},
	)
	h.tick()
	r := h.store.lastReport()
	if len(r) != 3 || !r[0].Retry || !r[1].Retry || !strings.HasPrefix(r[1].Error, "Telegram membatasi pengiriman (429)") || !r[2].OK {
		t.Fatalf("report = %+v", r)
	}
	if len(h.telegram.sent()) != 1 || len(h.slept) != 0 {
		t.Fatalf("sends = %+v slept = %v", h.telegram.sent(), h.slept)
	}
}

func TestMigratedGroupIsFollowed(t *testing.T) {
	h := newHarness(t, channels())
	h.telegram.reply("-100111", &telegram.Error{Status: 400, MigrateTo: "-100999"})
	h.store.enqueue(store.Alert{ID: 1, Channel: "telegram", Text: "a"})
	h.store.enqueue(store.Alert{ID: 2, Channel: "telegram", Text: "b"})
	h.tick()
	h.tick()
	var chats []string
	for _, s := range h.telegram.sent() {
		chats = append(chats, s.chat)
	}
	if !reflect.DeepEqual(chats, []string{"-100111", "-100999", "-100222", "-100999", "-100222"}) {
		t.Fatalf("chats = %v", chats)
	}
	if r := h.store.lastReport(); !r[0].OK {
		t.Fatalf("report = %+v", r)
	}
	if n := strings.Count(h.logs.String(), "upgraded to a supergroup"); n != 1 {
		t.Fatalf("migration logged %d times", n)
	}
}

func TestEmailErrorsAreClassified(t *testing.T) {
	h := newHarness(t, channels())
	h.email.replies = []error{
		&email.Error{Code: 550, Text: "SMTP RCPT TO a@olt.example ditolak: 550 no such user"},
		&email.Error{Code: 451, Text: "SMTP RCPT TO a@olt.example ditolak: 451 later", Retry: true},
		errors.New("unexpected"),
	}
	h.store.enqueue(
		store.Alert{ID: 1, Channel: "email", Subject: "s", Text: "t"},
		store.Alert{ID: 2, Channel: "email", Subject: "s", Text: "t"},
		store.Alert{ID: 3, Channel: "email", Subject: "s", Text: "t"},
	)
	h.tick()
	r := h.store.lastReport()
	if r[0].Retry || r[0].OK || !r[1].Retry || !r[2].Retry {
		t.Fatalf("report = %+v", r)
	}
}

func TestDisabledChannelFailsPermanently(t *testing.T) {
	h := newHarness(t, store.Channels{Revision: 1})
	h.store.enqueue(store.Alert{ID: 1, Channel: "telegram", Text: "a"}, store.Alert{ID: 2, Channel: "email", Text: "b"})
	h.tick()
	r := h.store.lastReport()
	if r[0].Retry || r[0].Error != "Kanal Telegram belum dikonfigurasi" || r[1].Retry || r[1].Error != "Kanal email belum dikonfigurasi" {
		t.Fatalf("report = %+v", r)
	}
}

func TestAlertsNotStartedBeforeTheLeaseDeadlineAreRescheduled(t *testing.T) {
	h := newHarness(t, channels())
	h.telegram.reply("-100111", &telegram.Error{Status: 429, Retry: true, RetryAfter: 30 * time.Second})
	h.d.opts.Sleep = func(_ context.Context, d time.Duration) bool {
		h.clock.advance(time.Minute)
		return true
	}
	h.store.enqueue(
		store.Alert{ID: 1, Channel: "telegram", Text: "a"},
		store.Alert{ID: 2, Channel: "telegram", Text: "b"},
	)
	h.d.sleep = h.d.opts.Sleep
	h.tick()
	r := h.store.lastReport()
	if r[1].OK || !r[1].Retry || r[1].Error != errorNotSent {
		t.Fatalf("report = %+v", r)
	}
}

func TestReportIsRetried(t *testing.T) {
	h := newHarness(t, channels())
	h.d.reportDelays = []time.Duration{time.Millisecond, time.Millisecond, time.Millisecond}
	h.store.reportFails = 2
	h.store.enqueue(store.Alert{ID: 1, Channel: "email", Subject: "s", Text: "t"})
	h.tick()
	if h.store.reportCalls != 3 || len(h.store.reports) != 1 {
		t.Fatalf("report calls = %d", h.store.reportCalls)
	}
	h.store.reportFails = 10
	h.store.enqueue(store.Alert{ID: 2, Channel: "email", Subject: "s", Text: "t"})
	h.tick()
	if !strings.Contains(h.logs.String(), "Could not report alert results") {
		t.Fatal("give-up not logged")
	}
}

func TestClaimErrorsAreLoggedOncePerState(t *testing.T) {
	h := newHarness(t, channels())
	h.tick()
	h.store.mu.Lock()
	h.store.batches = nil
	h.store.mu.Unlock()
	h.store.setDown(true)
	for range 5 {
		h.tick()
	}
	if n := strings.Count(h.logs.String(), "Could not read alert channels"); n != 1 {
		t.Fatalf("logged %d times", n)
	}
	h.store.setDown(false)
	h.tick()
	if !strings.Contains(h.logs.String(), "Reading alert channels works again") {
		t.Fatal("recovery not logged")
	}
}

func TestRunStopsWithTheContext(t *testing.T) {
	h := newHarness(t, channels())
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		h.d.Run(ctx)
		close(done)
	}()
	time.Sleep(50 * time.Millisecond)
	cancel()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("Run did not stop")
	}
}

func TestSecretsNeverReachLogsOrReports(t *testing.T) {
	bot := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.Contains(r.URL.Path, "-100111") || strings.HasSuffix(r.URL.Path, "/sendMessage") {
			w.WriteHeader(http.StatusBadRequest)
			_, _ = w.Write([]byte(`{"ok":false,"error_code":400,"description":"Bad Request: chat not found ` + botToken + `"}`))
		}
	}))
	defer bot.Close()
	closed := httptest.NewServer(http.NotFoundHandler())
	closed.Close()
	ln, _ := net.Listen("tcp", "127.0.0.1:0")
	smtpPort := ln.Addr().(*net.TCPAddr).Port
	ln.Close()

	for _, base := range []string{bot.URL, closed.URL} {
		h := newHarness(t, channels())
		h.d.opts.Telegram = telegram.New(base, time.Second, "test")
		h.d.opts.Email = email.New(email.Options{Timeout: time.Second})
		ch := channels()
		ch.Email.Host, ch.Email.Port, ch.Email.Security = "127.0.0.1", smtpPort, "tls"
		h.store.channels = ch
		h.store.enqueue(
			store.Alert{ID: 1, Channel: "telegram", Text: "message body"},
			store.Alert{ID: 2, Channel: "email", Subject: "s", Text: "message body"},
		)
		h.tick()
		h.failing = []string{"rest"}
		h.store.setDown(true)
		for range 30 {
			h.clock.advance(5 * time.Second)
			h.tick()
		}
		h.store.setDown(false)
		h.tick()

		logs := h.logs.String()
		reported := ""
		for _, report := range h.store.reports {
			for _, r := range report {
				reported += r.Error + "\n"
			}
		}
		for _, secret := range []string{botToken, "AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw", "SMTP-PASSWORD-123", "message body"} {
			if strings.Contains(logs, secret) || strings.Contains(reported, secret) {
				t.Fatalf("%q leaked (base %s)\nlogs:\n%s\nreported:\n%s", secret, base, logs, reported)
			}
		}
		if !strings.Contains(logs, "Alert delivery failed") || !strings.Contains(logs, "API/database unreachable") {
			t.Fatalf("expected failures to be logged:\n%s", logs)
		}
	}
}
