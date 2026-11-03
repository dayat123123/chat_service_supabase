package email

import (
	"bufio"
	"context"
	"errors"
	"io"
	"mime"
	"mime/quotedprintable"
	"net"
	"net/mail"
	"strings"
	"testing"
	"time"
)

const password = "s3cr3t-P@ss word"

func sender(s *smtpServer) *Sender {
	return New(Options{
		Timeout: 3 * time.Second,
		RootCAs: s.pool,
		Now:     func() time.Time { return time.Date(2026, 11, 3, 14, 5, 0, 0, time.FixedZone("WIB", 7*3600)) },
	})
}

func config(s *smtpServer, security string) Config {
	return Config{
		Host:     "127.0.0.1",
		Port:     s.port(),
		Security: security,
		From:     "OLT Ops <ops@olt.example>",
		To:       []string{"a@olt.example", "Budi <b@olt.example>"},
	}
}

var message = Message{
	Subject: "[OLT] KRITIS: Database tidak bisa dihubungi — 🔴",
	Text:    "🔴 KRITIS — Database tidak bisa dihubungi\nSejak: 03/11/2026 14:05:10 WIB\n.line starting with a dot\n" + strings.Repeat("panjang ", 30),
}

func parse(t *testing.T, data string) (*mail.Message, string) {
	t.Helper()
	msg, err := mail.ReadMessage(strings.NewReader(data))
	if err != nil {
		t.Fatalf("message does not parse: %v\n%s", err, data)
	}
	body, err := io.ReadAll(quotedprintable.NewReader(msg.Body))
	if err != nil {
		t.Fatal(err)
	}
	return msg, string(body)
}

func TestStartTLSWithAuthPlainDeliversOneMessageToAllRecipients(t *testing.T) {
	s := startSMTP(t, func(s *smtpServer) { s.offerTLS, s.user, s.pass = true, "ops", password })
	cfg := config(s, StartTLS)
	cfg.Username, cfg.Password = "ops", password

	if err := sender(s).Send(context.Background(), cfg, message); err != nil {
		t.Fatal(err)
	}
	sessions := s.sessionList()
	if len(sessions) != 1 {
		t.Fatalf("sessions = %d", len(sessions))
	}
	sess := sessions[0]
	if !sess.tls || !sess.ehloTLS || sess.helo != "olt.example" || sess.authUser != "ops" || sess.authPass != password || !sess.quit {
		t.Fatalf("session = %+v", sess)
	}
	if sess.from != "ops@olt.example" || strings.Join(sess.rcpts, ",") != "a@olt.example,b@olt.example" {
		t.Fatalf("envelope = %q %v", sess.from, sess.rcpts)
	}
	msg, body := parse(t, sess.data)
	h := msg.Header
	subject, err := new(mime.WordDecoder).DecodeHeader(h.Get("Subject"))
	if err != nil || subject != message.Subject {
		t.Fatalf("subject = %q (%v), raw %q", subject, err, h.Get("Subject"))
	}
	if !strings.HasPrefix(h.Get("Subject"), "=?utf-8?q?") {
		t.Fatalf("subject must be RFC 2047 encoded: %q", h.Get("Subject"))
	}
	from, _ := mail.ParseAddress(h.Get("From"))
	to, _ := h.AddressList("To")
	if from == nil || from.Address != "ops@olt.example" || from.Name != "OLT Ops" || len(to) != 2 || to[1].Name != "Budi" {
		t.Fatalf("from = %v to = %v", h.Get("From"), h.Get("To"))
	}
	if h.Get("MIME-Version") != "1.0" || h.Get("Content-Type") != "text/plain; charset=utf-8" ||
		h.Get("Content-Transfer-Encoding") != "quoted-printable" || h.Get("Auto-Submitted") != "auto-generated" {
		t.Fatalf("headers = %v", h)
	}
	if date, err := h.Date(); err != nil || !date.Equal(time.Date(2026, 11, 3, 7, 5, 0, 0, time.UTC)) {
		t.Fatalf("date = %v (%v)", h.Get("Date"), err)
	}
	if id := h.Get("Message-ID"); !strings.HasPrefix(id, "<") || !strings.HasSuffix(id, "@olt.example>") || len(id) < 30 {
		t.Fatalf("message id = %q", id)
	}
	if strings.TrimRight(strings.ReplaceAll(body, "\r\n", "\n"), "\n") != strings.TrimRight(message.Text, "\n") {
		t.Fatalf("body = %q", body)
	}
	for line := range strings.SplitSeq(sess.data, "\n") {
		if len(line) > 78 {
			t.Fatalf("line longer than 78 octets: %q", line)
		}
	}
}

func TestImplicitTLS(t *testing.T) {
	s := startSMTP(t, func(s *smtpServer) { s.implicitTLS, s.user, s.pass = true, "ops", password })
	cfg := config(s, TLS)
	cfg.Username, cfg.Password = "ops", password
	if err := sender(s).Send(context.Background(), cfg, message); err != nil {
		t.Fatal(err)
	}
	if sess := s.sessionList()[0]; !sess.tls || sess.authUser != "ops" || len(sess.rcpts) != 2 || sess.data == "" {
		t.Fatalf("session = %+v", sess)
	}
}

func TestPlainConnectionForDevelopment(t *testing.T) {
	s := startSMTP(t, func(s *smtpServer) { s.offerTLS = true })
	if err := sender(s).Send(context.Background(), config(s, None), message); err != nil {
		t.Fatal(err)
	}
	if sess := s.sessionList()[0]; sess.tls || sess.authUser != "" || sess.data == "" {
		t.Fatalf("session = %+v", sess)
	}
}

func TestPermanentAndTransientFailures(t *testing.T) {
	cases := []struct {
		name      string
		configure func(*smtpServer)
		security  string
		username  string
		retry     bool
		contains  string
	}{
		{"starttls required but missing", nil, StartTLS, "", false, "tidak menawarkan STARTTLS"},
		{"auth without tls refused before connecting", nil, None, "ops", false, "terenkripsi"},
		{"auth not offered", func(s *smtpServer) { s.offerTLS = true }, StartTLS, "ops", false, "tidak menawarkan AUTH"},
		{"wrong password", func(s *smtpServer) { s.offerTLS, s.user, s.pass = true, "ops", "other" }, StartTLS, "ops", false, "SMTP login ditolak: 535"},
		{"temporary auth failure", func(s *smtpServer) { s.offerTLS, s.user, s.authReply = true, "ops", "454 4.7.0 try later" }, StartTLS, "ops", true, "454"},
		{"sender rejected", func(s *smtpServer) { s.mailReply = "553 5.7.1 sender not allowed" }, None, "", false, "SMTP MAIL FROM ditolak: 553"},
		{"recipient unknown", func(s *smtpServer) { s.rcptReplies["b@olt.example"] = "550 5.1.1 no such user" }, None, "", false, "SMTP RCPT TO b@olt.example ditolak: 550 5.1.1 no such user"},
		{"recipient greylisted", func(s *smtpServer) { s.rcptReplies["a@olt.example"] = "451 4.7.1 greylisted" }, None, "", true, "451"},
		{"data rejected later", func(s *smtpServer) { s.dataReply = "452 4.3.1 insufficient storage" }, None, "", true, "452"},
		{"data refused", func(s *smtpServer) { s.dataReply = "554 5.6.0 message refused" }, None, "", false, "554"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			s := startSMTP(t, tc.configure)
			cfg := config(s, tc.security)
			if tc.username != "" {
				cfg.Username, cfg.Password = tc.username, password
			}
			err := sender(s).Send(context.Background(), cfg, message)
			var e *Error
			if !errors.As(err, &e) || e.Retry != tc.retry || !strings.Contains(err.Error(), tc.contains) {
				t.Fatalf("err = %v (%+v)", err, e)
			}
			if strings.Contains(err.Error(), password) {
				t.Fatalf("password leaked: %v", err)
			}
			for _, sess := range s.sessionList() {
				if sess.data != "" && tc.name != "data rejected later" && tc.name != "data refused" {
					t.Fatalf("message was sent despite the failure: %+v", sess)
				}
			}
		})
	}
}

func TestPasswordEchoedByTheServerIsScrubbed(t *testing.T) {
	s := startSMTP(t, func(s *smtpServer) {
		s.offerTLS, s.user, s.authReply = true, "ops", "535 5.7.8 rejected "+password
	})
	cfg := config(s, StartTLS)
	cfg.Username, cfg.Password = "ops", password
	err := sender(s).Send(context.Background(), cfg, message)
	if err == nil || strings.Contains(err.Error(), password) || !strings.Contains(err.Error(), "<password>") {
		t.Fatalf("err = %v", err)
	}
}

func TestUntrustedCertificateIsPermanent(t *testing.T) {
	s := startSMTP(t, func(s *smtpServer) { s.implicitTLS = true })
	err := New(Options{Timeout: 3 * time.Second}).Send(context.Background(), config(s, TLS), message)
	var e *Error
	if !errors.As(err, &e) || e.Retry || !strings.Contains(err.Error(), "Sertifikat TLS") {
		t.Fatalf("err = %v", err)
	}
}

func TestNetworkFailuresAreTransient(t *testing.T) {
	ln, _ := net.Listen("tcp", "127.0.0.1:0")
	port := ln.Addr().(*net.TCPAddr).Port
	ln.Close()
	cfg := Config{Host: "127.0.0.1", Port: port, Security: None, From: "ops@olt.example", To: []string{"a@olt.example"}}
	err := New(Options{Timeout: time.Second}).Send(context.Background(), cfg, message)
	var e *Error
	if !errors.As(err, &e) || !e.Retry || !strings.HasPrefix(err.Error(), "SMTP sambungan gagal") {
		t.Fatalf("refused: %v", err)
	}

	s := startSMTP(t, func(s *smtpServer) { s.silent = true })
	start := time.Now()
	err = New(Options{Timeout: 300 * time.Millisecond}).Send(context.Background(), config(s, None), message)
	if !errors.As(err, &e) || !e.Retry || !strings.Contains(err.Error(), "waktu habis") {
		t.Fatalf("silent server: %v", err)
	}
	if time.Since(start) > 2*time.Second {
		t.Fatal("SMTP_TIMEOUT was not enforced")
	}
}

func TestCancelledContextStopsTheConversation(t *testing.T) {
	s := startSMTP(t, func(s *smtpServer) { s.silent = true })
	ctx, cancel := context.WithCancel(context.Background())
	time.AfterFunc(100*time.Millisecond, cancel)
	start := time.Now()
	if err := New(Options{Timeout: 10 * time.Second}).Send(ctx, config(s, None), message); err == nil {
		t.Fatal("expected an error")
	}
	if time.Since(start) > 2*time.Second {
		t.Fatal("cancellation was ignored")
	}
}

func TestValidateRejectsBadConfiguration(t *testing.T) {
	good := Config{Host: "smtp.x", Port: 587, Security: StartTLS, From: "ops@x.test", To: []string{"a@x.test"}}
	if err := Validate(good); err != nil {
		t.Fatal(err)
	}
	many := make([]string, MaxRecipients+1)
	for i := range many {
		many[i] = "a@x.test"
	}
	for name, change := range map[string]func(*Config){
		"host":      func(c *Config) { c.Host = "" },
		"port":      func(c *Config) { c.Port = 0 },
		"security":  func(c *Config) { c.Security = "ssl" },
		"from":      func(c *Config) { c.From = "not an address" },
		"to empty":  func(c *Config) { c.To = nil },
		"to bad":    func(c *Config) { c.To = []string{"a@x.test\r\nBcc: evil@x.test"} },
		"too many":  func(c *Config) { c.To = many },
		"plainauth": func(c *Config) { c.Security, c.Username = None, "ops" },
	} {
		cfg := good
		change(&cfg)
		var e *Error
		if err := Validate(cfg); !errors.As(err, &e) || e.Retry {
			t.Errorf("%s: err = %v", name, err)
		}
	}
}

func TestBuildProducesAValidCRLFMessage(t *testing.T) {
	from, _ := mail.ParseAddress("ops@olt.example")
	to := []*mail.Address{{Address: "a@olt.example"}}
	raw := Build(from, to, "Subject\r\nBcc: evil@x", "line one\r\nline two\n"+strings.Repeat("x", 200)+"\n", time.Unix(0, 0))
	text := string(raw)
	if strings.Contains(strings.ReplaceAll(text, "\r\n", ""), "\n") || strings.Contains(strings.ReplaceAll(text, "\r\n", ""), "\r") {
		t.Fatal("bare CR or LF in the message")
	}
	if strings.Contains(text, "\r\nBcc:") {
		t.Fatal("header injection through the subject")
	}
	msg, err := mail.ReadMessage(bufio.NewReader(strings.NewReader(text)))
	if err != nil {
		t.Fatal(err)
	}
	if msg.Header.Get("Subject") != "Subject Bcc: evil@x" {
		t.Fatalf("subject = %q", msg.Header.Get("Subject"))
	}
	body, _ := io.ReadAll(quotedprintable.NewReader(msg.Body))
	if string(body) != "line one\r\nline two\r\n"+strings.Repeat("x", 200)+"\r\n" {
		t.Fatalf("body = %q", body)
	}
	for line := range strings.SplitSeq(text, "\r\n") {
		if len(line) > 78 {
			t.Fatalf("line too long: %q", line)
		}
	}
}

func TestLongSubjectsAreFolded(t *testing.T) {
	subject := strings.Repeat("Gangguan disk penuh — ", 8)
	encoded := EncodeSubject(subject)
	if !strings.Contains(encoded, "\r\n =?utf-8?q?") {
		t.Fatalf("subject not folded: %q", encoded)
	}
	decoded, err := new(mime.WordDecoder).DecodeHeader(strings.ReplaceAll(encoded, "\r\n", ""))
	if err != nil || decoded != strings.TrimSpace(subject) {
		t.Fatalf("decoded = %q (%v)", decoded, err)
	}
	if EncodeSubject("Plain ASCII") != "Plain ASCII" {
		t.Fatal("ASCII subjects stay readable")
	}
}
