package storage

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"olt-social/link-preview/internal/jwt"
)

const (
	Bucket   = "link-previews"
	maxReply = 64 << 10
)

type Client struct {
	baseURL string
	secret  []byte
	issuer  string
	http    *http.Client
	now     func() time.Time
}

func New(baseURL string, jwtSecret []byte, issuer string, timeout time.Duration) *Client {
	return &Client{
		baseURL: baseURL,
		secret:  jwtSecret,
		issuer:  issuer,
		http:    &http.Client{Timeout: timeout},
		now:     time.Now,
	}
}

func (c *Client) Upload(ctx context.Context, path, contentType string, body []byte) error {
	token, err := jwt.ServiceRole(c.secret, c.issuer, c.now())
	if err != nil {
		return err
	}
	endpoint := c.baseURL + "/object/" + Bucket + "/" + escapePath(path)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("Cache-Control", "max-age=604800")
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("storage upload: %w", transportError(err))
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(io.LimitReader(resp.Body, maxReply))
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}
	return fmt.Errorf("storage upload: status %d%s", resp.StatusCode, message(data))
}

func (c *Client) Ping(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/status", nil)
	if err != nil {
		return err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return transportError(err)
	}
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, maxReply))
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("storage status %d", resp.StatusCode)
	}
	return nil
}

func escapePath(path string) string {
	parts := strings.Split(path, "/")
	for i, p := range parts {
		parts[i] = url.PathEscape(p)
	}
	return strings.Join(parts, "/")
}

func message(data []byte) string {
	var body struct {
		Error   string `json:"error"`
		Message string `json:"message"`
	}
	if json.Unmarshal(data, &body) != nil {
		return ""
	}
	text := strings.TrimSpace(strings.TrimSpace(body.Error + " " + body.Message))
	if text == "" {
		return ""
	}
	if len(text) > 200 {
		text = text[:200]
	}
	return ": " + text
}

func transportError(err error) error {
	var urlErr *url.Error
	if errors.As(err, &urlErr) {
		return urlErr.Err
	}
	return err
}
