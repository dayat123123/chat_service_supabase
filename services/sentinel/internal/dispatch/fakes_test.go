package dispatch

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"slices"
	"sync"
	"testing"
	"time"

	"olt-social/sentinel/internal/email"
	"olt-social/sentinel/internal/outage"
	"olt-social/sentinel/internal/store"
)

const botToken = "123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw"

var errUnreachable = &store.Error{Fn: "alert_channels", Err: errors.New("dial tcp 10.0.0.5:3000: connect: connection refused")}

type clock struct {
	mu  sync.Mutex
	now time.Time
}

func (c *clock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.now
}

func (c *clock) advance(d time.Duration) {
	c.mu.Lock()
	c.now = c.now.Add(d)
	c.mu.Unlock()
}

type fakeStore struct {
	mu          sync.Mutex
	observe     func(error)
	channels    store.Channels
	down        bool
	asked       []int64
	batches     [][]store.Alert
	claims      int
	reportFails int
	reportCalls int
	reports     [][]store.Result
}

func (s *fakeStore) result(err error) error {
	if s.observe != nil {
		s.observe(err)
	}
	return err
}

func (s *fakeStore) Channels(_ context.Context, known int64) (store.Channels, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.asked = append(s.asked, known)
	if s.down {
		return store.Channels{}, s.result(errUnreachable)
	}
	if known == s.channels.Revision {
		return store.Channels{Revision: known, Unchanged: true}, s.result(nil)
	}
	return s.channels, s.result(nil)
}

func (s *fakeStore) Claim(_ context.Context, instance string, limit int, lease time.Duration) ([]store.Alert, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.claims++
	if s.down {
		return nil, s.result(errUnreachable)
	}
	if instance != "sentinel-test" || limit != 20 || lease != time.Minute {
		return nil, s.result(errors.New("unexpected claim arguments"))
	}
	if len(s.batches) == 0 {
		return nil, s.result(nil)
	}
	batch := s.batches[0]
	s.batches = s.batches[1:]
	return batch, s.result(nil)
}

func (s *fakeStore) Report(_ context.Context, _ string, results []store.Result) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.reportCalls++
	if s.reportFails > 0 {
		s.reportFails--
		return 0, s.result(&store.Error{Fn: "alert_report", Status: 503})
	}
	s.reports = append(s.reports, slices.Clone(results))
	return len(results), s.result(nil)
}

func (s *fakeStore) enqueue(alerts ...store.Alert) {
	s.mu.Lock()
	s.batches = append(s.batches, alerts)
	s.mu.Unlock()
}

func (s *fakeStore) setDown(down bool) {
	s.mu.Lock()
	s.down = down
	s.mu.Unlock()
}

func (s *fakeStore) lastReport() []store.Result {
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.reports) == 0 {
		return nil
	}
	return s.reports[len(s.reports)-1]
}

type telegramSend struct {
	token, chat, text string
}

type fakeTelegram struct {
	mu      sync.Mutex
	sends   []telegramSend
	replies map[string][]error
}

func (f *fakeTelegram) Send(_ context.Context, token, chat, text string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.sends = append(f.sends, telegramSend{token, chat, text})
	queue := f.replies[chat]
	if len(queue) == 0 {
		return nil
	}
	f.replies[chat] = queue[1:]
	return queue[0]
}

func (f *fakeTelegram) reply(chat string, errs ...error) {
	f.mu.Lock()
	if f.replies == nil {
		f.replies = map[string][]error{}
	}
	f.replies[chat] = append(f.replies[chat], errs...)
	f.mu.Unlock()
}

func (f *fakeTelegram) sent() []telegramSend {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.sends)
}

type emailSend struct {
	cfg email.Config
	msg email.Message
}

type fakeEmail struct {
	mu      sync.Mutex
	sends   []emailSend
	replies []error
}

func (f *fakeEmail) Send(_ context.Context, cfg email.Config, msg email.Message) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.sends = append(f.sends, emailSend{cfg, msg})
	if len(f.replies) == 0 {
		return nil
	}
	err := f.replies[0]
	f.replies = f.replies[1:]
	return err
}

func (f *fakeEmail) sent() []emailSend {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.sends)
}

type syncBuffer struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (s *syncBuffer) Write(p []byte) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.Write(p)
}

func (s *syncBuffer) String() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.String()
}

type harness struct {
	t        *testing.T
	d        *Dispatcher
	store    *fakeStore
	telegram *fakeTelegram
	email    *fakeEmail
	clock    *clock
	detector *outage.Detector
	logs     *syncBuffer
	slept    []time.Duration
	failing  []string
}

func channels() store.Channels {
	return store.Channels{
		Revision: 7,
		Telegram: &store.Telegram{BotToken: botToken, ChatIDs: []string{"-100111", "-100222"}},
		Email: &store.Email{Host: "smtp.olt.example", Port: 587, Security: "starttls", Username: "ops",
			Password: "SMTP-PASSWORD-123", From: "ops@olt.example", To: []string{"a@olt.example"}},
	}
}

func newHarness(t *testing.T, ch store.Channels) *harness {
	t.Helper()
	h := &harness{
		t:        t,
		telegram: &fakeTelegram{},
		email:    &fakeEmail{},
		clock:    &clock{now: time.Date(2026, 11, 3, 7, 0, 0, 0, time.UTC)},
		logs:     &syncBuffer{},
	}
	h.detector = outage.New(2*time.Minute, h.clock.Now, store.Unreachable)
	h.store = &fakeStore{channels: ch, observe: h.detector.Observe}
	h.d = New(Options{
		Store:           h.store,
		Telegram:        h.telegram,
		Email:           h.email,
		Outages:         h.detector,
		Log:             slog.New(slog.NewJSONHandler(h.logs, &slog.HandlerOptions{Level: slog.LevelDebug})),
		Instance:        "sentinel-test",
		BatchSize:       20,
		Lease:           time.Minute,
		PollInterval:    5 * time.Second,
		SendTimeout:     20 * time.Second,
		ShutdownTimeout: time.Second,
		FailingProbes:   func() []string { return h.failing },
		Now:             h.clock.Now,
		Sleep: func(_ context.Context, d time.Duration) bool {
			h.slept = append(h.slept, d)
			h.clock.advance(d)
			return true
		},
	})
	return h
}

func (h *harness) tick() {
	h.d.Tick(context.Background(), context.Background())
}
