package scrape

import (
	"bufio"
	"context"
	"crypto/pbkdf2"
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"io"
	"net"
	"strings"
	"testing"
	"time"
)

type fakeBouncer struct {
	t        *testing.T
	user     string
	password string
	auth     string
	columns  []string
	rows     [][]string
	queryErr string
	queries  chan string
}

func (f *fakeBouncer) start() string {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		f.t.Fatal(err)
	}
	f.queries = make(chan string, 10)
	f.t.Cleanup(func() { ln.Close() })
	go func() {
		for {
			conn, err := ln.Accept()
			if err != nil {
				return
			}
			go f.serve(conn)
		}
	}()
	return ln.Addr().String()
}

func (f *fakeBouncer) serve(conn net.Conn) {
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(5 * time.Second))
	r := bufio.NewReader(conn)
	var head [4]byte
	if _, err := io.ReadFull(r, head[:]); err != nil {
		return
	}
	startup := make([]byte, binary.BigEndian.Uint32(head[:])-4)
	if _, err := io.ReadFull(r, startup); err != nil {
		return
	}
	params := strings.Split(string(startup[4:]), "\x00")
	user := ""
	for i := 0; i+1 < len(params); i += 2 {
		if params[i] == "user" {
			user = params[i+1]
		}
	}
	if user != f.user || !f.authenticate(conn, r) {
		send(conn, 'E', errorBody("28P01", "password authentication failed for user \""+user+"\""))
		return
	}
	send(conn, 'R', u32(0))
	send(conn, 'S', []byte("server_version\x001.24.0\x00"))
	send(conn, 'Z', []byte("I"))
	kind, body := receive(r)
	if kind != 'Q' {
		return
	}
	f.queries <- strings.TrimRight(string(body), "\x00")
	if f.queryErr != "" {
		send(conn, 'E', errorBody("08P01", f.queryErr))
		send(conn, 'Z', []byte("I"))
		receive(r)
		return
	}
	desc := binary.BigEndian.AppendUint16(nil, uint16(len(f.columns)))
	for _, c := range f.columns {
		desc = append(desc, c...)
		desc = append(desc, 0)
		desc = append(desc, make([]byte, 18)...)
	}
	send(conn, 'T', desc)
	for _, row := range f.rows {
		data := binary.BigEndian.AppendUint16(nil, uint16(len(row)))
		for _, v := range row {
			if v == "<null>" {
				data = binary.BigEndian.AppendUint32(data, 0xFFFFFFFF)
				continue
			}
			data = binary.BigEndian.AppendUint32(data, uint32(len(v)))
			data = append(data, v...)
		}
		send(conn, 'D', data)
	}
	send(conn, 'C', []byte("SHOW\x00"))
	send(conn, 'Z', []byte("I"))
	receive(r)
}

func (f *fakeBouncer) authenticate(conn net.Conn, r *bufio.Reader) bool {
	switch f.auth {
	case "md5":
		salt := []byte{1, 2, 3, 4}
		send(conn, 'R', append(u32(5), salt...))
		kind, body := receive(r)
		return kind == 'p' && strings.TrimRight(string(body), "\x00") == md5Password(f.user, f.password, salt)
	case "scram", "scram-bad-signature":
		send(conn, 'R', append(u32(10), []byte("SCRAM-SHA-256\x00\x00")...))
		kind, body := receive(r)
		mech, rest, _ := strings.Cut(string(body), "\x00")
		if kind != 'p' || mech != scramMechanism || len(rest) < 4 {
			return false
		}
		clientFirst := rest[4:]
		bare := strings.TrimPrefix(clientFirst, "n,,")
		nonce := scramAttrs(bare)["r"] + "srvnonce"
		salt := []byte("pepper-salt")
		serverFirst := "r=" + nonce + ",s=" + base64.StdEncoding.EncodeToString(salt) + ",i=4096"
		send(conn, 'R', append(u32(11), serverFirst...))
		kind, body = receive(r)
		final := string(body)
		withoutProof, proof64, ok := strings.Cut(final, ",p=")
		if kind != 'p' || !ok || withoutProof != "c=biws,r="+nonce {
			return false
		}
		salted, _ := pbkdf2.Key(sha256.New, f.password, salt, 4096, sha256.Size)
		auth := bare + "," + serverFirst + "," + withoutProof
		stored := sha256.Sum256(mac(salted, "Client Key"))
		signature := mac(stored[:], auth)
		proof, err := base64.StdEncoding.DecodeString(proof64)
		if err != nil || len(proof) != len(signature) {
			return false
		}
		clientKey := make([]byte, len(proof))
		for i := range proof {
			clientKey[i] = proof[i] ^ signature[i]
		}
		if sha256.Sum256(clientKey) != stored {
			return false
		}
		serverSig := mac(mac(salted, "Server Key"), auth)
		if f.auth == "scram-bad-signature" {
			serverSig[0] ^= 0xFF
		}
		send(conn, 'R', append(u32(12), "v="+base64.StdEncoding.EncodeToString(serverSig)...))
		return true
	case "unsupported":
		send(conn, 'R', u32(7))
		return false
	}
	return true
}

func u32(v uint32) []byte {
	return binary.BigEndian.AppendUint32(nil, v)
}

func errorBody(code, message string) []byte {
	return []byte("SFATAL\x00C" + code + "\x00M" + message + "\x00\x00")
}

func send(conn net.Conn, kind byte, body []byte) {
	msg := append([]byte{kind}, binary.BigEndian.AppendUint32(nil, uint32(len(body)+4))...)
	_, _ = conn.Write(append(msg, body...))
}

func receive(r *bufio.Reader) (byte, []byte) {
	var head [5]byte
	if _, err := io.ReadFull(r, head[:]); err != nil {
		return 0, nil
	}
	body := make([]byte, binary.BigEndian.Uint32(head[1:])-4)
	if _, err := io.ReadFull(r, body); err != nil {
		return 0, nil
	}
	return head[0], body
}

var poolColumns = []string{"database", "user", "cl_active", "cl_waiting", "cl_active_cancel_req", "cl_waiting_cancel_req",
	"sv_active", "sv_active_cancel", "sv_being_canceled", "sv_idle", "sv_used", "sv_tested", "sv_login",
	"maxwait", "maxwait_us", "pool_mode", "load_balance_hosts"}

var poolRows = [][]string{
	{"pgbouncer", "pgbouncer", "1", "9", "0", "0", "0", "0", "0", "0", "0", "0", "0", "99", "0", "statement", "<null>"},
	{"postgres", "authenticator", "10", "3", "0", "0", "10", "0", "0", "0", "0", "0", "0", "2", "500000", "session", "<null>"},
	{"postgres", "supabase_auth_admin", "4", "1", "0", "0", "3", "0", "0", "2", "0", "0", "0", "0", "750000", "session", "<null>"},
}

func scrapeBouncer(t *testing.T, f *fakeBouncer, password string) Result {
	t.Helper()
	addr := f.start()
	sources, err := Parse("pgbouncer=pgbouncer://" + addr)
	if err != nil {
		t.Fatal(err)
	}
	s := New(Options{Timeout: 3 * time.Second, Password: password})
	results := s.Run(context.Background(), sources)
	if len(results) != 1 {
		t.Fatalf("got %+v", results)
	}
	return results[0]
}

func TestPgBouncerScram(t *testing.T) {
	f := &fakeBouncer{t: t, user: DefaultStatsUser, password: "rahasia-stats", auth: "scram", columns: poolColumns, rows: poolRows}
	r := scrapeBouncer(t, f, "rahasia-stats")
	if !r.OK {
		t.Fatalf("scrape failed: %s", *r.Error)
	}
	if q := <-f.queries; q != "SHOW POOLS" {
		t.Fatalf("query %q", q)
	}
	want := map[string]float64{
		"pgbouncer_pools":           2,
		"pgbouncer_cl_active":       14,
		"pgbouncer_cl_waiting":      4,
		"pgbouncer_sv_active":       13,
		"pgbouncer_sv_idle":         2,
		"pgbouncer_maxwait_seconds": 2.5,
	}
	for k, v := range want {
		if r.Values[k] != v {
			t.Errorf("%s = %v, want %v", k, r.Values[k], v)
		}
	}
	if len(r.Values) != len(want) {
		t.Errorf("values %v", r.Values)
	}
}

func TestPgBouncerMD5(t *testing.T) {
	f := &fakeBouncer{t: t, user: DefaultStatsUser, password: "pw", auth: "md5", columns: poolColumns, rows: poolRows[:1]}
	r := scrapeBouncer(t, f, "pw")
	if !r.OK || r.Values["pgbouncer_pools"] != 0 || r.Values["pgbouncer_cl_waiting"] != 0 {
		t.Fatalf("got %+v", r)
	}
}

func TestPgBouncerFailures(t *testing.T) {
	cases := []struct {
		name     string
		bouncer  fakeBouncer
		password string
		want     string
	}{
		{"wrong password", fakeBouncer{auth: "scram"}, "salah", "password authentication failed"},
		{"bad server signature", fakeBouncer{auth: "scram-bad-signature"}, "pw", "SCRAM server signature mismatch"},
		{"unsupported auth", fakeBouncer{auth: "unsupported"}, "pw", "unsupported authentication method 7"},
		{"query error", fakeBouncer{auth: "md5", queryErr: "not allowed"}, "pw", "not allowed"},
		{"missing columns", fakeBouncer{auth: "md5", columns: []string{"database"}, rows: [][]string{{"postgres"}}}, "pw", "column cl_active missing"},
		{"no password", fakeBouncer{auth: "md5"}, "", "PgBouncer stats user password is not set"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := tc.bouncer
			f.t, f.user, f.password = t, DefaultStatsUser, "pw"
			if f.columns == nil {
				f.columns, f.rows = poolColumns, poolRows
			}
			r := scrapeBouncer(t, &f, tc.password)
			if r.OK || r.Error == nil || !strings.Contains(*r.Error, tc.want) {
				t.Fatalf("got %+v, want error containing %q", r, tc.want)
			}
		})
	}
}

func TestPgBouncerTimeout(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	go func() {
		conn, err := ln.Accept()
		if err == nil {
			time.Sleep(2 * time.Second)
			conn.Close()
		}
	}()
	sources, _ := Parse("pgbouncer=pgbouncer://" + ln.Addr().String())
	start := time.Now()
	r := New(Options{Timeout: 300 * time.Millisecond, Password: "pw"}).Run(context.Background(), sources)[0]
	if r.OK || !strings.Contains(*r.Error, "waktu habis") || time.Since(start) > time.Second {
		t.Fatalf("got %+v after %s", r, time.Since(start))
	}
}
