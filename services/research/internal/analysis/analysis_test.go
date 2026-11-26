package analysis_test

import (
	"math"
	"slices"
	"testing"

	"olt-social/research/internal/analysis"
	"olt-social/research/internal/xbrl"
	"olt-social/research/internal/xbrltest"
)

func snapshot(t *testing.T, s xbrltest.Spec, id string) *analysis.Snapshot {
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
	return &analysis.Snapshot{ID: id, Period: r.Period, PeriodStart: r.PeriodStart, PeriodEnd: r.PeriodEnd, Facts: r.Facts}
}

func near(t *testing.T, label string, got *float64, want float64) {
	t.Helper()
	if got == nil {
		t.Errorf("%s missing, want %v", label, want)
		return
	}
	if math.Abs(*got-want) > 1e-6*math.Max(1, math.Abs(want)) {
		t.Errorf("%s = %v, want %v", label, *got, want)
	}
}

func TestBankWithComparatives(t *testing.T) {
	res := analysis.Analyze(analysis.Input{
		Current:   *snapshot(t, xbrltest.BankQ3(), "q3"),
		Previous:  snapshot(t, xbrltest.BankQ2(), "q2"),
		PriorYear: snapshot(t, xbrltest.BankQ3PriorYear(), "py"),
	})
	m := res.Metrics
	if m.Template != "bank" || m.Months != 9 || m.QuarterMonths != 3 || m.EarlierQuarters != 2 ||
		m.BalanceBase != analysis.BaseYearAgo || m.PreviousReport != "q2" || m.PriorYearReport != "py" {
		t.Fatalf("header = %+v", m)
	}
	net := m.Flow(analysis.NetProfit)
	near(t, "net ytd", net.YTD, 36e12)
	near(t, "net ytd prior", net.YTDPrior, 32e12)
	near(t, "net quarter", net.Quarter, 13e12)
	near(t, "net quarter prior", net.QuarterPrior, 11e12)
	near(t, "net earlier avg", net.EarlierAvg, 11.5e12)
	nii := m.Flow(analysis.NetInterestIncome)
	near(t, "nii quarter", nii.Quarter, 21e12)
	near(t, "nii quarter prior", nii.QuarterPrior, 19.5e12)
	near(t, "provision quarter", m.Flow(analysis.Provision).Quarter, 0.8e12)
	near(t, "opex ytd", m.Flow(analysis.OperatingExpense).YTD, 25e12)
	loans := m.Balance(analysis.Loans)
	near(t, "loans end", loans.End, 900e12)
	near(t, "loans year ago", loans.YearAgo, 800e12)
	near(t, "loans year end", loans.YearEnd, 850e12)
	near(t, "loans previous", loans.Previous, 880e12)
	near(t, "deposits", m.Balance(analysis.Deposits).End, 1000e12)
	near(t, "casa", m.Balance(analysis.CASA).End, 900e12)
	roe := m.Ratio(analysis.ROE)
	near(t, "roe", roe.Value, 48.0/245.0)
	near(t, "roe year ago", roe.YearAgo, (32.0*12/9)/225.0)
	near(t, "cost to income", m.Ratio(analysis.CostToIncome).Value, 25.0/75.0)
	ldr := m.Ratio(analysis.LDR)
	near(t, "ldr", ldr.Value, 0.9)
	near(t, "ldr previous", ldr.Previous, 880.0/990.0)
	near(t, "casa ratio", m.Ratio(analysis.CASARatio).Value, 0.9)
	near(t, "allowance", m.Ratio(analysis.LoanAllowanceRatio).Value, 0.03)
	near(t, "cost of credit", m.Ratio(analysis.CostOfCredit).Value, (3.0*12/9)/875.0)
	if len(res.Warnings) != 1 || res.Warnings[0].Code != analysis.WarnRestated ||
		!slices.Equal(res.Warnings[0].Lines, []string{analysis.OtherOperatingIncome}) {
		t.Fatalf("warnings = %+v", res.Warnings)
	}
}

func TestBankWithoutComparatives(t *testing.T) {
	res := analysis.Analyze(analysis.Input{Current: *snapshot(t, xbrltest.BankQ3(), "q3")})
	m := res.Metrics
	if m.QuarterMonths != 0 || m.BalanceBase != analysis.BaseYearEnd || len(res.Warnings) != 0 {
		t.Fatalf("metrics %+v warnings %+v", m, res.Warnings)
	}
	if f := m.Flow(analysis.NetProfit); f.Quarter != nil || f.EarlierAvg != nil {
		t.Fatalf("quarter values without a previous report: %+v", f)
	}
	if b := m.Balance(analysis.Loans); b.YearAgo != nil || b.Previous != nil {
		t.Fatalf("comparatives without reports: %+v", b)
	}
	if r := m.Ratio(analysis.ROE); r.YearAgo != nil {
		t.Fatal("year-ago ROE without a prior-year report")
	}
}

func TestComparativesOfTheWrongLengthAreIgnored(t *testing.T) {
	q3 := snapshot(t, xbrltest.BankQ3(), "q3")
	res := analysis.Analyze(analysis.Input{Current: *q3, Previous: q3, PriorYear: snapshot(t, xbrltest.BankQ2(), "q2")})
	if res.Metrics.QuarterMonths != 0 || res.Metrics.PreviousReport != "" || res.Metrics.PriorYearReport != "" {
		t.Fatalf("metrics = %+v", res.Metrics)
	}
}

func TestFirstQuarterIsItsOwnQuarter(t *testing.T) {
	s := xbrltest.BankQ2()
	s.End, s.PriorEnd, s.PeriodLabel = "2026-03-31", "2025-03-31", "Kuartal I / First Quarter"
	res := analysis.Analyze(analysis.Input{Current: *snapshot(t, s, "q1")})
	f := res.Metrics.Flow(analysis.NetProfit)
	if res.Metrics.QuarterMonths != 3 || f.Quarter == nil || *f.Quarter != *f.YTD || f.EarlierAvg != nil {
		t.Fatalf("q1 = %+v %+v", res.Metrics, f)
	}
}

func TestGeneralTemplateAndFullYear(t *testing.T) {
	res := analysis.Analyze(analysis.Input{Current: *snapshot(t, xbrltest.General(), "fy")})
	m := res.Metrics
	if m.Template != "general" || m.Months != 12 || m.BalanceBase != analysis.BaseYearAgo || len(res.Warnings) != 0 {
		t.Fatalf("metrics %+v warnings %+v", m, res.Warnings)
	}
	near(t, "assets year ago", m.Balance(analysis.Assets).YearAgo, 55e12)
	near(t, "gross margin", m.Ratio(analysis.GrossMargin).Value, 0.3)
	near(t, "net margin", m.Ratio(analysis.NetMargin).Value, 4.5/40)
	near(t, "der", m.Ratio(analysis.DER).Value, 24.0/36.0)
	near(t, "current ratio", m.Ratio(analysis.CurrentRatio).Value, 2)
	near(t, "roe", m.Ratio(analysis.ROE).Value, 4.5/33.5)
	if m.Ratio(analysis.CostToIncome) != nil {
		t.Fatal("bank ratio on a general report")
	}
}

func TestBasicTemplateAndMissingLines(t *testing.T) {
	s := xbrltest.General()
	delete(s.Current, "SalesAndRevenue")
	delete(s.CurrentEnd, "Assets")
	res := analysis.Analyze(analysis.Input{Current: *snapshot(t, s, "x")})
	if res.Metrics.Template != "basic" || len(res.Warnings) != 2 || res.Warnings[0].Code != analysis.WarnTemplateBasic ||
		res.Warnings[1].Code != analysis.WarnMissingLines || !slices.Equal(res.Warnings[1].Lines, []string{analysis.Assets}) {
		t.Fatalf("template %q warnings %+v", res.Metrics.Template, res.Warnings)
	}
}

func TestRatiosSkipNonPositiveDenominators(t *testing.T) {
	s := xbrltest.General()
	s.CurrentEnd["EquityAttributableToEquityOwnersOfParentEntity"] = -1e12
	s.PriorYearEnd["EquityAttributableToEquityOwnersOfParentEntity"] = -2e12
	s.CurrentEnd["CurrentLiabilities"] = 0
	m := analysis.Analyze(analysis.Input{Current: *snapshot(t, s, "x")}).Metrics
	if m.Ratio(analysis.ROE) != nil || m.Ratio(analysis.CurrentRatio) != nil {
		t.Fatalf("ratios = %+v", m.Ratios)
	}
}
