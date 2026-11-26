package clamd

import (
	"bufio"
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"net"
	"strings"
	"time"
)

const (
	DefaultChunk = 64 << 10
	maxReply     = 4 << 10
)

var ErrUnavailable = errors.New("scanner unavailable")

type Result struct {
	Infected  bool
	Signature string
}

type Client struct {
	addr    string
	timeout time.Duration
	chunk   int
	dial    func(ctx context.Context, network, addr string) (net.Conn, error)
}

func New(addr string, timeout time.Duration) *Client {
	d := &net.Dialer{Timeout: 5 * time.Second}
	return &Client{addr: addr, timeout: timeout, chunk: DefaultChunk, dial: d.DialContext}
}

func (c *Client) Scan(ctx context.Context, body []byte) (Result, error) {
	reply, err := c.command(ctx, "zINSTREAM\x00", func(conn net.Conn) error {
		header := make([]byte, 4)
		for start := 0; start < len(body); start += c.chunk {
			part := body[start:min(start+c.chunk, len(body))]
			binary.BigEndian.PutUint32(header, uint32(len(part)))
			if _, err := conn.Write(header); err != nil {
				return err
			}
			if _, err := conn.Write(part); err != nil {
				return err
			}
		}
		_, err := conn.Write([]byte{0, 0, 0, 0})
		return err
	})
	if err != nil {
		return Result{}, err
	}
	return parseScan(reply)
}

func (c *Client) Version(ctx context.Context) (string, error) {
	reply, err := c.command(ctx, "zVERSION\x00", nil)
	if err != nil {
		return "", err
	}
	if !strings.HasPrefix(reply, "ClamAV ") {
		return "", fmt.Errorf("%w: unexpected version reply %q", ErrUnavailable, clip(reply))
	}
	return reply, nil
}

func (c *Client) Ping(ctx context.Context) error {
	_, err := c.Version(ctx)
	return err
}

func (c *Client) command(ctx context.Context, cmd string, send func(net.Conn) error) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, c.timeout)
	defer cancel()
	conn, err := c.dial(ctx, "tcp", c.addr)
	if err != nil {
		return "", fmt.Errorf("%w: %v", ErrUnavailable, err)
	}
	defer conn.Close()
	if deadline, ok := ctx.Deadline(); ok {
		_ = conn.SetDeadline(deadline)
	}
	stop := context.AfterFunc(ctx, func() { _ = conn.SetDeadline(time.Unix(1, 0)) })
	defer stop()
	if _, err := conn.Write([]byte(cmd)); err != nil {
		return "", fmt.Errorf("%w: send command: %v", ErrUnavailable, err)
	}
	if send != nil {
		if err := send(conn); err != nil {
			return "", fmt.Errorf("%w: send data: %v", ErrUnavailable, err)
		}
	}
	reply, err := bufio.NewReaderSize(conn, maxReply).ReadSlice(0)
	if err != nil {
		return "", fmt.Errorf("%w: read reply: %v", ErrUnavailable, err)
	}
	return string(bytes.TrimSpace(bytes.TrimSuffix(reply, []byte{0}))), nil
}

func parseScan(reply string) (Result, error) {
	body, found := strings.CutPrefix(reply, "stream: ")
	switch {
	case !found:
		return Result{}, fmt.Errorf("%w: unexpected reply %q", ErrUnavailable, clip(reply))
	case body == "OK":
		return Result{}, nil
	case strings.HasSuffix(body, " FOUND"):
		return Result{Infected: true, Signature: strings.TrimSpace(strings.TrimSuffix(body, " FOUND"))}, nil
	}
	return Result{}, fmt.Errorf("%w: %s", ErrUnavailable, clip(body))
}

func SignatureDate(version string) (time.Time, bool) {
	parts := strings.Split(version, "/")
	if len(parts) < 3 {
		return time.Time{}, false
	}
	at, err := time.Parse("Mon Jan _2 15:04:05 2006", strings.TrimSpace(parts[2]))
	if err != nil {
		return time.Time{}, false
	}
	return at, true
}

func clip(s string) string {
	if len(s) > 120 {
		return s[:120]
	}
	return s
}
