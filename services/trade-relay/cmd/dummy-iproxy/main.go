package main

import (
	"context"
	"fmt"
	"log/slog"
	"math/rand/v2"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	zmq "github.com/pebbe/zmq4"

	"olt-social/trade-relay/internal/protocol"
)

type settings struct {
	bind      string
	accounts  []string
	interval  time.Duration
	noiseRate int
	compress  float64
	cipher    *protocol.Cipher
	stock     string
}

func env(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

func load() (settings, error) {
	s := settings{
		bind:     env("BIND", "tcp://*:9990"),
		accounts: strings.Split(env("ACCOUNTS", "DEMO1"), ","),
		stock:    env("STOCK", "BBCA"),
	}
	var err error
	if s.interval, err = time.ParseDuration(env("SCENARIO_INTERVAL", "20s")); err != nil {
		return s, fmt.Errorf("SCENARIO_INTERVAL: %w", err)
	}
	if s.noiseRate, err = strconv.Atoi(env("NOISE_RATE", "50")); err != nil || s.noiseRate < 0 {
		return s, fmt.Errorf("NOISE_RATE must be a non-negative integer")
	}
	if s.compress, err = strconv.ParseFloat(env("COMPRESS_RATIO", "0.5"), 64); err != nil {
		return s, fmt.Errorf("COMPRESS_RATIO must be a number")
	}
	if key := os.Getenv("AES_KEY"); key != "" {
		if s.cipher, err = protocol.NewCipher(env("AES_MODE", "ecb"), key, os.Getenv("AES_IV")); err != nil {
			return s, err
		}
	}
	return s, nil
}

type peers struct {
	mu  sync.Mutex
	ids map[string]time.Time
}

func (p *peers) seen(id string) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	_, known := p.ids[id]
	p.ids[id] = time.Now()
	return !known
}

func (p *peers) list() []string {
	p.mu.Lock()
	defer p.mu.Unlock()
	out := make([]string, 0, len(p.ids))
	for id, at := range p.ids {
		if time.Since(at) < time.Minute {
			out = append(out, id)
		}
	}
	return out
}

type sender struct {
	out  chan []byte
	set  settings
	drop atomic.Int64
}

func (s *sender) send(id uint16, payload []byte) {
	opt := protocol.BuildOptions{Compress: rand.Float64() < s.set.compress, Cipher: s.set.cipher, At: time.Now()}
	select {
	case s.out <- protocol.Build(id, payload, opt):
	default:
		s.drop.Add(1)
	}
}

func today() uint32 {
	n := time.Now().In(time.FixedZone("WIB", 7*3600))
	return uint32(n.Year()*10000 + int(n.Month())*100 + n.Day())
}

func nowClock() uint32 {
	n := time.Now().In(time.FixedZone("WIB", 7*3600))
	return uint32(n.Hour()*10000 + n.Minute()*100 + n.Second())
}

func scenario(s *sender, cust string, n int) {
	orderID := fmt.Sprintf("DMY-%s-%d", cust, n)
	o := protocol.Order{Status: 1, OrderID: orderID, OrderDate: today(), Board: "RG", CustID: cust,
		Command: uint8(n % 2 * 1), StockCode: s.set.stock, Price: 9150, OpenVolume: 2500, RemainVolume: 2500}
	step := func(status uint8, remain, traded uint64) {
		o.Status, o.RemainVolume, o.TradedVolume = status, remain, traded
		s.send(protocol.PkgNewOrder, protocol.EncodeOrder(o))
	}
	fill := func(id string, volume uint64) {
		s.send(protocol.PkgTrade, protocol.EncodeTrade(protocol.Trade{OrderID: orderID, TradeID: id,
			TradeDate: today(), TradeTime: nowClock(), Board: "RG", CustID: cust, Command: o.Command,
			StockCode: s.set.stock, Price: o.Price, Volume: volume}))
	}
	step(1, 2500, 0)
	fill(orderID+"-T1", 1000)
	step(1, 1500, 1000)
	if n%3 == 2 {
		step(4, 1500, 1000)
		step(5, 1500, 1000)
		return
	}
	fill(orderID+"-T2", 1500)
	step(2, 0, 2500)
}

func noise(s *sender, rate int, stop <-chan struct{}) {
	if rate == 0 {
		return
	}
	ticker := time.NewTicker(time.Second / time.Duration(rate))
	defer ticker.Stop()
	i := 0
	for {
		select {
		case <-stop:
			return
		case <-ticker.C:
		}
		i++
		cust := fmt.Sprintf("NOISE%05d", i%50000)
		switch i % 4 {
		case 0:
			s.send(0x0041, []byte("speed order book"))
		case 1:
			s.send(protocol.PkgTrade, protocol.EncodeTrade(protocol.Trade{OrderID: fmt.Sprintf("N%d", i),
				TradeID: fmt.Sprintf("NT%d", i), TradeDate: today(), TradeTime: nowClock(), Board: "RG", CustID: cust,
				StockCode: "TLKM", Price: 3000, Volume: 100}))
		default:
			s.send(protocol.PkgNewOrder, protocol.EncodeOrder(protocol.Order{Status: 1, OrderID: fmt.Sprintf("N%d", i),
				OrderDate: today(), Board: "RG", CustID: cust, StockCode: "TLKM", Price: 3000, OpenVolume: 100,
				RemainVolume: 100}))
		}
	}
}

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	set, err := load()
	if err != nil {
		log.Error("Invalid dummy iProxy settings", "error", err)
		os.Exit(1)
	}
	sock, err := zmq.NewSocket(zmq.ROUTER)
	if err != nil {
		log.Error("Could not create ROUTER socket", "error", err)
		os.Exit(1)
	}
	defer sock.Close()
	_ = sock.SetSndhwm(0)
	if err := sock.Bind(set.bind); err != nil {
		log.Error("Could not bind", "error", err)
		os.Exit(1)
	}
	log.Info("Dummy iProxy listening", "bind", set.bind, "accounts", len(set.accounts), "noise_rate", set.noiseRate,
		"encrypted", set.cipher != nil)
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	known := &peers{ids: map[string]time.Time{}}
	s := &sender{out: make(chan []byte, 100000), set: set}
	go func() {
		ticker := time.NewTicker(set.interval)
		defer ticker.Stop()
		for n := 0; ; {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
			}
			if len(known.list()) == 0 {
				continue
			}
			for _, cust := range set.accounts {
				scenario(s, strings.ToUpper(strings.TrimSpace(cust)), n)
			}
			n++
			log.Info("Scenario queued", "round", n)
		}
	}()
	go noise(s, set.noiseRate, ctx.Done())
	poller := zmq.NewPoller()
	poller.Add(sock, zmq.POLLIN)
	sent := 0
	lastLog := time.Now()
	for ctx.Err() == nil {
		polled, err := poller.Poll(10 * time.Millisecond)
		if err == nil && len(polled) > 0 {
			for {
				frames, err := sock.RecvMessageBytes(zmq.DONTWAIT)
				if err != nil || len(frames) == 0 {
					break
				}
				if known.seen(string(frames[0])) {
					log.Info("Peer connected", "identity", string(frames[0]))
				}
			}
		}
		list := known.list()
		for drained := 0; drained < 5000; drained++ {
			var frame []byte
			select {
			case frame = <-s.out:
			default:
			}
			if frame == nil {
				break
			}
			for _, p := range list {
				if _, err := sock.SendMessageDontwait(p, frame); err == nil {
					sent++
				}
			}
		}
		if time.Since(lastLog) > 30*time.Second {
			log.Info("Dummy iProxy stats", "peers", len(list), "frames_sent", sent, "dropped", s.drop.Load())
			lastLog = time.Now()
		}
	}
}
