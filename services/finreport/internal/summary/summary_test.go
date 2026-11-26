package summary

import (
	"strings"
	"testing"
	"unicode/utf8"

	"olt-social/finreport/internal/analysis"
	"olt-social/finreport/internal/xbrl"
	"olt-social/finreport/internal/xbrltest"
)

func report(t *testing.T, s xbrltest.Spec, id string) (*xbrl.Report, *analysis.Snapshot) {
	t.Helper()
	rc, err := xbrl.Open(xbrltest.Archive(s), xbrl.DefaultLimits())
	if err != nil {
		t.Fatal(err)
	}
	defer rc.Close()
	r, err := xbrl.Parse(rc)
	if err != nil {
		t.Fatal(err)
	}
	return r, &analysis.Snapshot{ID: id, Period: r.Period, PeriodStart: r.PeriodStart, PeriodEnd: r.PeriodEnd, Facts: r.Facts}
}

func meta(r *xbrl.Report) Meta {
	return Meta{EntityCode: r.EntityCode, Period: r.Period, PeriodStart: r.PeriodStart, PeriodEnd: r.PeriodEnd,
		Audit: r.Audit, Currency: r.Currency}
}

func TestBankSummaryWithComparatives(t *testing.T) {
	r, cur := report(t, xbrltest.BankQ3(), "q3")
	_, prev := report(t, xbrltest.BankQ2(), "q2")
	_, py := report(t, xbrltest.BankQ3PriorYear(), "py")
	got := Render(meta(r), analysis.Analyze(analysis.Input{Current: *cur, Previous: prev, PriorYear: py}).Metrics)
	want := strings.Join([]string{
		"$ABCD — Laporan Keuangan Kuartal III 2026 (belum diaudit)",
		"Laba bersih kuartal III Rp13,00 T, naik 18,2% YoY, di atas rata-rata kuartal sebelumnya tahun ini (Rp11,50 T). " +
			"Laba bersih 9 bulan Rp36,00 T (+12,5% YoY), EPS 9 bulan Rp300.",
		"Pendapatan bunga bersih kuartal III Rp21,00 T (+7,7% YoY). Beban cadangan kerugian kuartal III Rp800,00 M (-42,9% YoY).",
		"Kredit Rp900,00 T (+12,5% YoY, +2,3% QoQ). DPK Rp1.000,00 T (+5,3% YoY, +1,0% QoQ), CASA 90,0%.",
		"ROE disetahunkan 19,6% (tahun lalu 19,0%). Rasio biaya terhadap pendapatan 33,3%.",
		footer,
	}, "\n\n")
	if got != want {
		t.Fatalf("summary mismatch\n got: %q\nwant: %q", got, want)
	}
}

func TestBankSummaryWithoutComparatives(t *testing.T) {
	r, cur := report(t, xbrltest.BankQ3(), "q3")
	got := Render(meta(r), analysis.Analyze(analysis.Input{Current: *cur}).Metrics)
	want := strings.Join([]string{
		"$ABCD — Laporan Keuangan Kuartal III 2026 (belum diaudit)",
		"Laba bersih 9 bulan Rp36,00 T, naik 12,5% YoY. EPS 9 bulan Rp300 (tahun lalu Rp270).",
		"Pendapatan bunga bersih 9 bulan Rp60,00 T (+7,1% YoY). Beban cadangan kerugian 9 bulan Rp3,00 T (-25,0% YoY).",
		"Kredit Rp900,00 T (+5,9% sejak akhir 2025). DPK Rp1.000,00 T (+3,1% sejak akhir 2025), CASA 90,0%.",
		"ROE disetahunkan 19,6%. Rasio biaya terhadap pendapatan 33,3%.",
		footer,
	}, "\n\n")
	if got != want {
		t.Fatalf("summary mismatch\n got: %q\nwant: %q", got, want)
	}
}

func TestGeneralAnnualSummary(t *testing.T) {
	r, cur := report(t, xbrltest.General(), "fy")
	got := Render(meta(r), analysis.Analyze(analysis.Input{Current: *cur}).Metrics)
	want := strings.Join([]string{
		"$WXYZ — Laporan Keuangan Tahunan 2025 (diaudit)",
		"Laba bersih setahun Rp4,50 T, turun 10,0% YoY. EPS setahun Rp113 (tahun lalu Rp125).",
		"Pendapatan setahun Rp40,00 T (+11,1% YoY). Marjin kotor 30,0%, marjin bersih 11,3% setahun. " +
			"Arus kas operasi setahun Rp6,00 T (1,33x laba bersih).",
		"Total aset Rp60,00 T (+9,1% YoY), ekuitas Rp35,00 T (+9,4% YoY). DER 0,67x, rasio lancar 2,00x.",
		"ROE 13,4%.",
		footer,
	}, "\n\n")
	if got != want {
		t.Fatalf("summary mismatch\n got: %q\nwant: %q", got, want)
	}
}

func TestLossPhrases(t *testing.T) {
	profit := func(v float64) *float64 { return &v }
	cases := []struct {
		cur   float64
		prior *float64
		want  string
	}{
		{5e12, profit(4e12), "Laba bersih 9 bulan Rp5,00 T, naik 25,0% YoY"},
		{5e12, profit(5e12), "Laba bersih 9 bulan Rp5,00 T, stabil YoY"},
		{5e12, profit(-2e12), "Laba bersih 9 bulan Rp5,00 T, berbalik dari rugi Rp2,00 T tahun lalu"},
		{-1e12, profit(-2e12), "Rugi bersih 9 bulan Rp1,00 T, menyempit dari rugi Rp2,00 T tahun lalu"},
		{-3e12, profit(-2e12), "Rugi bersih 9 bulan Rp3,00 T, melebar dari rugi Rp2,00 T tahun lalu"},
		{-3e12, profit(2e12), "Rugi bersih 9 bulan Rp3,00 T, berbalik dari laba Rp2,00 T tahun lalu"},
		{-3e12, nil, "Rugi bersih 9 bulan Rp3,00 T"},
		{5e12, profit(0), "Laba bersih 9 bulan Rp5,00 T"},
	}
	for _, c := range cases {
		if got := profitPhrase("9 bulan", c.cur, c.prior, "IDR"); got != c.want {
			t.Errorf("profitPhrase(%v, %v) = %q, want %q", c.cur, c.prior, got, c.want)
		}
	}
}

func TestFormatting(t *testing.T) {
	cases := map[string]string{
		money(1039443469000000, "IDR"): "Rp1.039,44 T",
		money(768883000000, "IDR"):     "Rp768,88 M",
		money(-12345678, "IDR"):        "-Rp12,3 jt",
		money(950, "IDR"):              "Rp950",
		money(2.5e9, "USD"):            "US$2,50 miliar",
		money(12.3e6, "USD"):           "US$12,30 juta",
		money(4500, "SGD"):             "SGD 4,5 ribu",
		perShare(368, "IDR"):           "Rp368",
		perShare(12.5, "IDR"):          "Rp12,5",
		perShare(0.0123, "USD"):        "US$0,0123",
		perShare(-7, "IDR"):            "-Rp7",
		signed(9.04):                   "+9,0%",
		signed(-49.12):                 "-49,1%",
		signed(0.01):                   "0,0%",
		words(-3.9):                    "turun 3,9%",
		percent(0.8528):                "85,3%",
		times(0.6233):                  "0,62x",
		number(-0.0001, 1):             "0,0",
		number(1234567.891, 2):         "1.234.567,89",
	}
	for got, want := range cases {
		if got != want {
			t.Errorf("got %q, want %q", got, want)
		}
	}
}

func TestRenderNeverExceedsThePostLimit(t *testing.T) {
	r, cur := report(t, xbrltest.BankQ3(), "q3")
	m := meta(r)
	m.EntityCode = strings.Repeat("A", 3000)
	got := Render(m, analysis.Analyze(analysis.Input{Current: *cur}).Metrics)
	if utf8.RuneCountInString(got) != MaxLength {
		t.Fatalf("length %d", utf8.RuneCountInString(got))
	}
}
