package events

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strconv"
	"strings"
	"time"

	"olt-social/trade-relay/internal/protocol"
)

var wib = time.FixedZone("WIB", 7*3600)

var statuses = map[uint8]string{
	0: "rejected",
	1: "open",
	2: "matched",
	3: "amending",
	4: "withdrawing",
	5: "withdrawn",
	6: "amended",
}

type Event map[string]any

func hash(parts ...string) string {
	sum := sha256.Sum256([]byte(strings.Join(parts, "|")))
	return hex.EncodeToString(sum[:])
}

func NormalizeCust(c string) string {
	return strings.ToUpper(strings.TrimSpace(c))
}

func ValidCust(c string) bool {
	if len(c) == 0 || len(c) > 32 {
		return false
	}
	for i := 0; i < len(c); i++ {
		ch := c[i]
		if !(ch >= 'A' && ch <= 'Z' || ch >= '0' && ch <= '9' || ch == '.' || ch == '_' || ch == '-') {
			return false
		}
	}
	return true
}

func validStock(s string) bool {
	if len(s) == 0 || len(s) > 12 {
		return false
	}
	for i := 0; i < len(s); i++ {
		ch := s[i]
		if !(ch >= 'A' && ch <= 'Z' || ch >= '0' && ch <= '9' || ch == '-') {
			return false
		}
	}
	return true
}

func validBoard(s string) bool {
	if len(s) == 0 || len(s) > 6 {
		return false
	}
	for i := 0; i < len(s); i++ {
		if s[i] < 'A' || s[i] > 'Z' {
			return false
		}
	}
	return true
}

func side(command uint8) string {
	if command%2 == 0 {
		return "buy"
	}
	return "sell"
}

func OrderRef(orderID, cust string) string {
	return hash("order", orderID, cust)
}

func date(v uint32) (time.Time, bool) {
	y, m, d := int(v/10000), int(v/100%100), int(v%100)
	if y < 2000 || y > 2200 || m < 1 || m > 12 || d < 1 || d > 31 {
		return time.Time{}, false
	}
	t := time.Date(y, time.Month(m), d, 0, 0, 0, 0, wib)
	if t.Day() != d {
		return time.Time{}, false
	}
	return t, true
}

func clock(v uint32) (int, int, int, bool) {
	h, mi, s := int(v/10000), int(v/100%100), int(v%100)
	if h > 23 || mi > 59 || s > 59 {
		return 0, 0, 0, false
	}
	return h, mi, s, true
}

func FromOrder(o protocol.Order) (Event, error) {
	cust := NormalizeCust(o.CustID)
	stock := strings.ToUpper(o.StockCode)
	board := strings.ToUpper(o.Board)
	status, ok := statuses[o.Status]
	switch {
	case !ValidCust(cust):
		return nil, fmt.Errorf("invalid cust id")
	case !ok:
		return nil, fmt.Errorf("unknown order status %d", o.Status)
	case o.OrderID == "":
		return nil, fmt.Errorf("empty order id")
	case !validStock(stock):
		return nil, fmt.Errorf("invalid stock code")
	case !validBoard(board):
		return nil, fmt.Errorf("invalid board")
	case o.OpenVolume > 9e15 || o.RemainVolume > 9e15 || o.TradedVolume > 9e15 || o.Price > 2147483647:
		return nil, fmt.Errorf("value out of range")
	}
	e := Event{
		"kind":          "order",
		"cust_id":       cust,
		"order_ref":     OrderRef(o.OrderID, cust),
		"seq":           hash("seq", o.OrderID, strconv.Itoa(int(o.Status)), strconv.FormatUint(uint64(o.Price), 10), strconv.FormatUint(o.RemainVolume, 10), strconv.FormatUint(o.TradedVolume, 10)),
		"status":        status,
		"stock":         stock,
		"side":          side(o.Command),
		"board":         board,
		"order_shares":  o.OpenVolume,
		"remain_shares": o.RemainVolume,
		"traded_shares": o.TradedVolume,
		"order_price":   o.Price,
	}
	if d, ok := date(o.OrderDate); ok {
		e["order_date"] = d.Format("2006-01-02")
	}
	return e, nil
}

func FromTrade(t protocol.Trade) (Event, error) {
	cust := NormalizeCust(t.CustID)
	stock := strings.ToUpper(t.StockCode)
	board := strings.ToUpper(t.Board)
	d, okDate := date(t.TradeDate)
	h, mi, s, okTime := clock(t.TradeTime)
	switch {
	case !ValidCust(cust):
		return nil, fmt.Errorf("invalid cust id")
	case t.OrderID == "" || t.TradeID == "":
		return nil, fmt.Errorf("empty order or trade id")
	case !validStock(stock):
		return nil, fmt.Errorf("invalid stock code")
	case !validBoard(board):
		return nil, fmt.Errorf("invalid board")
	case !okDate || !okTime:
		return nil, fmt.Errorf("invalid trade time")
	case t.Volume == 0 || t.Volume > 9e15 || t.Price > 2147483647:
		return nil, fmt.Errorf("value out of range")
	}
	at := time.Date(d.Year(), d.Month(), d.Day(), h, mi, s, 0, wib)
	return Event{
		"kind":      "fill",
		"cust_id":   cust,
		"order_ref": OrderRef(t.OrderID, cust),
		"key":       hash("trade", strconv.FormatUint(uint64(t.TradeDate), 10), t.TradeID, cust, strconv.Itoa(int(t.Command))),
		"stock":     stock,
		"side":      side(t.Command),
		"board":     board,
		"traded_at": at.Format(time.RFC3339),
		"shares":    t.Volume,
		"price":     t.Price,
	}, nil
}
