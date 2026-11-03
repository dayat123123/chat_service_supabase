package safehttp

import (
	"errors"
	"net/netip"
	"net/url"
	"slices"
	"strconv"
	"strings"
)

var ErrBlocked = errors.New("blocked")

type BlockedError struct {
	Reason string
}

func (e *BlockedError) Error() string {
	return "blocked: " + e.Reason
}

func (e *BlockedError) Is(target error) bool {
	return target == ErrBlocked
}

func blocked(reason string) error {
	return &BlockedError{Reason: reason}
}

const (
	ReasonScheme      = "scheme"
	ReasonUserinfo    = "userinfo"
	ReasonPort        = "port"
	ReasonHost        = "invalid_host"
	ReasonNumericHost = "numeric_host"
	ReasonInternal    = "internal_host"
	ReasonNonASCII    = "non_ascii_host"
	ReasonAddress     = "private_address"
)

var deniedV4 = prefixes(
	"0.0.0.0/8",
	"10.0.0.0/8",
	"100.64.0.0/10",
	"127.0.0.0/8",
	"169.254.0.0/16",
	"172.16.0.0/12",
	"192.0.0.0/24",
	"192.0.2.0/24",
	"192.31.196.0/24",
	"192.52.193.0/24",
	"192.88.99.0/24",
	"192.168.0.0/16",
	"192.175.48.0/24",
	"198.18.0.0/15",
	"198.51.100.0/24",
	"203.0.113.0/24",
	"224.0.0.0/4",
	"240.0.0.0/4",
)

var (
	globalV6 = netip.MustParsePrefix("2000::/3")
	deniedV6 = prefixes(
		"2001::/23",
		"2001:db8::/32",
		"2002::/16",
		"3fff::/20",
	)
)

var internalSuffixes = []string{
	".localhost", ".local", ".localdomain", ".internal", ".intranet", ".lan", ".home", ".corp",
	".home.arpa", ".in-addr.arpa", ".ip6.arpa", ".test", ".invalid", ".example", ".onion",
}

var internalNames = []string{"localhost", "localhost.localdomain", "metadata", "metadata.google.internal"}

type Policy struct {
	Ports []uint16
	Allow []netip.Prefix
}

func DefaultPolicy() Policy {
	return Policy{Ports: []uint16{80, 443}}
}

func (p Policy) CheckAddr(addr netip.Addr) error {
	if !addr.IsValid() {
		return blocked(ReasonAddress)
	}
	if addr.Zone() != "" {
		return blocked(ReasonAddress)
	}
	addr = addr.Unmap()
	for _, allow := range p.Allow {
		if allow.Contains(addr) {
			return nil
		}
	}
	if addr.Is4() {
		for _, deny := range deniedV4 {
			if deny.Contains(addr) {
				return blocked(ReasonAddress)
			}
		}
		return nil
	}
	if !globalV6.Contains(addr) {
		return blocked(ReasonAddress)
	}
	for _, deny := range deniedV6 {
		if deny.Contains(addr) {
			return blocked(ReasonAddress)
		}
	}
	return nil
}

func (p Policy) CheckPort(port uint16) error {
	if !slices.Contains(p.Ports, port) {
		return blocked(ReasonPort)
	}
	return nil
}

func (p Policy) CheckURL(u *url.URL) error {
	if u == nil {
		return blocked(ReasonHost)
	}
	scheme := strings.ToLower(u.Scheme)
	if scheme != "http" && scheme != "https" {
		return blocked(ReasonScheme)
	}
	if u.User != nil {
		return blocked(ReasonUserinfo)
	}
	if u.Opaque != "" || u.Host == "" {
		return blocked(ReasonHost)
	}
	port, err := urlPort(u, scheme)
	if err != nil {
		return err
	}
	if err := p.CheckPort(port); err != nil {
		return err
	}
	return p.checkHost(u.Hostname())
}

func (p Policy) checkHost(host string) error {
	if host == "" {
		return blocked(ReasonHost)
	}
	if addr, err := netip.ParseAddr(host); err == nil {
		return p.CheckAddr(addr)
	}
	for i := 0; i < len(host); i++ {
		if host[i] >= 0x80 {
			return blocked(ReasonNonASCII)
		}
	}
	name := strings.TrimSuffix(strings.ToLower(host), ".")
	if name == "" || len(name) > 253 {
		return blocked(ReasonHost)
	}
	labels := strings.Split(name, ".")
	for _, label := range labels {
		if label == "" || len(label) > 63 || !validLabel(label) {
			return blocked(ReasonHost)
		}
	}
	if numericLabel(labels[len(labels)-1]) {
		return blocked(ReasonNumericHost)
	}
	if len(labels) < 2 || slices.Contains(internalNames, name) {
		return blocked(ReasonInternal)
	}
	for _, suffix := range internalSuffixes {
		if strings.HasSuffix(name, suffix) {
			return blocked(ReasonInternal)
		}
	}
	return nil
}

func urlPort(u *url.URL, scheme string) (uint16, error) {
	raw := u.Port()
	if raw == "" {
		if strings.HasSuffix(u.Host, ":") {
			return 0, blocked(ReasonPort)
		}
		if scheme == "https" {
			return 443, nil
		}
		return 80, nil
	}
	n, err := strconv.ParseUint(raw, 10, 16)
	if err != nil {
		return 0, blocked(ReasonPort)
	}
	return uint16(n), nil
}

func validLabel(label string) bool {
	for i := 0; i < len(label); i++ {
		c := label[i]
		switch {
		case c >= 'a' && c <= 'z', c >= '0' && c <= '9', c == '-', c == '_':
		default:
			return false
		}
	}
	return true
}

func numericLabel(label string) bool {
	if strings.HasPrefix(label, "0x") {
		label = label[2:]
		for i := 0; i < len(label); i++ {
			c := label[i]
			if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
				return false
			}
		}
		return true
	}
	for i := 0; i < len(label); i++ {
		if label[i] < '0' || label[i] > '9' {
			return false
		}
	}
	return label != ""
}

func prefixes(list ...string) []netip.Prefix {
	out := make([]netip.Prefix, 0, len(list))
	for _, s := range list {
		out = append(out, netip.MustParsePrefix(s))
	}
	return out
}
