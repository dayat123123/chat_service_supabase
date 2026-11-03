package storage

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
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
	maxObject   = 64 << 20
)

var ErrNotFound = errors.New("storage object not found")

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

func (c *Client) Copy(ctx context.Context, bucket, name, destBucket, destName string) error {
	body, err := json.Marshal(map[string]string{
		"bucketId":          bucket,
		"sourceKey":         name,
		"destinationBucket": destBucket,
		"destinationKey":    destName,
	})
	if err != nil {
		return err
	}
	req, err := c.request(ctx, http.MethodPost, c.baseURL+"/object/copy", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-upsert", "true")
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("storage copy %s: %w", bucket, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, maxResponse))
		return nil
	}
	data, _ := io.ReadAll(io.LimitReader(resp.Body, maxReason))
	if missing(resp.StatusCode, data) {
		return ErrNotFound
	}
	return fmt.Errorf("storage copy %s: status %d%s", bucket, resp.StatusCode, reason(data))
}

func (c *Client) Hash(ctx context.Context, bucket, name string) (string, int64, error) {
	req, err := c.request(ctx, http.MethodGet, c.baseURL+"/object/authenticated/"+objectPath(bucket, name), nil)
	if err != nil {
		return "", 0, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return "", 0, fmt.Errorf("storage read %s: %w", bucket, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		data, _ := io.ReadAll(io.LimitReader(resp.Body, maxReason))
		if missing(resp.StatusCode, data) {
			return "", 0, ErrNotFound
		}
		return "", 0, fmt.Errorf("storage read %s: status %d%s", bucket, resp.StatusCode, reason(data))
	}
	digest := sha256.New()
	size, err := io.Copy(digest, io.LimitReader(resp.Body, maxObject+1))
	if err != nil {
		return "", 0, fmt.Errorf("storage read %s: %w", bucket, err)
	}
	if size > maxObject {
		return "", 0, fmt.Errorf("storage read %s: object larger than %d MiB", bucket, maxObject>>20)
	}
	return hex.EncodeToString(digest.Sum(nil)), size, nil
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

func objectPath(bucket, name string) string {
	parts := strings.Split(name, "/")
	for i, part := range parts {
		parts[i] = url.PathEscape(part)
	}
	return url.PathEscape(bucket) + "/" + strings.Join(parts, "/")
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
