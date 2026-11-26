package summary

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"

	"olt-social/research/internal/analysis"
	"olt-social/research/internal/xbrltest"
)

func build(t *testing.T, cur xbrltest.Spec, previous, priorYear *xbrltest.Spec) Document {
	t.Helper()
	r, snap := report(t, cur, "cur")
	in := analysis.Input{Current: *snap}
	if previous != nil {
		_, in.Previous = report(t, *previous, "prev")
	}
	if priorYear != nil {
		_, in.PriorYear = report(t, *priorYear, "py")
	}
	m := meta(r)
	m.EntityName = r.EntityName
	return Build(m, analysis.Analyze(in).Metrics)
}

func types(doc Document) []string {
	out := []string{}
	for _, b := range doc.Blocks {
		out = append(out, b.Type)
	}
	return out
}

func TestBankDocument(t *testing.T) {
	q2, py := xbrltest.BankQ2(), xbrltest.BankQ3PriorYear()
	doc := build(t, xbrltest.BankQ3(), &q2, &py)
	if doc.Version != 1 || doc.Badge != "Ringkasan otomatis" || doc.Title != "Laporan Keuangan Kuartal III 2026" ||
		doc.Subtitle != "PT Bank Contoh Tbk. · Belum diaudit" || doc.Headline != "Laba bersih kuartal III naik 18,2% YoY" ||
		!strings.Contains(doc.Disclaimer, "tanpa AI") {
		t.Fatalf("header = %+v", doc)
	}
	if got := types(doc); !reflect.DeepEqual(got, []string{"paragraph", "metrics", "list", "callout"}) {
		t.Fatalf("blocks = %v", got)
	}
	if doc.Blocks[0].Text != "ABCD (PT Bank Contoh Tbk.) membukukan laba bersih kuartal III Rp13,00 T, naik 18,2% YoY. "+
		"Laba bersih 9 bulan mencapai Rp36,00 T (+12,5% YoY)." {
		t.Fatalf("lead = %q", doc.Blocks[0].Text)
	}
	want := []Metric{
		{Label: "Laba bersih kuartal III", Value: "Rp13,00 T", Change: "+18,2% YoY", Trend: "up"},
		{Label: "Pendapatan bunga bersih kuartal III", Value: "Rp21,00 T", Change: "+7,7% YoY", Trend: "up"},
		{Label: "Kredit", Value: "Rp900,00 T", Change: "+12,5% YoY", Trend: "up"},
		{Label: "ROE disetahunkan", Value: "19,6%", Change: "tahun lalu 19,0%", Trend: "up"},
	}
	if !reflect.DeepEqual(doc.Blocks[1].Metrics, want) {
		t.Fatalf("metrics = %+v", doc.Blocks[1].Metrics)
	}
	if list := doc.Blocks[2]; list.Style != "numbered" || len(list.Items) != 5 ||
		list.Items[1] != "Beban cadangan kerugian kuartal III Rp800,00 M (-42,9% YoY)." {
		t.Fatalf("list = %+v", list)
	}
	if c := doc.Blocks[3]; c.Title != "Poin utama" || c.Text != "Laba kuartal III di atas rata-rata kuartal sebelumnya "+
		"tahun ini. Beban cadangan kerugian turun 42,9% YoY, menopang laba." {
		t.Fatalf("callout = %+v", c)
	}
}

func TestBankDocumentWithoutComparatives(t *testing.T) {
	doc := build(t, xbrltest.BankQ3(), nil, nil)
	if doc.Headline != "Laba bersih 9 bulan naik 12,5% YoY" {
		t.Fatalf("headline = %q", doc.Headline)
	}
	if m := doc.Blocks[1].Metrics[2]; m.Label != "Kredit" || m.Change != "+5,9% YTD" {
		t.Fatalf("balance metric = %+v", m)
	}
}

func TestGeneralDocumentTakeaway(t *testing.T) {
	doc := build(t, xbrltest.General(), nil, nil)
	if doc.Title != "Laporan Keuangan Tahunan 2025" || doc.Subtitle != "PT Contoh Industri Tbk. · Diaudit" ||
		doc.Headline != "Laba bersih setahun turun 10,0% YoY" {
		t.Fatalf("header = %+v", doc)
	}
	if c := doc.Blocks[len(doc.Blocks)-1]; c.Text != "Laba bersih setahun turun 10,0% meski pendapatan naik 11,1%." {
		t.Fatalf("callout = %q", c.Text)
	}
}

func TestLossDocument(t *testing.T) {
	s := xbrltest.General()
	s.Current["ProfitLossAttributableToParentEntity"] = -2e12
	doc := build(t, s, nil, nil)
	if doc.Headline != "Rugi bersih setahun berbalik dari laba" {
		t.Fatalf("headline = %q", doc.Headline)
	}
	if c := doc.Blocks[len(doc.Blocks)-1]; !strings.HasPrefix(c.Text, "Kinerja setahun berbalik dari laba menjadi rugi.") {
		t.Fatalf("callout = %q", c.Text)
	}
}

func TestDocumentFitsTheDatabaseContract(t *testing.T) {
	q2, py := xbrltest.BankQ2(), xbrltest.BankQ3PriorYear()
	for _, doc := range []Document{build(t, xbrltest.BankQ3(), &q2, &py), build(t, xbrltest.General(), nil, nil)} {
		raw, err := json.Marshal(doc)
		if err != nil {
			t.Fatal(err)
		}
		var generic map[string]any
		_ = json.Unmarshal(raw, &generic)
		if generic["version"] != float64(1) || len(raw) > 32768 || len(doc.Blocks) == 0 || len(doc.Blocks) > 20 {
			t.Fatalf("document = %s", raw)
		}
		for _, field := range []string{doc.Title, doc.Headline, doc.Disclaimer} {
			if n := len([]rune(field)); n == 0 || n > 200 {
				t.Fatalf("field length %d: %q", n, field)
			}
		}
		for _, b := range doc.Blocks {
			switch b.Type {
			case "paragraph", "list", "callout", "metrics":
			default:
				t.Fatalf("unknown block %q", b.Type)
			}
		}
	}
}
