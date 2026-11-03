package dispatch

import (
	"context"
	"fmt"
	"strings"
	"time"

	"olt-social/sentinel/internal/email"
	"olt-social/sentinel/internal/outage"
	"olt-social/sentinel/internal/store"
)

const (
	SubjectDown      = "API/database tidak bisa dihubungi"
	SubjectRecovered = "API/database pulih"

	noticeTTL = time.Hour
)

var wib = time.FixedZone("WIB", 7*60*60)

type notice struct {
	kind     outage.Kind
	subject  string
	text     string
	created  time.Time
	telegram bool
	email    bool
	chats    map[string]bool
	warned   map[string]bool
}

func (d *Dispatcher) handle(events []outage.Event) {
	for _, event := range events {
		switch event.Kind {
		case outage.Down:
			d.down(event)
		case outage.Recovered:
			d.recovered(event)
		}
	}
}

func (d *Dispatcher) down(event outage.Event) {
	channels := d.current()
	d.log.Error("API/database unreachable", "since", event.Since.UTC().Format(time.RFC3339), "error", event.Cause)
	if channels.Telegram == nil && channels.Email == nil {
		d.log.Warn("No alert channels in memory; the outage is only logged")
		d.mu.Lock()
		d.announced = false
		d.mu.Unlock()
		return
	}
	text := SubjectDown + "\n\n" +
		"Sejak: " + stamp(event.Since) + "\n" +
		"Sentinel: " + d.opts.Instance + "\n" +
		"Error terakhir: " + clip(scrub(event.Cause, channels.Telegram, channels.Email), 300)
	if failing := d.opts.FailingProbes(); len(failing) > 0 {
		text += "\nProbe gagal: " + strings.Join(failing, ", ")
	}
	text += "\n\nDikirim langsung oleh sentinel dari kanal yang tersimpan di memori. Pesan susulan dikirim saat pulih."
	d.enqueue(&notice{kind: outage.Down, subject: SubjectDown, text: text}, channels)
	d.mu.Lock()
	d.announced = true
	d.mu.Unlock()
}

func (d *Dispatcher) recovered(event outage.Event) {
	d.log.Info("API/database reachable again", "since", event.Since.UTC().Format(time.RFC3339),
		"duration", event.Duration().Round(time.Second).String())
	d.mu.Lock()
	announced := d.announced
	d.announced = false
	kept := d.notices[:0]
	for _, n := range d.notices {
		if n.kind != outage.Down {
			kept = append(kept, n)
		}
	}
	d.notices = kept
	d.mu.Unlock()
	if !announced {
		return
	}
	channels := d.current()
	text := SubjectRecovered + "\n\n" +
		"Gangguan sejak: " + stamp(event.Since) + "\n" +
		"Pulih: " + stamp(event.At) + "\n" +
		"Lama gangguan: " + Duration(event.Duration()) + "\n" +
		"Sentinel: " + d.opts.Instance
	d.enqueue(&notice{kind: outage.Recovered, subject: SubjectRecovered, text: text}, channels)
}

func (d *Dispatcher) enqueue(n *notice, channels store.Channels) {
	n.created = d.now()
	n.telegram = channels.Telegram != nil
	n.email = channels.Email != nil
	n.chats = map[string]bool{}
	n.warned = map[string]bool{}
	if !n.telegram && !n.email {
		return
	}
	d.mu.Lock()
	d.notices = append(d.notices, n)
	d.mu.Unlock()
}

func (d *Dispatcher) deliverNotices(ctx context.Context) {
	d.mu.Lock()
	pending := append([]*notice(nil), d.notices...)
	d.mu.Unlock()
	if len(pending) == 0 {
		return
	}
	channels := d.current()
	for _, n := range pending {
		if ctx.Err() != nil {
			return
		}
		if n.kind == outage.Recovered && d.now().Sub(n.created) > noticeTTL {
			d.log.Warn("Giving up on a direct alert that could not be delivered for an hour", "subject", n.subject)
			n.telegram, n.email = false, false
		}
		if n.telegram {
			d.noticeTelegram(ctx, n, channels.Telegram)
		}
		if n.email {
			d.noticeEmail(ctx, n, channels.Email)
		}
	}
	d.mu.Lock()
	kept := d.notices[:0]
	for _, n := range d.notices {
		if n.telegram || n.email {
			kept = append(kept, n)
		}
	}
	d.notices = kept
	d.mu.Unlock()
}

func (d *Dispatcher) noticeTelegram(ctx context.Context, n *notice, cfg *store.Telegram) {
	if cfg == nil {
		n.telegram = false
		return
	}
	if d.telegramPaused() {
		return
	}
	retry, err := d.telegramAll(ctx, cfg, n.text, n.chats)
	switch {
	case err == nil:
		n.telegram = false
		d.countNotice(Sent)
		d.log.Info("Direct alert sent", "channel", ChannelTelegram, "subject", n.subject)
	case retry:
		if n.warned[ChannelTelegram] {
			return
		}
		n.warned[ChannelTelegram] = true
		d.log.Warn("Direct alert not sent yet; retrying on the next poll", "channel", ChannelTelegram, "error", scrub(err.Error(), cfg, nil))
	default:
		n.telegram = false
		d.countNotice(Failed)
		d.log.Warn("Direct alert failed", "channel", ChannelTelegram, "error", scrub(err.Error(), cfg, nil))
	}
}

func (d *Dispatcher) noticeEmail(ctx context.Context, n *notice, cfg *store.Email) {
	if cfg == nil {
		n.email = false
		return
	}
	err := d.opts.Email.Send(ctx, emailConfig(cfg), email.Message{Subject: n.subject, Text: n.text})
	switch {
	case err == nil:
		n.email = false
		d.countNotice(Sent)
		d.log.Info("Direct alert sent", "channel", ChannelEmail, "subject", n.subject)
	case retryable(err):
		if n.warned[ChannelEmail] {
			return
		}
		n.warned[ChannelEmail] = true
		d.log.Warn("Direct alert not sent yet; retrying on the next poll", "channel", ChannelEmail, "error", scrub(err.Error(), nil, cfg))
	default:
		n.email = false
		d.countNotice(Failed)
		d.log.Warn("Direct alert failed", "channel", ChannelEmail, "error", scrub(err.Error(), nil, cfg))
	}
}

func (d *Dispatcher) countNotice(outcome string) {
	d.mu.Lock()
	d.noticeStats[outcome]++
	d.mu.Unlock()
}

func stamp(t time.Time) string {
	return t.In(wib).Format("02/01/2006 15:04:05") + " WIB"
}

func Duration(d time.Duration) string {
	d = d.Round(time.Second)
	if d < time.Second {
		return "kurang dari 1 detik"
	}
	days := int(d / (24 * time.Hour))
	hours := int(d % (24 * time.Hour) / time.Hour)
	minutes := int(d % time.Hour / time.Minute)
	seconds := int(d % time.Minute / time.Second)
	var parts []string
	if days > 0 {
		parts = append(parts, fmt.Sprintf("%d hari", days))
	}
	if hours > 0 {
		parts = append(parts, fmt.Sprintf("%d jam", hours))
	}
	if minutes > 0 {
		parts = append(parts, fmt.Sprintf("%d menit", minutes))
	}
	if seconds > 0 && days == 0 {
		parts = append(parts, fmt.Sprintf("%d detik", seconds))
	}
	return strings.Join(parts, " ")
}
