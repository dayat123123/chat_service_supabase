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

	"olt-social/finreport/internal/jwt"
)

const (
	Bucket      = "financial-reports"
	maxReason   = 64 << 10
	contentType = "application/zip"
)

var (
	ErrNotFound    = errors.New("storage object not found")
	ErrTooLarge    = errors.New("storage object larger than allowed")
	ErrUnavailable = errors.New("storage unavailable")
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

func (c *Client) Upload(ctx context.Context, name string, body []byte) error {
	req, err := c.request(ctx, http.MethodPost, c.baseURL+"/object/"+objectPath(name), bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("x-upsert", "true")
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("%w: upload: %v", ErrUnavailable, err)
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(io.LimitReader(resp.Body, maxReason))
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}
	return fmt.Errorf("%w: upload status %d%s", ErrUnavailable, resp.StatusCode, reason(data))
}

func (c *Client) Download(ctx context.Context, name string, limit int64) ([]byte, error) {
	req, err := c.request(ctx, http.MethodGet, c.baseURL+"/object/authenticated/"+objectPath(name), nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: download: %v", ErrUnavailable, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		data, _ := io.ReadAll(io.LimitReader(resp.Body, maxReason))
		if missing(resp.StatusCode, data) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("%w: download status %d%s", ErrUnavailable, resp.StatusCode, reason(data))
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, limit+1))
	if err != nil {
		return nil, fmt.Errorf("%w: download: %v", ErrUnavailable, err)
	}
	if int64(len(data)) > limit {
		return nil, ErrTooLarge
	}
	return data, nil
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

func (c *Client) request(ctx context.Context, method, endpoint string, body io.Reader) (*http.Request, error) {
	token, err := jwt.ServiceRole(c.secret, c.issuer, c.now())
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, method, endpoint, body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Accept", "application/json")
	return req, nil
}

func objectPath(name string) string {
	parts := strings.Split(name, "/")
	for i, part := range parts {
		parts[i] = url.PathEscape(part)
	}
	return Bucket + "/" + strings.Join(parts, "/")
}

func missing(status int, data []byte) bool {
	if status == http.StatusNotFound {
		return true
	}
	var body struct {
		StatusCode string `json:"statusCode"`
		Code       string `json:"code"`
	}
	if json.Unmarshal(data, &body) != nil {
		return false
	}
	return body.StatusCode == "404" || body.Code == "NoSuchKey"
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
