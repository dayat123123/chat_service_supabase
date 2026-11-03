package safehttp

import (
	"errors"
	"net/netip"
	"net/url"
	"testing"
)

func reasonOf(err error) string {
	var b *BlockedError
	if errors.As(err, &b) {
		return b.Reason
	}
	return ""
}

func TestCheckURLRejectsDangerousTargets(t *testing.T) {
	policy := DefaultPolicy()
	cases := map[string]string{
		"http://127.0.0.1/":                       ReasonAddress,
		"http://127.0.0.1:443/":                   ReasonAddress,
		"http://10.1.2.3/":                        ReasonAddress,
		"http://172.16.0.1/":                      ReasonAddress,
		"http://172.31.255.254/":                  ReasonAddress,
		"http://192.168.1.1/":                     ReasonAddress,
		"http://169.254.169.254/latest/meta-data": ReasonAddress,
		"http://100.64.0.1/":                      ReasonAddress,
		"http://0.0.0.0/":                         ReasonAddress,
		"http://255.255.255.255/":                 ReasonAddress,
		"http://224.0.0.1/":                       ReasonAddress,
		"http://198.18.0.1/":                      ReasonAddress,
		"http://[::1]/":                           ReasonAddress,
		"http://[::]/":                            ReasonAddress,
		"http://[::ffff:127.0.0.1]/":              ReasonAddress,
		"http://[::ffff:a9fe:a9fe]/":              ReasonAddress,
		"http://[::127.0.0.1]/":                   ReasonAddress,
		"http://[fd00::1]/":                       ReasonAddress,
		"http://[fc00::1]/":                       ReasonAddress,
		"http://[fe80::1]/":                       ReasonAddress,
		"http://[fe80::1%25eth0]/":                ReasonAddress,
		"http://[fec0::1]/":                       ReasonAddress,
		"http://[ff02::1]/":                       ReasonAddress,
		"http://[64:ff9b::a00:1]/":                ReasonAddress,
		"http://[2002:a00:1::1]/":                 ReasonAddress,
		"http://[2001::1]/":                       ReasonAddress,
		"http://[2001:db8::1]/":                   ReasonAddress,
		"http://2130706433/":                      ReasonNumericHost,
		"http://0x7f.1/":                          ReasonNumericHost,
		"http://0x7f000001/":                      ReasonNumericHost,
		"http://017700000001/":                    ReasonNumericHost,
		"http://0177.0.0.1/":                      ReasonNumericHost,
		"http://127.1/":                           ReasonNumericHost,
		"http://1.2.3.4.5/":                       ReasonNumericHost,
		"http://0/":                               ReasonNumericHost,
		"http://evil@127.0.0.1/":                  ReasonUserinfo,
		"http://user:pass@example.com/":           ReasonUserinfo,
		"http://example.com@127.0.0.1/":           ReasonUserinfo,
		"http://storage:5000/status":              ReasonPort,
		"http://storage/status":                   ReasonInternal,
		"http://rest/":                            ReasonInternal,
		"http://localhost/":                       ReasonInternal,
		"http://LOCALHOST./":                      ReasonInternal,
		"http://api.localhost/":                   ReasonInternal,
		"http://printer.local/":                   ReasonInternal,
		"http://metadata.google.internal/":        ReasonInternal,
		"http://router.home.arpa/":                ReasonInternal,
		"http://example.com:22/":                  ReasonPort,
		"http://example.com:8080/":                ReasonPort,
		"http://example.com:/":                    ReasonPort,
		"https://example.com:0/":                  ReasonPort,
		"ftp://example.com/":                      ReasonScheme,
		"file:///etc/passwd":                      ReasonScheme,
		"gopher://example.com/":                   ReasonScheme,
		"javascript:alert(1)":                     ReasonScheme,
		"http://bücher.de/":                       ReasonNonASCII,
		"http://127。0。0。1/":                       ReasonNonASCII,
		"http://exa_mple..com/":                   ReasonHost,
	}
	for raw, want := range cases {
		t.Run(raw, func(t *testing.T) {
			u, err := url.Parse(raw)
			if err != nil {
				return
			}
			got := policy.CheckURL(u)
			if !errors.Is(got, ErrBlocked) || reasonOf(got) != want {
				t.Fatalf("CheckURL(%q) = %v, want blocked %s", raw, got, want)
			}
		})
	}
}

func TestCheckURLAllowsPublicTargets(t *testing.T) {
	policy := DefaultPolicy()
	for _, raw := range []string{
		"https://example.com/",
		"http://example.com:80/a?b=c",
		"https://example.com:443/",
		"http://example.com:443/",
		"https://www.idx.co.id/id/berita",
		"https://xn--bcher-kva.de/",
		"http://93.184.215.14/",
		"https://[2606:4700:4700::1111]/",
		"https://sub_domain.example.org/",
		"https://123.example.com/",
	} {
		u, err := url.Parse(raw)
		if err != nil {
			t.Fatalf("parse %q: %v", raw, err)
		}
		if err := policy.CheckURL(u); err != nil {
			t.Fatalf("CheckURL(%q) = %v", raw, err)
		}
	}
}

func TestCheckAddrCoversSpecialRanges(t *testing.T) {
	policy := DefaultPolicy()
	denied := []string{
		"0.1.2.3", "10.255.255.255", "100.127.255.255", "127.255.255.255", "169.254.0.1", "172.20.0.5",
		"192.0.0.8", "192.0.2.1", "192.88.99.1", "192.168.65.1", "198.19.255.255", "198.51.100.7",
		"203.0.113.9", "239.255.255.250", "240.0.0.1", "::1", "::", "::ffff:10.0.0.1", "::ffff:172.17.0.1",
		"fd12:3456::1", "fe80::abcd", "ff05::2", "64:ff9b::808:808", "64:ff9b:1::1", "100::1", "2001:0:4136::1",
		"2002:c0a8:101::1", "3fff::1", "::a00:1",
	}
	for _, s := range denied {
		if err := policy.CheckAddr(netip.MustParseAddr(s)); !errors.Is(err, ErrBlocked) {
			t.Fatalf("CheckAddr(%s) = %v, want blocked", s, err)
		}
	}
	allowed := []string{"1.1.1.1", "8.8.8.8", "93.184.215.14", "172.15.255.255", "172.32.0.1", "100.128.0.1",
		"2606:4700:4700::1111", "2a00:1450:4001:80b::200e"}
	for _, s := range allowed {
		if err := policy.CheckAddr(netip.MustParseAddr(s)); err != nil {
			t.Fatalf("CheckAddr(%s) = %v, want allowed", s, err)
		}
	}
}

func TestAllowListIsOptIn(t *testing.T) {
	loopback := netip.MustParseAddr("127.0.0.1")
	if err := DefaultPolicy().CheckAddr(loopback); err == nil {
		t.Fatal("default policy must deny loopback")
	}
	test := Policy{Ports: []uint16{80}, Allow: []netip.Prefix{netip.MustParsePrefix("127.0.0.1/32")}}
	if err := test.CheckAddr(loopback); err != nil {
		t.Fatalf("explicit allow: %v", err)
	}
	if err := test.CheckAddr(netip.MustParseAddr("127.0.0.2")); err == nil {
		t.Fatal("allow list must stay narrow")
	}
	if err := test.CheckAddr(netip.MustParseAddr("::ffff:127.0.0.1")); err != nil {
		t.Fatalf("mapped form of an allowed address: %v", err)
	}
}
