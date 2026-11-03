package email

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"io"
	"math/big"
	"net"
	"net/textproto"
	"strings"
	"sync"
	"testing"
	"time"
)

type session struct {
	helo     string
	tls      bool
	ehloTLS  bool
	authUser string
	authPass string
	from     string
	rcpts    []string
	data     string
	quit     bool
}

type smtpServer struct {
	implicitTLS bool
	offerTLS    bool
	user        string
	pass        string
	authReply   string
	mailReply   string
	rcptReplies map[string]string
	dataReply   string
	silent      bool

	ln        net.Listener
	tlsConfig *tls.Config
	pool      *x509.CertPool

	mu       sync.Mutex
	sessions []*session
}

func startSMTP(t *testing.T, configure func(*smtpServer)) *smtpServer {
	t.Helper()
	cert, pool := selfSigned(t)
	s := &smtpServer{
		tlsConfig:   &tls.Config{Certificates: []tls.Certificate{cert}, MinVersion: tls.VersionTLS12},
		pool:        pool,
		rcptReplies: map[string]string{},
	}
	if configure != nil {
		configure(s)
	}
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	if s.implicitTLS {
		ln = tls.NewListener(ln, s.tlsConfig)
	}
	s.ln = ln
	t.Cleanup(func() { ln.Close() })
	go s.serve()
	return s
}

func (s *smtpServer) port() int {
	return s.ln.Addr().(*net.TCPAddr).Port
}

func (s *smtpServer) sessionList() []session {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]session, len(s.sessions))
	for i, sess := range s.sessions {
		out[i] = *sess
		out[i].rcpts = append([]string(nil), sess.rcpts...)
	}
	return out
}

func (s *smtpServer) update(sess *session, change func(*session)) {
	s.mu.Lock()
	change(sess)
	s.mu.Unlock()
}

func (s *smtpServer) serve() {
	for {
		conn, err := s.ln.Accept()
		if err != nil {
			return
		}
		go s.handle(conn)
	}
}

func (s *smtpServer) handle(conn net.Conn) {
	defer func() { conn.Close() }()
	_ = conn.SetDeadline(time.Now().Add(10 * time.Second))
	sess := &session{tls: s.implicitTLS}
	s.mu.Lock()
	s.sessions = append(s.sessions, sess)
	s.mu.Unlock()
	if s.silent {
		_, _ = io.Copy(io.Discard, conn)
		return
	}
	tp := textproto.NewConn(conn)
	reply := func(lines ...string) {
		for _, line := range lines {
			_ = tp.PrintfLine("%s", line)
		}
	}
	reply("220 fake.test ESMTP ready")
	for {
		line, err := tp.ReadLine()
		if err != nil {
			return
		}
		verb, arg, _ := strings.Cut(line, " ")
		switch strings.ToUpper(verb) {
		case "EHLO":
			s.update(sess, func(x *session) { x.helo, x.ehloTLS = arg, x.tls })
			lines := []string{"250-fake.test"}
			if s.offerTLS && !sess.tls {
				lines = append(lines, "250-STARTTLS")
			}
			if s.user != "" {
				lines = append(lines, "250-AUTH PLAIN")
			}
			reply(append(lines, "250 SIZE 10485760")...)
		case "HELO":
			reply("250 fake.test")
		case "STARTTLS":
			if !s.offerTLS || sess.tls {
				reply("502 5.5.1 not offered")
				continue
			}
			reply("220 2.0.0 go ahead")
			secure := tls.Server(conn, s.tlsConfig)
			if err := secure.Handshake(); err != nil {
				return
			}
			conn = secure
			tp = textproto.NewConn(secure)
			s.update(sess, func(x *session) { x.tls, x.helo = true, "" })
		case "AUTH":
			fields := strings.Fields(arg)
			if s.authReply != "" {
				reply(s.authReply)
				continue
			}
			if len(fields) != 2 || !strings.EqualFold(fields[0], "PLAIN") {
				reply("504 5.5.4 unsupported")
				continue
			}
			decoded, _ := base64.StdEncoding.DecodeString(fields[1])
			parts := strings.Split(string(decoded), "\x00")
			if len(parts) != 3 {
				reply("501 5.5.2 malformed")
				continue
			}
			s.update(sess, func(x *session) { x.authUser, x.authPass = parts[1], parts[2] })
			if parts[1] == s.user && parts[2] == s.pass {
				reply("235 2.7.0 authenticated")
			} else {
				reply("535 5.7.8 authentication failed")
			}
		case "MAIL":
			if s.mailReply != "" {
				reply(s.mailReply)
				continue
			}
			s.update(sess, func(x *session) { x.from = between(arg) })
			reply("250 2.1.0 ok")
		case "RCPT":
			addr := between(arg)
			if r, ok := s.rcptReplies[addr]; ok {
				reply(r)
				continue
			}
			s.update(sess, func(x *session) { x.rcpts = append(x.rcpts, addr) })
			reply("250 2.1.5 ok")
		case "DATA":
			reply("354 end with .")
			data, err := tp.ReadDotBytes()
			if err != nil {
				return
			}
			s.update(sess, func(x *session) { x.data = string(data) })
			if s.dataReply != "" {
				reply(s.dataReply)
				continue
			}
			reply("250 2.0.0 queued")
		case "RSET", "NOOP":
			reply("250 2.0.0 ok")
		case "QUIT":
			s.update(sess, func(x *session) { x.quit = true })
			reply("221 2.0.0 bye")
			return
		default:
			reply("502 5.5.2 unknown command")
		}
	}
}

func between(arg string) string {
	start := strings.IndexByte(arg, '<')
	end := strings.IndexByte(arg, '>')
	if start < 0 || end < start {
		return ""
	}
	return arg[start+1 : end]
}

func selfSigned(t *testing.T) (tls.Certificate, *x509.CertPool) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	template := &x509.Certificate{
		SerialNumber:          big.NewInt(time.Now().UnixNano()),
		Subject:               pkix.Name{CommonName: "fake smtp"},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().Add(time.Hour),
		KeyUsage:              x509.KeyUsageDigitalSignature | x509.KeyUsageCertSign,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		BasicConstraintsValid: true,
		IsCA:                  true,
		DNSNames:              []string{"localhost"},
		IPAddresses:           []net.IP{net.ParseIP("127.0.0.1")},
	}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	leaf, _ := x509.ParseCertificate(der)
	pool := x509.NewCertPool()
	pool.AddCert(leaf)
	return tls.Certificate{Certificate: [][]byte{der}, PrivateKey: key, Leaf: leaf}, pool
}
