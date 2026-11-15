package protocol

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func goldenTime(h Header) time.Time {
	return time.Date(int(h.Date/10000), time.Month(h.Date/100%100), int(h.Date%100), int(h.Time/10000), int(h.Time/100%100),
		int(h.Time%100), 0, time.UTC)
}

func golden(t *testing.T, name string) []byte {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("testdata", "olt", name))
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func goldenPayload(t *testing.T, name string, c *Cipher) (Header, []byte) {
	t.Helper()
	frame := golden(t, name)
	h, err := ParseHeader(frame)
	if err != nil {
		t.Fatalf("%s header: %v", name, err)
	}
	p, err := Payload(frame, h, c)
	if err != nil {
		t.Fatalf("%s payload: %v", name, err)
	}
	return h, p
}

func TestGoldenOrdersFromOLTCode(t *testing.T) {
	want := Order{Status: 1, OrderID: "ORD-GOLD-1", AmendID: "", OrderDate: 20261116, Board: "RG", CustID: "GOLD01",
		Command: 0, StockCode: "BBCA", Price: 9150, OpenVolume: 2500, RemainVolume: 1500, TradedVolume: 1000}
	ecb := mustCipher(t, "ecb", "0123456789ABCDEF", "")
	for name, tc := range map[string]struct {
		cipher *Cipher
		flags  uint16
	}{
		"order_plain.bin":              {nil, 0},
		"order_compressed.bin":         {nil, FlagCompressed},
		"order_compressed_aes_ecb.bin": {ecb, FlagCompressed | FlagEncrypted},
	} {
		t.Run(name, func(t *testing.T) {
			h, p := goldenPayload(t, name, tc.cipher)
			if h.PackageID != PkgNewOrder || h.Flags&(FlagCompressed|FlagEncrypted) != tc.flags {
				t.Fatalf("header %+v", h)
			}
			got, err := DecodeOrder(p)
			if err != nil {
				t.Fatal(err)
			}
			if got != want {
				t.Fatalf("got %+v, want %+v", got, want)
			}
			if cust, err := OrderCustID(p); err != nil || cust != "GOLD01" {
				t.Fatalf("cust %q %v", cust, err)
			}
		})
	}
}

func TestGoldenTradesFromOLTCode(t *testing.T) {
	want := Trade{OrderID: "ORD-GOLD-1", TradeID: "TRD-GOLD-1", TradeDate: 20261116, TradeTime: 93005, Board: "RG",
		CustID: "GOLD01", Command: 1, StockCode: "BBCA", Price: 9175, Volume: 1500}
	aes256 := mustCipher(t, "ecb", "0123456789ABCDEF0123456789ABCDEF", "")
	for name, c := range map[string]*Cipher{
		"trade_plain.bin":      nil,
		"trade_compressed.bin": nil,
		"trade_aes_ecb256.bin": aes256,
	} {
		t.Run(name, func(t *testing.T) {
			h, p := goldenPayload(t, name, c)
			if h.PackageID != PkgTrade {
				t.Fatalf("package id %x", h.PackageID)
			}
			got, err := DecodeTrade(p)
			if err != nil {
				t.Fatal(err)
			}
			if got != want {
				t.Fatalf("got %+v, want %+v", got, want)
			}
		})
	}
}

func TestGoldenLargeCompressedOrder(t *testing.T) {
	_, p := goldenPayload(t, "order_large_compressed.bin", nil)
	got, err := DecodeOrder(p)
	if err != nil {
		t.Fatal(err)
	}
	if got.Status != 2 || got.OrderID != "ORD-GOLD-2" || got.TradedVolume != 100000 || got.RemainVolume != 0 {
		t.Fatalf("got %+v", got)
	}
}

func TestGoldenHeartbeatMatchesOLT(t *testing.T) {
	olt := golden(t, "heartbeat.bin")
	h, err := ParseHeader(olt)
	if err != nil || h.PackageID != PkgHeartbeat || len(olt) != HeaderLength {
		t.Fatalf("olt heartbeat %+v %v", h, err)
	}
	ours := Heartbeat(goldenTime(h))
	if string(ours) != string(olt) {
		t.Fatalf("heartbeat differs:\n ours %x\n olt  %x", ours, olt)
	}
}

func TestGoldenWrongKeyIsDetected(t *testing.T) {
	frame := golden(t, "order_compressed_aes_ecb.bin")
	h, _ := ParseHeader(frame)
	if p, err := Payload(frame, h, mustCipher(t, "ecb", "FEDCBA9876543210", "")); err == nil {
		if _, err := DecodeOrder(p); err == nil {
			t.Fatal("wrong key decoded a valid order")
		}
	}
}
