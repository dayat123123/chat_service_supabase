package probe

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unicode/utf8"
)

const (
	HTTP       = "http"
	TCP        = "tcp"
	MaxTargets = 100
	maxError   = 300
)

var namePattern = regexp.MustCompile(`^[a-z0-9][a-z0-9_.-]{0,59}$`)

type Target struct {
	Name string
	URL  string
	Kind string
	Addr string
}

type Result struct {
	Name      string  `json:"name"`
	Target    string  `json:"target"`
	OK        bool    `json:"ok"`
	Status    *int    `json:"status"`
	LatencyMS int64   `json:"latency_ms"`
	Error     *string `json:"error"`
}

func ValidName(name string) bool {
	return namePattern.MatchString(name)
}

func Parse(spec string) ([]Target, error) {
	var targets []Target
	seen := map[string]bool{}
	for item := range strings.SplitSeq(spec, ",") {
		item = strings.TrimSpace(item)
		if item == "" {
			continue
		}
		name, raw, ok := strings.Cut(item, "=")
		name, raw = strings.TrimSpace(name), strings.TrimSpace(raw)
		if !ok || !ValidName(name) {
			return nil, fmt.Errorf("each entry must look like name=url, with a lowercase name of letters, digits, '.', '_' or '-' (max. 60)")
		}
		if seen[name] {
			return nil, fmt.Errorf("probe %q is listed twice", name)
		}
		seen[name] = true
		target, err := parseTarget(name, raw)
		if err != nil {
			return nil, err
		}
		targets = append(targets, target)
	}
	if len(targets) > MaxTargets {
		return nil, fmt.Errorf("at most %d probes are allowed", MaxTargets)
	}
	return targets, nil
}

func parseTarget(name, raw string) (Target, error) {
	u, err := url.Parse(raw)
	if err != nil || u.Hostname() == "" {
		return Target{}, fmt.Errorf("probe %q needs an http(s)://host/path or tcp://host:port URL", name)
	}
	if u.User != nil {
		return Target{}, fmt.Errorf("probe %q must not carry credentials in its URL", name)
	}
	switch u.Scheme {
	case "http", "https":
		u.Fragment = ""
		return Target{Name: name, URL: u.String(), Kind: HTTP}, nil
	case "tcp":
		port, err := strconv.Atoi(u.Port())
		if err != nil || port < 1 || port > 65535 || (u.Path != "" && u.Path != "/") || u.RawQuery != "" {
			return Target{}, fmt.Errorf("probe %q: tcp targets look like tcp://host:port", name)
		}
		return Target{Name: name, URL: "tcp://" + u.Host, Kind: TCP, Addr: u.Host}, nil
	}
	return Target{}, fmt.Errorf("probe %q needs an http(s)://host/path or tcp://host:port URL", name)
}

type Prober struct {
	timeout time.Duration
	agent   string
	client  *http.Client
	dialer  *net.Dialer
}

func New(timeout time.Duration, userAgent string) *Prober {
	dialer := &net.Dialer{Timeout: timeout}
	transport := &http.Transport{
		DialContext:            dialer.DialContext,
		DisableKeepAlives:      true,
		TLSHandshakeTimeout:    timeout,
		ResponseHeaderTimeout:  timeout,
		MaxResponseHeaderBytes: 64 << 10,
	}
	return &Prober{
		timeout: timeout,
		agent:   userAgent,
		dialer:  dialer,
		client: &http.Client{
			Transport: transport,
			Timeout:   timeout,
			CheckRedirect: func(*http.Request, []*http.Request) error {
				return http.ErrUseLastResponse
			},
		},
	}
}

func (p *Prober) Run(ctx context.Context, targets []Target) []Result {
	results := make([]Result, len(targets))
	var wg sync.WaitGroup
	for i, target := range targets {
		wg.Add(1)
		go func() {
			defer wg.Done()
			results[i] = p.Check(ctx, target)
		}()
	}
	wg.Wait()
	return results
}

func (p *Prober) Check(ctx context.Context, target Target) Result {
	ctx, cancel := context.WithTimeout(ctx, p.timeout)
	defer cancel()
	result := Result{Name: target.Name, Target: target.URL}
	start := time.Now()
	var err error
	if target.Kind == TCP {
		err = p.connect(ctx, target.Addr)
	} else {
		result.Status, err = p.get(ctx, target.URL)
	}
	result.LatencyMS = time.Since(start).Milliseconds()
	if err != nil {
		text := p.describe(err)
		result.Error = &text
		return result
	}
	result.OK = true
	return result
}

func (p *Prober) connect(ctx context.Context, addr string) error {
	conn, err := p.dialer.DialContext(ctx, "tcp", addr)
	if err != nil {
		return err
	}
	return conn.Close()
}

type statusError int

func (s statusError) Error() string {
	return "HTTP " + strconv.Itoa(int(s))
}

func (p *Prober) get(ctx context.Context, target string) (*int, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, target, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", p.agent)
	req.Header.Set("Accept", "*/*")
	resp, err := p.client.Do(req)
	if err != nil {
		return nil, err
	}
	resp.Body.Close()
	status := resp.StatusCode
	if status >= 500 {
		return &status, statusError(status)
	}
	return &status, nil
}

func (p *Prober) describe(err error) string {
	var status statusError
	var dns *net.DNSError
	var netErr net.Error
	var urlErr *url.Error
	switch {
	case errors.As(err, &status):
		return status.Error()
	case errors.Is(err, context.DeadlineExceeded), errors.As(err, &netErr) && netErr.Timeout():
		return "waktu habis setelah " + p.timeout.String()
	case errors.As(err, &dns) && dns.IsNotFound:
		return "nama host tidak ditemukan"
	case errors.Is(err, syscall.ECONNREFUSED) || strings.Contains(strings.ToLower(err.Error()), "refused"):
		return "koneksi ditolak"
	case errors.Is(err, syscall.ECONNRESET):
		return "koneksi diputus"
	case errors.As(err, &urlErr):
		return clip("gagal: " + urlErr.Err.Error())
	}
	return clip("gagal: " + err.Error())
}

func clip(s string) string {
	if utf8.RuneCountInString(s) <= maxError {
		return s
	}
	return string([]rune(s)[:maxError])
}
