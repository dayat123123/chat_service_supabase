package olt

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gorilla/websocket"

	"olt-social/auth-bridge/internal/config"
)

type WebSocketVerifier struct {
	cfg      config.OLTConfig
	template any
	dialer   *websocket.Dialer
}

func NewWebSocketVerifier(cfg config.OLTConfig) (*WebSocketVerifier, error) {
	var tmpl any
	if err := json.Unmarshal([]byte(cfg.LoginTemplate), &tmpl); err != nil {
		return nil, fmt.Errorf("template login: %w", err)
	}
	return &WebSocketVerifier{
		cfg:      cfg,
		template: tmpl,
		dialer: &websocket.Dialer{
			HandshakeTimeout: cfg.Timeout,
			Proxy:            http.ProxyFromEnvironment,
		},
	}, nil
}

func (v *WebSocketVerifier) Verify(ctx context.Context, token string) (User, error) {
	ctx, cancel := context.WithTimeout(ctx, v.cfg.Timeout)
	defer cancel()

	header := http.Header{}
	if v.cfg.Origin != "" {
		header.Set("Origin", v.cfg.Origin)
	}
	conn, resp, err := v.dialer.DialContext(ctx, v.cfg.WebSocketURL, header)
	if resp != nil && resp.Body != nil {
		resp.Body.Close()
	}
	if err != nil {
		return User{}, fmt.Errorf("%w: dial: %v", ErrUnavailable, err)
	}
	defer conn.Close()

	deadline, _ := ctx.Deadline()
	_ = conn.SetReadDeadline(deadline)
	_ = conn.SetWriteDeadline(deadline)
	defer func() {
		_ = conn.WriteControl(websocket.CloseMessage,
			websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""), time.Now().Add(time.Second))
	}()

	vars := strings.NewReplacer(config.TokenPlaceholder, token, config.RequestIDPlaceholder, newRequestID())
	msg, err := json.Marshal(substitute(v.template, vars))
	if err != nil {
		return User{}, fmt.Errorf("build login message: %w", err)
	}
	if err := conn.WriteMessage(websocket.TextMessage, msg); err != nil {
		return User{}, fmt.Errorf("%w: send login: %v", ErrUnavailable, err)
	}

	for {
		_, data, err := conn.ReadMessage()
		if err != nil {
			return User{}, fmt.Errorf("%w: waiting for login response: %v", ErrUnavailable, err)
		}
		doc, ok := decodeJSON(data)
		if !ok {
			continue
		}
		if v.cfg.ResponseMatchPath != "" {
			if val, ok := Lookup(doc, v.cfg.ResponseMatchPath); !ok || val != v.cfg.ResponseMatchValue {
				continue
			}
		}
		return v.parseLoginResponse(doc)
	}
}

func (v *WebSocketVerifier) parseLoginResponse(doc any) (User, error) {
	if v.cfg.SuccessPath != "" {
		val, ok := Lookup(doc, v.cfg.SuccessPath)
		if !ok || !strings.EqualFold(val, v.cfg.SuccessValue) {
			reason, _ := Lookup(doc, v.cfg.ErrorMessagePath)
			if reason == "" {
				reason = "login rejected"
			}
			return User{}, fmt.Errorf("%w: %s", ErrInvalidToken, reason)
		}
	}

	id, ok := Lookup(doc, v.cfg.UserIDPath)
	if !ok || id == "" {
		return User{}, fmt.Errorf("%w: login response has no user id (%s)", ErrInvalidToken, v.cfg.UserIDPath)
	}
	u := User{ID: id}
	u.Username, _ = Lookup(doc, v.cfg.UsernamePath)
	u.Email, _ = Lookup(doc, v.cfg.EmailPath)
	u.DisplayName, _ = Lookup(doc, v.cfg.DisplayNamePath)
	if u.Username == "" {
		u.Username = "user_" + id
	}
	return u, nil
}

func substitute(node any, vars *strings.Replacer) any {
	switch n := node.(type) {
	case map[string]any:
		out := make(map[string]any, len(n))
		for k, val := range n {
			out[k] = substitute(val, vars)
		}
		return out
	case []any:
		out := make([]any, len(n))
		for i, val := range n {
			out[i] = substitute(val, vars)
		}
		return out
	case string:
		return vars.Replace(n)
	default:
		return n
	}
}

func newRequestID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	h := hex.EncodeToString(b[:])
	return h[0:8] + "-" + h[8:12] + "-" + h[12:16] + "-" + h[16:20] + "-" + h[20:32]
}

func decodeJSON(data []byte) (any, bool) {
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.UseNumber()
	var doc any
	if err := dec.Decode(&doc); err != nil {
		return nil, false
	}
	return doc, true
}

func Lookup(doc any, path string) (string, bool) {
	if path == "" {
		return "", false
	}
	cur := doc
	for _, seg := range strings.Split(path, ".") {
		switch node := cur.(type) {
		case map[string]any:
			next, ok := node[seg]
			if !ok {
				return "", false
			}
			cur = next
		case []any:
			idx, err := strconv.Atoi(seg)
			if err != nil || idx < 0 || idx >= len(node) {
				return "", false
			}
			cur = node[idx]
		default:
			return "", false
		}
	}

	switch val := cur.(type) {
	case nil:
		return "", false
	case string:
		return val, true
	case json.Number:
		return val.String(), true
	case bool:
		return strconv.FormatBool(val), true
	default:
		b, err := json.Marshal(val)
		if err != nil {
			return "", false
		}
		return string(b), true
	}
}

func IsUnavailable(err error) bool { return errors.Is(err, ErrUnavailable) }
