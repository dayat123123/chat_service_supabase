package moderation

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"math"
	"net/http"
	"net/url"
	"slices"
	"sync"
	"time"
)

const (
	UnknownRevision int64 = -1

	maxReply = 64 << 10
)

var (
	ErrUnavailable  = errors.New("classifier unavailable")
	ErrModelMissing = errors.New("classifier model missing")
	ErrUnreadable   = errors.New("classifier cannot read the image")
)

type Verdict string

const (
	Allow Verdict = "allow"
	Hold  Verdict = "hold"
	Block Verdict = "block"
)

type Limit struct {
	Hold  *float64 `json:"hold"`
	Block *float64 `json:"block"`
}

type Thresholds struct {
	Revision int64
	Limits   map[string]Limit
}

type Config struct {
	Revision  int64
	Unchanged bool
	Limits    map[string]Limit
}

type Result struct {
	Model  string             `json:"model"`
	Scores map[string]float64 `json:"scores"`
}

type Decision struct {
	Verdict  Verdict
	Category string
	Score    float64
}

func Decide(scores map[string]float64, t Thresholds) Decision {
	categories := make([]string, 0, len(t.Limits))
	for c := range t.Limits {
		categories = append(categories, c)
	}
	slices.Sort(categories)
	pick := func(limit func(Limit) *float64) (Decision, bool) {
		var best Decision
		found := false
		for _, c := range categories {
			l := limit(t.Limits[c])
			s, ok := scores[c]
			if l == nil || !ok || s < *l {
				continue
			}
			if !found || s > best.Score {
				best, found = Decision{Category: c, Score: s}, true
			}
		}
		return best, found
	}
	if d, ok := pick(func(l Limit) *float64 { return l.Block }); ok {
		d.Verdict = Block
		return d
	}
	if d, ok := pick(func(l Limit) *float64 { return l.Hold }); ok {
		d.Verdict = Hold
		return d
	}
	d := Decision{Verdict: Allow}
	for _, c := range categories {
		if s, ok := scores[c]; ok && (d.Category == "" || s > d.Score) {
			d.Category, d.Score = c, s
		}
	}
	return d
}

type Client struct {
	baseURL string
	timeout time.Duration
	http    *http.Client
}

func NewClient(baseURL string, timeout time.Duration, connections int) *Client {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.Proxy = nil
	transport.MaxIdleConnsPerHost = max(connections, 2)
	return &Client{baseURL: baseURL, timeout: timeout, http: &http.Client{Transport: transport}}
}

func (c *Client) Classify(ctx context.Context, mime string, body []byte, requestID string) (Result, error) {
	ctx, cancel := context.WithTimeout(ctx, c.timeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/classify", bytes.NewReader(body))
	if err != nil {
		return Result{}, fmt.Errorf("%w: %v", ErrUnavailable, err)
	}
	req.Header.Set("Content-Type", mime)
	req.Header.Set("X-Request-Id", requestID)
	resp, err := c.http.Do(req)
	if err != nil {
		return Result{}, fmt.Errorf("%w: %v", ErrUnavailable, transportError(err))
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxReply))
	if err != nil {
		return Result{}, fmt.Errorf("%w: read reply: %v", ErrUnavailable, err)
	}
	if resp.StatusCode == http.StatusOK {
		var r Result
		if err := json.Unmarshal(data, &r); err != nil || r.Model == "" || len(r.Scores) == 0 || !validScores(r.Scores) {
			return Result{}, fmt.Errorf("%w: invalid reply", ErrUnavailable)
		}
		return r, nil
	}
	var reply struct {
		Code string `json:"code"`
	}
	_ = json.Unmarshal(data, &reply)
	switch {
	case reply.Code == "model_missing":
		return Result{}, ErrModelMissing
	case resp.StatusCode == http.StatusUnprocessableEntity || resp.StatusCode == http.StatusUnsupportedMediaType:
		return Result{}, fmt.Errorf("%w: %s", ErrUnreadable, reply.Code)
	}
	return Result{}, fmt.Errorf("%w: status %d %s", ErrUnavailable, resp.StatusCode, reply.Code)
}

func (c *Client) Ping(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/status", nil)
	if err != nil {
		return err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrUnavailable, transportError(err))
	}
	data, _ := io.ReadAll(io.LimitReader(resp.Body, maxReply))
	resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		return nil
	}
	var reply struct {
		Code string `json:"code"`
	}
	if json.Unmarshal(data, &reply) == nil && reply.Code == "model_missing" {
		return ErrModelMissing
	}
	return fmt.Errorf("%w: status %d", ErrUnavailable, resp.StatusCode)
}

func validScores(scores map[string]float64) bool {
	for _, v := range scores {
		if math.IsNaN(v) || v < 0 || v > 1 {
			return false
		}
	}
	return true
}

func transportError(err error) string {
	var urlErr *url.Error
	if errors.As(err, &urlErr) {
		err = urlErr.Err
	}
	return err.Error()
}

type ConfigStore interface {
	ModerationConfig(ctx context.Context, known int64) (Config, error)
}

type Policy struct {
	store    ConfigStore
	log      *slog.Logger
	interval time.Duration
	timeout  time.Duration
	changed  func()

	mu      sync.Mutex
	current *Thresholds
	failing bool
}

func NewPolicy(store ConfigStore, log *slog.Logger, interval time.Duration, changed func()) *Policy {
	return &Policy{store: store, log: log, interval: interval, timeout: 10 * time.Second, changed: changed}
}

func (p *Policy) Current() (Thresholds, bool) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.current == nil {
		return Thresholds{Revision: UnknownRevision}, false
	}
	return *p.current, true
}

func (p *Policy) Run(ctx context.Context) {
	p.Refresh(ctx)
	ticker := time.NewTicker(p.interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			p.Refresh(ctx)
		}
	}
}

func (p *Policy) Refresh(ctx context.Context) {
	known, _ := p.Current()
	call, cancel := context.WithTimeout(ctx, p.timeout)
	cfg, err := p.store.ModerationConfig(call, known.Revision)
	cancel()
	if ctx.Err() != nil {
		return
	}
	p.mu.Lock()
	was := p.failing
	p.failing = err != nil
	loadedBefore := p.current != nil
	if err == nil && !cfg.Unchanged {
		p.current = &Thresholds{Revision: cfg.Revision, Limits: cfg.Limits}
	}
	p.mu.Unlock()
	switch {
	case err != nil && !was:
		p.log.Warn("Image thresholds could not be loaded; retrying on the next interval", "error", err,
			"loaded", loadedBefore)
	case err == nil && was:
		p.log.Info("Image thresholds can be loaded again")
	}
	if err == nil && !cfg.Unchanged {
		p.log.Info("Image thresholds loaded", "revision", cfg.Revision, "categories", len(cfg.Limits))
		if !loadedBefore && p.changed != nil {
			p.changed()
		}
	}
}
