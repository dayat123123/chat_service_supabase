package olt

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/gorilla/websocket"

	"olt-social/cs/internal/breaker"
)

var ErrUnavailable = errors.New("OLT tidak tersedia")

type Error struct {
	Code    string
	Message string
}

func (e *Error) Error() string {
	return "OLT " + e.Code + ": " + e.Message
}

func IsCode(err error, code string) bool {
	var e *Error
	return errors.As(err, &e) && e.Code == code
}

type Config struct {
	URL     string
	Token   string
	Origin  string
	Timeout time.Duration
}

type Client struct {
	cfg     Config
	dialer  *websocket.Dialer
	breaker *breaker.Breaker
}

func New(cfg Config, brk *breaker.Breaker) *Client {
	return &Client{
		cfg:     cfg,
		dialer:  &websocket.Dialer{HandshakeTimeout: cfg.Timeout, Proxy: http.ProxyFromEnvironment},
		breaker: brk,
	}
}

func (c *Client) Call(ctx context.Context, kind string, payload, out any) error {
	if c.cfg.URL == "" {
		return fmt.Errorf("%w: OLT_WS_URL belum diatur", ErrUnavailable)
	}
	if !c.breaker.Allow() {
		return fmt.Errorf("%w: circuit breaker terbuka", ErrUnavailable)
	}
	err := c.call(ctx, kind, payload, out)
	var protocol *Error
	isProtocol := errors.As(err, &protocol)
	switch {
	case err == nil || (isProtocol && !transient(protocol.Code)):
		c.breaker.Success()
	case ctx.Err() != nil:
		c.breaker.Release()
	default:
		c.breaker.Failure()
	}
	if isProtocol && transient(protocol.Code) {
		return fmt.Errorf("%w: %s", ErrUnavailable, protocol.Code)
	}
	return err
}

func transient(code string) bool {
	return code == "RATE_LIMITED" || code == "INTERNAL" || code == "UNAVAILABLE"
}

type response struct {
	Type      string          `json:"type"`
	RequestID string          `json:"request_id"`
	Status    string          `json:"status"`
	Data      json.RawMessage `json:"data"`
	Error     *struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
}

func (c *Client) call(ctx context.Context, kind string, payload, out any) error {
	ctx, cancel := context.WithTimeout(ctx, c.cfg.Timeout)
	defer cancel()

	header := http.Header{}
	header.Set("Authorization", "Bearer "+c.cfg.Token)
	if c.cfg.Origin != "" {
		header.Set("Origin", c.cfg.Origin)
	}
	conn, resp, err := c.dialer.DialContext(ctx, c.cfg.URL, header)
	if resp != nil && resp.Body != nil {
		resp.Body.Close()
	}
	if err != nil {
		return fmt.Errorf("%w: dial: %v", ErrUnavailable, err)
	}
	defer conn.Close()
	defer func() {
		_ = conn.WriteControl(websocket.CloseMessage,
			websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""), time.Now().Add(time.Second))
	}()
	deadline, _ := ctx.Deadline()
	_ = conn.SetReadDeadline(deadline)
	_ = conn.SetWriteDeadline(deadline)

	id := requestID()
	if err := conn.WriteJSON(map[string]any{"v": 1, "type": kind, "request_id": id, "payload": payload}); err != nil {
		return fmt.Errorf("%w: kirim %s: %v", ErrUnavailable, kind, err)
	}
	for {
		_, raw, err := conn.ReadMessage()
		if err != nil {
			return fmt.Errorf("%w: menunggu %s: %v", ErrUnavailable, kind, err)
		}
		var msg response
		if json.Unmarshal(raw, &msg) != nil || msg.RequestID != id {
			continue
		}
		if msg.Type != kind+"_result" && msg.Type != "error" {
			continue
		}
		if msg.Status != "OK" {
			e := &Error{Code: "INTERNAL", Message: "OLT menolak permintaan tanpa detail"}
			if msg.Error != nil && msg.Error.Code != "" {
				e.Code, e.Message = msg.Error.Code, msg.Error.Message
			}
			return e
		}
		if out == nil || len(msg.Data) == 0 {
			return nil
		}
		if err := json.Unmarshal(msg.Data, out); err != nil {
			return fmt.Errorf("decode %s: %w", kind, err)
		}
		return nil
	}
}

func requestID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	h := hex.EncodeToString(b[:])
	return h[0:8] + "-" + h[8:12] + "-" + h[12:16] + "-" + h[16:20] + "-" + h[20:32]
}
