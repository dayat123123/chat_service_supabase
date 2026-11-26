package xbrltest

import (
	"archive/zip"
	"bytes"
	"encoding/xml"
	"fmt"
	"maps"
	"slices"
	"strconv"
	"strings"
)

type Spec struct {
	Code         string
	Name         string
	PeriodLabel  string
	Start        string
	End          string
	PriorStart   string
	PriorEnd     string
	YearEnd      string
	AuditLabel   string
	Currency     string
	Current      map[string]float64
	Prior        map[string]float64
	CurrentEnd   map[string]float64
	PriorYearEnd map[string]float64
}

const header = `<?xml version="1.0"?>
<xbrl xmlns="http://www.xbrl.org/2003/instance" xmlns:link="http://www.xbrl.org/2003/linkbase" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:idx-dei="http://www.idx.co.id/xbrl/taxonomy/2020-01-01/dei" xmlns:idx-cor="http://www.idx.co.id/xbrl/taxonomy/2020-01-01/cor" xmlns:xbrldi="http://xbrl.org/2006/xbrldi" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:iso4217="http://www.xbrl.org/2003/iso4217">
<link:schemaRef xlink:type="simple" xlink:href="Taxonomy.xsd"/>
<unit id="IDR"><measure>iso4217:IDR</measure></unit>
`

func Instance(s Spec) []byte {
	var b strings.Builder
	b.WriteString(header)
	entity := `<entity><identifier scheme="http://www.idx.co.id/xbrl">` + strings.ToLower(s.Code) + `_user</identifier></entity>`
	fmt.Fprintf(&b, `<context id="CurrentYearDuration">%s<period><startDate>%s</startDate><endDate>%s</endDate></period></context>`+"\n", entity, s.Start, s.End)
	fmt.Fprintf(&b, `<context id="PriorYearDuration">%s<period><startDate>%s</startDate><endDate>%s</endDate></period></context>`+"\n", entity, s.PriorStart, s.PriorEnd)
	fmt.Fprintf(&b, `<context id="CurrentYearInstant">%s<period><instant>%s</instant></period></context>`+"\n", entity, s.End)
	fmt.Fprintf(&b, `<context id="PriorEndYearInstant">%s<period><instant>%s</instant></period></context>`+"\n", entity, s.YearEnd)
	fmt.Fprintf(&b, `<context id="CurrentYearInstant_Member">%s<period><instant>%s</instant></period><scenario><xbrldi:explicitMember dimension="idx-cor:ComponentsOfEquityAxis">idx-cor:NonControllingInterestsMember</xbrldi:explicitMember></scenario></context>`+"\n", entity, s.End)
	dei := [][2]string{
		{"EntityName", s.Name}, {"EntityCode", s.Code}, {"Sector", "G. Financials"}, {"Subsector", "G1. Banks"},
		{"PeriodOfFinancialStatementsSubmissions", s.PeriodLabel},
		{"CurrentPeriodStartDate", s.Start}, {"CurrentPeriodEndDate", s.End},
		{"PriorYearEndDate", s.YearEnd}, {"PriorPeriodStartDate", s.PriorStart}, {"PriorPeriodEndDate", s.PriorEnd},
		{"DescriptionOfPresentationCurrency", s.Currency}, {"LevelOfRoundingUsedInFinancialStatements", "Jutaan / In Million"},
		{"TypeOfReportOnFinancialStatements", s.AuditLabel}, {"CurrentYearAuditor", ""},
	}
	for _, d := range dei {
		if d[1] == "" {
			fmt.Fprintf(&b, `<idx-dei:%s contextRef="CurrentYearInstant"/>`+"\n", d[0])
			continue
		}
		fmt.Fprintf(&b, `<idx-dei:%s contextRef="CurrentYearInstant">%s</idx-dei:%s>`+"\n", d[0], escape(d[1]), d[0])
	}
	for _, set := range []struct {
		context string
		values  map[string]float64
	}{{"CurrentYearDuration", s.Current}, {"PriorYearDuration", s.Prior}, {"CurrentYearInstant", s.CurrentEnd},
		{"PriorEndYearInstant", s.PriorYearEnd}} {
		for _, name := range slices.Sorted(maps.Keys(set.values)) {
			fmt.Fprintf(&b, `<idx-cor:%s contextRef="%s" unitRef="IDR" decimals="-6">%s</idx-cor:%s>`+"\n",
				name, set.context, strconv.FormatFloat(set.values[name], 'f', -1, 64), name)
		}
	}
	b.WriteString(`<idx-cor:Assets contextRef="CurrentYearInstant_Member" unitRef="IDR" decimals="-6">1</idx-cor:Assets>` + "\n")
	b.WriteString(`<idx-cor:GeneralInformationTextBlock contextRef="CurrentYearDuration">&lt;p&gt;Catatan atas laporan keuangan&lt;/p&gt;</idx-cor:GeneralInformationTextBlock>` + "\n")
	b.WriteString(`<idx-cor:ProfitLossFromDiscontinuedOperations contextRef="CurrentYearDuration" xsi:nil="true"/>` + "\n")
	b.WriteString("</xbrl>\n")
	return []byte(b.String())
}

func escape(s string) string {
	var b bytes.Buffer
	_ = xml.EscapeText(&b, []byte(s))
	return b.String()
}

type Entry struct {
	Name string
	Body []byte
}

func Zip(entries ...Entry) []byte {
	var buf bytes.Buffer
	w := zip.NewWriter(&buf)
	for _, e := range entries {
		f, err := w.Create(e.Name)
		if err != nil {
			panic(err)
		}
		if _, err := f.Write(e.Body); err != nil {
			panic(err)
		}
	}
	if err := w.Close(); err != nil {
		panic(err)
	}
	return buf.Bytes()
}

func Archive(s Spec) []byte {
	return Zip(Entry{Name: "Taxonomy.xsd", Body: []byte(`<schema xmlns="http://www.w3.org/2001/XMLSchema"/>`)},
		Entry{Name: "instance.xbrl", Body: Instance(s)})
}

const T = 1e12

func bankFlows(ii, ie, ooi, rec, ga, other, pbt, net, eps float64) map[string]float64 {
	return map[string]float64{
		"InterestIncome": ii * T, "InterestExpenses": ie * T, "OtherOperatingIncome": ooi * T,
		"RecoveryOfImpairmentLossesOfFinancialAssets": rec * T, "GeneralAndAdministrativeExpenses": ga * T,
		"OtherOperatingExpenses": other * T, "ProfitLossBeforeIncomeTax": pbt * T,
		"ProfitLossAttributableToParentEntity": net * T, "ProfitLoss": (net + 0.1) * T,
		"BasicEarningsLossPerShareFromContinuingOperations": eps,
	}
}

func bankBalance(loans, ca, sa, td, allowance, assets, equity float64) map[string]float64 {
	return map[string]float64{
		"LoansThirdParties": loans * T, "LoansRelatedParties": 0, "CurrentAccounts": ca * T, "SavingsDeposits": sa * T,
		"TimeDeposits": td * T, "AllowanceForImpairmentLossesForLoans": allowance * T, "Assets": assets * T,
		"EquityAttributableToEquityOwnersOfParentEntity": equity * T, "Equity": (equity + 0.2) * T,
	}
}

func BankQ3() Spec {
	return Spec{
		Code: "ABCD", Name: "PT Bank Contoh Tbk.", PeriodLabel: "Kuartal III / Third Quarter",
		Start: "2026-01-01", End: "2026-09-30", PriorStart: "2025-01-01", PriorEnd: "2025-09-30", YearEnd: "2025-12-31",
		AuditLabel: "Tidak Diaudit / Unaudit", Currency: "Rupiah / IDR",
		Current:      bankFlows(90, 30, 15, -3, 10, 15, 47, 36, 300),
		Prior:        bankFlows(84, 28, 14, -4, 9, 14, 43, 32, 270),
		CurrentEnd:   bankBalance(900, 400, 500, 100, 27, 1500, 250),
		PriorYearEnd: bankBalance(850, 380, 480, 110, 26, 1450, 240),
	}
}

func BankQ2() Spec {
	return Spec{
		Code: "ABCD", Name: "PT Bank Contoh Tbk.", PeriodLabel: "Kuartal II / Second Quarter",
		Start: "2026-01-01", End: "2026-06-30", PriorStart: "2025-01-01", PriorEnd: "2025-06-30", YearEnd: "2025-12-31",
		AuditLabel: "Tidak Diaudit / Unaudit", Currency: "Rupiah / IDR",
		Current:      bankFlows(59, 20, 10, -2.2, 6.5, 10, 30, 23, 192),
		Prior:        bankFlows(55, 18.5, 9, -2.6, 6, 9.5, 28, 21, 177),
		CurrentEnd:   bankBalance(880, 390, 495, 105, 26.8, 1520, 245),
		PriorYearEnd: bankBalance(850, 380, 480, 110, 26, 1450, 240),
	}
}

func BankQ3PriorYear() Spec {
	return Spec{
		Code: "ABCD", Name: "PT Bank Contoh Tbk.", PeriodLabel: "Kuartal III / Third Quarter",
		Start: "2025-01-01", End: "2025-09-30", PriorStart: "2024-01-01", PriorEnd: "2024-09-30", YearEnd: "2024-12-31",
		AuditLabel: "Tidak Diaudit / Unaudit", Currency: "Rupiah / IDR",
		Current:      bankFlows(84, 28, 15.4, -4, 9, 14, 43, 32, 270),
		Prior:        bankFlows(80, 27, 13, -4.5, 8.5, 13, 40, 30, 250),
		CurrentEnd:   bankBalance(800, 360, 470, 120, 25, 1400, 230),
		PriorYearEnd: bankBalance(780, 350, 460, 125, 24, 1380, 220),
	}
}

func General() Spec {
	return Spec{
		Code: "WXYZ", Name: "PT Contoh Industri Tbk.", PeriodLabel: "Tahunan / Annual",
		Start: "2025-01-01", End: "2025-12-31", PriorStart: "2024-01-01", PriorEnd: "2024-12-31", YearEnd: "2024-12-31",
		AuditLabel: "Diaudit / Audited", Currency: "Rupiah / IDR",
		Current: map[string]float64{"SalesAndRevenue": 40 * T, "GrossProfit": 12 * T, "ProfitLossBeforeIncomeTax": 6 * T,
			"ProfitLossAttributableToParentEntity": 4.5 * T, "BasicEarningsLossPerShareFromContinuingOperations": 112.5,
			"NetCashFlowsReceivedFromUsedInOperatingActivities": 6 * T},
		Prior: map[string]float64{"SalesAndRevenue": 36 * T, "GrossProfit": 10.8 * T, "ProfitLossBeforeIncomeTax": 5 * T,
			"ProfitLossAttributableToParentEntity": 5 * T, "BasicEarningsLossPerShareFromContinuingOperations": 125},
		CurrentEnd: map[string]float64{"Assets": 60 * T, "Liabilities": 24 * T, "Equity": 36 * T,
			"EquityAttributableToEquityOwnersOfParentEntity": 35 * T, "CurrentAssets": 20 * T, "CurrentLiabilities": 10 * T},
		PriorYearEnd: map[string]float64{"Assets": 55 * T, "Liabilities": 22 * T, "Equity": 33 * T,
			"EquityAttributableToEquityOwnersOfParentEntity": 32 * T, "CurrentAssets": 18 * T, "CurrentLiabilities": 10 * T},
	}
}
