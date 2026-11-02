package storage

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"olt-social/janitor/internal/jwt"
)

const (
	maxResponse = 32 << 20
	maxReason   = 64 << 10
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

func (c *Client) Delete(ctx context.Context, bucket string, names []string) (int, error) {
	if len(names) == 0 {
		return 0, nil
	}
	body, err := json.Marshal(map[string][]string{"prefixes": names})
	if err != nil {
		return 0, err
	}
	token, err := jwt.ServiceRole(c.secret, c.issuer, c.now())
	if err != nil {
		return 0, err
	}
	endpoint := c.baseURL + "/object/" + url.PathEscape(bucket)
	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, endpoint, bytes.NewReader(body))
	if err != nil {
		return 0, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return 0, fmt.Errorf("storage delete %s: %w", bucket, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		data, _ := io.ReadAll(io.LimitReader(resp.Body, maxReason))
		return 0, fmt.Errorf("storage delete %s: status %d%s", bucket, resp.StatusCode, reason(data))
	}
	var deleted []json.RawMessage
	if err := json.NewDecoder(io.LimitReader(resp.Body, maxResponse)).Decode(&deleted); err != nil {
		return 0, fmt.Errorf("storage delete %s: decode response: %w", bucket, err)
	}
	return len(deleted), nil
}

func (c *Client) Ping(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/status", nil)
	if err != nil {
		return err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("storage status %d", resp.StatusCode)
	}
	return nil
}

func reason(data []byte) string {
	var body struct {
		Message string `json:"message"`
		Error   string `json:"error"`
	}
	if json.Unmarshal(data, &body) != nil {
		return ""
	}
	for _, text := range []string{body.Message, body.Error} {
		if text = strings.TrimSpace(text); text != "" {
			return ": " + text
		}
	}
	return ""
}
