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
	"strconv"
	"strings"
	"unicode/utf8"
)

const (
	maxReply  = 64 << 10
	maxReason = 300

	CodeForbidden    = "upload_forbidden"
	CodeExists       = "already_exists"
	CodeTooLarge     = "file_too_large"
	CodeTooMany      = "too_many_uploads"
	CodeInvalidToken = "invalid_token"
	CodeError        = "storage_error"
	CodeUnavailable  = "storage_unavailable"
)

const EdgeHeader = "X-Olt-Edge"

type Upload struct {
	Bucket      string
	Path        string
	ContentType string
	Body        []byte
	Upsert      bool
	Token       string
	Edge        string
}

type Failure struct {
	Code        string
	Status      int
	Reason      string
	Unreachable bool
}

func (f *Failure) Error() string {
	return f.Code + ": " + f.Reason
}

type Client struct {
	baseURL string
	http    *http.Client
}

func New(baseURL string, connections int) *Client {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.MaxIdleConnsPerHost = max(connections, 2)
	return &Client{baseURL: baseURL, http: &http.Client{Transport: transport}}
}

func (c *Client) Upload(ctx context.Context, u Upload) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/object/"+u.Bucket+"/"+u.Path, bytes.NewReader(u.Body))
	if err != nil {
		return &Failure{Code: CodeError, Status: http.StatusBadGateway, Reason: err.Error()}
	}
	req.Header.Set("Authorization", "Bearer "+u.Token)
	req.Header.Set("Content-Type", u.ContentType)
	req.Header.Set("Cache-Control", "max-age=3600")
	if u.Upsert {
		req.Header.Set("x-upsert", "true")
	}
	if u.Edge != "" {
		req.Header.Set(EdgeHeader, u.Edge)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return &Failure{Code: CodeUnavailable, Status: http.StatusBadGateway, Reason: transportError(err), Unreachable: true}
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(io.LimitReader(resp.Body, maxReply))
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}
	return Classify(resp.StatusCode, data)
}

func (c *Client) Delete(ctx context.Context, bucket, path, token string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, c.baseURL+"/object/"+bucket+"/"+path, nil)
	if err != nil {
		return &Failure{Code: CodeError, Status: http.StatusBadGateway, Reason: err.Error()}
	}
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := c.http.Do(req)
	if err != nil {
		return &Failure{Code: CodeUnavailable, Status: http.StatusBadGateway, Reason: transportError(err), Unreachable: true}
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(io.LimitReader(resp.Body, maxReply))
	if (resp.StatusCode >= 200 && resp.StatusCode < 300) || resp.StatusCode == http.StatusNotFound {
		return nil
	}
	return Classify(resp.StatusCode, data)
}

func (c *Client) Ping(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/status", nil)
	if err != nil {
		return err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return errors.New(transportError(err))
	}
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, maxReply))
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("storage status %d", resp.StatusCode)
	}
	return nil
}

type reply struct {
	StatusCode json.RawMessage `json:"statusCode"`
	Error      string          `json:"error"`
	Message    string          `json:"message"`
	Code       string          `json:"code"`
}

func Classify(status int, data []byte) *Failure {
	var body reply
	_ = json.Unmarshal(data, &body)
	effective := status
	if code, ok := statusCode(body.StatusCode); ok {
		effective = code
	}
	text := strings.ToLower(body.Message + " " + body.Error + " " + body.Code)
	reason := clip(fmt.Sprintf("status %d, statusCode %d, %s: %s", status, effective,
		strings.TrimSpace(body.Code+" "+body.Error), body.Message))
	failure := func(code string, httpStatus int) *Failure {
		return &Failure{Code: code, Status: httpStatus, Reason: reason}
	}
	switch {
	case strings.Contains(text, "row-level security"):
		return failure(CodeForbidden, http.StatusForbidden)
	case effective == http.StatusTooManyRequests || status == http.StatusTooManyRequests ||
		strings.Contains(text, "too_many") || strings.Contains(text, "429") || strings.Contains(text, "rate_limited"):
		return failure(CodeTooMany, http.StatusTooManyRequests)
	case effective == http.StatusConflict || body.Code == "KeyAlreadyExists":
		return failure(CodeExists, http.StatusConflict)
	case effective == http.StatusRequestEntityTooLarge || status == http.StatusRequestEntityTooLarge:
		return failure(CodeTooLarge, http.StatusRequestEntityTooLarge)
	case effective == http.StatusForbidden && strings.Contains(text, "\"exp\" claim"):
		return failure(CodeInvalidToken, http.StatusUnauthorized)
	case effective == http.StatusForbidden && !tokenProblem(text):
		return failure(CodeForbidden, http.StatusForbidden)
	}
	return failure(CodeError, http.StatusBadGateway)
}

func tokenProblem(text string) bool {
	for _, s := range []string{"signature", "jwt", "claim", "algorithm", "invalid compact"} {
		if strings.Contains(text, s) {
			return true
		}
	}
	return false
}

func statusCode(raw json.RawMessage) (int, bool) {
	if len(raw) == 0 {
		return 0, false
	}
	var text string
	if json.Unmarshal(raw, &text) != nil {
		text = string(raw)
	}
	code, err := strconv.Atoi(strings.TrimSpace(text))
	if err != nil || code < 100 || code > 599 {
		return 0, false
	}
	return code, true
}

func transportError(err error) string {
	var urlErr *url.Error
	if errors.As(err, &urlErr) {
		err = urlErr.Err
	}
	return clip(err.Error())
}

func clip(s string) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= maxReason {
		return s
	}
	return string([]rune(s)[:maxReason])
}
