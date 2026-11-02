package csadmin

import (
	"context"
	"crypto/ed25519"
	"errors"
	"log/slog"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"
)

const (
	CheckOK            = "ok"
	CheckRefused       = "refused"
	CheckIPNotAllowed  = "ip_not_allowed"
	CheckDisabled      = "disabled"
	CheckUnexpected    = "unexpected"
	CheckUnreachable   = "unreachable"
	CheckNotConfigured = "not_configured"
	CheckNoKey         = "no_key"
)

var (
	ClientIDPattern = regexp.MustCompile(`^[A-Za-z0-9._-]{1,50}$`)
	hostPattern     = regexp.MustCompile(`^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?$`)
	pathPattern     = regexp.MustCompile(`^(/[A-Za-z0-9._~-]+)*/?$`)
)

type Settings struct {
	URL      string
	ClientID string
}

type Record struct {
	URL         string  `json:"url"`
	ClientID    string  `json:"client_id"`
	Configured  bool    `json:"configured"`
	ConnectedAt *string `json:"connected_at"`
	ConnectedBy *string `json:"connected_by"`
}

func (r Record) Settings() Settings { return Settings{URL: r.URL, ClientID: r.ClientID} }

type Source interface {
	Integration(ctx context.Context) (Record, error)
}

type CheckResult struct {
	Result     string `json:"result"`
	Status     int    `json:"status,omitempty"`
	DurationMS int64  `json:"duration_ms"`
}

type ProviderOptions struct {
	Source Source
	Key    ed25519.PrivateKey
	Client *http.Client
	TTL    time.Duration
	Log    *slog.Logger
}

type Provider struct {
	opts ProviderOptions
	now  func() time.Time

	mu      sync.Mutex
	session *Session
	current Settings
	checked time.Time
}

func NewProvider(opts ProviderOptions) *Provider {
	if opts.Client == nil {
		opts.Client = &http.Client{Timeout: 15 * time.Second}
	}
	if opts.TTL <= 0 {
		opts.TTL = 15 * time.Second
	}
	if opts.Log == nil {
		opts.Log = slog.New(slog.DiscardHandler)
	}
	return &Provider{opts: opts, now: time.Now}
}

func ValidURL(raw string) bool {
	if raw == "" || len(raw) > 200 || strings.ContainsAny(raw, " ?#@\\") {
		return false
	}
	u, err := url.Parse(raw)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Opaque != "" || u.User != nil {
		return false
	}
	return hostPattern.MatchString(u.Host) && pathPattern.MatchString(u.EscapedPath())
}

func Usable(s Settings) bool {
	return ValidURL(s.URL) && ClientIDPattern.MatchString(s.ClientID)
}

func (p *Provider) Session(ctx context.Context) *Session {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.session == nil || !p.now().Before(p.checked.Add(p.opts.TTL)) {
		p.reload(ctx)
	}
	return p.session
}

func (p *Provider) Refresh(ctx context.Context) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.reload(ctx)
}

func (p *Provider) PublicKey() string {
	if len(p.opts.Key) != ed25519.PrivateKeySize {
		return ""
	}
	return PublicKeyLine(p.opts.Key)
}

func (p *Provider) Check(ctx context.Context, s Settings) CheckResult {
	if p.PublicKey() == "" {
		return CheckResult{Result: CheckNoKey}
	}
	if s.URL == "" || s.ClientID == "" {
		return CheckResult{Result: CheckNotConfigured}
	}
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	started := time.Now()
	_, _, err := NewSession(s.URL, s.ClientID, p.opts.Key, p.opts.Client).exchange(ctx)
	result := CheckResult{DurationMS: time.Since(started).Milliseconds()}
	var refused *RefusedError
	switch {
	case err == nil:
		result.Result, result.Status = CheckOK, http.StatusOK
	case errors.As(err, &refused):
		result.Status = refused.Status
		switch refused.Status {
		case http.StatusUnauthorized:
			result.Result = CheckRefused
		case http.StatusForbidden:
			result.Result = CheckIPNotAllowed
		case http.StatusNotFound:
			result.Result = CheckDisabled
		default:
			result.Result = CheckUnexpected
		}
	default:
		result.Result = CheckUnreachable
	}
	return result
}

func (p *Provider) reload(ctx context.Context) {
	p.checked = p.now()
	var next Settings
	if p.opts.Source != nil {
		ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
		defer cancel()
		record, err := p.opts.Source.Integration(ctx)
		if err != nil {
			p.opts.Log.Warn("Customer admin settings could not be read", "error", err)
			if p.session != nil {
				return
			}
		}
		if record.Configured && Usable(record.Settings()) {
			next = record.Settings()
		}
	}
	next.URL = strings.TrimSuffix(next.URL, "/")
	if p.session != nil && next == p.current {
		return
	}
	p.current = next
	p.session = NewSession(next.URL, next.ClientID, p.opts.Key, p.opts.Client)
	if p.session.Configured() {
		p.opts.Log.Info("Customer admin integration configured", "url", next.URL, "client_id", next.ClientID,
			"public_key", PublicKeyLine(p.opts.Key))
	} else {
		p.opts.Log.Warn("Customer admin integration is not set up; customer requests will be refused",
			"key_configured", p.PublicKey() != "")
	}
}
