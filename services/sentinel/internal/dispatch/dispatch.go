package dispatch

import (
	"context"
	"errors"
	"log/slog"
	"maps"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"olt-social/sentinel/internal/email"
	"olt-social/sentinel/internal/logstate"
	"olt-social/sentinel/internal/outage"
	"olt-social/sentinel/internal/store"
	"olt-social/sentinel/internal/telegram"
)

const (
	ChannelTelegram = "telegram"
	ChannelEmail    = "email"
	ChannelOther    = "other"

	Sent   = "sent"
	Retry  = "retry"
	Failed = "failed"

	leaseMargin   = 3 * time.Second
	reportTimeout = 15 * time.Second
	partialTTL    = 24 * time.Hour
	maxError      = 500

	errorNotSent = "Belum sempat dikirim, dijadwalkan ulang"
)

var (
	Channels = []string{ChannelTelegram, ChannelEmail, ChannelOther}
	Outcomes = []string{Sent, Retry, Failed}
)

type Store interface {
	Channels(ctx context.Context, known int64) (store.Channels, error)
	Claim(ctx context.Context, instance string, limit int, lease time.Duration) ([]store.Alert, error)
	Report(ctx context.Context, instance string, results []store.Result) (int, error)
}

type Telegram interface {
	Send(ctx context.Context, token, chatID, text string) error
}

type Email interface {
	Send(ctx context.Context, cfg email.Config, msg email.Message) error
}

type Outages interface {
	Check()
	Events() []outage.Event
}

type Options struct {
	Store           Store
	Telegram        Telegram
	Email           Email
	Outages         Outages
	Log             *slog.Logger
	Instance        string
	BatchSize       int
	Lease           time.Duration
	PollInterval    time.Duration
	SendTimeout     time.Duration
	ShutdownTimeout time.Duration
	FailingProbes   func() []string
	Now             func() time.Time
	Sleep           func(ctx context.Context, d time.Duration) bool
}

type Snapshot struct {
	Alerts             map[string]map[string]uint64
	Notices            map[string]uint64
	Revision           int64
	TelegramConfigured bool
	EmailConfigured    bool
}

type progress struct {
	chats   map[string]bool
	touched time.Time
}

type Dispatcher struct {
	opts         Options
	log          *slog.Logger
	now          func() time.Time
	sleep        func(ctx context.Context, d time.Duration) bool
	reportDelays []time.Duration
	readLatch    logstate.Latch
	claimLatch   logstate.Latch

	mu          sync.Mutex
	revision    int64
	channels    store.Channels
	pausedUntil time.Time
	migrated    map[string]string
	partial     map[int64]*progress
	notices     []*notice
	announced   bool
	alerts      map[string]map[string]uint64
	noticeStats map[string]uint64
}

func New(opts Options) *Dispatcher {
	now := opts.Now
	if now == nil {
		now = time.Now
	}
	sleep := opts.Sleep
	if sleep == nil {
		sleep = wait
	}
	if opts.FailingProbes == nil {
		opts.FailingProbes = func() []string { return nil }
	}
	alerts := map[string]map[string]uint64{}
	for _, ch := range Channels {
		alerts[ch] = map[string]uint64{}
	}
	return &Dispatcher{
		opts:         opts,
		log:          opts.Log,
		now:          now,
		sleep:        sleep,
		reportDelays: []time.Duration{250 * time.Millisecond, 500 * time.Millisecond, time.Second},
		revision:     store.UnknownRevision,
		migrated:     map[string]string{},
		partial:      map[int64]*progress{},
		alerts:       alerts,
		noticeStats:  map[string]uint64{},
	}
}

func (d *Dispatcher) Run(ctx context.Context) {
	work, cancelWork := context.WithCancel(context.WithoutCancel(ctx))
	defer cancelWork()
	go d.enforceShutdown(ctx, work, cancelWork)
	timer := time.NewTimer(0)
	defer timer.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-timer.C:
		}
		d.Tick(ctx, work)
		timer.Reset(d.opts.PollInterval)
	}
}

func (d *Dispatcher) Tick(ctx, work context.Context) {
	if err := d.refresh(ctx); err == nil || !store.Unreachable(err) {
		for ctx.Err() == nil {
			claimed, err := d.cycle(ctx, work)
			if err != nil || claimed < d.opts.BatchSize {
				break
			}
		}
	}
	if ctx.Err() != nil {
		return
	}
	d.opts.Outages.Check()
	d.handle(d.opts.Outages.Events())
	d.deliverNotices(work)
}

func (d *Dispatcher) Metrics() Snapshot {
	d.mu.Lock()
	defer d.mu.Unlock()
	alerts := make(map[string]map[string]uint64, len(d.alerts))
	for ch, counts := range d.alerts {
		alerts[ch] = maps.Clone(counts)
	}
	return Snapshot{
		Alerts:             alerts,
		Notices:            maps.Clone(d.noticeStats),
		Revision:           d.revision,
		TelegramConfigured: d.channels.Telegram != nil,
		EmailConfigured:    d.channels.Email != nil,
	}
}

func (d *Dispatcher) enforceShutdown(ctx, work context.Context, cancelWork context.CancelFunc) {
	select {
	case <-work.Done():
		return
	case <-ctx.Done():
	}
	timer := time.NewTimer(d.opts.ShutdownTimeout)
	defer timer.Stop()
	select {
	case <-timer.C:
		d.log.Warn("Shutdown timeout reached; abandoning alert deliveries still in flight", "timeout", d.opts.ShutdownTimeout.String())
		cancelWork()
	case <-work.Done():
	}
}

func (d *Dispatcher) refresh(ctx context.Context) error {
	d.mu.Lock()
	known := d.revision
	d.mu.Unlock()
	channels, err := d.opts.Store.Channels(ctx, known)
	if ctx.Err() != nil {
		return ctx.Err()
	}
	if err != nil {
		if d.readLatch.Fail(err.Error()) {
			d.log.Warn("Could not read alert channels; the ones in memory stay in use", "error", err, "revision", known)
		}
		return err
	}
	if d.readLatch.Recover() {
		d.log.Info("Reading alert channels works again")
	}
	if channels.Unchanged {
		return nil
	}
	d.mu.Lock()
	d.revision = channels.Revision
	d.channels = store.Channels{Revision: channels.Revision, Telegram: channels.Telegram, Email: channels.Email}
	d.migrated = map[string]string{}
	d.mu.Unlock()
	d.describe(channels)
	return nil
}

func (d *Dispatcher) describe(channels store.Channels) {
	attrs := []any{"revision", channels.Revision, "telegram", channels.Telegram != nil, "email", channels.Email != nil}
	if t := channels.Telegram; t != nil {
		attrs = append(attrs, "telegram_chats", len(t.ChatIDs))
	}
	if e := channels.Email; e != nil {
		attrs = append(attrs, "email_host", e.Host, "email_port", e.Port, "email_security", e.Security,
			"email_recipients", len(e.To), "email_auth", e.Username != "")
	}
	d.log.Info("Alert channels loaded", attrs...)
	if t := channels.Telegram; t != nil {
		switch {
		case !telegram.ValidToken(t.BotToken):
			d.log.Warn("The Telegram bot token has an invalid format; Telegram alerts will fail until it is replaced", "revision", channels.Revision)
		case len(t.ChatIDs) == 0:
			d.log.Warn("Telegram is enabled without chat ids", "revision", channels.Revision)
		}
	}
	if e := channels.Email; e != nil {
		if err := email.Validate(emailConfig(e)); err != nil {
			d.log.Warn("The email channel cannot be used", "revision", channels.Revision, "error", err)
		}
	}
}

func (d *Dispatcher) current() store.Channels {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.channels
}

func (d *Dispatcher) cycle(ctx, work context.Context) (int, error) {
	claimedAt := d.now()
	alerts, err := d.opts.Store.Claim(work, d.opts.Instance, d.opts.BatchSize, d.opts.Lease)
	if err != nil {
		if ctx.Err() == nil && d.claimLatch.Fail(err.Error()) {
			d.log.Warn("Could not claim alerts", "error", err)
		}
		return 0, err
	}
	if d.claimLatch.Recover() {
		d.log.Info("Claiming alerts works again")
	}
	if len(alerts) == 0 {
		return 0, nil
	}
	results := d.deliver(work, alerts, claimedAt.Add(d.opts.Lease-d.opts.SendTimeout-leaseMargin))
	d.record(alerts, results, d.now().Sub(claimedAt))
	d.report(ctx, results)
	return len(alerts), nil
}

func (d *Dispatcher) deliver(work context.Context, alerts []store.Alert, startBy time.Time) []store.Result {
	channels := d.current()
	results := make([]store.Result, len(alerts))
	var viaTelegram, viaEmail []int
	for i, alert := range alerts {
		switch alert.Channel {
		case ChannelTelegram:
			viaTelegram = append(viaTelegram, i)
		case ChannelEmail:
			viaEmail = append(viaEmail, i)
		default:
			results[i] = failure(alert.ID, "Kanal alert tidak dikenal: "+clip(alert.Channel, 40), false)
		}
	}
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		for _, i := range viaTelegram {
			results[i] = d.telegramAlert(work, channels.Telegram, alerts[i], startBy)
		}
	}()
	go func() {
		defer wg.Done()
		for _, i := range viaEmail {
			results[i] = d.emailAlert(work, channels.Email, alerts[i], startBy)
		}
	}()
	wg.Wait()
	d.prune()
	return results
}

func (d *Dispatcher) telegramAlert(work context.Context, cfg *store.Telegram, alert store.Alert, startBy time.Time) store.Result {
	if cfg == nil {
		return failure(alert.ID, "Kanal Telegram belum dikonfigurasi", false)
	}
	if len(cfg.ChatIDs) == 0 {
		return failure(alert.ID, "Belum ada chat id Telegram", false)
	}
	if ok, text := d.awaitTelegram(work, startBy); !ok {
		return failure(alert.ID, text, true)
	}
	if work.Err() != nil || d.now().After(startBy) {
		return failure(alert.ID, errorNotSent, true)
	}
	message := alert.Text
	if strings.TrimSpace(message) == "" {
		message = alert.Subject
	}
	done := d.progressFor(alert.ID)
	retry, err := d.telegramAll(work, cfg, message, done)
	if err == nil || !retry {
		d.forget(alert.ID)
	}
	if err != nil {
		return failure(alert.ID, scrub(err.Error(), cfg, nil), retry)
	}
	return store.Result{ID: alert.ID, OK: true}
}

func (d *Dispatcher) telegramAll(ctx context.Context, cfg *store.Telegram, text string, done map[string]bool) (bool, error) {
	var permanent error
	for _, chat := range cfg.ChatIDs {
		if done[chat] {
			continue
		}
		err := d.opts.Telegram.Send(ctx, cfg.BotToken, d.route(chat), text)
		var tgErr *telegram.Error
		if errors.As(err, &tgErr) && tgErr.MigrateTo != "" {
			d.migrate(chat, tgErr.MigrateTo)
			err = d.opts.Telegram.Send(ctx, cfg.BotToken, tgErr.MigrateTo, text)
		}
		if err == nil {
			done[chat] = true
			continue
		}
		err = &chatError{chat: chat, err: err}
		if retryable(err) {
			if errors.As(err, &tgErr) && tgErr.RetryAfter > 0 {
				d.pauseTelegram(tgErr.RetryAfter)
			}
			return true, err
		}
		permanent = err
	}
	return false, permanent
}

type chatError struct {
	chat string
	err  error
}

func (e *chatError) Error() string {
	return "chat " + e.chat + ": " + e.err.Error()
}

func (e *chatError) Unwrap() error {
	return e.err
}

func (d *Dispatcher) awaitTelegram(ctx context.Context, startBy time.Time) (bool, string) {
	d.mu.Lock()
	until := d.pausedUntil
	d.mu.Unlock()
	now := d.now()
	if !until.After(now) {
		return true, ""
	}
	if until.After(startBy) {
		return false, "Telegram membatasi pengiriman (429); dicoba lagi setelah " + until.In(wib).Format("15:04:05") + " WIB"
	}
	if !d.sleep(ctx, until.Sub(now)) {
		return false, errorNotSent
	}
	return true, ""
}

func (d *Dispatcher) pauseTelegram(after time.Duration) {
	d.mu.Lock()
	until := d.now().Add(after)
	if until.After(d.pausedUntil) {
		d.pausedUntil = until
	}
	d.mu.Unlock()
	d.log.Warn("Telegram asked to slow down; pausing Telegram sends", "retry_after", after.String())
}

func (d *Dispatcher) telegramPaused() bool {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.pausedUntil.After(d.now())
}

func (d *Dispatcher) route(chat string) string {
	d.mu.Lock()
	defer d.mu.Unlock()
	if to, ok := d.migrated[chat]; ok {
		return to
	}
	return chat
}

func (d *Dispatcher) migrate(from, to string) {
	d.mu.Lock()
	known := d.migrated[from] == to
	d.migrated[from] = to
	d.mu.Unlock()
	if !known {
		d.log.Warn("Telegram group was upgraded to a supergroup; sending to the new chat id until the channel settings are updated",
			"chat_id", from, "new_chat_id", to)
	}
}

func (d *Dispatcher) progressFor(id int64) map[string]bool {
	d.mu.Lock()
	defer d.mu.Unlock()
	p, ok := d.partial[id]
	if !ok {
		p = &progress{chats: map[string]bool{}}
		d.partial[id] = p
	}
	p.touched = d.now()
	return p.chats
}

func (d *Dispatcher) forget(id int64) {
	d.mu.Lock()
	delete(d.partial, id)
	d.mu.Unlock()
}

func (d *Dispatcher) prune() {
	d.mu.Lock()
	defer d.mu.Unlock()
	cutoff := d.now().Add(-partialTTL)
	for id, p := range d.partial {
		if p.touched.Before(cutoff) {
			delete(d.partial, id)
		}
	}
}

func (d *Dispatcher) emailAlert(work context.Context, cfg *store.Email, alert store.Alert, startBy time.Time) store.Result {
	if cfg == nil {
		return failure(alert.ID, "Kanal email belum dikonfigurasi", false)
	}
	if work.Err() != nil || d.now().After(startBy) {
		return failure(alert.ID, errorNotSent, true)
	}
	subject := strings.TrimSpace(alert.Subject)
	if subject == "" {
		subject, _, _ = strings.Cut(strings.TrimSpace(alert.Text), "\n")
	}
	err := d.opts.Email.Send(work, emailConfig(cfg), email.Message{Subject: subject, Text: alert.Text})
	if err != nil {
		return failure(alert.ID, scrub(err.Error(), nil, cfg), retryable(err))
	}
	return store.Result{ID: alert.ID, OK: true}
}

func (d *Dispatcher) record(alerts []store.Alert, results []store.Result, took time.Duration) {
	counts := map[string]int{}
	d.mu.Lock()
	for i, r := range results {
		channel := alerts[i].Channel
		if channel != ChannelTelegram && channel != ChannelEmail {
			channel = ChannelOther
		}
		outcome := outcomeOf(r)
		d.alerts[channel][outcome]++
		counts[outcome]++
	}
	d.mu.Unlock()
	for i, r := range results {
		if r.OK || r.Error == errorNotSent {
			continue
		}
		d.log.Warn("Alert delivery failed", "id", r.ID, "channel", alerts[i].Channel, "retry", r.Retry, "error", r.Error)
	}
	d.log.Info("Alert batch processed", "claimed", len(alerts), "sent", counts[Sent], "retry", counts[Retry],
		"failed", counts[Failed], "took_ms", took.Milliseconds())
}

func (d *Dispatcher) report(ctx context.Context, results []store.Result) {
	ctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), reportTimeout)
	defer cancel()
	var err error
	for attempt := 0; ; attempt++ {
		var updated int
		if updated, err = d.opts.Store.Report(ctx, d.opts.Instance, results); err == nil {
			if updated < len(results) {
				d.log.Warn("Some alert results were not applied; their lease may have ended", "results", len(results), "updated", updated)
			}
			return
		}
		if attempt == len(d.reportDelays) {
			break
		}
		timer := time.NewTimer(d.reportDelays[attempt])
		select {
		case <-ctx.Done():
			timer.Stop()
		case <-timer.C:
		}
	}
	d.log.Error("Could not report alert results; the alerts return to the queue when the lease ends",
		"error", err, "results", len(results))
}

func outcomeOf(r store.Result) string {
	switch {
	case r.OK:
		return Sent
	case r.Retry:
		return Retry
	}
	return Failed
}

func retryable(err error) bool {
	var tgErr *telegram.Error
	if errors.As(err, &tgErr) {
		return tgErr.Retry
	}
	var mailErr *email.Error
	if errors.As(err, &mailErr) {
		return mailErr.Retry
	}
	return true
}

func failure(id int64, text string, retry bool) store.Result {
	return store.Result{ID: id, Error: clip(text, maxError), Retry: retry}
}

func emailConfig(e *store.Email) email.Config {
	return email.Config{
		Host:     e.Host,
		Port:     e.Port,
		Security: e.Security,
		Username: e.Username,
		Password: e.Password,
		From:     e.From,
		To:       e.To,
	}
}

func scrub(text string, t *store.Telegram, e *store.Email) string {
	if t != nil && t.BotToken != "" {
		text = strings.ReplaceAll(text, t.BotToken, "<token>")
	}
	if e != nil && e.Password != "" {
		text = strings.ReplaceAll(text, e.Password, "<password>")
	}
	return text
}

func clip(s string, n int) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}

func wait(ctx context.Context, d time.Duration) bool {
	timer := time.NewTimer(d)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-timer.C:
		return true
	}
}
