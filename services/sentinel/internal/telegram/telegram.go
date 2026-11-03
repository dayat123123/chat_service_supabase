package telegram

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf16"
	"unicode/utf8"
)

const (
	MaxText     = 4096
	maxResponse = 64 << 10
	maxDetail   = 300
)

var tokenPattern = regexp.MustCompile(`^[0-9]{1,20}:[A-Za-z0-9_-]{20,200}$`)

type Error struct {
	Status      int
	Description string
	Retry       bool
	RetryAfter  time.Duration
	MigrateTo   string
}

func (e *Error) Error() string {
	if e.Status == 0 {
		return e.Description
	}
	if e.Description == "" {
		return fmt.Sprintf("Telegram %d", e.Status)
	}
	return fmt.Sprintf("Telegram %d: %s", e.Status, e.Description)
}

func ValidToken(token string) bool {
	return tokenPattern.MatchString(token)
}

type Client struct {
	baseURL string
	agent   string
	http    *http.Client
}

func New(baseURL string, timeout time.Duration, userAgent string) *Client {
	return &Client{
		baseURL: strings.TrimSuffix(baseURL, "/"),
		agent:   userAgent,
		http: &http.Client{
			Timeout: timeout,
			CheckRedirect: func(*http.Request, []*http.Request) error {
				return http.ErrUseLastResponse
			},
		},
	}
}

type reply struct {
	OK          bool   `json:"ok"`
	ErrorCode   int    `json:"error_code"`
	Description string `json:"description"`
	Parameters  struct {
		RetryAfter      int             `json:"retry_after"`
		MigrateToChatID json.RawMessage `json:"migrate_to_chat_id"`
	} `json:"parameters"`
}

func (c *Client) Send(ctx context.Context, token, chatID, text string) error {
	if !ValidToken(token) {
		return &Error{Description: "Format token bot Telegram tidak valid", Retry: true}
	}
	body, err := json.Marshal(map[string]any{
		"chat_id":                  chatID,
		"text":                     Clip(text),
		"disable_web_page_preview": true,
	})
	if err != nil {
		return &Error{Description: "Pesan Telegram tidak bisa disusun"}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/bot"+token+"/sendMessage", bytes.NewReader(body))
	if err != nil {
		return &Error{Description: "Alamat API Telegram tidak valid"}
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", c.agent)
	resp, err := c.http.Do(req)
	if err != nil {
		return &Error{Description: "Telegram tidak bisa dihubungi: " + scrub(cause(err), token), Retry: true}
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(io.LimitReader(resp.Body, maxResponse))
	return classify(resp, data, token)
}

func classify(resp *http.Response, data []byte, token string) error {
	var r reply
	decoded := json.Unmarshal(data, &r) == nil
	status := resp.StatusCode
	if status >= 200 && status < 300 && decoded && r.OK {
		return nil
	}
	e := &Error{Status: status, Description: scrub(clip(r.Description, maxDetail), token)}
	switch {
	case status == http.StatusTooManyRequests:
		e.Retry = true
		e.RetryAfter = time.Duration(r.Parameters.RetryAfter) * time.Second
		if e.RetryAfter <= 0 {
			if seconds, err := strconv.Atoi(strings.TrimSpace(resp.Header.Get("Retry-After"))); err == nil && seconds > 0 {
				e.RetryAfter = time.Duration(seconds) * time.Second
			}
		}
		e.RetryAfter = max(e.RetryAfter, time.Second)
	case status >= 500, status >= 200 && status < 300:
		e.Retry = true
	case status == http.StatusUnauthorized, status == http.StatusNotFound:
		e.Retry = true
		if e.Description == "" {
			e.Description = "token bot ditolak"
		}
	case status == http.StatusBadRequest:
		if id := chatID(r.Parameters.MigrateToChatID); id != "" {
			e.MigrateTo = id
		}
	}
	return e
}

func chatID(raw json.RawMessage) string {
	if len(raw) == 0 || string(raw) == "null" {
		return ""
	}
	var number json.Number
	if json.Unmarshal(raw, &number) == nil {
		return number.String()
	}
	var text string
	if json.Unmarshal(raw, &text) == nil {
		return strings.TrimSpace(text)
	}
	return ""
}

func cause(err error) string {
	var urlErr *url.Error
	if errors.As(err, &urlErr) {
		err = urlErr.Err
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return "waktu habis"
	}
	return clip(err.Error(), maxDetail)
}

func scrub(text, token string) string {
	if token == "" {
		return text
	}
	return strings.ReplaceAll(text, token, "<token>")
}

func Clip(text string) string {
	if utf16Len(text) <= MaxText {
		return text
	}
	var b strings.Builder
	used := 0
	for _, r := range text {
		n := utf16.RuneLen(r)
		if n < 0 {
			n = 1
		}
		if used+n > MaxText-1 {
			break
		}
		b.WriteRune(r)
		used += n
	}
	b.WriteString("…")
	return b.String()
}

func utf16Len(text string) int {
	n := 0
	for _, r := range text {
		if size := utf16.RuneLen(r); size > 0 {
			n += size
		} else {
			n++
		}
	}
	return n
}

func clip(s string, n int) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}
