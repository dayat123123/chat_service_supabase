package customers

import (
	"fmt"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"olt-social/dummy-olt/internal/users"
)

type Account struct {
	Bank   string `json:"bank"`
	Number string `json:"number"`
}

type Profile struct {
	UserID            string    `json:"user_id"`
	Name              string    `json:"name"`
	ClientCode        string    `json:"client_code"`
	SID               string    `json:"sid"`
	NIK               string    `json:"nik"`
	Email             string    `json:"email"`
	Phone             string    `json:"phone"`
	BirthDate         string    `json:"birth_date"`
	Address           string    `json:"address"`
	AccountStatus     string    `json:"account_status"`
	KYCStatus         string    `json:"kyc_status"`
	JoinedAt          time.Time `json:"joined_at"`
	Segment           string    `json:"segment"`
	Language          string    `json:"language"`
	RDN               Account   `json:"rdn"`
	WithdrawalAccount Account   `json:"withdrawal_account"`
}

type Order struct {
	OrderID      string    `json:"order_id"`
	Time         time.Time `json:"time"`
	Code         string    `json:"code"`
	Side         string    `json:"side"`
	Type         string    `json:"type"`
	Price        int64     `json:"price"`
	Lot          int64     `json:"lot"`
	FilledLot    int64     `json:"filled_lot"`
	Status       string    `json:"status"`
	RejectCode   string    `json:"reject_code,omitempty"`
	RejectReason string    `json:"reject_reason,omitempty"`
	Channel      string    `json:"channel"`
	Session      string    `json:"session"`
}

type OrderEvent struct {
	Time   time.Time `json:"time"`
	Status string    `json:"status"`
	Note   string    `json:"note,omitempty"`
}

type Execution struct {
	Time  time.Time `json:"time"`
	Price int64     `json:"price"`
	Lot   int64     `json:"lot"`
}

type OrderDetail struct {
	Order
	History    []OrderEvent `json:"history"`
	Executions []Execution  `json:"executions"`
}

type CashTransaction struct {
	ID            string    `json:"id"`
	Time          time.Time `json:"time"`
	Kind          string    `json:"kind"`
	Amount        int64     `json:"amount"`
	Bank          string    `json:"bank"`
	Status        string    `json:"status"`
	BankRef       string    `json:"bank_ref"`
	FailureReason string    `json:"failure_reason,omitempty"`
}

type Holding struct {
	Code     string `json:"code"`
	Lot      int64  `json:"lot"`
	AvgPrice int64  `json:"avg_price"`
}

type Portfolio struct {
	Cash struct {
		Available int64 `json:"available"`
		T1        int64 `json:"t1"`
		T2        int64 `json:"t2"`
	} `json:"cash"`
	Holdings []Holding `json:"holdings"`
}

type Session struct {
	ID         string    `json:"id"`
	Device     string    `json:"device"`
	Platform   string    `json:"platform"`
	AppVersion string    `json:"app_version"`
	IP         string    `json:"ip"`
	LastActive time.Time `json:"last_active"`
}

type Login struct {
	Time     time.Time `json:"time"`
	Device   string    `json:"device"`
	Platform string    `json:"platform"`
	IP       string    `json:"ip"`
	Result   string    `json:"result"`
}

type Security struct {
	TradingLocked      bool      `json:"trading_locked"`
	AccountLocked      bool      `json:"account_locked"`
	LockReason         string    `json:"lock_reason,omitempty"`
	FailedLogins24h    int       `json:"failed_logins_24h"`
	LastPasswordChange time.Time `json:"last_password_change"`
	OTPEnabled         bool      `json:"otp_enabled"`
	Suspicious         bool      `json:"suspicious"`
}

type Filter struct {
	From     time.Time
	To       time.Time
	Statuses []string
	Code     string
	Cursor   string
	Limit    int
}

type customer struct {
	profile   Profile
	orders    []OrderDetail
	cash      []CashTransaction
	portfolio Portfolio
	sessions  []Session
	logins    []Login
	security  Security
}

type Store struct {
	mu        sync.Mutex
	customers map[string]*customer
	secured   map[string]map[string]string
}

var stocks = []struct {
	code  string
	price int64
}{
	{"BBCA", 9250}, {"BBRI", 4250}, {"TLKM", 2890}, {"GOTO", 68}, {"ASII", 5025}, {"BMRI", 5900}, {"ANTM", 1500},
}

var orderStatuses = []string{"filled", "rejected", "open", "partial", "cancelled", "filled", "rejected", "filled", "expired", "filled"}

func NewStore(dir *users.Directory, now time.Time) *Store {
	s := &Store{customers: map[string]*customer{}, secured: map[string]map[string]string{}}
	base := now.UTC().Truncate(time.Minute)
	for _, u := range dir.All() {
		s.customers[strconv.FormatInt(u.ID, 10)] = build(u, base)
	}
	return s
}

func build(u users.User, now time.Time) *customer {
	n := u.ID
	id := strconv.FormatInt(n, 10)
	c := &customer{profile: Profile{
		UserID:            id,
		Name:              u.FullName,
		ClientCode:        fmt.Sprintf("C%07d", n),
		SID:               fmt.Sprintf("IDD%010d", n*7919),
		NIK:               fmt.Sprintf("3174%012d", n*91373),
		Email:             u.Email,
		Phone:             fmt.Sprintf("0812%08d", n*4567),
		BirthDate:         fmt.Sprintf("19%02d-%02d-%02d", 80+n%15, 1+n%12, 1+n%28),
		Address:           fmt.Sprintf("Jl. Melati No. %d, Jakarta Selatan", n%90+1),
		AccountStatus:     "active",
		KYCStatus:         "verified",
		JoinedAt:          time.Date(2020+int(n%5), time.Month(1+n%12), 1, 0, 0, 0, 0, time.UTC),
		Segment:           "regular",
		Language:          "id",
		RDN:               Account{Bank: "BCA", Number: fmt.Sprintf("88%08d", n*31)},
		WithdrawalAccount: Account{Bank: "Mandiri", Number: fmt.Sprintf("137%010d", n*17)},
	}}
	if u.Status == users.StatusSuspended {
		c.profile.AccountStatus = "suspended"
	}

	for i := 0; i < len(orderStatuses); i++ {
		stock := stocks[(int(n)+i)%len(stocks)]
		placed := now.Add(-time.Duration(i)*50*time.Hour - time.Duration(i)*7*time.Minute)
		o := Order{
			OrderID: fmt.Sprintf("O-%d%03d", n, i+1),
			Time:    placed,
			Code:    stock.code,
			Side:    choose(i%3 != 2, "buy", "sell"),
			Type:    choose(i%5 == 4, "market", "limit"),
			Price:   stock.price + int64(i%3-1)*tick(stock.price),
			Lot:     1 + (n*7+int64(i)*3)%50,
			Status:  orderStatuses[i],
			Channel: choose(i%2 == 0, "android", "windows"),
			Session: strconv.Itoa(1 + i%2),
		}
		detail := OrderDetail{Order: o, History: []OrderEvent{{Time: placed, Status: "open", Note: "Order diterima bursa"}}}
		switch o.Status {
		case "filled":
			detail.FilledLot = o.Lot
			detail.Executions = []Execution{{Time: placed.Add(2 * time.Minute), Price: o.Price, Lot: o.Lot}}
			detail.History = append(detail.History, OrderEvent{Time: placed.Add(2 * time.Minute), Status: "filled"})
		case "partial":
			detail.FilledLot = o.Lot / 2
			detail.Executions = []Execution{{Time: placed.Add(5 * time.Minute), Price: o.Price, Lot: o.Lot / 2}}
			detail.History = append(detail.History, OrderEvent{Time: placed.Add(5 * time.Minute), Status: "partial"})
		case "rejected":
			detail.RejectCode, detail.RejectReason = "E-1021", "Saldo tidak cukup"
			if o.Side == "sell" {
				detail.RejectCode, detail.RejectReason = "E-2003", "Harga di luar batas auto rejection"
			}
			detail.History = []OrderEvent{{Time: placed, Status: "rejected", Note: detail.RejectReason}}
		case "cancelled":
			detail.History = append(detail.History, OrderEvent{Time: placed.Add(30 * time.Minute), Status: "cancelled", Note: "Dibatalkan nasabah"})
		case "expired":
			detail.History = append(detail.History, OrderEvent{Time: placed.Add(8 * time.Hour), Status: "expired", Note: "Sesi perdagangan berakhir"})
		}
		c.orders = append(c.orders, detail)
	}

	cash := []CashTransaction{
		{Kind: "deposit", Amount: 5_000_000, Status: "processing", Bank: "BCA"},
		{Kind: "deposit", Amount: 2_000_000, Status: "success", Bank: "BCA"},
		{Kind: "withdrawal", Amount: 1_500_000, Status: "failed", Bank: "Mandiri", FailureReason: "Rekening tujuan tidak aktif"},
		{Kind: "withdrawal", Amount: 750_000, Status: "success", Bank: "Mandiri"},
		{Kind: "cash_dividend", Amount: 125_400, Status: "success", Bank: "BCA"},
		{Kind: "fee", Amount: 7_500, Status: "success", Bank: "BCA"},
	}
	for i := range cash {
		cash[i].ID = fmt.Sprintf("T-%d%03d", n, i+1)
		cash[i].Time = now.Add(-time.Duration(i)*61*time.Hour - 3*time.Hour)
		cash[i].BankRef = fmt.Sprintf("REF%d%04d", n, i+1)
	}
	c.cash = cash

	c.portfolio.Cash.Available = 12_500_000 + n*1000
	c.portfolio.Cash.T1 = 2_300_000
	c.portfolio.Cash.T2 = -850_000
	for i := 0; i < 3; i++ {
		stock := stocks[(int(n)+i*2)%len(stocks)]
		c.portfolio.Holdings = append(c.portfolio.Holdings,
			Holding{Code: stock.code, Lot: 5 + (n+int64(i)*11)%40, AvgPrice: stock.price - tick(stock.price)*int64(i+1)})
	}

	c.sessions = []Session{
		{ID: id + "-android", Device: "Pixel 8", Platform: "android", AppVersion: "3.2.1", IP: "182.1.20.33", LastActive: now.Add(-10 * time.Minute)},
		{ID: id + "-windows", Device: "Windows 11", Platform: "windows", AppVersion: "3.2.0", IP: "36.84.12.7", LastActive: now.Add(-26 * time.Hour)},
	}
	c.logins = []Login{
		{Time: now.Add(-10 * time.Minute), Device: "Pixel 8", Platform: "android", IP: "182.1.20.33", Result: "success"},
		{Time: now.Add(-26 * time.Hour), Device: "Windows 11", Platform: "windows", IP: "36.84.12.7", Result: "success"},
		{Time: now.Add(-49 * time.Hour), Device: "Unknown", Platform: "android", IP: "103.10.66.2", Result: "failed_password"},
	}
	c.security = Security{OTPEnabled: true, LastPasswordChange: now.Add(-90 * 24 * time.Hour)}
	if n == 1004 {
		c.security.FailedLogins24h, c.security.Suspicious = 3, true
	}
	return c
}

func tick(price int64) int64 {
	switch {
	case price < 200:
		return 1
	case price < 500:
		return 2
	case price < 2000:
		return 5
	case price < 5000:
		return 10
	default:
		return 25
	}
}

func (s *Store) get(userID string) (*customer, bool) {
	c, ok := s.customers[strings.TrimSpace(userID)]
	return c, ok
}

func (s *Store) Profile(userID string) (Profile, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	c, ok := s.get(userID)
	if !ok {
		return Profile{}, false
	}
	return mask(c.profile), true
}

func (s *Store) Reveal(userID, field string) (string, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	c, ok := s.get(userID)
	if !ok {
		return "", false
	}
	p := c.profile
	values := map[string]string{
		"nik": p.NIK, "phone": p.Phone, "email": p.Email, "client_code": p.ClientCode, "sid": p.SID,
		"address": p.Address, "birth_date": p.BirthDate, "rdn_number": p.RDN.Number, "bank_account": p.WithdrawalAccount.Number,
	}
	v, ok := values[field]
	return v, ok
}

func (s *Store) Orders(userID string, f Filter) ([]Order, string, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	c, ok := s.get(userID)
	if !ok {
		return nil, "", false
	}
	var matched []Order
	for _, o := range c.orders {
		if inPeriod(o.Time, f) && (len(f.Statuses) == 0 || slices.Contains(f.Statuses, o.Status)) &&
			(f.Code == "" || o.Code == f.Code) {
			matched = append(matched, o.Order)
		}
	}
	page, next := paginate(matched, f)
	return page, next, true
}

func (s *Store) Order(userID, orderID string) (OrderDetail, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	c, ok := s.get(userID)
	if !ok {
		return OrderDetail{}, false
	}
	for _, o := range c.orders {
		if o.OrderID == orderID {
			return o, true
		}
	}
	return OrderDetail{}, false
}

func (s *Store) CashTransactions(userID string, f Filter) ([]CashTransaction, string, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	c, ok := s.get(userID)
	if !ok {
		return nil, "", false
	}
	var matched []CashTransaction
	for _, t := range c.cash {
		if inPeriod(t.Time, f) {
			matched = append(matched, t)
		}
	}
	page, next := paginate(matched, f)
	return page, next, true
}

func (s *Store) CashTransaction(userID, id string) (CashTransaction, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	c, ok := s.get(userID)
	if !ok {
		return CashTransaction{}, false
	}
	for _, t := range c.cash {
		if t.ID == id {
			return t, true
		}
	}
	return CashTransaction{}, false
}

func (s *Store) Portfolio(userID string) (Portfolio, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	c, ok := s.get(userID)
	if !ok {
		return Portfolio{}, false
	}
	p := c.portfolio
	p.Holdings = slices.Clone(p.Holdings)
	return p, true
}

func (s *Store) Sessions(userID string) ([]Session, []Login, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	c, ok := s.get(userID)
	if !ok {
		return nil, nil, false
	}
	return slices.Clone(c.sessions), slices.Clone(c.logins), true
}

func (s *Store) Security(userID string) (Security, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	c, ok := s.get(userID)
	if !ok {
		return Security{}, false
	}
	return c.security, true
}

func (s *Store) SecureAccount(userID string, actions []string, key string) (map[string]string, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	c, ok := s.get(userID)
	if !ok {
		return nil, false
	}
	if previous, ok := s.secured[key]; ok && key != "" {
		return previous, true
	}
	results := map[string]string{}
	for _, action := range actions {
		switch action {
		case "logout_all":
			c.sessions = nil
			results[action] = "OK"
		case "lock_trading":
			c.security.TradingLocked = true
			c.security.LockReason = "customer_emergency"
			results[action] = "OK"
		case "lock_account":
			c.security.AccountLocked = true
			c.security.LockReason = "customer_emergency"
			results[action] = "OK"
		default:
			results[action] = "UNSUPPORTED"
		}
	}
	if key != "" {
		s.secured[key] = results
	}
	return results, true
}

func inPeriod(t time.Time, f Filter) bool {
	return (f.From.IsZero() || !t.Before(f.From)) && (f.To.IsZero() || t.Before(f.To))
}

func paginate[T any](items []T, f Filter) ([]T, string) {
	limit := f.Limit
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	offset, err := strconv.Atoi(f.Cursor)
	if err != nil || offset < 0 || offset > len(items) {
		offset = 0
	}
	end := min(offset+limit, len(items))
	next := ""
	if end < len(items) {
		next = strconv.Itoa(end)
	}
	return slices.Clone(items[offset:end]), next
}

func mask(p Profile) Profile {
	p.NIK = keep(p.NIK, 4, 4)
	p.Phone = keep(p.Phone, 4, 3)
	p.ClientCode = keep(p.ClientCode, 0, 4)
	p.SID = keep(p.SID, 3, 3)
	if at := strings.LastIndex(p.Email, "@"); at > 2 {
		p.Email = p.Email[:2] + "***" + p.Email[at:]
	}
	if i := strings.LastIndex(p.Address, ","); i >= 0 {
		p.Address = "***" + p.Address[i:]
	}
	if len(p.BirthDate) >= 4 {
		p.BirthDate = p.BirthDate[:4] + "-**-**"
	}
	p.RDN.Number = keep(p.RDN.Number, 0, 4)
	p.WithdrawalAccount.Number = keep(p.WithdrawalAccount.Number, 0, 4)
	return p
}

func keep(v string, head, tail int) string {
	if len(v) <= head+tail {
		return strings.Repeat("*", len(v))
	}
	return v[:head] + strings.Repeat("*", len(v)-head-tail) + v[len(v)-tail:]
}

func choose(cond bool, yes, no string) string {
	if cond {
		return yes
	}
	return no
}
