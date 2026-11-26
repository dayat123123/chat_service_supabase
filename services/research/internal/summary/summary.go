package summary

import (
	"fmt"
	"math"
	"strings"
	"time"

	"olt-social/research/internal/analysis"
)

const (
	MaxLength = 2000
	footer    = "Sumber: laporan keuangan emiten (XBRL IDX), diolah otomatis. Bukan rekomendasi investasi."
)

type Meta struct {
	EntityCode  string
	EntityName  string
	Period      string
	PeriodStart time.Time
	PeriodEnd   time.Time
	Audit       string
	Currency    string
}

type writer struct {
	meta Meta
	m    *analysis.Metrics
}

func Render(meta Meta, m analysis.Metrics) string {
	w := writer{meta: meta, m: &m}
	parts := []string{w.headline()}
	for _, p := range []string{w.profit(), w.income(), w.balance(), w.ratios()} {
		if p != "" {
			parts = append(parts, p)
		}
	}
	parts = append(parts, footer)
	text := strings.Join(parts, "\n\n")
	if len([]rune(text)) > MaxLength {
		text = string([]rune(text)[:MaxLength])
	}
	return text
}

func (w writer) headline() string {
	var title string
	switch w.meta.Period {
	case "FY":
		title = fmt.Sprintf("Laporan Keuangan Tahunan %d", w.meta.PeriodEnd.Year())
	default:
		title = fmt.Sprintf("Laporan Keuangan %s %d", quarterTitle(w.meta.Period), w.meta.PeriodEnd.Year())
	}
	switch w.meta.Audit {
	case "audited":
		title += " (diaudit)"
	case "unaudited":
		title += " (belum diaudit)"
	}
	return "$" + w.meta.EntityCode + " — " + title
}

func (w writer) standalone() bool {
	return w.m.QuarterMonths == 3 && w.m.Months > 3
}

func (w writer) ytd() string {
	switch w.m.Months {
	case 3:
		return "kuartal I"
	case 12:
		return "setahun"
	}
	return fmt.Sprintf("%d bulan", w.m.Months)
}

func (w writer) quarter() string {
	return "kuartal " + strings.TrimPrefix(quarterTitle(w.meta.Period), "Kuartal ")
}

func (w writer) scope() string {
	if w.standalone() {
		return w.quarter()
	}
	return w.ytd()
}

func (w writer) flowScope(f *analysis.Flow) (*float64, *float64) {
	if w.standalone() && f.Quarter != nil {
		return f.Quarter, f.QuarterPrior
	}
	return f.YTD, f.YTDPrior
}

func (w writer) profit() string {
	net := w.m.Flow(analysis.NetProfit)
	if net == nil {
		return ""
	}
	cur := w.meta.Currency
	var b strings.Builder
	if w.standalone() && net.Quarter != nil {
		b.WriteString(profitPhrase(w.quarter(), *net.Quarter, net.QuarterPrior, cur))
		if net.EarlierAvg != nil && *net.Quarter > 0 && *net.EarlierAvg > 0 {
			rel := "di atas"
			if *net.Quarter < *net.EarlierAvg {
				rel = "di bawah"
			}
			fmt.Fprintf(&b, ", %s rata-rata kuartal sebelumnya tahun ini (%s)", rel, money(*net.EarlierAvg, cur))
		}
		b.WriteString(". ")
		fmt.Fprintf(&b, "%s %s %s%s", profitWord(*net.YTD), w.ytd(), money(math.Abs(*net.YTD), cur), paren(net.YTD, net.YTDPrior))
		if eps := w.m.Flow(analysis.EPS); eps != nil && eps.YTD != nil {
			fmt.Fprintf(&b, ", EPS %s %s", w.ytd(), perShare(*eps.YTD, cur))
		}
		b.WriteString(".")
		return b.String()
	}
	b.WriteString(profitPhrase(w.ytd(), *net.YTD, net.YTDPrior, cur))
	b.WriteString(".")
	if eps := w.m.Flow(analysis.EPS); eps != nil && eps.YTD != nil {
		fmt.Fprintf(&b, " EPS %s %s", w.ytd(), perShare(*eps.YTD, cur))
		if eps.YTDPrior != nil {
			fmt.Fprintf(&b, " (tahun lalu %s)", perShare(*eps.YTDPrior, cur))
		}
		b.WriteString(".")
	}
	return b.String()
}

func (w writer) income() string {
	cur := w.meta.Currency
	var sentences []string
	switch w.m.Template {
	case "bank":
		if f := w.m.Flow(analysis.NetInterestIncome); f != nil {
			v, p := w.flowScope(f)
			sentences = append(sentences, fmt.Sprintf("Pendapatan bunga bersih %s %s%s.", w.scope(), money(*v, cur), paren(v, p)))
		}
		if f := w.m.Flow(analysis.Provision); f != nil {
			v, p := w.flowScope(f)
			if *v >= 0 {
				sentences = append(sentences, fmt.Sprintf("Beban cadangan kerugian %s %s%s.", w.scope(), money(*v, cur), paren(v, p)))
			} else {
				sentences = append(sentences, fmt.Sprintf("Pemulihan cadangan kerugian %s %s.", w.scope(), money(-*v, cur)))
			}
		}
	case "general":
		if f := w.m.Flow(analysis.Revenue); f != nil {
			v, p := w.flowScope(f)
			sentences = append(sentences, fmt.Sprintf("Pendapatan %s %s%s.", w.scope(), money(*v, cur), paren(v, p)))
		}
		var margins []string
		if r := w.m.Ratio(analysis.GrossMargin); r != nil {
			margins = append(margins, "marjin kotor "+percent(*r.Value))
		}
		if r := w.m.Ratio(analysis.NetMargin); r != nil {
			margins = append(margins, "marjin bersih "+percent(*r.Value))
		}
		if len(margins) > 0 {
			sentences = append(sentences, capitalize(fmt.Sprintf("%s %s.", strings.Join(margins, ", "), w.ytd())))
		}
		if f := w.m.Flow(analysis.OperatingCashFlow); f != nil {
			s := fmt.Sprintf("Arus kas operasi %s %s", w.ytd(), money(*f.YTD, cur))
			if net := w.m.Flow(analysis.NetProfit); net != nil && *net.YTD > 0 && *f.YTD > 0 {
				s += fmt.Sprintf(" (%s laba bersih)", times(*f.YTD / *net.YTD))
			}
			sentences = append(sentences, s+".")
		}
	}
	return strings.Join(sentences, " ")
}

func (w writer) balance() string {
	cur := w.meta.Currency
	var sentences []string
	item := func(label, key string) string {
		b := w.m.Balance(key)
		if b == nil {
			return ""
		}
		return label + " " + money(*b.End, cur) + w.balanceChange(b)
	}
	switch w.m.Template {
	case "bank":
		if s := item("Kredit", analysis.Loans); s != "" {
			sentences = append(sentences, s+".")
		}
		if s := item("DPK", analysis.Deposits); s != "" {
			if r := w.m.Ratio(analysis.CASARatio); r != nil {
				s += ", CASA " + percent(*r.Value)
			}
			sentences = append(sentences, s+".")
		}
	default:
		var items []string
		for _, it := range []struct{ label, key string }{{"Total aset", analysis.Assets}, {"ekuitas", analysis.EquityParent}} {
			if s := item(it.label, it.key); s != "" {
				items = append(items, s)
			}
		}
		if len(items) > 0 {
			sentences = append(sentences, capitalize(strings.Join(items, ", "))+".")
		}
		var levers []string
		if r := w.m.Ratio(analysis.DER); r != nil {
			levers = append(levers, "DER "+times(*r.Value))
		}
		if r := w.m.Ratio(analysis.CurrentRatio); r != nil {
			levers = append(levers, "rasio lancar "+times(*r.Value))
		}
		if len(levers) > 0 {
			sentences = append(sentences, capitalize(strings.Join(levers, ", "))+".")
		}
	}
	return strings.Join(sentences, " ")
}

func (w writer) balanceChange(b *analysis.Balance) string {
	var parts []string
	switch {
	case w.m.BalanceBase == analysis.BaseYearAgo && b.YearAgo != nil:
		if p, ok := change(*b.End, *b.YearAgo); ok {
			parts = append(parts, signed(p)+" YoY")
		}
	case b.YearEnd != nil:
		if p, ok := change(*b.End, *b.YearEnd); ok {
			parts = append(parts, signed(p)+" sejak "+w.yearEndLabel())
		}
	}
	if b.Previous != nil {
		if p, ok := change(*b.End, *b.Previous); ok {
			parts = append(parts, signed(p)+" QoQ")
		}
	}
	if len(parts) == 0 {
		return ""
	}
	return " (" + strings.Join(parts, ", ") + ")"
}

func (w writer) yearEndLabel() string {
	if w.meta.PeriodStart.Month() == time.January && w.meta.PeriodStart.Day() == 1 {
		return fmt.Sprintf("akhir %d", w.meta.PeriodStart.Year()-1)
	}
	return "akhir tahun buku lalu"
}

func (w writer) ratios() string {
	var sentences []string
	if r := w.m.Ratio(analysis.ROE); r != nil {
		label := "ROE disetahunkan"
		if w.m.Months == 12 {
			label = "ROE"
		}
		s := label + " " + percent(*r.Value)
		if r.YearAgo != nil {
			s += " (tahun lalu " + percent(*r.YearAgo) + ")"
		}
		sentences = append(sentences, s+".")
	}
	if r := w.m.Ratio(analysis.CostToIncome); r != nil {
		sentences = append(sentences, "Rasio biaya terhadap pendapatan "+percent(*r.Value)+".")
	}
	return strings.Join(sentences, " ")
}

func profitPhrase(scope string, v float64, prior *float64, currency string) string {
	head := fmt.Sprintf("%s %s %s", profitWord(v), scope, money(math.Abs(v), currency))
	if prior == nil {
		return head
	}
	switch {
	case v >= 0 && *prior > 0:
		p, _ := change(v, *prior)
		return head + ", " + words(p) + " YoY"
	case v >= 0 && *prior < 0:
		return head + ", berbalik dari rugi " + money(-*prior, currency) + " tahun lalu"
	case v < 0 && *prior < 0:
		trend := "melebar"
		if -v < -*prior {
			trend = "menyempit"
		}
		return head + ", " + trend + " dari rugi " + money(-*prior, currency) + " tahun lalu"
	case v < 0 && *prior > 0:
		return head + ", berbalik dari laba " + money(*prior, currency) + " tahun lalu"
	}
	return head
}

func profitWord(v float64) string {
	if v < 0 {
		return "Rugi bersih"
	}
	return "Laba bersih"
}

func paren(v, prior *float64) string {
	if v == nil || prior == nil {
		return ""
	}
	if p, ok := change(*v, *prior); ok {
		return " (" + signed(p) + " YoY)"
	}
	return ""
}

func quarterTitle(period string) string {
	switch period {
	case "Q1":
		return "Kuartal I"
	case "Q2":
		return "Kuartal II"
	case "Q3":
		return "Kuartal III"
	}
	return "Kuartal IV"
}

func capitalize(s string) string {
	if s == "" {
		return s
	}
	r := []rune(s)
	return strings.ToUpper(string(r[0])) + string(r[1:])
}
