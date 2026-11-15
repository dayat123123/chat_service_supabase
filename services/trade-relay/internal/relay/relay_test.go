package relay

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"sync"
	"testing"
	"time"

	"olt-social/trade-relay/internal/events"
	"olt-social/trade-relay/internal/protocol"
	"olt-social/trade-relay/internal/store"
)

type fakeStore struct {
	mu      sync.Mutex
	cfg     store.Config
	batches [][]events.Event
	fail    int
	reject  bool
	status  []map[string]any
}

func (f *fakeStore) Config(context.Context, string, int64, int64) (store.Config, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.cfg, nil
}

func (f *fakeStore) Events(_ context.Context, _ string, ev any) (store.Result, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.reject {
		return store.Result{}, &store.HTTPError{Status: 400, Code: "invalid_batch"}
	}
	if f.fail > 0 {
		f.fail--
		return store.Result{}, errors.New("database unavailable")
	}
	batch := ev.([]events.Event)
	f.batches = append(f.batches, batch)
	return store.Result{Counts: map[string]int64{"accepted": int64(len(batch))}}, nil
}

func (f *fakeStore) Status(_ context.Context, _ string, s map[string]any) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.status = append(f.status, s)
	return nil
}

func (f *fakeStore) Heartbeat(context.Context, string, string, time.Time, string, string, map[string]any) error {
	return nil
}

func (f *fakeStore) sent() []events.Event {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []events.Event
	for _, b := range f.batches {
		out = append(out, b...)
	}
	return out
}

type fakeSocket struct {
	mu     sync.Mutex
	frames chan []byte
	sent   [][]byte
	closed bool
}

func (s *fakeSocket) Recv() ([][]byte, error) {
	select {
	case f := <-s.frames:
		return [][]byte{f}, nil
	case <-time.After(5 * time.Millisecond):
		return nil, nil
	}
}

func (s *fakeSocket) Send(b []byte) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sent = append(s.sent, b)
	return nil
}

func (s *fakeSocket) Close() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.closed = true
	return nil
}

type harness struct {
	r     *Relay
	st    *fakeStore
	dials chan *fakeSocket
	last  *fakeSocket
	mu    sync.Mutex
}

func newHarness(cfg store.Config) *harness {
	h := &harness{st: &fakeStore{cfg: cfg}, dials: make(chan *fakeSocket, 10)}
	h.r = New(Options{
		Store: h.st,
		Dial: func(string, string, int, time.Duration) (Socket, error) {
			s := &fakeSocket{frames: make(chan []byte, 100)}
			h.mu.Lock()
			h.last = s
			h.mu.Unlock()
			h.dials <- s
			return s, nil
		},
		Log:            slog.New(slog.NewTextHandler(io.Discard, nil)),
		Instance:       "test",
		Version:        "test",
		ConfigInterval: 20 * time.Millisecond,
		StatusInterval: 50 * time.Millisecond,
		FlushInterval:  5 * time.Millisecond,
		BatchSize:      50,
		BufferSize:     100,
		RecvQueue:      100,
		RecvHWM:        1000,
		RecvTimeout:    5 * time.Millisecond,
		RequestTimeout: time.Second,
		RestartFlush:   time.Second,
		RetryBackoff:   10 * time.Millisecond,
	})
	return h
}

func baseConfig() store.Config {
	return store.Config{Enabled: true, Version: 1, AccountsVersion: 1, HasConnection: true,
		IProxyAddr: "tcp://iproxy:9990", Identity: "social_trade_relay", HeartbeatSeconds: 1,
		Accounts: &store.Accounts{Sharers: []string{"SHARE1"}, Owners: []string{"OWNER1"}}}
}

func order(cust string) []byte {
	return protocol.Build(protocol.PkgNewOrder, protocol.EncodeOrder(protocol.Order{Status: 1, OrderID: "O-" + cust,
		OrderDate: 20261116, Board: "RG", CustID: cust, StockCode: "BBCA", Price: 100, OpenVolume: 100, RemainVolume: 100}),
		protocol.BuildOptions{Compress: true})
}

func trade(cust, id string) []byte {
	return protocol.Build(protocol.PkgTrade, protocol.EncodeTrade(protocol.Trade{OrderID: "O-" + cust, TradeID: id,
		TradeDate: 20261116, TradeTime: 93000, Board: "RG", CustID: cust, StockCode: "BBCA", Price: 100, Volume: 100}),
		protocol.BuildOptions{})
}

func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatal("condition not met")
}

func TestFiltersAndForwards(t *testing.T) {
	h := newHarness(baseConfig())
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- h.r.Run(ctx) }()
	sock := <-h.dials
	sock.frames <- order("SHARE1")
	sock.frames <- order("OWNER1")
	sock.frames <- order("OTHER1")
	sock.frames <- trade("SHARE1", "T1")
	sock.frames <- trade("OWNER1", "T2")
	sock.frames <- trade("OTHER1", "T3")
	sock.frames <- protocol.Build(0x0005, []byte("x"), protocol.BuildOptions{})
	sock.frames <- []byte("garbage frame that is not a package")
	waitFor(t, func() bool { return len(h.st.sent()) == 3 })
	kinds := map[string]int{}
	for _, e := range h.st.sent() {
		kinds[e["kind"].(string)+":"+e["cust_id"].(string)]++
	}
	if kinds["order:SHARE1"] != 1 || kinds["fill:SHARE1"] != 1 || kinds["fill:OWNER1"] != 1 {
		t.Fatalf("forwarded %v", kinds)
	}
	c := h.r.Counters()
	if c.Get("filtered_out") != 3 || c.Get("other") != 1 || c.Get("decode_errors") != 1 {
		t.Fatalf("counters %v", c.Snapshot())
	}
	cancel()
	if err := <-done; err != nil {
		t.Fatalf("run: %v", err)
	}
}

func TestDisabledForwardsNothing(t *testing.T) {
	cfg := baseConfig()
	cfg.Enabled = false
	h := newHarness(cfg)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go h.r.Run(ctx)
	sock := <-h.dials
	sock.frames <- trade("SHARE1", "T1")
	waitFor(t, func() bool { return h.r.Counters().Get("filtered_out") == 1 })
	if len(h.st.sent()) != 0 {
		t.Fatal("disabled relay forwarded events")
	}
}

func TestRetriesUntilDelivered(t *testing.T) {
	h := newHarness(baseConfig())
	h.st.fail = 2
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go h.r.Run(ctx)
	sock := <-h.dials
	sock.frames <- trade("SHARE1", "T1")
	waitFor(t, func() bool { return len(h.st.sent()) == 1 })
	if h.r.Counters().Get("send_errors") != 2 {
		t.Fatalf("send_errors = %d", h.r.Counters().Get("send_errors"))
	}
}

func TestRejectedBatchIsDropped(t *testing.T) {
	h := newHarness(baseConfig())
	h.st.reject = true
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go h.r.Run(ctx)
	sock := <-h.dials
	sock.frames <- trade("SHARE1", "T1")
	waitFor(t, func() bool { return h.r.Counters().Get("send_rejected") == 1 })
	if h.r.q.Len() != 0 {
		t.Fatal("rejected batch still queued")
	}
}

func TestEncryptedNeedsKey(t *testing.T) {
	c, _ := protocol.NewCipher("ecb", "ABCDEFGHIJKLMNOP", "")
	frame := protocol.Build(protocol.PkgTrade, protocol.EncodeTrade(protocol.Trade{OrderID: "O1", TradeID: "T1",
		TradeDate: 20261116, TradeTime: 93000, Board: "RG", CustID: "SHARE1", StockCode: "BBCA", Price: 1, Volume: 1}),
		protocol.BuildOptions{Compress: true, Cipher: c})
	h := newHarness(baseConfig())
	h.r.applyConfig(baseConfig())
	h.r.Process(frame)
	if h.r.Counters().Get("encrypted_no_key") != 1 {
		t.Fatalf("counters %v", h.r.Counters().Snapshot())
	}
	cfg := baseConfig()
	cfg.Version = 2
	cfg.AES = &store.AES{Mode: "ecb", Key: "ABCDEFGHIJKLMNOP"}
	h.r.applyConfig(cfg)
	h.r.Process(frame)
	if h.r.Counters().Get("forwarded_fill") != 1 {
		t.Fatalf("counters %v", h.r.Counters().Snapshot())
	}
}

func TestReconnectAndRestartCommands(t *testing.T) {
	cfg := baseConfig()
	h := newHarness(cfg)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan error, 1)
	go func() { done <- h.r.Run(ctx) }()
	first := <-h.dials
	h.st.mu.Lock()
	h.st.cfg.ReconnectGeneration = 1
	h.st.mu.Unlock()
	second := <-h.dials
	waitFor(t, func() bool {
		first.mu.Lock()
		defer first.mu.Unlock()
		return first.closed
	})
	second.frames <- trade("SHARE1", "T9")
	waitFor(t, func() bool { return len(h.st.sent()) == 1 })
	h.st.mu.Lock()
	h.st.cfg.RestartGeneration = 1
	h.st.mu.Unlock()
	select {
	case err := <-done:
		if !errors.Is(err, ErrRestart) {
			t.Fatalf("run err = %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("restart not honoured")
	}
	last := h.st.status[len(h.st.status)-1]
	if last["applied_restart"] != int64(1) || last["applied_reconnect"] != int64(1) {
		t.Fatalf("status %v", last)
	}
}

func TestHeartbeatWhenIdle(t *testing.T) {
	h := newHarness(baseConfig())
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go h.r.Run(ctx)
	sock := <-h.dials
	waitFor(t, func() bool {
		sock.mu.Lock()
		defer sock.mu.Unlock()
		if len(sock.sent) == 0 {
			return false
		}
		id, ok := protocol.PeekPackageID(sock.sent[0])
		return ok && id == protocol.PkgHeartbeat
	})
}

func TestBufferOverflowCounted(t *testing.T) {
	h := newHarness(baseConfig())
	h.r.applyConfig(baseConfig())
	for i := 0; i < 150; i++ {
		h.r.Process(trade("SHARE1", "T"+string(rune('a'+i%26))+string(rune('a'+i/26))))
	}
	if h.r.Counters().Get("buffer_overflow") != 50 || h.r.q.Len() != 100 {
		t.Fatalf("overflow %d len %d", h.r.Counters().Get("buffer_overflow"), h.r.q.Len())
	}
}
