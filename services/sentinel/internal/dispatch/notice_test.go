package dispatch

import (
	"strings"
	"testing"
	"time"

	"olt-social/sentinel/internal/email"
	"olt-social/sentinel/internal/store"
	"olt-social/sentinel/internal/telegram"
)

func (h *harness) outage(ticks int) {
	h.store.setDown(true)
	for range ticks {
		h.clock.advance(5 * time.Second)
		h.tick()
	}
}

func TestDatabaseOutageAlertsDirectlyOnceAndAnnouncesRecovery(t *testing.T) {
	h := newHarness(t, channels())
	h.tick()
	h.failing = []string{"db", "rest"}

	h.outage(24)
	if len(h.telegram.sent()) != 0 || len(h.email.sent()) != 0 {
		t.Fatalf("alerted before DB_DOWN_AFTER: %+v", h.telegram.sent())
	}
	h.outage(1)
	sends := h.telegram.sent()
	mails := h.email.sent()
	if len(sends) != 2 || len(mails) != 1 {
		t.Fatalf("telegram = %d, email = %d", len(sends), len(mails))
	}
	text := sends[0].text
	for _, part := range []string{
		"API/database tidak bisa dihubungi\n\n",
		"Sejak: 03/11/2026 14:00:05 WIB",
		"Sentinel: sentinel-test",
		"Error terakhir: rpc alert_channels: dial tcp 10.0.0.5:3000: connect: connection refused",
		"Probe gagal: db, rest",
	} {
		if !strings.Contains(text, part) {
			t.Fatalf("down text misses %q:\n%s", part, text)
		}
	}
	if sends[1].chat != "-100222" || sends[1].text != text || mails[0].msg.Subject != SubjectDown || mails[0].msg.Text != text {
		t.Fatalf("sends = %+v mails = %+v", sends, mails)
	}

	h.outage(20)
	if len(h.telegram.sent()) != 2 || len(h.email.sent()) != 1 {
		t.Fatal("outage alert sent more than once")
	}

	h.store.setDown(false)
	h.clock.advance(5 * time.Second)
	h.tick()
	sends = h.telegram.sent()
	mails = h.email.sent()
	if len(sends) != 4 || len(mails) != 2 {
		t.Fatalf("telegram = %d, email = %d", len(sends), len(mails))
	}
	recovered := sends[2].text
	for _, part := range []string{
		"API/database pulih\n\n",
		"Gangguan sejak: 03/11/2026 14:00:05 WIB",
		"Pulih: 03/11/2026 14:03:50 WIB",
		"Lama gangguan: 3 menit 45 detik",
	} {
		if !strings.Contains(recovered, part) {
			t.Fatalf("recovery text misses %q:\n%s", part, recovered)
		}
	}
	if mails[1].msg.Subject != SubjectRecovered {
		t.Fatalf("recovery subject = %q", mails[1].msg.Subject)
	}
	for range 5 {
		h.clock.advance(5 * time.Second)
		h.tick()
	}
	if len(h.telegram.sent()) != 4 || len(h.email.sent()) != 2 {
		t.Fatal("recovery sent more than once")
	}
	if m := h.d.Metrics(); m.Notices[Sent] != 4 {
		t.Fatalf("notices = %+v", m.Notices)
	}
}

func TestOutageWithoutChannelsIsOnlyLogged(t *testing.T) {
	h := newHarness(t, channels())
	h.outage(30)
	if len(h.telegram.sent()) != 0 || len(h.email.sent()) != 0 {
		t.Fatal("nothing can be sent without channels")
	}
	if !strings.Contains(h.logs.String(), "No alert channels in memory") {
		t.Fatalf("logs = %s", h.logs.String())
	}
	h.store.setDown(false)
	h.tick()
	h.tick()
	if len(h.telegram.sent()) != 0 || len(h.email.sent()) != 0 {
		t.Fatal("recovery must not be announced when the outage was not")
	}
	if !strings.Contains(h.logs.String(), "API/database reachable again") {
		t.Fatal("recovery not logged")
	}
}

func TestTransientNoticeFailuresAreRetriedWithoutDuplicates(t *testing.T) {
	h := newHarness(t, channels())
	h.tick()
	h.telegram.reply("-100222", &telegram.Error{Status: 502, Retry: true}, &telegram.Error{Status: 502, Retry: true})
	h.email.replies = []error{&email.Error{Text: "SMTP sambungan gagal", Retry: true}}
	h.outage(25)
	h.outage(2)
	var chats []string
	for _, s := range h.telegram.sent() {
		chats = append(chats, s.chat)
	}
	if strings.Join(chats, ",") != "-100111,-100222,-100222,-100222" {
		t.Fatalf("chats = %v", chats)
	}
	if len(h.email.sent()) != 2 {
		t.Fatalf("emails = %d", len(h.email.sent()))
	}
	if n := strings.Count(h.logs.String(), "Direct alert not sent yet"); n != 2 {
		t.Fatalf("retry warning logged %d times", n)
	}
}

func TestUndeliveredOutageAlertIsReplacedByTheRecovery(t *testing.T) {
	h := newHarness(t, store.Channels{Revision: 3, Email: channels().Email})
	h.tick()
	h.email.replies = []error{
		&email.Error{Text: "down", Retry: true},
		&email.Error{Text: "down", Retry: true},
	}
	h.outage(26)
	h.store.setDown(false)
	h.tick()
	mails := h.email.sent()
	if len(mails) != 3 || mails[0].msg.Subject != SubjectDown || mails[1].msg.Subject != SubjectDown || mails[2].msg.Subject != SubjectRecovered {
		var subjects []string
		for _, m := range mails {
			subjects = append(subjects, m.msg.Subject)
		}
		t.Fatalf("subjects = %v", subjects)
	}
	h.tick()
	if len(h.email.sent()) != 3 {
		t.Fatal("the dropped outage alert was sent after recovery")
	}
}

func TestPermanentNoticeFailureIsDropped(t *testing.T) {
	h := newHarness(t, store.Channels{Revision: 3, Telegram: channels().Telegram})
	h.tick()
	h.telegram.reply("-100111", &telegram.Error{Status: 403, Description: "Forbidden"})
	h.outage(26)
	h.outage(3)
	if n := len(h.telegram.sent()); n != 2 {
		t.Fatalf("sends = %d", n)
	}
	if m := h.d.Metrics(); m.Notices[Failed] != 1 {
		t.Fatalf("notices = %+v", m.Notices)
	}
}

func TestDurationIsWrittenInIndonesian(t *testing.T) {
	cases := map[time.Duration]string{
		400 * time.Millisecond:                     "kurang dari 1 detik",
		45 * time.Second:                           "45 detik",
		7*time.Minute + 30*time.Second:             "7 menit 30 detik",
		time.Hour + 5*time.Minute:                  "1 jam 5 menit",
		26*time.Hour + 3*time.Minute + time.Second: "1 hari 2 jam 3 menit",
	}
	for d, want := range cases {
		if got := Duration(d); got != want {
			t.Errorf("Duration(%v) = %q, want %q", d, got, want)
		}
	}
}
