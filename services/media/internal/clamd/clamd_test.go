package clamd

import (
	"bufio"
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"strings"
	"sync"
	"testing"
	"time"
)

const eicar = `X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*`

type fakeClamd struct {
	ln     net.Listener
	mu     sync.Mutex
	chunks []int
	got    []byte
	reply  func(cmd string, data []byte) string
}

func newFakeClamd(t *testing.T, reply func(cmd string, data []byte) string) *fakeClamd {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	f := &fakeClamd{ln: ln, reply: reply}
	t.Cleanup(func() { ln.Close() })
	go func() {
		for {
			conn, err := ln.Accept()
			if err != nil {
				return
			}
			go f.serve(conn)
		}
	}()
	return f
}

func (f *fakeClamd) serve(conn net.Conn) {
	defer conn.Close()
	r := bufio.NewReader(conn)
	cmd, err := r.ReadString(0)
	if err != nil {
		return
	}
	cmd = strings.TrimSuffix(cmd, "\x00")
	var data []byte
	if cmd == "zINSTREAM" {
		header := make([]byte, 4)
		for {
			if _, err := io.ReadFull(r, header); err != nil {
				return
			}
			n := binary.BigEndian.Uint32(header)
			if n == 0 {
				break
			}
			part := make([]byte, n)
			if _, err := io.ReadFull(r, part); err != nil {
				return
			}
			f.mu.Lock()
			f.chunks = append(f.chunks, int(n))
			f.mu.Unlock()
			data = append(data, part...)
		}
	}
	f.mu.Lock()
	f.got = data
	f.mu.Unlock()
	reply := f.reply(cmd, data)
	if reply == "" {
		time.Sleep(2 * time.Second)
		return
	}
	_, _ = conn.Write([]byte(reply + "\x00"))
}

func standard(cmd string, data []byte) string {
	switch {
	case cmd == "zVERSION":
		return "ClamAV 1.5.4/27820/Sun Nov  9 08:24:02 2026"
	case bytes.Contains(data, []byte("EICAR-STANDARD-ANTIVIRUS-TEST-FILE")):
		return "stream: Eicar-Test-Signature FOUND"
	}
	return "stream: OK"
}

func TestScanStreamsInChunks(t *testing.T) {
	f := newFakeClamd(t, standard)
	c := New(f.ln.Addr().String(), time.Second)
	c.chunk = 10
	body := []byte(strings.Repeat("a", 25))
	res, err := c.Scan(context.Background(), body)
	if err != nil || res.Infected {
		t.Fatalf("res = %+v err = %v", res, err)
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if !bytes.Equal(f.got, body) || len(f.chunks) != 3 || f.chunks[0] != 10 || f.chunks[2] != 5 {
		t.Fatalf("chunks = %v got = %q", f.chunks, f.got)
	}
}

func TestScanFindsEICAR(t *testing.T) {
	f := newFakeClamd(t, standard)
	res, err := New(f.ln.Addr().String(), time.Second).Scan(context.Background(), []byte(eicar))
	if err != nil || !res.Infected || res.Signature != "Eicar-Test-Signature" {
		t.Fatalf("res = %+v err = %v", res, err)
	}
}

func TestScanFailuresAreUnavailable(t *testing.T) {
	cases := map[string]func(string, []byte) string{
		"size limit": func(string, []byte) string { return "INSTREAM size limit exceeded. ERROR" },
		"error":      func(string, []byte) string { return "stream: Can't allocate memory ERROR" },
		"garbage":    func(string, []byte) string { return "hello" },
		"no reply":   func(string, []byte) string { return "" },
	}
	for name, reply := range cases {
		t.Run(name, func(t *testing.T) {
			f := newFakeClamd(t, reply)
			_, err := New(f.ln.Addr().String(), 300*time.Millisecond).Scan(context.Background(), []byte("x"))
			if !errors.Is(err, ErrUnavailable) {
				t.Fatalf("err = %v", err)
			}
		})
	}
	ln, _ := net.Listen("tcp", "127.0.0.1:0")
	addr := ln.Addr().String()
	ln.Close()
	if _, err := New(addr, time.Second).Scan(context.Background(), []byte("x")); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("closed port err = %v", err)
	}
}

func TestVersionAndSignatureDate(t *testing.T) {
	f := newFakeClamd(t, standard)
	c := New(f.ln.Addr().String(), time.Second)
	v, err := c.Version(context.Background())
	if err != nil || v != "ClamAV 1.5.4/27820/Sun Nov  9 08:24:02 2026" {
		t.Fatalf("version = %q err = %v", v, err)
	}
	if err := c.Ping(context.Background()); err != nil {
		t.Fatal(err)
	}
	at, ok := SignatureDate(v)
	if !ok || !at.Equal(time.Date(2026, 11, 9, 8, 24, 2, 0, time.UTC)) {
		t.Fatalf("date = %v %v", at, ok)
	}
	if _, ok := SignatureDate("ClamAV 1.5.4"); ok {
		t.Fatal("version without database has no date")
	}
	bad := newFakeClamd(t, func(string, []byte) string { return "PONG" })
	if _, err := New(bad.ln.Addr().String(), time.Second).Version(context.Background()); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("err = %v", err)
	}
}

func TestScanHonoursTheContext(t *testing.T) {
	f := newFakeClamd(t, func(string, []byte) string { return "" })
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()
	started := time.Now()
	_, err := New(f.ln.Addr().String(), time.Minute).Scan(ctx, []byte("x"))
	if !errors.Is(err, ErrUnavailable) || time.Since(started) > time.Second {
		t.Fatalf("err = %v after %s", err, time.Since(started))
	}
}
