package safehttp

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"strconv"
	"syscall"
	"time"
)

const (
	MaxRedirects   = 3
	maxHeaderBytes = 64 << 10
	maxURLLength   = 2048
)

var (
	ErrTooManyRedirects = errors.New("too many redirects")
	ErrTooLarge         = errors.New("response too large")
	ErrStatus           = errors.New("unexpected status")
)

type StatusError struct {
	Code int
}

func (e *StatusError) Error() string {
	return "status " + strconv.Itoa(e.Code)
}

func (e *StatusError) Is(target error) bool {
	return target == ErrStatus
}

type Resolver interface {
	LookupNetIP(ctx context.Context, network, host string) ([]netip.Addr, error)
}

type Options struct {
	Policy    Policy
	Resolver  Resolver
	Timeout   time.Duration
	UserAgent string
	RootCAs   *x509.CertPool
}

type Client struct {
	policy    Policy
	resolver  Resolver
	timeout   time.Duration
	userAgent string
	dialer    *net.Dialer
	http      *http.Client
}

type Response struct {
	URL         *url.URL
	Status      int
	ContentType string
	Body        []byte
	Truncated   bool
}

func New(opts Options) *Client {
	c := &Client{
		policy:    opts.Policy,
		resolver:  opts.Resolver,
		timeout:   opts.Timeout,
		userAgent: opts.UserAgent,
	}
	if c.resolver == nil {
		c.resolver = net.DefaultResolver
	}
	c.dialer = &net.Dialer{Timeout: opts.Timeout, Control: c.control}
	transport := &http.Transport{
		Proxy:                  nil,
		DialContext:            c.dial,
		TLSClientConfig:        &tls.Config{MinVersion: tls.VersionTLS12, RootCAs: opts.RootCAs},
		TLSHandshakeTimeout:    opts.Timeout,
		ResponseHeaderTimeout:  opts.Timeout,
		MaxResponseHeaderBytes: maxHeaderBytes,
		DisableKeepAlives:      true,
		ForceAttemptHTTP2:      false,
	}
	c.http = &http.Client{
		Transport: transport,
		Timeout:   opts.Timeout,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) > MaxRedirects {
				return ErrTooManyRedirects
			}
			if len(req.URL.String()) > maxURLLength {
				return blocked(ReasonHost)
			}
			return c.policy.CheckURL(req.URL)
		},
	}
	return c
}

func (c *Client) Policy() Policy {
	return c.policy
}

func (c *Client) Get(ctx context.Context, rawURL, accept string, limit int64, allowTruncated bool) (*Response, error) {
	u, err := url.Parse(rawURL)
	if err != nil || len(rawURL) > maxURLLength {
		return nil, blocked(ReasonHost)
	}
	if err := c.policy.CheckURL(u); err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(ctx, c.timeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return nil, blocked(ReasonHost)
	}
	req.Header.Set("User-Agent", c.userAgent)
	req.Header.Set("Accept", accept)
	req.Header.Set("Accept-Language", "id,en;q=0.8")
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, unwrap(err)
	}
	defer resp.Body.Close()
	out := &Response{URL: resp.Request.URL, Status: resp.StatusCode, ContentType: resp.Header.Get("Content-Type")}
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4<<10))
		return out, &StatusError{Code: resp.StatusCode}
	}
	if resp.ContentLength > limit && !allowTruncated {
		return out, fmt.Errorf("%w: %d bytes announced", ErrTooLarge, resp.ContentLength)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, limit+1))
	if err != nil {
		return out, unwrap(err)
	}
	if int64(len(body)) > limit {
		if !allowTruncated {
			return out, fmt.Errorf("%w: more than %d bytes", ErrTooLarge, limit)
		}
		body = body[:limit]
		out.Truncated = true
	}
	out.Body = body
	return out, nil
}

func (c *Client) dial(ctx context.Context, network, address string) (net.Conn, error) {
	host, portText, err := net.SplitHostPort(address)
	if err != nil {
		return nil, blocked(ReasonHost)
	}
	port, err := strconv.ParseUint(portText, 10, 16)
	if err != nil {
		return nil, blocked(ReasonPort)
	}
	if err := c.policy.CheckPort(uint16(port)); err != nil {
		return nil, err
	}
	var addrs []netip.Addr
	if addr, err := netip.ParseAddr(host); err == nil {
		addrs = []netip.Addr{addr}
	} else {
		if err := c.policy.checkHost(host); err != nil {
			return nil, err
		}
		addrs, err = c.resolver.LookupNetIP(ctx, "ip", host)
		if err != nil {
			return nil, err
		}
	}
	if len(addrs) == 0 {
		return nil, &net.DNSError{Err: "no addresses", Name: host, IsNotFound: true}
	}
	for _, addr := range addrs {
		if err := c.policy.CheckAddr(addr); err != nil {
			return nil, err
		}
	}
	var last error
	for _, addr := range addrs {
		conn, err := c.dialer.DialContext(ctx, network, netip.AddrPortFrom(addr.Unmap(), uint16(port)).String())
		if err == nil {
			return conn, nil
		}
		last = err
		if ctx.Err() != nil || errors.Is(err, ErrBlocked) {
			break
		}
	}
	return nil, last
}

func (c *Client) control(network, address string, _ syscall.RawConn) error {
	if network != "tcp4" && network != "tcp6" {
		return blocked(ReasonAddress)
	}
	addrPort, err := netip.ParseAddrPort(address)
	if err != nil {
		return blocked(ReasonAddress)
	}
	if err := c.policy.CheckPort(addrPort.Port()); err != nil {
		return err
	}
	return c.policy.CheckAddr(addrPort.Addr())
}

func unwrap(err error) error {
	var blockedErr *BlockedError
	if errors.As(err, &blockedErr) {
		return blockedErr
	}
	if errors.Is(err, ErrTooManyRedirects) {
		return ErrTooManyRedirects
	}
	var urlErr *url.Error
	if errors.As(err, &urlErr) {
		return urlErr.Err
	}
	return err
}
