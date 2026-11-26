package analysis

import (
	"math"
	"time"

	"olt-social/research/internal/xbrl"
)

const (
	MetricsVersion = 1

	BaseYearAgo = "year_ago"
	BaseYearEnd = "year_end"

	WarnRestated      = "restated"
	WarnTemplateBasic = "template_basic"
	WarnMissingLines  = "missing_lines"

	restateTolerance = 0.005
)

type Snapshot struct {
	ID          string
	Period      string
	PeriodStart time.Time
	PeriodEnd   time.Time
	Facts       xbrl.Facts
}

func (s *Snapshot) months() int {
	return xbrl.MonthsBetween(s.PeriodStart, s.PeriodEnd)
}

type Input struct {
	Current   Snapshot
	Previous  *Snapshot
	PriorYear *Snapshot
}

type Flow struct {
	Key          string   `json:"key"`
	YTD          *float64 `json:"ytd,omitempty"`
	YTDPrior     *float64 `json:"ytd_prior,omitempty"`
	Quarter      *float64 `json:"quarter,omitempty"`
	QuarterPrior *float64 `json:"quarter_prior,omitempty"`
	EarlierAvg   *float64 `json:"earlier_quarter_avg,omitempty"`
}

type Balance struct {
	Key      string   `json:"key"`
	End      *float64 `json:"end,omitempty"`
	YearAgo  *float64 `json:"year_ago,omitempty"`
	YearEnd  *float64 `json:"year_end,omitempty"`
	Previous *float64 `json:"previous,omitempty"`
}

type Ratio struct {
	Key      string   `json:"key"`
	Value    *float64 `json:"value,omitempty"`
	YearAgo  *float64 `json:"year_ago,omitempty"`
	Previous *float64 `json:"previous,omitempty"`
}

type Metrics struct {
	Version         int       `json:"version"`
	Template        string    `json:"template"`
	Months          int       `json:"months"`
	QuarterMonths   int       `json:"quarter_months,omitempty"`
	EarlierQuarters int       `json:"earlier_quarters,omitempty"`
	BalanceBase     string    `json:"balance_base"`
	PreviousReport  string    `json:"previous_report,omitempty"`
	PriorYearReport string    `json:"prior_year_report,omitempty"`
	Flows           []Flow    `json:"flows"`
	Balances        []Balance `json:"balances"`
	Ratios          []Ratio   `json:"ratios"`
}

func (m *Metrics) Flow(key string) *Flow {
	for i := range m.Flows {
		if m.Flows[i].Key == key {
			return &m.Flows[i]
		}
	}
	return nil
}

func (m *Metrics) Balance(key string) *Balance {
	for i := range m.Balances {
		if m.Balances[i].Key == key {
			return &m.Balances[i]
		}
	}
	return nil
}

func (m *Metrics) Ratio(key string) *Ratio {
	for i := range m.Ratios {
		if m.Ratios[i].Key == key {
			return &m.Ratios[i]
		}
	}
	return nil
}

type Warning struct {
	Code  string   `json:"code"`
	Lines []string `json:"lines,omitempty"`
}

type Result struct {
	Metrics  Metrics
	Warnings []Warning
}

func Template(f xbrl.Facts) string {
	_, interest := f.Value(xbrl.Current, "InterestIncome")
	_, loans := f.Value(xbrl.CurrentEnd, "LoansThirdParties")
	if interest && loans {
		return "bank"
	}
	if _, sales := f.Value(xbrl.Current, "SalesAndRevenue"); sales {
		return "general"
	}
	return "basic"
}

func Analyze(in Input) Result {
	t := templates[Template(in.Current.Facts)]
	cur := in.Current
	months := cur.months()
	m := Metrics{
		Version:     MetricsVersion,
		Template:    t.name,
		Months:      months,
		BalanceBase: BaseYearEnd,
		Flows:       []Flow{},
		Balances:    []Balance{},
		Ratios:      []Ratio{},
	}
	prev := in.Previous
	if prev != nil && months-prev.months() != 3 {
		prev = nil
	}
	py := in.PriorYear
	if py != nil && py.months() != months {
		py = nil
	}
	switch {
	case months == 3:
		m.QuarterMonths = 3
	case prev != nil:
		m.QuarterMonths = 3
		m.EarlierQuarters = prev.months() / 3
		m.PreviousReport = prev.ID
	}
	if py != nil {
		m.PriorYearReport = py.ID
		m.BalanceBase = BaseYearAgo
	}
	if cur.Period == "FY" {
		m.BalanceBase = BaseYearAgo
	}

	present := map[string]bool{}
	for _, l := range t.flows {
		f := Flow{Key: l.key, YTD: eval(l.value, cur.Facts[xbrl.Current]), YTDPrior: eval(l.value, cur.Facts[xbrl.Prior])}
		switch {
		case months == 3:
			f.Quarter, f.QuarterPrior = f.YTD, f.YTDPrior
		case prev != nil:
			earlier := eval(l.value, prev.Facts[xbrl.Current])
			f.Quarter = sub(f.YTD, earlier)
			f.QuarterPrior = sub(f.YTDPrior, eval(l.value, prev.Facts[xbrl.Prior]))
			if earlier != nil && m.EarlierQuarters > 0 {
				f.EarlierAvg = ptr(*earlier / float64(m.EarlierQuarters))
			}
		}
		if f.YTD != nil {
			present[l.key] = true
			m.Flows = append(m.Flows, f)
		}
	}
	for _, l := range t.balances {
		b := Balance{Key: l.key, End: eval(l.value, cur.Facts[xbrl.CurrentEnd]),
			YearEnd: eval(l.value, cur.Facts[xbrl.PriorYearEnd])}
		switch {
		case py != nil:
			b.YearAgo = eval(l.value, py.Facts[xbrl.CurrentEnd])
		case cur.Period == "FY":
			b.YearAgo = b.YearEnd
		}
		if prev != nil {
			b.Previous = eval(l.value, prev.Facts[xbrl.CurrentEnd])
		}
		if b.End != nil {
			present[l.key] = true
			m.Balances = append(m.Balances, b)
		}
	}
	m.Ratios = ratios(t.name, &cur, prev, py)

	var warnings []Warning
	if t.name == "basic" {
		warnings = append(warnings, Warning{Code: WarnTemplateBasic})
	}
	var missing []string
	for _, key := range t.core {
		if !present[key] {
			missing = append(missing, key)
		}
	}
	if len(missing) > 0 {
		warnings = append(warnings, Warning{Code: WarnMissingLines, Lines: missing})
	}
	if py != nil {
		var restated []string
		for _, l := range t.flows {
			now := eval(l.value, cur.Facts[xbrl.Prior])
			then := eval(l.value, py.Facts[xbrl.Current])
			if now != nil && then != nil && math.Abs(*now-*then) > restateTolerance*math.Max(math.Abs(*then), 1) {
				restated = append(restated, l.key)
			}
		}
		if len(restated) > 0 {
			warnings = append(warnings, Warning{Code: WarnRestated, Lines: restated})
		}
	}
	return Result{Metrics: m, Warnings: warnings}
}

func ratios(name string, cur, prev, py *Snapshot) []Ratio {
	type rule struct {
		key      string
		calc     func(t template, s *Snapshot) *float64
		previous bool
	}
	rules := []rule{{key: ROE, calc: roe}}
	switch name {
	case "bank":
		rules = append(rules,
			rule{key: CostToIncome, calc: costToIncome},
			rule{key: LDR, calc: endRatio(Loans, Deposits), previous: true},
			rule{key: CASARatio, calc: endRatio(CASA, Deposits), previous: true},
			rule{key: LoanAllowanceRatio, calc: endRatio(LoanAllowance, Loans), previous: true},
			rule{key: CostOfCredit, calc: costOfCredit},
		)
	case "general":
		rules = append(rules,
			rule{key: GrossMargin, calc: flowRatio(GrossProfit, Revenue)},
			rule{key: NetMargin, calc: flowRatio(NetProfit, Revenue)},
			rule{key: DER, calc: endRatio(Liabilities, EquityTotal), previous: true},
			rule{key: CurrentRatio, calc: endRatio(CurrentAssets, CurrentLiabilities), previous: true},
		)
	}
	t := templates[name]
	out := []Ratio{}
	for _, r := range rules {
		v := Ratio{Key: r.key, Value: r.calc(t, cur)}
		if v.Value == nil {
			continue
		}
		if py != nil {
			v.YearAgo = r.calc(t, py)
		}
		if prev != nil && r.previous {
			v.Previous = r.calc(t, prev)
		}
		out = append(out, v)
	}
	return out
}

func roe(t template, s *Snapshot) *float64 {
	profit := flowValue(t, NetProfit, s.Facts[xbrl.Current])
	equity := average(balanceValue(t, EquityParent, s.Facts[xbrl.CurrentEnd]),
		balanceValue(t, EquityParent, s.Facts[xbrl.PriorYearEnd]))
	return divide(annualize(profit, s.months()), equity)
}

func costToIncome(t template, s *Snapshot) *float64 {
	income := add(flowValue(t, NetInterestIncome, s.Facts[xbrl.Current]),
		flowValue(t, OtherOperatingIncome, s.Facts[xbrl.Current]))
	return divide(flowValue(t, OperatingExpense, s.Facts[xbrl.Current]), income)
}

func costOfCredit(t template, s *Snapshot) *float64 {
	loans := average(balanceValue(t, Loans, s.Facts[xbrl.CurrentEnd]), balanceValue(t, Loans, s.Facts[xbrl.PriorYearEnd]))
	return divide(annualize(flowValue(t, Provision, s.Facts[xbrl.Current]), s.months()), loans)
}

func endRatio(num, den string) func(template, *Snapshot) *float64 {
	return func(t template, s *Snapshot) *float64 {
		return divide(balanceValue(t, num, s.Facts[xbrl.CurrentEnd]), balanceValue(t, den, s.Facts[xbrl.CurrentEnd]))
	}
}

func flowRatio(num, den string) func(template, *Snapshot) *float64 {
	return func(t template, s *Snapshot) *float64 {
		return divide(flowValue(t, num, s.Facts[xbrl.Current]), flowValue(t, den, s.Facts[xbrl.Current]))
	}
}

func flowValue(t template, key string, values map[string]float64) *float64 {
	for _, l := range t.flows {
		if l.key == key {
			return eval(l.value, values)
		}
	}
	return nil
}

func balanceValue(t template, key string, values map[string]float64) *float64 {
	for _, l := range t.balances {
		if l.key == key {
			return eval(l.value, values)
		}
	}
	return nil
}

func eval(e expr, values map[string]float64) *float64 {
	if values == nil {
		return nil
	}
	v, ok := e(values)
	if !ok || math.IsNaN(v) || math.IsInf(v, 0) {
		return nil
	}
	return &v
}

func ptr(v float64) *float64 {
	return &v
}

func sub(a, b *float64) *float64 {
	if a == nil || b == nil {
		return nil
	}
	return ptr(*a - *b)
}

func add(a, b *float64) *float64 {
	if a == nil || b == nil {
		return nil
	}
	return ptr(*a + *b)
}

func average(a, b *float64) *float64 {
	switch {
	case a != nil && b != nil:
		return ptr((*a + *b) / 2)
	case a != nil:
		return a
	}
	return b
}

func annualize(v *float64, months int) *float64 {
	if v == nil || months <= 0 {
		return nil
	}
	return ptr(*v * 12 / float64(months))
}

func divide(a, b *float64) *float64 {
	if a == nil || b == nil || *b <= 0 {
		return nil
	}
	return ptr(*a / *b)
}
