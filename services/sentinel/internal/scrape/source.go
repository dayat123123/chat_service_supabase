package scrape

import (
	"fmt"
	"net"
	"net/url"
	"strconv"
	"strings"

	"olt-social/sentinel/internal/probe"
)

const (
	Prometheus = "prometheus"
	PgBouncer  = "pgbouncer"
	MaxSources = 20

	DefaultStatsUser = "olt_stats"
)

type Source struct {
	Name   string
	Target string
	Kind   string
	URL    *url.URL
	JWT    bool
	Host   string
	Port   string
	User   string
}

func (s Source) Address(host string) string {
	return net.JoinHostPort(host, s.Port)
}

func Parse(spec string) ([]Source, error) {
	var sources []Source
	seen := map[string]bool{}
	for item := range strings.SplitSeq(spec, ",") {
		item = strings.TrimSpace(item)
		if item == "" {
			continue
		}
		name, raw, ok := strings.Cut(item, "=")
		name, raw = strings.TrimSpace(name), strings.TrimSpace(raw)
		if !ok || !probe.ValidName(name) {
			return nil, fmt.Errorf("each entry must look like name=url, with a lowercase name of letters, digits, '.', '_' or '-' (max. 60)")
		}
		if seen[name] {
			return nil, fmt.Errorf("metrics source %q is listed twice", name)
		}
		seen[name] = true
		source, err := parseSource(name, raw)
		if err != nil {
			return nil, err
		}
		sources = append(sources, source)
	}
	if len(sources) > MaxSources {
		return nil, fmt.Errorf("at most %d metrics sources are allowed", MaxSources)
	}
	return sources, nil
}

func parseSource(name, raw string) (Source, error) {
	invalid := fmt.Errorf("metrics source %q needs an http(s)://, jwt+http(s):// or pgbouncer://user@host:port URL", name)
	u, err := url.Parse(raw)
	if err != nil || u.Hostname() == "" {
		return Source{}, invalid
	}
	if _, hasPassword := u.User.Password(); hasPassword {
		return Source{}, fmt.Errorf("metrics source %q must not carry a secret in its URL", name)
	}
	source := Source{Name: name, Host: u.Hostname()}
	switch u.Scheme {
	case "http", "https", "jwt+http", "jwt+https":
		if u.User != nil {
			return Source{}, fmt.Errorf("metrics source %q must not carry credentials in its URL", name)
		}
		source.Kind = Prometheus
		source.JWT = strings.HasPrefix(u.Scheme, "jwt+")
		u.Scheme = strings.TrimPrefix(u.Scheme, "jwt+")
		u.Fragment = ""
		source.Port = u.Port()
		if source.Port == "" {
			source.Port = map[string]string{"http": "80", "https": "443"}[u.Scheme]
		}
		source.URL = u
		source.Target = u.String()
		if source.JWT {
			source.Target = "jwt+" + source.Target
		}
		return source, nil
	case "pgbouncer":
		port, err := strconv.Atoi(u.Port())
		if err != nil || port < 1 || port > 65535 || (u.Path != "" && u.Path != "/") || u.RawQuery != "" {
			return Source{}, fmt.Errorf("metrics source %q: pgbouncer sources look like pgbouncer://user@host:port", name)
		}
		source.Kind = PgBouncer
		source.Port = u.Port()
		source.User = DefaultStatsUser
		if u.User != nil && u.User.Username() != "" {
			source.User = u.User.Username()
		}
		source.Target = "pgbouncer://" + source.User + "@" + u.Host
		return source, nil
	}
	return Source{}, invalid
}

func NeedsPgBouncerPassword(sources []Source) bool {
	for _, s := range sources {
		if s.Kind == PgBouncer {
			return true
		}
	}
	return false
}
