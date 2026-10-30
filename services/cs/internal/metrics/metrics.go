package metrics

import (
	"fmt"
	"math"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
)

type Registry struct {
	mu      sync.Mutex
	metrics []metric
}

type metric interface {
	write(b *strings.Builder)
}

func NewRegistry() *Registry { return &Registry{} }

func (r *Registry) add(m metric) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.metrics = append(r.metrics, m)
}

func (r *Registry) Handler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		var b strings.Builder
		r.mu.Lock()
		for _, m := range r.metrics {
			m.write(&b)
		}
		r.mu.Unlock()
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		_, _ = w.Write([]byte(b.String()))
	})
}

type CounterVec struct {
	name, help string
	labels     []string

	mu     sync.Mutex
	values map[string]float64
}

func (r *Registry) Counter(name, help string, labels ...string) *CounterVec {
	c := &CounterVec{name: name, help: help, labels: labels, values: map[string]float64{}}
	r.add(c)
	return c
}

func (c *CounterVec) Inc(labelValues ...string) { c.Add(1, labelValues...) }

func (c *CounterVec) Add(v float64, labelValues ...string) {
	key := labelKey(c.labels, labelValues)
	c.mu.Lock()
	c.values[key] += v
	c.mu.Unlock()
}

func (c *CounterVec) write(b *strings.Builder) {
	header(b, c.name, c.help, "counter")
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, key := range sortedKeys(c.values) {
		fmt.Fprintf(b, "%s%s %s\n", c.name, key, num(c.values[key]))
	}
}

type HistogramVec struct {
	name, help string
	labels     []string
	buckets    []float64

	mu     sync.Mutex
	series map[string]*histogramSeries
}

type histogramSeries struct {
	counts []uint64
	sum    float64
	count  uint64
}

func (r *Registry) Histogram(name, help string, buckets []float64, labels ...string) *HistogramVec {
	h := &HistogramVec{name: name, help: help, labels: labels, buckets: buckets, series: map[string]*histogramSeries{}}
	r.add(h)
	return h
}

func (h *HistogramVec) Observe(v float64, labelValues ...string) {
	key := labelKey(h.labels, labelValues)
	h.mu.Lock()
	defer h.mu.Unlock()
	s, ok := h.series[key]
	if !ok {
		s = &histogramSeries{counts: make([]uint64, len(h.buckets))}
		h.series[key] = s
	}
	for i, le := range h.buckets {
		if v <= le {
			s.counts[i]++
		}
	}
	s.sum += v
	s.count++
}

func (h *HistogramVec) write(b *strings.Builder) {
	header(b, h.name, h.help, "histogram")
	h.mu.Lock()
	defer h.mu.Unlock()
	keys := make([]string, 0, len(h.series))
	for k := range h.series {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, key := range keys {
		s := h.series[key]
		for i, le := range h.buckets {
			fmt.Fprintf(b, "%s_bucket%s %d\n", h.name, withLabel(key, "le", num(le)), s.counts[i])
		}
		fmt.Fprintf(b, "%s_bucket%s %d\n", h.name, withLabel(key, "le", "+Inf"), s.count)
		fmt.Fprintf(b, "%s_sum%s %s\n", h.name, key, num(s.sum))
		fmt.Fprintf(b, "%s_count%s %d\n", h.name, key, s.count)
	}
}

type gaugeFunc struct {
	name, help string
	fn         func() float64
}

func (r *Registry) GaugeFunc(name, help string, fn func() float64) {
	r.add(&gaugeFunc{name: name, help: help, fn: fn})
}

func (g *gaugeFunc) write(b *strings.Builder) {
	header(b, g.name, g.help, "gauge")
	fmt.Fprintf(b, "%s %s\n", g.name, num(g.fn()))
}

func header(b *strings.Builder, name, help, typ string) {
	fmt.Fprintf(b, "# HELP %s %s\n# TYPE %s %s\n", name, help, name, typ)
}

func labelKey(names, values []string) string {
	if len(names) == 0 {
		return ""
	}
	parts := make([]string, len(names))
	for i, n := range names {
		v := ""
		if i < len(values) {
			v = values[i]
		}
		parts[i] = n + `="` + escape(v) + `"`
	}
	return "{" + strings.Join(parts, ",") + "}"
}

func withLabel(key, name, value string) string {
	label := name + `="` + value + `"`
	if key == "" {
		return "{" + label + "}"
	}
	return key[:len(key)-1] + "," + label + "}"
}

func escape(v string) string {
	return strings.NewReplacer(`\`, `\\`, `"`, `\"`, "\n", `\n`).Replace(v)
}

func num(v float64) string {
	if math.IsInf(v, 1) {
		return "+Inf"
	}
	return strconv.FormatFloat(v, 'g', -1, 64)
}

func sortedKeys(m map[string]float64) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
