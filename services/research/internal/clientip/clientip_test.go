package clientip

import (
	"net/http/httptest"
	"net/netip"
	"testing"
)

func TestOf(t *testing.T) {
	r := New([]netip.Prefix{
		netip.MustParsePrefix("10.0.0.0/8"),
		netip.MustParsePrefix("172.16.0.0/12"),
		netip.MustParsePrefix("192.168.0.0/16"),
	})
	cases := []struct {
		name, remote, xff, want string
	}{
		{"langsung tanpa proxy", "203.0.113.5:4000", "", "203.0.113.5"},
		{"XFF dari klien internet diabaikan", "203.0.113.5:4000", "10.9.9.9", "203.0.113.5"},
		{"lewat Traefik dan Kong", "172.18.0.4:5000", "198.51.100.7, 172.18.0.3", "198.51.100.7"},
		{"klien palsu di kiri diabaikan", "172.18.0.4:5000", "1.2.3.4, 198.51.100.7, 172.18.0.3", "198.51.100.7"},
		{"semua hop privat: server LAN OLT", "172.18.0.4:5000", "192.168.10.20, 172.18.0.3", "192.168.10.20"},
		{"tanpa XFF dari jaringan internal", "172.18.0.4:5000", "", "172.18.0.4"},
		{"XFF rusak berhenti di hop rusak", "172.18.0.4:5000", "198.51.100.7, bukan-ip", "172.18.0.4"},
		{"IPv4 dalam IPv6", "[::ffff:172.18.0.4]:5000", "::ffff:198.51.100.7", "198.51.100.7"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest("POST", "/notify/messages", nil)
			req.RemoteAddr = tc.remote
			if tc.xff != "" {
				req.Header.Set("X-Forwarded-For", tc.xff)
			}
			if got := r.Of(req); got != tc.want {
				t.Fatalf("Of = %q, want %q", got, tc.want)
			}
		})
	}
}
