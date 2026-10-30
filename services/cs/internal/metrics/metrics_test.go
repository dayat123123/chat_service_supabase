package metrics

import (
	"io"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestExposition(t *testing.T) {
	r := NewRegistry()
	c := r.Counter("demo_requests_total", "Jumlah request", "path", "status")
	c.Inc("/exchange", "200")
	c.Inc("/exchange", "200")
	c.Inc("/exchange", "429")
	h := r.Histogram("demo_duration_seconds", "Durasi", []float64{0.1, 1}, "path")
	h.Observe(0.05, "/exchange")
	h.Observe(0.5, "/exchange")
	r.GaugeFunc("demo_breaker_open", "Breaker terbuka", func() float64 { return 1 })

	rec := httptest.NewRecorder()
	r.Handler().ServeHTTP(rec, httptest.NewRequest("GET", "/metrics", nil))
	body, _ := io.ReadAll(rec.Body)
	out := string(body)

	for _, want := range []string{
		"# TYPE demo_requests_total counter",
		`demo_requests_total{path="/exchange",status="200"} 2`,
		`demo_requests_total{path="/exchange",status="429"} 1`,
		`demo_duration_seconds_bucket{path="/exchange",le="0.1"} 1`,
		`demo_duration_seconds_bucket{path="/exchange",le="1"} 2`,
		`demo_duration_seconds_bucket{path="/exchange",le="+Inf"} 2`,
		`demo_duration_seconds_count{path="/exchange"} 2`,
		"demo_breaker_open 1",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("output tidak memuat %q:\n%s", want, out)
		}
	}
}

func TestLabelValuesAreEscaped(t *testing.T) {
	r := NewRegistry()
	r.Counter("x_total", "x", "v").Inc("a\"b\\c\nd")
	rec := httptest.NewRecorder()
	r.Handler().ServeHTTP(rec, httptest.NewRequest("GET", "/metrics", nil))
	if !strings.Contains(rec.Body.String(), `x_total{v="a\"b\\c\nd"} 1`) {
		t.Fatalf("label tidak di-escape: %s", rec.Body.String())
	}
}
