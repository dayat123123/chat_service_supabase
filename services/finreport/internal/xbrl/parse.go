package xbrl

import (
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"regexp"
	"strconv"
	"strings"
	"time"
)

const (
	Current      = "current"
	Prior        = "prior"
	CurrentEnd   = "current_end"
	PriorYearEnd = "prior_year_end"

	instanceNS = "http://www.xbrl.org/2003/instance"
	nilNS      = "http://www.w3.org/2001/XMLSchema-instance"
	dateLayout = "2006-01-02"
	maxDEIText = 300
)

var (
	ErrInvalid       = errors.New("invalid IDX XBRL instance")
	ErrUnknownEntity = errors.New("entity code is not a valid stock code")

	taxonomyNS = regexp.MustCompile(`^http://www\.idx\.co\.id/xbrl/taxonomy/[0-9-]+/(cor|dei)$`)
	entityCode = regexp.MustCompile(`^[A-Z][A-Z0-9]{1,11}$`)
	isoCode    = regexp.MustCompile(`\b[A-Z]{3}\b`)
)

type Facts map[string]map[string]float64

func (f Facts) Value(role, concept string) (float64, bool) {
	v, ok := f[role][concept]
	return v, ok
}

type Report struct {
	EntityCode  string
	EntityName  string
	Sector      string
	Subsector   string
	Period      string
	PeriodStart time.Time
	PeriodEnd   time.Time
	Audit       string
	Currency    string
	Facts       Facts
}

func (r *Report) Months() int {
	return MonthsBetween(r.PeriodStart, r.PeriodEnd)
}

func MonthsBetween(start, end time.Time) int {
	months := (end.Year()-start.Year())*12 + int(end.Month()) - int(start.Month())
	if end.Day() >= start.Day()-1 {
		months++
	}
	return months
}

type context struct {
	dimensional bool
	start       string
	end         string
	instant     string
}

type rawContext struct {
	ID     string `xml:"id,attr"`
	Entity struct {
		Segment *struct{} `xml:"segment"`
	} `xml:"entity"`
	Scenario *struct{} `xml:"scenario"`
	Period   struct {
		Start   string `xml:"startDate"`
		End     string `xml:"endDate"`
		Instant string `xml:"instant"`
	} `xml:"period"`
}

type rawFact struct {
	Context string `xml:"contextRef,attr"`
	Nil     string `xml:"http://www.w3.org/2001/XMLSchema-instance nil,attr"`
	Text    string `xml:",chardata"`
}

type fact struct {
	context string
	value   float64
}

func Parse(r io.Reader) (*Report, error) {
	dec := xml.NewDecoder(r)
	dec.Strict = true
	contexts := map[string]context{}
	numbers := map[string][]fact{}
	dei := map[string]string{}
	depth := 0
	sawRoot := false
	for {
		tok, err := dec.Token()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrInvalid, err)
		}
		switch t := tok.(type) {
		case xml.StartElement:
			depth++
			if depth == 1 {
				if t.Name.Space != instanceNS || t.Name.Local != "xbrl" {
					return nil, fmt.Errorf("%w: root element is not xbrli:xbrl", ErrInvalid)
				}
				sawRoot = true
				continue
			}
			if depth != 2 {
				continue
			}
			if err := readChild(dec, t, contexts, numbers, dei); err != nil {
				return nil, err
			}
			depth--
		case xml.EndElement:
			depth--
		}
	}
	if !sawRoot {
		return nil, fmt.Errorf("%w: empty document", ErrInvalid)
	}
	return build(contexts, numbers, dei)
}

func readChild(dec *xml.Decoder, t xml.StartElement, contexts map[string]context, numbers map[string][]fact,
	dei map[string]string) error {
	if t.Name.Space == instanceNS && t.Name.Local == "context" {
		var c rawContext
		if err := dec.DecodeElement(&c, &t); err != nil {
			return fmt.Errorf("%w: context: %v", ErrInvalid, err)
		}
		contexts[c.ID] = context{
			dimensional: c.Entity.Segment != nil || c.Scenario != nil,
			start:       strings.TrimSpace(c.Period.Start),
			end:         strings.TrimSpace(c.Period.End),
			instant:     strings.TrimSpace(c.Period.Instant),
		}
		return nil
	}
	m := taxonomyNS.FindStringSubmatch(t.Name.Space)
	if m == nil {
		return dec.Skip()
	}
	var f rawFact
	if err := dec.DecodeElement(&f, &t); err != nil {
		return fmt.Errorf("%w: %s: %v", ErrInvalid, t.Name.Local, err)
	}
	if strings.EqualFold(strings.TrimSpace(f.Nil), "true") {
		return nil
	}
	text := strings.TrimSpace(f.Text)
	if m[1] == "dei" {
		if _, seen := dei[t.Name.Local]; !seen && text != "" && len(text) <= maxDEIText {
			dei[t.Name.Local] = text
		}
		return nil
	}
	if text == "" || len(text) > 40 {
		return nil
	}
	v, err := strconv.ParseFloat(text, 64)
	if err != nil {
		return nil
	}
	numbers[t.Name.Local] = append(numbers[t.Name.Local], fact{context: f.Context, value: v})
	return nil
}

func build(contexts map[string]context, numbers map[string][]fact, dei map[string]string) (*Report, error) {
	code := strings.ToUpper(strings.TrimSpace(dei["EntityCode"]))
	if code == "" {
		return nil, fmt.Errorf("%w: idx-dei:EntityCode is missing", ErrInvalid)
	}
	if !entityCode.MatchString(code) {
		return nil, fmt.Errorf("%w: %q", ErrUnknownEntity, code)
	}
	start, err1 := time.Parse(dateLayout, dei["CurrentPeriodStartDate"])
	end, err2 := time.Parse(dateLayout, dei["CurrentPeriodEndDate"])
	if err1 != nil || err2 != nil || !end.After(start) {
		return nil, fmt.Errorf("%w: current period dates are missing or invalid", ErrInvalid)
	}
	priorStart, errA := time.Parse(dateLayout, dei["PriorPeriodStartDate"])
	priorEnd, errB := time.Parse(dateLayout, dei["PriorPeriodEndDate"])
	if errA != nil || errB != nil {
		priorStart, priorEnd = start.AddDate(-1, 0, 0), end.AddDate(-1, 0, 0)
	}
	yearEnd, err := time.Parse(dateLayout, dei["PriorYearEndDate"])
	if err != nil {
		yearEnd = start.AddDate(0, 0, -1)
	}
	name := strings.TrimSpace(dei["EntityName"])
	if name == "" {
		name = code
	}
	report := &Report{
		EntityCode:  code,
		EntityName:  name,
		Sector:      dei["Sector"],
		Subsector:   dei["Subsector"],
		PeriodStart: start,
		PeriodEnd:   end,
		Audit:       auditOf(dei["TypeOfReportOnFinancialStatements"]),
		Currency:    currencyOf(dei["DescriptionOfPresentationCurrency"]),
	}
	report.Period = periodOf(dei["PeriodOfFinancialStatementsSubmissions"], report.Months())
	if report.Period == "" {
		return nil, fmt.Errorf("%w: period is neither a quarter nor a full year", ErrInvalid)
	}

	roles := map[string]string{}
	for id, c := range contexts {
		if c.dimensional {
			continue
		}
		switch {
		case c.start == start.Format(dateLayout) && c.end == end.Format(dateLayout):
			roles[id] = Current
		case c.start == priorStart.Format(dateLayout) && c.end == priorEnd.Format(dateLayout):
			roles[id] = Prior
		case c.instant == end.Format(dateLayout):
			roles[id] = CurrentEnd
		case c.instant == yearEnd.Format(dateLayout):
			roles[id] = PriorYearEnd
		}
	}
	report.Facts = Facts{Current: {}, Prior: {}, CurrentEnd: {}, PriorYearEnd: {}}
	for concept, list := range numbers {
		for _, f := range list {
			role, ok := roles[f.context]
			if !ok {
				continue
			}
			if _, seen := report.Facts[role][concept]; !seen {
				report.Facts[role][concept] = f.value
			}
		}
	}
	if len(report.Facts[Current]) == 0 || len(report.Facts[CurrentEnd]) == 0 {
		return nil, fmt.Errorf("%w: no figures for the current period", ErrInvalid)
	}
	return report, nil
}

func periodOf(label string, months int) string {
	l := strings.ToLower(label)
	switch {
	case strings.Contains(l, "kuartal iii") || strings.Contains(l, "third"):
		return "Q3"
	case strings.Contains(l, "kuartal ii") || strings.Contains(l, "second"):
		return "Q2"
	case strings.Contains(l, "kuartal i") || strings.Contains(l, "first"):
		return "Q1"
	case strings.Contains(l, "tahunan") || strings.Contains(l, "annual"):
		return "FY"
	}
	switch months {
	case 3:
		return "Q1"
	case 6:
		return "Q2"
	case 9:
		return "Q3"
	case 12:
		return "FY"
	}
	return ""
}

func auditOf(label string) string {
	l := strings.ToLower(label)
	switch {
	case strings.Contains(l, "tidak diaudit") || strings.Contains(l, "unaudit") || strings.Contains(l, "review") ||
		strings.Contains(l, "reviu"):
		return "unaudited"
	case strings.Contains(l, "audit"):
		return "audited"
	}
	return "unknown"
}

func currencyOf(label string) string {
	if codes := isoCode.FindAllString(label, -1); len(codes) > 0 {
		return codes[len(codes)-1]
	}
	if strings.Contains(strings.ToLower(label), "rupiah") {
		return "IDR"
	}
	return "XXX"
}
