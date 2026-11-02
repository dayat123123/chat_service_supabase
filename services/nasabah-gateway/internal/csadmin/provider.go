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
	DefaultClientID = "web-cs"

	SourceSettings = "settings"
	SourceServer   = "server"
	SourceNone     = "none"

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

type Source interface {
	Integration(ctx context.Context) (Settings, error)
}

type Effective struct {
	URL            string `json:"url"`
	URLSource      string `json:"url_source"`
	ClientID       string `json:"client_id"`
	ClientIDSource string `json:"client_id_source"`
}

type CheckResult struct {
	Result     string `json:"result"`
	Status     int    `json:"status,omitempty"`
	DurationMS int64  `json:"duration_ms"`
}

type ProviderOptions struct {
	Source Source
	Server Settings
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
	current Effective
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

func (p *Provider) Session(ctx context.Context) *Session {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.session == nil || (p.opts.Source != nil && !p.now().Before(p.checked.Add(p.opts.TTL))) {
		p.reload(ctx)
	}
	return p.session
}

func (p *Provider) Effective(ctx context.Context) Effective {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.reload(ctx)
	return p.current
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
	if s.URL == "" {
		return CheckResult{Result: CheckNotConfigured}
	}
	if s.ClientID == "" {
		s.ClientID = DefaultClientID
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
	var stored Settings
	if p.opts.Source != nil {
		ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
		defer cancel()
		loaded, err := p.opts.Source.Integration(ctx)
		if err != nil {
			p.opts.Log.Warn("Customer admin settings could not be read", "error", err)
			if p.session != nil {
				return
			}
		}
		stored = loaded
	}
	if stored.URL != "" && !ValidURL(stored.URL) {
		p.opts.Log.Warn("Ignoring an invalid customer admin address from the console settings")
	}
	next := resolve(stored, p.opts.Server)
	if p.session != nil && next == p.current {
		return
	}
	p.current = next
	p.session = NewSession(next.URL, next.ClientID, p.opts.Key, p.opts.Client)
	if p.session.Configured() {
		p.opts.Log.Info("Customer admin integration configured", "url", next.URL, "url_source", next.URLSource,
			"client_id", next.ClientID, "public_key", PublicKeyLine(p.opts.Key))
	} else {
		p.opts.Log.Warn("Customer admin service is not configured; customer requests will be refused",
			"url_source", next.URLSource, "key_configured", p.PublicKey() != "")
	}
}

func resolve(stored, server Settings) Effective {
	e := Effective{URLSource: SourceNone, ClientID: DefaultClientID, ClientIDSource: SourceServer}
	switch {
	case ValidURL(stored.URL):
		e.URL, e.URLSource = stored.URL, SourceSettings
	case server.URL != "":
		e.URL, e.URLSource = server.URL, SourceServer
	}
	switch {
	case ClientIDPattern.MatchString(stored.ClientID):
		e.ClientID, e.ClientIDSource = stored.ClientID, SourceSettings
	case server.ClientID != "":
		e.ClientID = server.ClientID
	}
	e.URL = strings.TrimSuffix(e.URL, "/")
	return e
}
