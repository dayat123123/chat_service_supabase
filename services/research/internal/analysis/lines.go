package analysis

type expr func(values map[string]float64) (float64, bool)

func concept(name string) expr {
	return func(values map[string]float64) (float64, bool) {
		v, ok := values[name]
		return v, ok
	}
}

func total(names ...string) expr {
	return func(values map[string]float64) (float64, bool) {
		var sum float64
		found := false
		for _, name := range names {
			if v, ok := values[name]; ok {
				sum += v
				found = true
			}
		}
		return sum, found
	}
}

func minus(a, b expr) expr {
	return func(values map[string]float64) (float64, bool) {
		x, okA := a(values)
		y, okB := b(values)
		return x - y, okA && okB
	}
}

func negate(a expr) expr {
	return func(values map[string]float64) (float64, bool) {
		v, ok := a(values)
		return -v, ok
	}
}

func either(options ...expr) expr {
	return func(values map[string]float64) (float64, bool) {
		for _, option := range options {
			if v, ok := option(values); ok {
				return v, true
			}
		}
		return 0, false
	}
}

const (
	NetProfit            = "net_profit"
	EPS                  = "eps"
	NetInterestIncome    = "net_interest_income"
	OtherOperatingIncome = "other_operating_income"
	Provision            = "provision"
	OperatingExpense     = "operating_expense"
	ProfitBeforeTax      = "profit_before_tax"
	Revenue              = "revenue"
	GrossProfit          = "gross_profit"
	OperatingCashFlow    = "operating_cash_flow"

	Loans              = "loans"
	Deposits           = "deposits"
	CASA               = "casa"
	LoanAllowance      = "loan_allowance"
	Assets             = "assets"
	Liabilities        = "liabilities"
	EquityParent       = "equity_parent"
	EquityTotal        = "equity_total"
	CurrentAssets      = "current_assets"
	CurrentLiabilities = "current_liabilities"

	ROE                = "roe"
	CostToIncome       = "cost_to_income"
	LDR                = "ldr"
	CASARatio          = "casa_ratio"
	LoanAllowanceRatio = "loan_allowance_ratio"
	CostOfCredit       = "cost_of_credit"
	GrossMargin        = "gross_margin"
	NetMargin          = "net_margin"
	DER                = "der"
	CurrentRatio       = "current_ratio"
)

type line struct {
	key   string
	value expr
}

var (
	netProfit = line{NetProfit, either(concept("ProfitLossAttributableToParentEntity"), concept("ProfitLoss"))}
	eps       = line{EPS, either(concept("BasicEarningsLossPerShareFromContinuingOperations"),
		concept("BasicEarningsLossPerShare"))}
	assets       = line{Assets, concept("Assets")}
	equityParent = line{EquityParent, either(concept("EquityAttributableToEquityOwnersOfParentEntity"), concept("Equity"))}
)

type template struct {
	name     string
	flows    []line
	balances []line
	core     []string
}

var templates = map[string]template{
	"bank": {
		name: "bank",
		flows: []line{
			netProfit, eps,
			{NetInterestIncome, minus(concept("InterestIncome"), concept("InterestExpenses"))},
			{OtherOperatingIncome, concept("OtherOperatingIncome")},
			{Provision, negate(concept("RecoveryOfImpairmentLossesOfFinancialAssets"))},
			{OperatingExpense, total("GeneralAndAdministrativeExpenses", "OtherOperatingExpenses")},
			{ProfitBeforeTax, concept("ProfitLossBeforeIncomeTax")},
		},
		balances: []line{
			{Loans, total("LoansThirdParties", "LoansRelatedParties")},
			{Deposits, total("CurrentAccounts", "SavingsDeposits", "TimeDeposits")},
			{CASA, total("CurrentAccounts", "SavingsDeposits")},
			{LoanAllowance, concept("AllowanceForImpairmentLossesForLoans")},
			assets, equityParent,
		},
		core: []string{NetProfit, NetInterestIncome, Loans, Deposits, EquityParent},
	},
	"general": {
		name: "general",
		flows: []line{
			netProfit, eps,
			{Revenue, concept("SalesAndRevenue")},
			{GrossProfit, concept("GrossProfit")},
			{ProfitBeforeTax, concept("ProfitLossBeforeIncomeTax")},
			{OperatingCashFlow, concept("NetCashFlowsReceivedFromUsedInOperatingActivities")},
		},
		balances: []line{
			assets,
			{Liabilities, concept("Liabilities")},
			equityParent,
			{EquityTotal, concept("Equity")},
			{CurrentAssets, concept("CurrentAssets")},
			{CurrentLiabilities, concept("CurrentLiabilities")},
		},
		core: []string{NetProfit, Revenue, Assets, EquityParent},
	},
	"basic": {
		name:     "basic",
		flows:    []line{netProfit, eps, {ProfitBeforeTax, concept("ProfitLossBeforeIncomeTax")}},
		balances: []line{assets, equityParent},
		core:     []string{NetProfit, Assets},
	},
}
