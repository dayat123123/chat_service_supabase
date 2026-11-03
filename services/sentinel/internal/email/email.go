package email

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"errors"
	"fmt"
	"net"
	"net/mail"
	"net/smtp"
	"net/textproto"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"
)

const (
	TLS      = "tls"
	StartTLS = "starttls"
	None     = "none"

	MaxRecipients = 50
	maxDetail     = 300
)

type Config struct {
	Host     string
	Port     int
	Security string
	Username string
	Password string
	From     string
	To       []string
}

type Message struct {
	Subject string
	Text    string
}

type Error struct {
	Code  int
	Text  string
	Retry bool
}

func (e *Error) Error() string {
	return e.Text
}

type Options struct {
	Timeout time.Duration
	RootCAs *x509.CertPool
	Now     func() time.Time
}

type Sender struct {
	timeout time.Duration
	rootCAs *x509.CertPool
	now     func() time.Time
}

func New(opts Options) *Sender {
	now := opts.Now
	if now == nil {
		now = time.Now
	}
	return &Sender{timeout: opts.Timeout, rootCAs: opts.RootCAs, now: now}
}

type envelope struct {
	from *mail.Address
	to   []*mail.Address
}

func check(cfg Config) (envelope, error) {
	var env envelope
	switch {
	case strings.TrimSpace(cfg.Host) == "" || strings.ContainsAny(cfg.Host, " \r\n/"):
		return env, permanent("Konfigurasi email tidak valid: host SMTP kosong atau salah")
	case cfg.Port < 1 || cfg.Port > 65535:
		return env, permanent("Konfigurasi email tidak valid: port SMTP harus 1-65535")
	case cfg.Security != TLS && cfg.Security != StartTLS && cfg.Security != None:
		return env, permanent("Konfigurasi email tidak valid: security harus tls, starttls, atau none")
	case cfg.Security == None && cfg.Username != "":
		return env, permanent("Login SMTP hanya dikirim lewat koneksi terenkripsi; pakai security tls atau starttls")
	case len(cfg.To) == 0:
		return env, permanent("Konfigurasi email tidak valid: belum ada penerima")
	case len(cfg.To) > MaxRecipients:
		return env, permanent(fmt.Sprintf("Konfigurasi email tidak valid: maksimal %d penerima", MaxRecipients))
	}
	from, err := mail.ParseAddress(cfg.From)
	if err != nil {
		return env, permanent("Konfigurasi email tidak valid: alamat pengirim salah")
	}
	env.from = from
	for _, raw := range cfg.To {
		addr, err := mail.ParseAddress(raw)
		if err != nil {
			return env, permanent("Konfigurasi email tidak valid: alamat penerima salah")
		}
		env.to = append(env.to, addr)
	}
	return env, nil
}

func Validate(cfg Config) error {
	_, err := check(cfg)
	return err
}

func (s *Sender) Send(ctx context.Context, cfg Config, msg Message) error {
	env, err := check(cfg)
	if err != nil {
		return err
	}
	err = s.send(ctx, cfg, env, msg)
	var e *Error
	if errors.As(err, &e) {
		e.Text = scrub(e.Text, cfg)
		return e
	}
	return err
}

func (s *Sender) send(ctx context.Context, cfg Config, env envelope, msg Message) error {
	ctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()
	addr := net.JoinHostPort(cfg.Host, strconv.Itoa(cfg.Port))
	tlsConfig := &tls.Config{ServerName: cfg.Host, RootCAs: s.rootCAs, MinVersion: tls.VersionTLS12}
	dialer := &net.Dialer{Timeout: s.timeout}
	step := "sambungan"
	var conn net.Conn
	var err error
	if cfg.Security == TLS {
		step = "sambungan TLS"
		conn, err = (&tls.Dialer{NetDialer: dialer, Config: tlsConfig}).DialContext(ctx, "tcp", addr)
	} else {
		conn, err = dialer.DialContext(ctx, "tcp", addr)
	}
	if err != nil {
		return classify(step, err)
	}
	return s.converse(ctx, conn, cfg, env, msg, tlsConfig)
}

func (s *Sender) converse(ctx context.Context, conn net.Conn, cfg Config, env envelope, msg Message, tlsConfig *tls.Config) error {
	defer conn.Close()
	if deadline, ok := ctx.Deadline(); ok {
		_ = conn.SetDeadline(deadline)
	}
	stop := context.AfterFunc(ctx, func() { _ = conn.SetDeadline(time.Unix(1, 0)) })
	defer stop()

	c, err := smtp.NewClient(conn, cfg.Host)
	if err != nil {
		return classify("salam pembuka", err)
	}
	defer c.Close()
	if err := c.Hello(helloName(env.from.Address)); err != nil {
		return classify("EHLO", err)
	}
	if cfg.Security == StartTLS {
		if ok, _ := c.Extension("STARTTLS"); !ok {
			return permanent("Server SMTP tidak menawarkan STARTTLS, padahal security starttls wajib memakainya")
		}
		if err := c.StartTLS(tlsConfig); err != nil {
			return classify("STARTTLS", err)
		}
	}
	if cfg.Username != "" {
		if ok, _ := c.Extension("AUTH"); !ok {
			return permanent("Server SMTP tidak menawarkan AUTH, padahal username diisi")
		}
		if err := c.Auth(smtp.PlainAuth("", cfg.Username, cfg.Password, cfg.Host)); err != nil {
			return classifyAuth(err)
		}
	}
	if err := c.Mail(env.from.Address); err != nil {
		return classify("MAIL FROM", err)
	}
	for _, rcpt := range env.to {
		if err := c.Rcpt(rcpt.Address); err != nil {
			return classify("RCPT TO "+rcpt.Address, err)
		}
	}
	w, err := c.Data()
	if err != nil {
		return classify("DATA", err)
	}
	if _, err := w.Write(Build(env.from, env.to, msg.Subject, msg.Text, s.now())); err != nil {
		return classify("isi pesan", err)
	}
	if err := w.Close(); err != nil {
		return classify("isi pesan", err)
	}
	_ = c.Quit()
	return nil
}

func classify(step string, err error) *Error {
	var reply *textproto.Error
	if errors.As(err, &reply) {
		return &Error{
			Code:  reply.Code,
			Text:  clip(fmt.Sprintf("SMTP %s ditolak: %d %s", step, reply.Code, reply.Msg)),
			Retry: reply.Code < 500,
		}
	}
	var verify *tls.CertificateVerificationError
	var hostname x509.HostnameError
	var authority x509.UnknownAuthorityError
	var invalid x509.CertificateInvalidError
	if errors.As(err, &verify) || errors.As(err, &hostname) || errors.As(err, &authority) || errors.As(err, &invalid) {
		return &Error{Text: clip("Sertifikat TLS server SMTP ditolak: " + err.Error())}
	}
	if errors.Is(err, context.DeadlineExceeded) || isTimeout(err) {
		return &Error{Text: "SMTP " + step + " gagal: waktu habis", Retry: true}
	}
	return &Error{Text: clip("SMTP " + step + " gagal: " + err.Error()), Retry: true}
}

func classifyAuth(err error) *Error {
	var reply *textproto.Error
	var netErr net.Error
	if errors.As(err, &reply) || errors.As(err, &netErr) {
		return classify("login", err)
	}
	return &Error{Text: clip("SMTP login gagal: " + err.Error())}
}

func isTimeout(err error) bool {
	var netErr net.Error
	return errors.As(err, &netErr) && netErr.Timeout()
}

func permanent(text string) *Error {
	return &Error{Text: text}
}

func helloName(address string) string {
	if at := strings.LastIndexByte(address, '@'); at >= 0 && at < len(address)-1 {
		return address[at+1:]
	}
	return "localhost"
}

func scrub(text string, cfg Config) string {
	if cfg.Password == "" {
		return text
	}
	text = strings.ReplaceAll(text, cfg.Password, "<password>")
	plain := base64.StdEncoding.EncodeToString([]byte("\x00" + cfg.Username + "\x00" + cfg.Password))
	return strings.ReplaceAll(text, plain, "<credentials>")
}

func clip(s string) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= maxDetail {
		return s
	}
	return string([]rune(s)[:maxDetail])
}
