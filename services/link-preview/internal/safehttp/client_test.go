package safehttp

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"net/url"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

type fakeResolver struct {
	answers map[string][]netip.Addr
	calls   atomic.Int64
	flip    map[string][]netip.Addr
}

func (f *fakeResolver) LookupNetIP(_ context.Context, _, host string) ([]netip.Addr, error) {
	n := f.calls.Add(1)
	if alt, ok := f.flip[host]; ok && n%2 == 0 {
		return alt, nil
	}
	if addrs, ok := f.answers[host]; ok {
		return addrs, nil
	}
	return nil, &net.DNSError{Err: "no such host", Name: host, IsNotFound: true}
}

func addrs(list ...string) []netip.Addr {
	out := make([]netip.Addr, 0, len(list))
	for _, s := range list {
		out = append(out, netip.MustParseAddr(s))
	}
	return out
}

type harness struct {
	client   *Client
	resolver *fakeResolver
	port     string
	base     string
}

func newHarness(t *testing.T, handler http.Handler, timeout time.Duration) *harness {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	u, err := url.Parse(srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	port, _ := strconv.Atoi(u.Port())
	resolver := &fakeResolver{answers: map[string][]netip.Addr{
		"site.olt-test.com":     addrs("127.0.0.1"),
		"evil.olt-test.com":     addrs("10.0.0.1"),
		"meta.olt-test.com":     addrs("169.254.169.254"),
		"mixed.olt-test.com":    addrs("127.0.0.1", "192.168.1.1"),
		"v6local.olt-test.com":  addrs("::1"),
		"mapped.olt-test.com":   addrs("::ffff:10.0.0.1"),
		"loopback.olt-test.com": addrs("127.0.0.2"),
	}}
	policy := Policy{Ports: []uint16{uint16(port)}, Allow: []netip.Prefix{netip.MustParsePrefix("127.0.0.1/32")}}
	client := New(Options{Policy: policy, Resolver: resolver, Timeout: timeout, UserAgent: "OLTSocialLinkPreview/1.0 (+https://test.invalid)"})
	return &harness{client: client, resolver: resolver, port: u.Port(), base: "http://site.olt-test.com:" + u.Port()}
}

func (h *harness) url(host, path string) string {
	return "http://" + host + ":" + h.port + path
}

func pageHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/page", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprintf(w, "<title>ok</title><p>%s</p>", r.Header.Get("User-Agent"))
	})
	mux.HandleFunc("/to", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, r.URL.Query().Get("u"), http.StatusFound)
	})
	mux.HandleFunc("/chain/", func(w http.ResponseWriter, r *http.Request) {
		n, _ := strconv.Atoi(strings.TrimPrefix(r.URL.Path, "/chain/"))
		if n <= 0 {
			_, _ = w.Write([]byte("<title>end</title>"))
			return
		}
		http.Redirect(w, r, "/chain/"+strconv.Itoa(n-1), http.StatusMovedPermanently)
	})
	mux.HandleFunc("/missing", func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "nope", http.StatusNotFound)
	})
	return mux
}

func TestGetFetchesAllowedHost(t *testing.T) {
	h := newHarness(t, pageHandler(), 2*time.Second)
	resp, err := h.client.Get(context.Background(), h.base+"/page", "text/html", 1<<20, true)
	if err != nil {
		t.Fatal(err)
	}
	if resp.Status != 200 || !strings.Contains(string(resp.Body), "OLTSocialLinkPreview/1.0") {
		t.Fatalf("unexpected response %d %q", resp.Status, resp.Body)
	}
	if resp.URL.String() != h.base+"/page" || resp.Truncated {
		t.Fatalf("final url %s truncated %v", resp.URL, resp.Truncated)
	}
}

func TestGetBlocksPrivateTargets(t *testing.T) {
	h := newHarness(t, pageHandler(), 2*time.Second)
	cases := map[string]string{
		"dns resolves to private":       h.url("evil.olt-test.com", "/page"),
		"dns resolves to metadata":      h.url("meta.olt-test.com", "/page"),
		"one private answer of many":    h.url("mixed.olt-test.com", "/page"),
		"dns resolves to ipv6 loopback": h.url("v6local.olt-test.com", "/page"),
		"dns resolves to mapped ipv4":   h.url("mapped.olt-test.com", "/page"),
		"other loopback address":        h.url("loopback.olt-test.com", "/page"),
		"literal outside allow list":    h.url("127.0.0.2", "/page"),
		"literal ipv6 loopback":         "http://[::1]:" + h.port + "/page",
		"decimal ip":                    "http://2130706433:" + h.port + "/page",
		"hex ip":                        "http://0x7f.1:" + h.port + "/page",
		"userinfo trick":                "http://evil@127.0.0.1:" + h.port + "/page",
		"single label service":          "http://storage:" + h.port + "/status",
		"cloud metadata literal":        "http://169.254.169.254:" + h.port + "/latest/meta-data/",
	}
	for name, target := range cases {
		t.Run(name, func(t *testing.T) {
			_, err := h.client.Get(context.Background(), target, "text/html", 1<<20, true)
			if !errors.Is(err, ErrBlocked) {
				t.Fatalf("Get(%s) = %v, want blocked", target, err)
			}
		})
	}
}

func TestRedirectsAreCheckedOnEveryHop(t *testing.T) {
	h := newHarness(t, pageHandler(), 2*time.Second)
	targets := map[string]string{
		"private literal":     "http://10.0.0.1:" + h.port + "/",
		"metadata":            "http://169.254.169.254:" + h.port + "/latest/meta-data/",
		"metadata default":    "http://169.254.169.254/latest/meta-data/",
		"name to private":     h.url("evil.olt-test.com", "/page"),
		"localhost":           "http://localhost:" + h.port + "/page",
		"other port":          "http://site.olt-test.com:1/page",
		"internal service":    "http://storage:5000/status",
		"userinfo":            "http://x@site.olt-test.com:" + h.port + "/page",
		"file scheme":         "file:///etc/passwd",
		"mapped ipv6 literal": "http://[::ffff:127.0.0.2]:" + h.port + "/",
	}
	for name, target := range targets {
		t.Run(name, func(t *testing.T) {
			_, err := h.client.Get(context.Background(), h.base+"/to?u="+url.QueryEscape(target), "text/html", 1<<20, true)
			if !errors.Is(err, ErrBlocked) {
				t.Fatalf("redirect to %s = %v, want blocked", target, err)
			}
		})
	}
	resp, err := h.client.Get(context.Background(), h.base+"/to?u="+url.QueryEscape(h.base+"/page"), "text/html", 1<<20, true)
	if err != nil || resp.URL.Path != "/page" {
		t.Fatalf("redirect to allowed host: %v", err)
	}
}

func TestRedirectLimit(t *testing.T) {
	h := newHarness(t, pageHandler(), 2*time.Second)
	resp, err := h.client.Get(context.Background(), h.base+"/chain/3", "text/html", 1<<20, true)
	if err != nil || string(resp.Body) != "<title>end</title>" {
		t.Fatalf("three redirects should be followed: %v", err)
	}
	if _, err := h.client.Get(context.Background(), h.base+"/chain/4", "text/html", 1<<20, true); !errors.Is(err, ErrTooManyRedirects) {
		t.Fatalf("four redirects = %v, want ErrTooManyRedirects", err)
	}
}

func TestEachConnectionResolvesAndChecksAgain(t *testing.T) {
	h := newHarness(t, pageHandler(), 2*time.Second)
	h.resolver.flip = map[string][]netip.Addr{"site.olt-test.com": addrs("10.0.0.1")}
	h.resolver.calls.Store(0)
	if _, err := h.client.Get(context.Background(), h.base+"/page", "text/html", 1<<20, true); err != nil {
		t.Fatalf("first resolution is allowed: %v", err)
	}
	if _, err := h.client.Get(context.Background(), h.base+"/page", "text/html", 1<<20, true); !errors.Is(err, ErrBlocked) {
		t.Fatalf("rebound answer = %v, want blocked", err)
	}
}

func TestControlIsTheLastLine(t *testing.T) {
	c := New(Options{Policy: DefaultPolicy(), Timeout: time.Second})
	cases := []struct{ network, address string }{
		{"tcp4", "127.0.0.1:80"},
		{"tcp4", "10.0.0.1:443"},
		{"tcp4", "169.254.169.254:80"},
		{"tcp6", "[::1]:443"},
		{"tcp6", "[fd00::1]:443"},
		{"tcp4", "93.184.215.14:22"},
		{"udp4", "93.184.215.14:443"},
		{"tcp4", "not-an-address"},
	}
	for _, tc := range cases {
		if err := c.control(tc.network, tc.address, nil); !errors.Is(err, ErrBlocked) {
			t.Fatalf("control(%s, %s) = %v, want blocked", tc.network, tc.address, err)
		}
	}
	if err := c.control("tcp4", "93.184.215.14:443", nil); err != nil {
		t.Fatalf("public address: %v", err)
	}
}

func TestDefaultPolicyRefusesTestServer(t *testing.T) {
	srv := httptest.NewServer(pageHandler())
	defer srv.Close()
	u, _ := url.Parse(srv.URL)
	port, _ := strconv.Atoi(u.Port())
	policy := DefaultPolicy()
	policy.Ports = append(policy.Ports, uint16(port))
	c := New(Options{Policy: policy, Resolver: &fakeResolver{answers: map[string][]netip.Addr{"site.olt-test.com": addrs("127.0.0.1")}}, Timeout: time.Second})
	for _, target := range []string{srv.URL + "/page", "http://site.olt-test.com:" + u.Port() + "/page"} {
		_, err := c.Get(context.Background(), target, "text/html", 1<<20, true)
		if reasonOf(err) != ReasonAddress {
			t.Fatalf("Get(%s) = %v, want private_address", target, err)
		}
	}
}

func TestProxyEnvironmentIsIgnored(t *testing.T) {
	h := newHarness(t, pageHandler(), 2*time.Second)
	t.Setenv("HTTP_PROXY", "http://10.9.9.9:3128")
	t.Setenv("http_proxy", "http://10.9.9.9:3128")
	if _, err := h.client.Get(context.Background(), h.base+"/page", "text/html", 1<<20, true); err != nil {
		t.Fatalf("request must not use a proxy: %v", err)
	}
}

func TestBodyLimits(t *testing.T) {
	big := strings.Repeat("a", 2<<20)
	mux := http.NewServeMux()
	mux.HandleFunc("/big", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		_, _ = w.Write([]byte(big))
	})
	mux.HandleFunc("/chunked", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "image/png")
		for i := 0; i < 6; i++ {
			_, _ = w.Write(make([]byte, 1<<20))
			w.(http.Flusher).Flush()
		}
	})
	h := newHarness(t, mux, 5*time.Second)
	resp, err := h.client.Get(context.Background(), h.base+"/big", "text/html", 1<<20, true)
	if err != nil || !resp.Truncated || len(resp.Body) != 1<<20 {
		t.Fatalf("html should be cut at 1 MiB: err=%v truncated=%v len=%d", err, resp != nil && resp.Truncated, len(resp.Body))
	}
	if _, err := h.client.Get(context.Background(), h.base+"/big", "image/*", 1<<20, false); !errors.Is(err, ErrTooLarge) {
		t.Fatalf("announced length over the limit = %v", err)
	}
	if _, err := h.client.Get(context.Background(), h.base+"/chunked", "image/*", 5<<20, false); !errors.Is(err, ErrTooLarge) {
		t.Fatalf("streamed body over the limit = %v", err)
	}
}

func TestTimeouts(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("/slow-headers", func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-time.After(3 * time.Second):
		case <-r.Context().Done():
		}
	})
	mux.HandleFunc("/drip", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		for i := 0; i < 30; i++ {
			_, _ = w.Write([]byte("<!-- -->"))
			w.(http.Flusher).Flush()
			select {
			case <-time.After(100 * time.Millisecond):
			case <-r.Context().Done():
				return
			}
		}
	})
	h := newHarness(t, mux, 300*time.Millisecond)
	for _, path := range []string{"/slow-headers", "/drip"} {
		start := time.Now()
		_, err := h.client.Get(context.Background(), h.base+path, "text/html", 1<<20, true)
		var netErr net.Error
		if err == nil || !(errors.Is(err, context.DeadlineExceeded) || errors.As(err, &netErr) && netErr.Timeout()) {
			t.Fatalf("%s = %v, want timeout", path, err)
		}
		if took := time.Since(start); took > 2*time.Second {
			t.Fatalf("%s took %s", path, took)
		}
	}
}

func TestStatusErrors(t *testing.T) {
	h := newHarness(t, pageHandler(), 2*time.Second)
	resp, err := h.client.Get(context.Background(), h.base+"/missing", "text/html", 1<<20, true)
	var status *StatusError
	if !errors.As(err, &status) || status.Code != 404 || resp.Status != 404 {
		t.Fatalf("404 = %v", err)
	}
	_, err = h.client.Get(context.Background(), h.url("unknown.olt-test.com", "/"), "text/html", 1<<20, true)
	var dnsErr *net.DNSError
	if !errors.As(err, &dnsErr) || !dnsErr.IsNotFound {
		t.Fatalf("unknown host = %v", err)
	}
}
