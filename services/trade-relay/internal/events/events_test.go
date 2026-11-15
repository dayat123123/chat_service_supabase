package events

import (
	"testing"

	"olt-social/trade-relay/internal/protocol"
)

func TestFromOrder(t *testing.T) {
	e, err := FromOrder(protocol.Order{Status: 2, OrderID: "O1", OrderDate: 20261116, Board: "rg", CustID: " acc1 ",
		Command: 1, StockCode: "bbca", Price: 9150, OpenVolume: 100, RemainVolume: 0, TradedVolume: 100})
	if err != nil {
		t.Fatal(err)
	}
	checks := map[string]any{"status": "matched", "side": "sell", "cust_id": "ACC1", "stock": "BBCA", "board": "RG",
		"order_date": "2026-11-16", "kind": "order"}
	for k, v := range checks {
		if e[k] != v {
			t.Fatalf("%s = %v, want %v", k, e[k], v)
		}
	}
	if e["order_ref"] != OrderRef("O1", "ACC1") || len(e["seq"].(string)) != 64 {
		t.Fatalf("bad refs %v %v", e["order_ref"], e["seq"])
	}
}

func TestOrderSeqChangesWithState(t *testing.T) {
	base := protocol.Order{Status: 1, OrderID: "O1", OrderDate: 20261116, Board: "RG", CustID: "A1", StockCode: "BBCA",
		Price: 100, OpenVolume: 100, RemainVolume: 100}
	a, _ := FromOrder(base)
	base.TradedVolume, base.RemainVolume = 50, 50
	b, _ := FromOrder(base)
	if a["seq"] == b["seq"] || a["order_ref"] != b["order_ref"] {
		t.Fatal("seq must change while order_ref stays")
	}
}

func TestFromTrade(t *testing.T) {
	e, err := FromTrade(protocol.Trade{OrderID: "O1", TradeID: "T1", TradeDate: 20261116, TradeTime: 93005, Board: "RG",
		CustID: "A1", Command: 0, StockCode: "BBCA", Price: 9150, Volume: 500})
	if err != nil {
		t.Fatal(err)
	}
	if e["traded_at"] != "2026-11-16T09:30:05+07:00" || e["side"] != "buy" || e["shares"] != uint64(500) {
		t.Fatalf("unexpected %v", e)
	}
	other, _ := FromTrade(protocol.Trade{OrderID: "O1", TradeID: "T1", TradeDate: 20261116, TradeTime: 93005,
		Board: "RG", CustID: "B1", Command: 1, StockCode: "BBCA", Price: 9150, Volume: 500})
	if other["key"] == e["key"] {
		t.Fatal("both sides of a trade must have different keys")
	}
}

func TestInvalidValues(t *testing.T) {
	cases := []protocol.Trade{
		{OrderID: "O1", TradeID: "T1", TradeDate: 20261316, TradeTime: 93005, Board: "RG", CustID: "A1", StockCode: "BBCA", Volume: 1},
		{OrderID: "O1", TradeID: "T1", TradeDate: 20261116, TradeTime: 256000, Board: "RG", CustID: "A1", StockCode: "BBCA", Volume: 1},
		{OrderID: "O1", TradeID: "T1", TradeDate: 20261116, TradeTime: 93005, Board: "RG", CustID: "A 1", StockCode: "BBCA", Volume: 1},
		{OrderID: "O1", TradeID: "T1", TradeDate: 20261116, TradeTime: 93005, Board: "RG", CustID: "A1", StockCode: "BB$A", Volume: 1},
		{OrderID: "O1", TradeID: "T1", TradeDate: 20261116, TradeTime: 93005, Board: "RG", CustID: "A1", StockCode: "BBCA", Volume: 0},
		{OrderID: "", TradeID: "T1", TradeDate: 20261116, TradeTime: 93005, Board: "RG", CustID: "A1", StockCode: "BBCA", Volume: 1},
	}
	for i, c := range cases {
		if _, err := FromTrade(c); err == nil {
			t.Fatalf("case %d accepted", i)
		}
	}
	if _, err := FromOrder(protocol.Order{Status: 9, OrderID: "O1", Board: "RG", CustID: "A1", StockCode: "BBCA"}); err == nil {
		t.Fatal("unknown status accepted")
	}
}
