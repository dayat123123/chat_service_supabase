package summary

import (
	"fmt"
	"math"
	"strings"

	"olt-social/research/internal/analysis"
)

const (
	DocumentVersion = 1
	maxPoints       = 5
	maxMetrics      = 4
	badge           = "Ringkasan otomatis"
	disclaimer      = "Diolah otomatis dari laporan keuangan emiten (XBRL IDX) dengan rumus tetap, tanpa AI. Bukan rekomendasi investasi."
)

type Metric struct {
	Label  string `json:"label"`
	Value  string `json:"value"`
	Change string `json:"change,omitempty"`
	Trend  string `json:"trend,omitempty"`
}

type Block struct {
	Type    string   `json:"type"`
	Text    string   `json:"text,omitempty"`
	Title   string   `json:"title,omitempty"`
	Style   string   `json:"style,omitempty"`
	Items   []string `json:"items,omitempty"`
	Metrics []Metric `json:"metrics,omitempty"`
}

type Document struct {
	Version    int     `json:"version"`
	Badge      string  `json:"badge"`
	Title      string  `json:"title"`
	Subtitle   string  `json:"subtitle,omitempty"`
	Headline   string  `json:"headline"`
	Blocks     []Block `json:"blocks"`
	Disclaimer string  `json:"disclaimer"`
}

func Build(meta Meta, m analysis.Metrics) Document {
	w := writer{meta: meta, m: &m}
	doc := Document{
		Version:    DocumentVersion,
		Badge:      badge,
		Title:      w.reportTitle(),
		Subtitle:   w.subtitle(),
		Headline:   w.docHeadline(),
		Disclaimer: disclaimer,
	}
	if lead := w.lead(); lead != "" {
		doc.Blocks = append(doc.Blocks, Block{Type: "paragraph", Text: lead})
	}
	if metrics := w.metrics(); len(metrics) > 0 {
		doc.Blocks = append(doc.Blocks, Block{Type: "metrics", Metrics: metrics})
	}
	if points := w.points(); len(points) > 0 {
		doc.Blocks = append(doc.Blocks, Block{Type: "list", Style: "numbered", Items: points})
	}
	if takeaway := w.takeaway(); takeaway != "" {
		doc.Blocks = append(doc.Blocks, Block{Type: "callout", Title: "Poin utama", Text: takeaway})
	}
	return doc
}

func (w writer) reportTitle() string {
	if w.meta.Period == "FY" {
		return fmt.Sprintf("Laporan Keuangan Tahunan %d", w.meta.PeriodEnd.Year())
	}
	return fmt.Sprintf("Laporan Keuangan %s %d", quarterTitle(w.meta.Period), w.meta.PeriodEnd.Year())
}

func (w writer) subtitle() string {
	parts := []string{}
	if w.meta.EntityName != "" {
		parts = append(parts, w.meta.EntityName)
	}
	switch w.meta.Audit {
	case "audited":
		parts = append(parts, "Diaudit")
	case "unaudited":
		parts = append(parts, "Belum diaudit")
	}
	return strings.Join(parts, " · ")
}

func (w writer) profitScope() (*float64, *float64, string) {
	net := w.m.Flow(analysis.NetProfit)
	if net == nil {
		return nil, nil, ""
	}
	if w.standalone() && net.Quarter != nil {
		return net.Quarter, net.QuarterPrior, w.quarter()
	}
	return net.YTD, net.YTDPrior, w.ytd()
}

func (w writer) docHeadline() string {
	v, prior, scope := w.profitScope()
	if v == nil {
		return w.headline()
	}
	word := profitWord(*v)
	switch {
	case prior == nil:
		return fmt.Sprintf("%s %s %s", word, scope, money(math.Abs(*v), w.meta.Currency))
	case *v >= 0 && *prior > 0:
		p, _ := change(*v, *prior)
		return fmt.Sprintf("%s %s %s YoY", word, scope, words(p))
	case *v >= 0 && *prior < 0:
		return fmt.Sprintf("%s %s berbalik dari rugi", word, scope)
	case *v < 0 && *prior > 0:
		return fmt.Sprintf("%s %s berbalik dari laba", word, scope)
	case *v < 0 && *prior < 0 && -*v < -*prior:
		return fmt.Sprintf("%s %s menyempit", word, scope)
	case *v < 0 && *prior < 0:
		return fmt.Sprintf("%s %s melebar", word, scope)
	}
	return fmt.Sprintf("%s %s %s", word, scope, money(math.Abs(*v), w.meta.Currency))
}

func (w writer) lead() string {
	v, prior, scope := w.profitScope()
	if v == nil {
		return ""
	}
	who := w.meta.EntityCode
	if w.meta.EntityName != "" {
		who += " (" + w.meta.EntityName + ")"
	}
	s := fmt.Sprintf("%s membukukan %s.", who, lowerFirst(profitPhrase(scope, *v, prior, w.meta.Currency)))
	if w.standalone() {
		net := w.m.Flow(analysis.NetProfit)
		s += fmt.Sprintf(" %s %s mencapai %s%s.", profitWord(*net.YTD), w.ytd(),
			money(math.Abs(*net.YTD), w.meta.Currency), paren(net.YTD, net.YTDPrior))
	}
	return s
}

func (w writer) metrics() []Metric {
	cur := w.meta.Currency
	var out []Metric
	addFlow := func(label, key string) {
		f := w.m.Flow(key)
		if f == nil {
			return
		}
		v, p := w.flowScope(f)
		out = append(out, Metric{Label: label + " " + w.scope(), Value: money(*v, cur), Change: changeText(v, p, "YoY"),
			Trend: trend(v, p)})
	}
	addBalance := func(label, key string) {
		b := w.m.Balance(key)
		if b == nil {
			return
		}
		base, suffix := b.YearAgo, "YoY"
		if w.m.BalanceBase != analysis.BaseYearAgo || base == nil {
			base, suffix = b.YearEnd, "YTD"
		}
		out = append(out, Metric{Label: label, Value: money(*b.End, cur), Change: changeText(b.End, base, suffix),
			Trend: trend(b.End, base)})
	}
	addFlow("Laba bersih", analysis.NetProfit)
	switch w.m.Template {
	case "bank":
		addFlow("Pendapatan bunga bersih", analysis.NetInterestIncome)
		addBalance("Kredit", analysis.Loans)
	case "general":
		addFlow("Pendapatan", analysis.Revenue)
		addBalance("Total aset", analysis.Assets)
	default:
		addBalance("Total aset", analysis.Assets)
	}
	if r := w.m.Ratio(analysis.ROE); r != nil {
		label := "ROE disetahunkan"
		if w.m.Months == 12 {
			label = "ROE"
		}
		metric := Metric{Label: label, Value: percent(*r.Value)}
		if r.YearAgo != nil {
			metric.Change = "tahun lalu " + percent(*r.YearAgo)
			metric.Trend = trend(r.Value, r.YearAgo)
		}
		out = append(out, metric)
	}
	if len(out) > maxMetrics {
		out = out[:maxMetrics]
	}
	return out
}

func (w writer) points() []string {
	var out []string
	for _, part := range []string{w.income(), w.balance(), w.ratios()} {
		for _, sentence := range splitSentences(part) {
			out = append(out, sentence)
		}
	}
	if eps := w.m.Flow(analysis.EPS); eps != nil && eps.YTD != nil {
		s := fmt.Sprintf("EPS %s %s", w.ytd(), perShare(*eps.YTD, w.meta.Currency))
		if eps.YTDPrior != nil {
			s += fmt.Sprintf(" (tahun lalu %s)", perShare(*eps.YTDPrior, w.meta.Currency))
		}
		out = append(out, s+".")
	}
	if len(out) > maxPoints {
		out = out[:maxPoints]
	}
	return out
}

func (w writer) takeaway() string {
	var notes []string
	v, prior, scope := w.profitScope()
	if v != nil && prior != nil && (*v >= 0) != (*prior >= 0) && *prior != 0 {
		if *v >= 0 {
			notes = append(notes, fmt.Sprintf("Kinerja %s berbalik dari rugi menjadi laba.", scope))
		} else {
			notes = append(notes, fmt.Sprintf("Kinerja %s berbalik dari laba menjadi rugi.", scope))
		}
	}
	if net := w.m.Flow(analysis.NetProfit); w.standalone() && net != nil && net.Quarter != nil && net.EarlierAvg != nil &&
		*net.Quarter > 0 && *net.EarlierAvg > 0 {
		rel := "di atas"
		if *net.Quarter < *net.EarlierAvg {
			rel = "di bawah"
		}
		notes = append(notes, fmt.Sprintf("Laba %s %s rata-rata kuartal sebelumnya tahun ini.", w.quarter(), rel))
	}
	switch w.m.Template {
	case "bank":
		if f := w.m.Flow(analysis.Provision); f != nil {
			cur, pri := w.flowScope(f)
			if p, ok := changeOf(cur, pri); ok && math.Abs(p) >= 20 {
				effect := "menopang laba"
				if p > 0 {
					effect = "menekan laba"
				}
				notes = append(notes, fmt.Sprintf("Beban cadangan kerugian %s YoY, %s.", words(p), effect))
			}
		}
		loans, nii := w.m.Balance(analysis.Loans), w.m.Flow(analysis.NetInterestIncome)
		if loans != nil && nii != nil && w.m.BalanceBase == analysis.BaseYearAgo {
			cur, pri := w.flowScope(nii)
			lg, okL := changeOf(loans.End, loans.YearAgo)
			ng, okN := changeOf(cur, pri)
			if okL && okN && lg-ng >= 5 {
				notes = append(notes, fmt.Sprintf("Kredit tumbuh %s YoY, lebih cepat dari pendapatan bunga bersih (%s).",
					number(lg, 1)+"%", signed(ng)))
			}
		}
	case "general":
		rev, gp := w.m.Flow(analysis.Revenue), w.m.Flow(analysis.GrossProfit)
		if rev != nil && v != nil {
			rv, rp := w.flowScope(rev)
			pg, okP := changeOf(v, prior)
			rg, okR := changeOf(rv, rp)
			if okP && okR && math.Abs(pg) >= 1 && math.Abs(rg) >= 1 && (pg > 0) != (rg > 0) {
				notes = append(notes, fmt.Sprintf("%s %s %s meski pendapatan %s.", profitWord(*v), scope, words(pg), words(rg)))
			}
		}
		if rev != nil && gp != nil && rev.YTD != nil && rev.YTDPrior != nil && gp.YTD != nil && gp.YTDPrior != nil &&
			*rev.YTD > 0 && *rev.YTDPrior > 0 {
			now, before := *gp.YTD / *rev.YTD, *gp.YTDPrior / *rev.YTDPrior
			if math.Abs(now-before) >= 0.01 {
				dir := "melebar"
				if now < before {
					dir = "menyempit"
				}
				notes = append(notes, fmt.Sprintf("Marjin kotor %s dari %s menjadi %s.", dir, percent(before), percent(now)))
			}
		}
	}
	if len(notes) == 0 && v != nil {
		return fmt.Sprintf("Kinerja %s relatif sejalan dengan periode yang sama tahun lalu.", scope)
	}
	if len(notes) > 2 {
		notes = notes[:2]
	}
	return strings.Join(notes, " ")
}

func changeOf(cur, prior *float64) (float64, bool) {
	if cur == nil || prior == nil {
		return 0, false
	}
	return change(*cur, *prior)
}

func changeText(cur, prior *float64, suffix string) string {
	if p, ok := changeOf(cur, prior); ok {
		return signed(p) + " " + suffix
	}
	return ""
}

func trend(cur, prior *float64) string {
	p, ok := changeOf(cur, prior)
	switch {
	case !ok:
		return ""
	case math.Abs(p) < 0.05:
		return "flat"
	case p > 0:
		return "up"
	}
	return "down"
}

func splitSentences(text string) []string {
	var out []string
	for _, part := range strings.SplitAfter(text, ". ") {
		if part = strings.TrimSpace(part); part != "" {
			out = append(out, part)
		}
	}
	return out
}

func lowerFirst(s string) string {
	if s == "" {
		return s
	}
	r := []rune(s)
	return strings.ToLower(string(r[0])) + string(r[1:])
}
