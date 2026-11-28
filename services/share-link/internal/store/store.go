package store

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"olt-social/share-link/internal/heartbeat"
	"olt-social/share-link/internal/jwt"
	"olt-social/share-link/internal/stats"
)

const (
	maxResponse = 1 << 20
	maxError    = 500
)

var (
	ErrUnavailable = errors.New("upstream unavailable")
	ErrNotFound    = errors.New("not found")
	ErrTooLarge    = errors.New("image too large")
)

type AndroidApp struct {
	Package string   `json:"package"`
	SHA256  []string `json:"sha256"`
}

type Settings struct {
	Ready              bool         `json:"ready"`
	Enabled            bool         `json:"enabled"`
	BaseURL            string       `json:"base_url"`
	Preview            bool         `json:"preview"`
	AppName            string       `json:"app_name"`
	AppScheme          string       `json:"app_scheme"`
	Android            []AndroidApp `json:"android"`
	IOSAppIDs          []string     `json:"ios_app_ids"`
	AndroidStoreURL    string       `json:"android_store_url"`
	IOSStoreURL        string       `json:"ios_store_url"`
	WindowsDownloadURL string       `json:"windows_download_url"`
	MacDownloadURL     string       `json:"macos_download_url"`
}

type Author struct {
	Username    string `json:"username"`
	DisplayName string `json:"display_name"`
	Verified    bool   `json:"verified"`
	Official    bool   `json:"official"`
	AvatarPath  string `json:"avatar_path"`
}

type Image struct {
	Path   string `json:"path"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
}

type Preview struct {
	Status       string    `json:"status"`
	Code         string    `json:"code"`
	Preview      bool      `json:"preview"`
	Author       Author    `json:"author"`
	Body         string    `json:"body"`
	Truncated    bool      `json:"truncated"`
	CreatedAt    time.Time `json:"created_at"`
	LikeCount    int       `json:"like_count"`
	CommentCount int       `json:"comment_count"`
	Image        *Image    `json:"image"`
	Stocks       []Stock   `json:"stocks"`
}

type Stock struct {
	Code string `json:"code"`
	Name string `json:"name"`
}

type Blob struct {
	Data        []byte
	ContentType string
	ETag        string
}

type Client struct {
	restURL    string
	storageURL string
	secret     []byte
	issuer     string
	http       *http.Client
	now        func() time.Time
}

func New(restURL, storageURL string, jwtSecret []byte, issuer string, timeout time.Duration) *Client {
	return &Client{
		restURL:    restURL,
		storageURL: storageURL,
		secret:     jwtSecret,
		issuer:     issuer,
		http: &http.Client{
			Timeout: timeout,
			CheckRedirect: func(*http.Request, []*http.Request) error {
				return http.ErrUseLastResponse
			},
		},
		now: time.Now,
	}
}

func (c *Client) Settings(ctx context.Context) (Settings, error) {
	var out Settings
	data, err := c.call(ctx, "share_link_config", map[string]any{})
	if err != nil {
		return out, err
	}
	if err := json.Unmarshal(data, &out); err != nil {
		return out, fmt.Errorf("%w: decode share_link_config: %v", ErrUnavailable, err)
	}
	return out, nil
}

func (c *Client) Preview(ctx context.Context, code string) (Preview, error) {
	var out Preview
	data, err := c.call(ctx, "share_post_preview", map[string]any{"p_code": code})
	if err != nil {
		return out, err
	}
	if err := json.Unmarshal(data, &out); err != nil {
		return out, fmt.Errorf("%w: decode share_post_preview: %v", ErrUnavailable, err)
	}
	return out, nil
}

func (c *Client) RecordStats(ctx context.Context, rows []stats.Row) error {
	_, err := c.call(ctx, "share_link_record_stats", map[string]any{"p_rows": rows})
	return err
}

func (c *Client) Heartbeat(ctx context.Context, beat heartbeat.Beat) error {
	detail := beat.Detail
	if detail == nil {
		detail = map[string]any{}
	}
	_, err := c.call(ctx, "service_heartbeat", map[string]any{
		"p_service":    beat.Service,
		"p_instance":   beat.Instance,
		"p_version":    beat.Version,
		"p_started_at": beat.StartedAt.UTC().Format(time.RFC3339),
		"p_status":     beat.Status,
		"p_error":      nullable(clip(beat.Error, maxError)),
		"p_detail":     detail,
	})
	return err
}

func (c *Client) PostImage(ctx context.Context, path string, width int, limit int64) (Blob, error) {
	query := url.Values{"width": {strconv.Itoa(width)}, "resize": {"contain"}, "quality": {"80"}}
	return c.image(ctx, "/render/image/authenticated/attachments/"+escapePath(path)+"?"+query.Encode(), true, limit)
}

func (c *Client) Avatar(ctx context.Context, path string, limit int64) (Blob, error) {
	query := url.Values{"width": {"160"}, "height": {"160"}, "resize": {"cover"}, "quality": {"80"}}
	return c.image(ctx, "/render/image/public/avatars/"+escapePath(path)+"?"+query.Encode(), false, limit)
}

func (c *Client) image(ctx context.Context, target string, auth bool, limit int64) (Blob, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.storageURL+target, nil)
	if err != nil {
		return Blob{}, err
	}
	if auth {
		token, err := jwt.ServiceRole(c.secret, c.issuer, c.now())
		if err != nil {
			return Blob{}, err
		}
		req.Header.Set("Authorization", "Bearer "+token)
	}
	req.Header.Set("Accept", "image/webp,image/jpeg,image/png,image/*;q=0.8")
	resp, err := c.http.Do(req)
	if err != nil {
		return Blob{}, fmt.Errorf("%w: storage: %v", ErrUnavailable, err)
	}
	defer resp.Body.Close()
	switch {
	case resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusBadRequest:
		return Blob{}, ErrNotFound
	case resp.StatusCode >= 300:
		return Blob{}, fmt.Errorf("%w: storage status %d", ErrUnavailable, resp.StatusCode)
	}
	contentType := strings.TrimSpace(strings.Split(resp.Header.Get("Content-Type"), ";")[0])
	if !imageType(contentType) {
		return Blob{}, ErrNotFound
	}
	if resp.ContentLength > limit {
		return Blob{}, ErrTooLarge
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, limit+1))
	if err != nil {
		return Blob{}, fmt.Errorf("%w: storage read: %v", ErrUnavailable, err)
	}
	if int64(len(data)) > limit {
		return Blob{}, ErrTooLarge
	}
	return Blob{Data: data, ContentType: contentType, ETag: resp.Header.Get("ETag")}, nil
}

func imageType(contentType string) bool {
	switch contentType {
	case "image/jpeg", "image/png", "image/webp", "image/gif", "image/avif":
		return true
	}
	return false
}

func escapePath(path string) string {
	parts := strings.Split(path, "/")
	for i, part := range parts {
		parts[i] = url.PathEscape(part)
	}
	return strings.Join(parts, "/")
}

func (c *Client) call(ctx context.Context, fn string, args map[string]any) (json.RawMessage, error) {
	body, err := json.Marshal(args)
	if err != nil {
		return nil, err
	}
	token, err := jwt.ServiceRole(c.secret, c.issuer, c.now())
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.restURL+"/rpc/"+fn, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Profile", "public")
	req.Header.Set("Accept-Profile", "public")
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%w: rpc %s: %v", ErrUnavailable, fn, err)
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxResponse))
	if err != nil {
		return nil, fmt.Errorf("%w: rpc %s: read response: %v", ErrUnavailable, fn, err)
	}
	if resp.StatusCode < 300 {
		return data, nil
	}
	var e struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	}
	_ = json.Unmarshal(data, &e)
	return nil, fmt.Errorf("%w: rpc %s: status %d %s", ErrUnavailable, fn, resp.StatusCode, clip(e.Code+" "+e.Message, 200))
}

func clip(s string, n int) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}
