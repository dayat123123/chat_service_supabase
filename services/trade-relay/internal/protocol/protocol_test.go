package protocol

import (
	"bytes"
	"errors"
	"testing"
	"time"
)

func sampleOrder() Order {
	return Order{Status: 1, OrderID: "ORD1", AmendID: "", OrderDate: 20261116, Board: "RG", CustID: "ACC1",
		Command: 0, StockCode: "BBCA", Price: 9150, OpenVolume: 2500, RemainVolume: 1500, TradedVolume: 1000}
}

func sampleTrade() Trade {
	return Trade{OrderID: "ORD1", TradeID: "TRD1", TradeDate: 20261116, TradeTime: 100523, Board: "RG",
		CustID: "ACC1", Command: 1, StockCode: "BBCA", Price: 9150, Volume: 500}
}

func mustCipher(t *testing.T, mode, key, iv string) *Cipher {
	t.Helper()
	c, err := NewCipher(mode, key, iv)
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func roundTrip(t *testing.T, id uint16, payload []byte, opt BuildOptions, c *Cipher) []byte {
	t.Helper()
	frame := Build(id, payload, opt)
	h, err := ParseHeader(frame)
	if err != nil {
		t.Fatalf("parse header: %v", err)
	}
	if h.PackageID != id {
		t.Fatalf("package id = %x, want %x", h.PackageID, id)
	}
	out, err := Payload(frame, h, c)
	if err != nil {
		t.Fatalf("payload: %v", err)
	}
	return out
}

func TestOrderRoundTrip(t *testing.T) {
	want := sampleOrder()
	payload := EncodeOrder(want)
	for name, opt := range map[string]BuildOptions{
		"plain":             {},
		"compressed":        {Compress: true},
		"encrypted ecb":     {Cipher: mustCipher(t, "ecb", "ABCDEFGHIJKLMNOP", "")},
		"compressed+cbc":    {Compress: true, Cipher: mustCipher(t, "cbc", "ABCDEFGHIJKLMNOPQRSTUVWX", "0123456789abcdef")},
		"compressed+ecb256": {Compress: true, Cipher: mustCipher(t, "ecb", "ABCDEFGHIJKLMNOPQRSTUVWXYZ012345", "")},
	} {
		t.Run(name, func(t *testing.T) {
			out := roundTrip(t, PkgNewOrder, payload, opt, opt.Cipher)
			if !bytes.Equal(out, payload) {
				t.Fatalf("payload mismatch")
			}
			got, err := DecodeOrder(out)
			if err != nil {
				t.Fatal(err)
			}
			if got != want {
				t.Fatalf("got %+v, want %+v", got, want)
			}
			cust, err := OrderCustID(out)
			if err != nil || cust != "ACC1" {
				t.Fatalf("cust = %q, %v", cust, err)
			}
		})
	}
}

func TestTradeRoundTrip(t *testing.T) {
	want := sampleTrade()
	out := roundTrip(t, PkgTrade, EncodeTrade(want), BuildOptions{Compress: true}, nil)
	got, err := DecodeTrade(out)
	if err != nil {
		t.Fatal(err)
	}
	if got != want {
		t.Fatalf("got %+v, want %+v", got, want)
	}
	cust, err := TradeCustID(out)
	if err != nil || cust != "ACC1" {
		t.Fatalf("cust = %q, %v", cust, err)
	}
}

func TestEncryptedWithoutKey(t *testing.T) {
	frame := Build(PkgTrade, EncodeTrade(sampleTrade()), BuildOptions{Cipher: mustCipher(t, "ecb", "ABCDEFGHIJKLMNOP", "")})
	h, _ := ParseHeader(frame)
	if _, err := Payload(frame, h, nil); !errors.Is(err, ErrNoKey) {
		t.Fatalf("err = %v, want ErrNoKey", err)
	}
}

func TestWrongKeyIsRejectedByDecoder(t *testing.T) {
	frame := Build(PkgTrade, EncodeTrade(sampleTrade()), BuildOptions{Cipher: mustCipher(t, "ecb", "ABCDEFGHIJKLMNOP", "")})
	h, _ := ParseHeader(frame)
	out, err := Payload(frame, h, mustCipher(t, "ecb", "PONMLKJIHGFEDCBA", ""))
	if err != nil {
		return
	}
	if got, err := DecodeTrade(out); err == nil && got == sampleTrade() {
		t.Fatal("wrong key produced the original trade")
	}
}

func TestHeaderValidation(t *testing.T) {
	if _, err := ParseHeader(make([]byte, 10)); !errors.Is(err, ErrShort) {
		t.Fatalf("short: %v", err)
	}
	bad := Build(PkgTrade, nil, BuildOptions{})
	bad[0] ^= 0xff
	if _, err := ParseHeader(bad); !errors.Is(err, ErrSignature) {
		t.Fatalf("signature: %v", err)
	}
	if _, err := ParseHeader(make([]byte, MaxPacket+1)); !errors.Is(err, ErrTooLarge) {
		t.Fatalf("too large: %v", err)
	}
	if _, ok := PeekPackageID(bad); ok {
		t.Fatal("peek accepted a bad signature")
	}
}

func TestTruncatedPayloadsFail(t *testing.T) {
	payload := EncodeOrder(sampleOrder())
	for n := 0; n < len(payload)-8*3-4; n++ {
		if _, err := DecodeOrder(payload[:n]); err == nil {
			t.Fatalf("decoding %d of %d bytes succeeded", n, len(payload))
		}
	}
	trade := EncodeTrade(sampleTrade())
	for n := 0; n < len(trade)-3; n++ {
		if _, err := DecodeTrade(trade[:n]); err == nil {
			t.Fatalf("decoding %d of %d trade bytes succeeded", n, len(trade))
		}
	}
}

func TestCompressionBombRejected(t *testing.T) {
	frame := Build(PkgTrade, bytes.Repeat([]byte{'A'}, 1000), BuildOptions{Compress: true})
	frame[HeaderLength] = 0x7f
	h, _ := ParseHeader(frame)
	if _, err := Payload(frame, h, nil); err == nil {
		t.Fatal("inconsistent original length accepted")
	}
}

func TestHeartbeat(t *testing.T) {
	at := time.Date(2026, 11, 16, 9, 30, 5, 0, time.UTC)
	hb := Heartbeat(at)
	h, err := ParseHeader(hb)
	if err != nil || h.PackageID != PkgHeartbeat || h.Date != 20261116 || h.Time != 93005 || len(hb) != HeaderLength {
		t.Fatalf("heartbeat %+v %v", h, err)
	}
}

func TestStringLimit(t *testing.T) {
	w := &Writer{}
	w.U16(MaxString + 1)
	r := NewReader(append(w.Bytes(), make([]byte, MaxString+1)...))
	r.Str()
	if !errors.Is(r.Err(), ErrString) {
		t.Fatalf("err = %v", r.Err())
	}
}

func FuzzFrame(f *testing.F) {
	c, _ := NewCipher("ecb", "ABCDEFGHIJKLMNOP", "")
	f.Add(Build(PkgNewOrder, EncodeOrder(sampleOrder()), BuildOptions{}))
	f.Add(Build(PkgTrade, EncodeTrade(sampleTrade()), BuildOptions{Compress: true}))
	f.Add(Build(PkgTrade, EncodeTrade(sampleTrade()), BuildOptions{Compress: true, Cipher: c}))
	f.Add([]byte{})
	f.Fuzz(func(t *testing.T, frame []byte) {
		h, err := ParseHeader(frame)
		if err != nil {
			return
		}
		payload, err := Payload(frame, h, c)
		if err != nil {
			return
		}
		_, _ = OrderCustID(payload)
		_, _ = TradeCustID(payload)
		_, _ = DecodeOrder(payload)
		_, _ = DecodeTrade(payload)
	})
}
