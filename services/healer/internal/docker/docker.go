package docker

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"
)

const (
	ProjectLabel = "com.docker.compose.project"
	ServiceLabel = "com.docker.compose.service"
	maxResponse  = 4 << 20
	maxOutput    = 300
)

var idPattern = regexp.MustCompile(`^[0-9a-f]{12,64}$`)

type Container struct {
	ID      string
	Name    string
	Service string
	Labels  map[string]string
}

type Detail struct {
	ID        string
	Name      string
	Service   string
	Labels    map[string]string
	Running   bool
	Health    string
	StartedAt time.Time
	Output    string
}

type Error struct {
	Op     string
	Status int
	Err    error
}

func (e *Error) Error() string {
	if e.Status == 0 {
		return fmt.Sprintf("docker %s: %v", e.Op, e.Err)
	}
	if e.Err != nil {
		return fmt.Sprintf("docker %s: status %d: %v", e.Op, e.Status, e.Err)
	}
	return fmt.Sprintf("docker %s: status %d", e.Op, e.Status)
}

func (e *Error) Unwrap() error {
	return e.Err
}

func NotFound(err error) bool {
	var dockerErr *Error
	return errors.As(err, &dockerErr) && dockerErr.Status == http.StatusNotFound
}

type Client struct {
	http           *http.Client
	base           string
	requestTimeout time.Duration
	restartTimeout time.Duration
}

type Options struct {
	Socket         string
	BaseURL        string
	Transport      http.RoundTripper
	RequestTimeout time.Duration
	RestartTimeout time.Duration
}

func New(opts Options) *Client {
	transport := opts.Transport
	if transport == nil {
		socket := opts.Socket
		dialer := &net.Dialer{Timeout: 5 * time.Second}
		transport = &http.Transport{
			DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
				return dialer.DialContext(ctx, "unix", socket)
			},
			MaxIdleConns:    2,
			IdleConnTimeout: 30 * time.Second,
		}
	}
	base := opts.BaseURL
	if base == "" {
		base = "http://docker"
	}
	request, restart := opts.RequestTimeout, opts.RestartTimeout
	if request <= 0 {
		request = 10 * time.Second
	}
	if restart <= 0 {
		restart = 3 * time.Minute
	}
	return &Client{http: &http.Client{Transport: transport}, base: strings.TrimSuffix(base, "/"), requestTimeout: request, restartTimeout: restart}
}

type wireContainer struct {
	ID     string            `json:"Id"`
	Names  []string          `json:"Names"`
	Labels map[string]string `json:"Labels"`
}

func (c *Client) List(ctx context.Context, labels ...string) ([]Container, error) {
	filters, err := json.Marshal(map[string][]string{"label": labels})
	if err != nil {
		return nil, err
	}
	var wire []wireContainer
	if err := c.do(ctx, c.requestTimeout, http.MethodGet, "/containers/json?filters="+url.QueryEscape(string(filters)), "list", &wire); err != nil {
		return nil, err
	}
	containers := make([]Container, 0, len(wire))
	for _, w := range wire {
		if !idPattern.MatchString(w.ID) {
			continue
		}
		name := ""
		if len(w.Names) > 0 {
			name = strings.TrimPrefix(w.Names[0], "/")
		}
		containers = append(containers, Container{ID: w.ID, Name: name, Service: w.Labels[ServiceLabel], Labels: w.Labels})
	}
	return containers, nil
}

type wireDetail struct {
	ID    string `json:"Id"`
	Name  string `json:"Name"`
	State struct {
		Running   bool   `json:"Running"`
		StartedAt string `json:"StartedAt"`
		Health    *struct {
			Status string `json:"Status"`
			Log    []struct {
				ExitCode int    `json:"ExitCode"`
				Output   string `json:"Output"`
			} `json:"Log"`
		} `json:"Health"`
	} `json:"State"`
	Config struct {
		Labels map[string]string `json:"Labels"`
	} `json:"Config"`
}

func (c *Client) Inspect(ctx context.Context, id string) (Detail, error) {
	if !validRef(id) {
		return Detail{}, &Error{Op: "inspect", Err: errors.New("invalid container reference")}
	}
	var wire wireDetail
	if err := c.do(ctx, c.requestTimeout, http.MethodGet, "/containers/"+url.PathEscape(id)+"/json", "inspect", &wire); err != nil {
		return Detail{}, err
	}
	d := Detail{
		ID:      wire.ID,
		Name:    strings.TrimPrefix(wire.Name, "/"),
		Service: wire.Config.Labels[ServiceLabel],
		Labels:  wire.Config.Labels,
		Running: wire.State.Running,
	}
	if started, err := time.Parse(time.RFC3339Nano, wire.State.StartedAt); err == nil {
		d.StartedAt = started
	}
	if h := wire.State.Health; h != nil {
		d.Health = h.Status
		if n := len(h.Log); n > 0 {
			d.Output = clip(h.Log[n-1].Output, maxOutput)
		}
	}
	return d, nil
}

func (c *Client) Restart(ctx context.Context, id string) error {
	if !idPattern.MatchString(id) {
		return &Error{Op: "restart", Err: errors.New("invalid container id")}
	}
	return c.do(ctx, c.restartTimeout, http.MethodPost, "/containers/"+id+"/restart", "restart", nil)
}

func (c *Client) do(ctx context.Context, timeout time.Duration, method, path, op string, out any) error {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, method, c.base+path, nil)
	if err != nil {
		return &Error{Op: op, Err: err}
	}
	req.Header.Set("Accept", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return &Error{Op: op, Err: err}
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxResponse+1))
	if err != nil {
		return &Error{Op: op, Status: resp.StatusCode, Err: fmt.Errorf("read response: %w", err)}
	}
	if len(data) > maxResponse {
		return &Error{Op: op, Status: resp.StatusCode, Err: errors.New("response larger than 4 MiB")}
	}
	if resp.StatusCode >= 300 {
		return &Error{Op: op, Status: resp.StatusCode, Err: reason(data)}
	}
	if out == nil || len(data) == 0 {
		return nil
	}
	if err := json.Unmarshal(data, out); err != nil {
		return &Error{Op: op, Status: resp.StatusCode, Err: fmt.Errorf("decode response: %w", err)}
	}
	return nil
}

func reason(data []byte) error {
	var body struct {
		Message string `json:"message"`
	}
	if json.Unmarshal(data, &body) != nil || strings.TrimSpace(body.Message) == "" {
		return nil
	}
	return errors.New(clip(body.Message, maxOutput))
}

func validRef(ref string) bool {
	if idPattern.MatchString(ref) {
		return true
	}
	return ref != "" && len(ref) <= 128 && strings.IndexFunc(ref, func(r rune) bool {
		return !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '-' || r == '_' || r == '.')
	}) < 0
}

func clip(s string, n int) string {
	s = strings.Join(strings.Fields(s), " ")
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}
