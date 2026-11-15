package metrics

import (
	"fmt"
	"net/http"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
)

var Names = []string{
	"received", "recv_overflow", "heartbeats", "other", "decode_errors", "encrypted_no_key", "decrypt_errors",
	"decompress_errors", "filtered_out", "orders", "trades", "forwarded_order", "forwarded_fill", "buffer_overflow",
	"sent_batches", "send_errors", "send_rejected", "accepted", "duplicate", "ignored", "dropped", "invalid",
	"reconnects", "config_errors",
}

type Counters struct {
	mu     sync.RWMutex
	values map[string]*atomic.Int64
}

func New() *Counters {
	c := &Counters{values: map[string]*atomic.Int64{}}
	for _, n := range Names {
		c.values[n] = &atomic.Int64{}
	}
	return c
}

func (c *Counters) Add(name string, delta int64) {
	c.mu.RLock()
	v, ok := c.values[name]
	c.mu.RUnlock()
	if !ok {
		c.mu.Lock()
		if v, ok = c.values[name]; !ok {
			v = &atomic.Int64{}
			c.values[name] = v
		}
		c.mu.Unlock()
	}
	v.Add(delta)
}

func (c *Counters) Inc(name string) {
	c.Add(name, 1)
}

func (c *Counters) Get(name string) int64 {
	c.mu.RLock()
	defer c.mu.RUnlock()
	if v, ok := c.values[name]; ok {
		return v.Load()
	}
	return 0
}

func (c *Counters) Snapshot() map[string]int64 {
	c.mu.RLock()
	defer c.mu.RUnlock()
	out := make(map[string]int64, len(c.values))
	for k, v := range c.values {
		out[k] = v.Load()
	}
	return out
}

func validName(s string) bool {
	for i := 0; i < len(s); i++ {
		ch := s[i]
		if !(ch >= 'a' && ch <= 'z' || ch >= '0' && ch <= '9' || ch == '_') {
			return false
		}
	}
	return s != ""
}

func Handler(snapshot func() map[string]int64, gauges func() map[string]float64) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		var b strings.Builder
		values := snapshot()
		keys := make([]string, 0, len(values))
		for k := range values {
			if validName(k) {
				keys = append(keys, k)
			}
		}
		sort.Strings(keys)
		for _, k := range keys {
			fmt.Fprintf(&b, "# TYPE trade_relay_%s_total counter\ntrade_relay_%s_total %d\n", k, k, values[k])
		}
		g := gauges()
		gk := make([]string, 0, len(g))
		for k := range g {
			if validName(k) {
				gk = append(gk, k)
			}
		}
		sort.Strings(gk)
		for _, k := range gk {
			fmt.Fprintf(&b, "# TYPE trade_relay_%s gauge\ntrade_relay_%s %g\n", k, k, g[k])
		}
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		_, _ = w.Write([]byte(b.String()))
	})
}
