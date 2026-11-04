package scrape

import (
	"bufio"
	"context"
	"crypto/hmac"
	"crypto/md5"
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"math"
	"net"
	"strconv"
	"strings"
	"time"
)

const (
	protocolVersion = 196608
	maxMessage      = 1 << 20
	scramMechanism  = "SCRAM-SHA-256"
)

type ServerError struct {
	Code    string
	Message string
}

func (e *ServerError) Error() string {
	return "pgbouncer: " + e.Message
}

type wire struct {
	conn net.Conn
	r    *bufio.Reader
}

func (s *Scraper) pgbouncer(ctx context.Context, source Source, addr string) (map[string]float64, error) {
	if s.opts.Password == "" {
		return nil, errors.New("password user statistik PgBouncer belum diatur")
	}
	conn, err := s.dialer.DialContext(ctx, "tcp", source.Address(addr))
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	if deadline, ok := ctx.Deadline(); ok {
		_ = conn.SetDeadline(deadline)
	}
	stop := context.AfterFunc(ctx, func() { _ = conn.SetDeadline(time.Unix(1, 0)) })
	defer stop()
	w := &wire{conn: conn, r: bufio.NewReader(conn)}
	if err := w.startup(source.User, s.opts.Password); err != nil {
		return nil, err
	}
	columns, rows, err := w.query("SHOW POOLS")
	_ = w.send('X', nil)
	if err != nil {
		return nil, err
	}
	return poolValues(columns, rows)
}

func poolValues(columns []string, rows [][]*string) (map[string]float64, error) {
	index := map[string]int{}
	for i, c := range columns {
		index[c] = i
	}
	for _, need := range []string{"database", "cl_active", "cl_waiting", "sv_active", "sv_idle", "maxwait"} {
		if _, ok := index[need]; !ok {
			return nil, fmt.Errorf("kolom %s tidak ada di SHOW POOLS", need)
		}
	}
	cell := func(row []*string, name string) float64 {
		i, ok := index[name]
		if !ok || i >= len(row) || row[i] == nil {
			return 0
		}
		v, err := strconv.ParseFloat(*row[i], 64)
		if err != nil || math.IsNaN(v) || math.IsInf(v, 0) {
			return 0
		}
		return v
	}
	values := map[string]float64{
		"pgbouncer_cl_active":       0,
		"pgbouncer_cl_waiting":      0,
		"pgbouncer_sv_active":       0,
		"pgbouncer_sv_idle":         0,
		"pgbouncer_maxwait_seconds": 0,
		"pgbouncer_pools":           0,
	}
	for _, row := range rows {
		if db := row[index["database"]]; db != nil && *db == "pgbouncer" {
			continue
		}
		values["pgbouncer_pools"]++
		values["pgbouncer_cl_active"] += cell(row, "cl_active")
		values["pgbouncer_cl_waiting"] += cell(row, "cl_waiting")
		values["pgbouncer_sv_active"] += cell(row, "sv_active")
		values["pgbouncer_sv_idle"] += cell(row, "sv_idle")
		wait := cell(row, "maxwait") + cell(row, "maxwait_us")/1e6
		values["pgbouncer_maxwait_seconds"] = max(values["pgbouncer_maxwait_seconds"], wait)
	}
	return values, nil
}

func (w *wire) startup(user, password string) error {
	var body []byte
	body = binary.BigEndian.AppendUint32(body, protocolVersion)
	for _, kv := range [][2]string{{"user", user}, {"database", "pgbouncer"}, {"application_name", "sentinel"}} {
		body = append(body, kv[0]...)
		body = append(body, 0)
		body = append(body, kv[1]...)
		body = append(body, 0)
	}
	body = append(body, 0)
	if err := w.write(nil, body); err != nil {
		return err
	}
	var scram *scramClient
	for {
		kind, msg, err := w.read()
		if err != nil {
			return err
		}
		switch kind {
		case 'E':
			return parseError(msg)
		case 'R':
			if len(msg) < 4 {
				return errors.New("pgbouncer: balasan autentikasi rusak")
			}
			code, data := binary.BigEndian.Uint32(msg), msg[4:]
			switch code {
			case 0:
			case 5:
				if len(data) < 4 {
					return errors.New("pgbouncer: salt md5 rusak")
				}
				if err := w.send('p', cstring(md5Password(user, password, data[:4]))); err != nil {
					return err
				}
			case 10:
				if !hasMechanism(data, scramMechanism) {
					return errors.New("pgbouncer: SCRAM-SHA-256 tidak ditawarkan")
				}
				scram, err = newScram(password)
				if err != nil {
					return err
				}
				first := scram.first()
				var out []byte
				out = append(out, scramMechanism...)
				out = append(out, 0)
				out = binary.BigEndian.AppendUint32(out, uint32(len(first)))
				out = append(out, first...)
				if err := w.send('p', out); err != nil {
					return err
				}
			case 11:
				if scram == nil {
					return errors.New("pgbouncer: urutan SCRAM salah")
				}
				final, err := scram.final(string(data))
				if err != nil {
					return err
				}
				if err := w.send('p', []byte(final)); err != nil {
					return err
				}
			case 12:
				if scram == nil || !scram.verify(string(data)) {
					return errors.New("pgbouncer: tanda tangan server SCRAM tidak cocok")
				}
			default:
				return fmt.Errorf("pgbouncer: metode autentikasi %d tidak didukung", code)
			}
		case 'Z':
			return nil
		}
	}
}

func (w *wire) query(sql string) ([]string, [][]*string, error) {
	if err := w.send('Q', cstring(sql)); err != nil {
		return nil, nil, err
	}
	var columns []string
	var rows [][]*string
	var failure error
	for {
		kind, msg, err := w.read()
		if err != nil {
			return nil, nil, err
		}
		switch kind {
		case 'E':
			failure = parseError(msg)
		case 'T':
			if columns, err = rowDescription(msg); err != nil {
				return nil, nil, err
			}
		case 'D':
			row, err := dataRow(msg)
			if err != nil {
				return nil, nil, err
			}
			rows = append(rows, row)
		case 'Z':
			return columns, rows, failure
		}
	}
}

func (w *wire) send(kind byte, body []byte) error {
	return w.write([]byte{kind}, body)
}

func (w *wire) write(prefix, body []byte) error {
	msg := append(prefix, binary.BigEndian.AppendUint32(nil, uint32(len(body)+4))...)
	_, err := w.conn.Write(append(msg, body...))
	return err
}

func (w *wire) read() (byte, []byte, error) {
	var head [5]byte
	if _, err := io.ReadFull(w.r, head[:]); err != nil {
		return 0, nil, err
	}
	size := int(binary.BigEndian.Uint32(head[1:]))
	if size < 4 || size > maxMessage {
		return 0, nil, errors.New("pgbouncer: ukuran pesan tidak valid")
	}
	msg := make([]byte, size-4)
	if _, err := io.ReadFull(w.r, msg); err != nil {
		return 0, nil, err
	}
	return head[0], msg, nil
}

func parseError(msg []byte) error {
	e := &ServerError{}
	for len(msg) > 0 && msg[0] != 0 {
		field := msg[0]
		end := strings.IndexByte(string(msg[1:]), 0)
		if end < 0 {
			break
		}
		value := string(msg[1 : 1+end])
		msg = msg[2+end:]
		switch field {
		case 'C':
			e.Code = value
		case 'M':
			e.Message = value
		}
	}
	if e.Message == "" {
		e.Message = "error tanpa pesan"
	}
	return e
}

func rowDescription(msg []byte) ([]string, error) {
	if len(msg) < 2 {
		return nil, errors.New("pgbouncer: deskripsi kolom rusak")
	}
	count := int(binary.BigEndian.Uint16(msg))
	msg = msg[2:]
	columns := make([]string, 0, count)
	for range count {
		end := strings.IndexByte(string(msg), 0)
		if end < 0 || len(msg) < end+19 {
			return nil, errors.New("pgbouncer: deskripsi kolom rusak")
		}
		columns = append(columns, string(msg[:end]))
		msg = msg[end+19:]
	}
	return columns, nil
}

func dataRow(msg []byte) ([]*string, error) {
	if len(msg) < 2 {
		return nil, errors.New("pgbouncer: baris data rusak")
	}
	count := int(binary.BigEndian.Uint16(msg))
	msg = msg[2:]
	row := make([]*string, 0, count)
	for range count {
		if len(msg) < 4 {
			return nil, errors.New("pgbouncer: baris data rusak")
		}
		size := int32(binary.BigEndian.Uint32(msg))
		msg = msg[4:]
		if size < 0 {
			row = append(row, nil)
			continue
		}
		if int(size) > len(msg) {
			return nil, errors.New("pgbouncer: baris data rusak")
		}
		value := string(msg[:size])
		row = append(row, &value)
		msg = msg[size:]
	}
	return row, nil
}

func cstring(s string) []byte {
	return append([]byte(s), 0)
}

func hasMechanism(data []byte, want string) bool {
	for _, m := range strings.Split(string(data), "\x00") {
		if m == want {
			return true
		}
	}
	return false
}

func md5Password(user, password string, salt []byte) string {
	inner := md5.Sum([]byte(password + user))
	outer := md5.Sum(append([]byte(hex.EncodeToString(inner[:])), salt...))
	return "md5" + hex.EncodeToString(outer[:])
}

type scramClient struct {
	password string
	nonce    string
	bare     string
	auth     string
	salted   []byte
}

func newScram(password string) (*scramClient, error) {
	var raw [18]byte
	if _, err := rand.Read(raw[:]); err != nil {
		return nil, err
	}
	nonce := base64.StdEncoding.EncodeToString(raw[:])
	return &scramClient{password: password, nonce: nonce, bare: "n=,r=" + nonce}, nil
}

func (c *scramClient) first() string {
	return "n,," + c.bare
}

func (c *scramClient) final(serverFirst string) (string, error) {
	attrs := scramAttrs(serverFirst)
	nonce, salt64, iter := attrs["r"], attrs["s"], attrs["i"]
	if !strings.HasPrefix(nonce, c.nonce) || len(nonce) == len(c.nonce) {
		return "", errors.New("pgbouncer: nonce SCRAM tidak cocok")
	}
	salt, err := base64.StdEncoding.DecodeString(salt64)
	if err != nil {
		return "", errors.New("pgbouncer: salt SCRAM rusak")
	}
	rounds, err := strconv.Atoi(iter)
	if err != nil || rounds < 1 || rounds > 1_000_000 {
		return "", errors.New("pgbouncer: jumlah iterasi SCRAM tidak valid")
	}
	c.salted, err = pbkdf2.Key(sha256.New, c.password, salt, rounds, sha256.Size)
	if err != nil {
		return "", err
	}
	withoutProof := "c=biws,r=" + nonce
	c.auth = c.bare + "," + serverFirst + "," + withoutProof
	clientKey := mac(c.salted, "Client Key")
	stored := sha256.Sum256(clientKey)
	signature := mac(stored[:], c.auth)
	proof := make([]byte, len(clientKey))
	for i := range clientKey {
		proof[i] = clientKey[i] ^ signature[i]
	}
	return withoutProof + ",p=" + base64.StdEncoding.EncodeToString(proof), nil
}

func (c *scramClient) verify(serverFinal string) bool {
	got, err := base64.StdEncoding.DecodeString(scramAttrs(serverFinal)["v"])
	if err != nil || c.salted == nil {
		return false
	}
	want := mac(mac(c.salted, "Server Key"), c.auth)
	return subtle.ConstantTimeCompare(got, want) == 1
}

func scramAttrs(s string) map[string]string {
	attrs := map[string]string{}
	for part := range strings.SplitSeq(s, ",") {
		if k, v, ok := strings.Cut(part, "="); ok && len(k) == 1 {
			attrs[k] = v
		}
	}
	return attrs
}

func mac(key []byte, msg string) []byte {
	h := hmac.New(sha256.New, key)
	h.Write([]byte(msg))
	return h.Sum(nil)
}
