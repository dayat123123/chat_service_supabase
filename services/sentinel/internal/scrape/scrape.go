package scrape

import (
	"bufio"
	"cmp"
	"context"
	"errors"
	"fmt"
	"io"
	"math"
	"net"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"olt-social/sentinel/internal/probe"
)

const maxBody = 4 << 20

var Families = map[string]bool{
	"pgrst_db_pool_timeouts_total":          true,
	"pgrst_db_pool_waiting":                 true,
	"pgrst_db_pool_available":               true,
	"pgrst_db_pool_max":                     true,
	"realtime_channel_global_events":        true,
	"realtime_connections_global_connected": true,
}

type Result struct {
	Source   string             `json:"source"`
	Instance string             `json:"instance"`
	OK       bool               `json:"ok"`
	Error    *string            `json:"error"`
	Values   map[string]float64 `json:"values"`
	Missed   int                `json:"missed,omitempty"`
}

type Options struct {
	Timeout   time.Duration
	UserAgent string
	Token     func() (string, error)
	Password  string
	Lookup    func(ctx context.Context, host string) ([]string, error)
}

type Scraper struct {
	opts   Options
	dialer *net.Dialer
}

func New(opts Options) *Scraper {
	if opts.Lookup == nil {
		opts.Lookup = net.DefaultResolver.LookupHost
	}
	return &Scraper{opts: opts, dialer: &net.Dialer{Timeout: opts.Timeout}}
}

func (s *Scraper) Run(ctx context.Context, sources []Source) []Result {
	var mu sync.Mutex
	var results []Result
	var wg sync.WaitGroup
	for _, source := range sources {
		wg.Add(1)
		go func() {
			defer wg.Done()
			found := s.source(ctx, source)
			mu.Lock()
			results = append(results, found...)
			mu.Unlock()
		}()
	}
	wg.Wait()
	slices.SortFunc(results, func(a, b Result) int {
		return cmp.Or(cmp.Compare(a.Source, b.Source), cmp.Compare(a.Instance, b.Instance))
	})
	if results == nil {
		results = []Result{}
	}
	return results
}

func (s *Scraper) source(ctx context.Context, source Source) []Result {
	ctx, cancel := context.WithTimeout(ctx, s.opts.Timeout)
	defer cancel()
	addrs, err := s.resolve(ctx, source.Host)
	if err != nil {
		return []Result{s.failed(source, "", err)}
	}
	results := make([]Result, len(addrs))
	var wg sync.WaitGroup
	for i, addr := range addrs {
		wg.Add(1)
		go func() {
			defer wg.Done()
			values, err := s.fetch(ctx, source, addr)
			if err != nil {
				results[i] = s.failed(source, addr, err)
				return
			}
			results[i] = Result{Source: source.Name, Instance: addr, OK: true, Values: values}
		}()
	}
	wg.Wait()
	return results
}

func (s *Scraper) resolve(ctx context.Context, host string) ([]string, error) {
	if net.ParseIP(host) != nil {
		return []string{host}, nil
	}
	addrs, err := s.opts.Lookup(ctx, host)
	if err != nil {
		return nil, err
	}
	if len(addrs) == 0 {
		return nil, &net.DNSError{Err: "no such host", Name: host, IsNotFound: true}
	}
	slices.Sort(addrs)
	return slices.Compact(addrs), nil
}

func (s *Scraper) failed(source Source, instance string, err error) Result {
	text := probe.Describe(err, s.opts.Timeout)
	return Result{Source: source.Name, Instance: instance, Error: &text, Values: map[string]float64{}}
}

func (s *Scraper) fetch(ctx context.Context, source Source, addr string) (map[string]float64, error) {
	if source.Kind == PgBouncer {
		return s.pgbouncer(ctx, source, addr)
	}
	return s.prometheus(ctx, source, addr)
}

func (s *Scraper) prometheus(ctx context.Context, source Source, addr string) (map[string]float64, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, source.URL.String(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", s.opts.UserAgent)
	req.Header.Set("Accept", "text/plain")
	if source.JWT {
		if s.opts.Token == nil {
			return nil, errors.New("token JWT tidak tersedia")
		}
		token, err := s.opts.Token()
		if err != nil {
			return nil, err
		}
		req.Header.Set("Authorization", "Bearer "+token)
	}
	target := source.Address(addr)
	client := &http.Client{
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, network, _ string) (net.Conn, error) {
				return s.dialer.DialContext(ctx, network, target)
			},
			DisableKeepAlives:      true,
			TLSHandshakeTimeout:    s.opts.Timeout,
			ResponseHeaderTimeout:  s.opts.Timeout,
			MaxResponseHeaderBytes: 64 << 10,
		},
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, probe.StatusError(resp.StatusCode)
	}
	return ParseText(io.LimitReader(resp.Body, maxBody))
}

func ParseText(r io.Reader) (map[string]float64, error) {
	values := map[string]float64{}
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 64<<10), 1<<20)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || line[0] == '#' {
			continue
		}
		name, value, ok := sample(line)
		if !ok || !Families[name] {
			continue
		}
		values[name] += value
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("metrik tidak terbaca: %w", err)
	}
	return values, nil
}

func sample(line string) (string, float64, bool) {
	end := strings.IndexAny(line, "{ \t")
	if end <= 0 {
		return "", 0, false
	}
	name, rest := line[:end], line[end:]
	if rest[0] == '{' {
		closing := labelsEnd(rest)
		if closing < 0 {
			return "", 0, false
		}
		rest = rest[closing+1:]
	}
	fields := strings.Fields(rest)
	if len(fields) == 0 {
		return "", 0, false
	}
	value, err := strconv.ParseFloat(fields[0], 64)
	if err != nil || math.IsNaN(value) || math.IsInf(value, 0) {
		return "", 0, false
	}
	return name, value, true
}

func labelsEnd(s string) int {
	quoted, escaped := false, false
	for i := 1; i < len(s); i++ {
		c := s[i]
		switch {
		case escaped:
			escaped = false
		case c == '\\' && quoted:
			escaped = true
		case c == '"':
			quoted = !quoted
		case c == '}' && !quoted:
			return i
		}
	}
	return -1
}
