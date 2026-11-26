package xbrl_test

import (
	"archive/zip"
	"bytes"
	"errors"
	"io"
	"strings"
	"testing"
	"time"

	"olt-social/research/internal/xbrl"
	"olt-social/research/internal/xbrltest"
)

func parse(t *testing.T, s xbrltest.Spec) *xbrl.Report {
	t.Helper()
	rc, err := xbrl.Open(xbrltest.Archive(s), xbrl.DefaultLimits())
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	defer rc.Close()
	r, err := xbrl.Parse(rc)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	return r
}

func TestParseReadsIdentityAndMainContexts(t *testing.T) {
	r := parse(t, xbrltest.BankQ3())
	if r.EntityCode != "ABCD" || r.EntityName != "PT Bank Contoh Tbk." || r.Period != "Q3" || r.Audit != "unaudited" ||
		r.Currency != "IDR" || r.Sector != "G. Financials" || r.Subsector != "G1. Banks" {
		t.Fatalf("identity = %+v", r)
	}
	if !r.PeriodStart.Equal(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)) ||
		!r.PeriodEnd.Equal(time.Date(2026, 9, 30, 0, 0, 0, 0, time.UTC)) || r.Months() != 9 {
		t.Fatalf("period = %s..%s (%d months)", r.PeriodStart, r.PeriodEnd, r.Months())
	}
	checks := []struct {
		role, concept string
		want          float64
	}{
		{xbrl.Current, "InterestIncome", 90e12},
		{xbrl.Prior, "InterestIncome", 84e12},
		{xbrl.CurrentEnd, "Assets", 1500e12},
		{xbrl.PriorYearEnd, "Assets", 1450e12},
		{xbrl.Current, "BasicEarningsLossPerShareFromContinuingOperations", 300},
	}
	for _, c := range checks {
		if got, ok := r.Facts.Value(c.role, c.concept); !ok || got != c.want {
			t.Errorf("%s %s = %v, %v; want %v", c.role, c.concept, got, ok, c.want)
		}
	}
}

func TestParseIgnoresDimensionalTextAndNilFacts(t *testing.T) {
	r := parse(t, xbrltest.BankQ3())
	if got, _ := r.Facts.Value(xbrl.CurrentEnd, "Assets"); got != 1500e12 {
		t.Fatalf("dimensional fact leaked into Assets: %v", got)
	}
	if _, ok := r.Facts.Value(xbrl.Current, "GeneralInformationTextBlock"); ok {
		t.Fatal("text block stored as a number")
	}
	if _, ok := r.Facts.Value(xbrl.Current, "ProfitLossFromDiscontinuedOperations"); ok {
		t.Fatal("xsi:nil fact stored")
	}
}

func TestParseFallsBackToMonthsAndDefaults(t *testing.T) {
	s := xbrltest.BankQ2()
	s.PeriodLabel = "Semester"
	s.AuditLabel = "Direviu Terbatas / Limited Review"
	s.Currency = "Dolar Amerika Serikat / USD"
	r := parse(t, s)
	if r.Period != "Q2" || r.Audit != "unaudited" || r.Currency != "USD" {
		t.Fatalf("period %q audit %q currency %q", r.Period, r.Audit, r.Currency)
	}
	s.AuditLabel = "Diaudit / Audited"
	s.Currency = "Rupiah"
	if r := parse(t, s); r.Audit != "audited" || r.Currency != "IDR" {
		t.Fatalf("audit %q currency %q", r.Audit, r.Currency)
	}
}

func TestParseRejectsBadInstances(t *testing.T) {
	good := string(xbrltest.Instance(xbrltest.BankQ3()))
	cases := map[string]struct {
		doc  string
		want error
	}{
		"not xml":      {"hello", xbrl.ErrInvalid},
		"wrong root":   {`<?xml version="1.0"?><html></html>`, xbrl.ErrInvalid},
		"broken":       {good[:len(good)/2], xbrl.ErrInvalid},
		"no code":      {strings.Replace(good, ">ABCD<", "><", 1), xbrl.ErrInvalid},
		"bad code":     {strings.Replace(good, ">ABCD<", ">abcd efg<", 1), xbrl.ErrUnknownEntity},
		"no dates":     {strings.Replace(good, "CurrentPeriodEndDate", "SomethingElse", 2), xbrl.ErrInvalid},
		"no current":   {strings.ReplaceAll(good, `contextRef="CurrentYearDuration"`, `contextRef="Missing"`), xbrl.ErrInvalid},
		"empty":        {"", xbrl.ErrInvalid},
		"odd period":   {strings.Replace(strings.Replace(good, "Kuartal III / Third Quarter", "Lainnya", 1), "<idx-dei:CurrentPeriodEndDate contextRef=\"CurrentYearInstant\">2026-09-30", "<idx-dei:CurrentPeriodEndDate contextRef=\"CurrentYearInstant\">2026-08-15", 1), xbrl.ErrInvalid},
		"external dtd": {`<?xml version="1.0"?><!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]><xbrl xmlns="http://www.xbrl.org/2003/instance">&e;</xbrl>`, xbrl.ErrInvalid},
		"no currency":  {strings.Replace(good, "Rupiah / IDR", "", 1), nil},
	}
	for name, c := range cases {
		_, err := xbrl.Parse(strings.NewReader(c.doc))
		if c.want == nil {
			if err != nil {
				t.Errorf("%s: unexpected error %v", name, err)
			}
			continue
		}
		if !errors.Is(err, c.want) {
			t.Errorf("%s: error %v, want %v", name, err, c.want)
		}
	}
}

func TestInspectRejectsUnsafeArchives(t *testing.T) {
	instance := xbrltest.Instance(xbrltest.BankQ3())
	many := make([]xbrltest.Entry, 17)
	for i := range many {
		many[i] = xbrltest.Entry{Name: strings.Repeat("a", i+1) + ".txt", Body: []byte("x")}
	}
	cases := map[string]struct {
		data []byte
		want error
	}{
		"not zip":     {[]byte("PK not really"), xbrl.ErrNotZip},
		"empty":       {xbrltest.Zip(), xbrl.ErrNoInstance},
		"no instance": {xbrltest.Zip(xbrltest.Entry{Name: "readme.txt", Body: []byte("x")}), xbrl.ErrNoInstance},
		"two":         {xbrltest.Zip(xbrltest.Entry{Name: "a.xbrl", Body: instance}, xbrltest.Entry{Name: "b.XBRL", Body: instance}), xbrl.ErrUnsafeZip},
		"many":        {xbrltest.Zip(many...), xbrl.ErrUnsafeZip},
		"bomb":        {xbrltest.Zip(xbrltest.Entry{Name: "instance.xbrl", Body: make([]byte, 4<<20)}), xbrl.ErrUnsafeZip},
	}
	for name, c := range cases {
		if _, err := xbrl.Inspect(c.data, xbrl.DefaultLimits()); !errors.Is(err, c.want) {
			t.Errorf("%s: error %v, want %v", name, err, c.want)
		}
	}
	limits := xbrl.DefaultLimits()
	limits.MaxInstanceBytes = 1024
	if _, err := xbrl.Inspect(xbrltest.Archive(xbrltest.BankQ3()), limits); !errors.Is(err, xbrl.ErrUnsafeZip) {
		t.Fatalf("oversized instance: %v", err)
	}
	if f, err := xbrl.Inspect(xbrltest.Zip(xbrltest.Entry{Name: "dir/INSTANCE.XBRL", Body: instance}), xbrl.DefaultLimits()); err != nil || f.Name != "dir/INSTANCE.XBRL" {
		t.Fatalf("case-insensitive extension: %v", err)
	}
}

func TestOpenStopsAtTheLimitEvenWhenTheHeaderLies(t *testing.T) {
	var buf bytes.Buffer
	w := zip.NewWriter(&buf)
	f, _ := w.CreateHeader(&zip.FileHeader{Name: "instance.xbrl", Method: zip.Store})
	_, _ = f.Write(bytes.Repeat([]byte("a"), 4096))
	_ = w.Close()
	limits := xbrl.DefaultLimits()
	limits.MaxInstanceBytes = 4096
	rc, err := xbrl.Open(buf.Bytes(), limits)
	if err != nil {
		t.Fatal(err)
	}
	if data, err := io.ReadAll(rc); err != nil || len(data) != 4096 {
		t.Fatalf("exact-size read: %d bytes, %v", len(data), err)
	}
	limits.MaxInstanceBytes = 4095
	if _, err := xbrl.Open(buf.Bytes(), limits); !errors.Is(err, xbrl.ErrUnsafeZip) {
		t.Fatalf("declared size above limit: %v", err)
	}
}

func TestMonthsBetween(t *testing.T) {
	d := func(s string) time.Time {
		v, _ := time.Parse("2006-01-02", s)
		return v
	}
	cases := map[[2]string]int{
		{"2026-01-01", "2026-03-31"}: 3,
		{"2026-01-01", "2026-06-30"}: 6,
		{"2026-01-01", "2026-09-30"}: 9,
		{"2026-01-01", "2026-12-31"}: 12,
		{"2025-07-01", "2026-06-30"}: 12,
		{"2026-04-01", "2026-06-30"}: 3,
	}
	for in, want := range cases {
		if got := xbrl.MonthsBetween(d(in[0]), d(in[1])); got != want {
			t.Errorf("%v = %d, want %d", in, got, want)
		}
	}
}

func TestEntityNameIsTidied(t *testing.T) {
	cases := map[string]string{
		"Akasha Wira International Tbk  Tbk": "Akasha Wira International Tbk",
		"PT Bank Contoh Tbk.":                "PT Bank Contoh Tbk.",
		"  PT  Contoh	Industri Tbk TBK. ":    "PT Contoh Industri Tbk",
		"Indo Tambangraya Megah Tbk":         "Indo Tambangraya Megah Tbk",
		"   ":                                "ABCD",
		"Tbk":                                "Tbk",
	}
	for raw, want := range cases {
		spec := xbrltest.BankQ3()
		spec.Name = raw
		if got := parse(t, spec).EntityName; got != want {
			t.Errorf("name %q = %q, want %q", raw, got, want)
		}
	}
}
