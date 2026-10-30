package postgrest

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"time"
)

const schema = "cs_api"

var codePattern = regexp.MustCompile(`^[a-z][a-z0-9_]*$`)

type TokenSource interface {
	Token() (string, error)
}

type Error struct {
	Status     int
	Code       string
	Message    string
	RetryAfter string
}

func (e *Error) Error() string {
	return fmt.Sprintf("postgrest %d %s: %s", e.Status, e.Code, e.Message)
}

func AsError(err error) (*Error, bool) {
	var e *Error
	ok := errors.As(err, &e)
	return e, ok
}

type Client struct {
	baseURL string
	tokens  TokenSource
	http    *http.Client
}

func New(baseURL string, tokens TokenSource, timeout time.Duration) *Client {
	return &Client{baseURL: baseURL, tokens: tokens, http: &http.Client{Timeout: timeout}}
}

func (c *Client) Call(ctx context.Context, fn string, args, out any) error {
	tok, err := c.tokens.Token()
	if err != nil {
		return fmt.Errorf("service token: %w", err)
	}
	return c.CallAs(ctx, tok, fn, args, out)
}

func (c *Client) CallAs(ctx context.Context, bearer, fn string, args, out any) error {
	body, err := json.Marshal(args)
	if err != nil {
		return fmt.Errorf("rpc %s: encode: %w", fn, err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/rpc/"+fn, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+bearer)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Profile", schema)
	req.Header.Set("Accept-Profile", schema)

	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("rpc %s: %w", fn, err)
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
	if err != nil {
		return fmt.Errorf("rpc %s: read: %w", fn, err)
	}
	if resp.StatusCode >= 300 {
		return decodeError(resp, data)
	}
	if out == nil || len(bytes.TrimSpace(data)) == 0 {
		return nil
	}
	if err := json.Unmarshal(data, out); err != nil {
		return fmt.Errorf("rpc %s: decode: %w", fn, err)
	}
	return nil
}

func (c *Client) Ping(ctx context.Context) error {
	tok, err := c.tokens.Token()
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodHead, c.baseURL+"/", nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+tok)
	req.Header.Set("Accept-Profile", schema)
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	if resp.StatusCode >= 500 {
		return fmt.Errorf("postgrest status %d", resp.StatusCode)
	}
	return nil
}

func decodeError(resp *http.Response, data []byte) error {
	var body struct {
		Code    string `json:"code"`
		Message string `json:"message"`
		Details string `json:"details"`
	}
	_ = json.Unmarshal(data, &body)
	e := &Error{Status: resp.StatusCode, Code: body.Code, Message: body.Message, RetryAfter: resp.Header.Get("Retry-After")}
	if codePattern.MatchString(body.Message) {
		e.Code = body.Message
		if body.Details != "" {
			e.Message = body.Details
		}
	}
	if e.Code == "" {
		e.Code = http.StatusText(resp.StatusCode)
	}
	return e
}
