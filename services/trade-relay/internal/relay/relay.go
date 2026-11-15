package relay

import (
	"context"
	"errors"
	"log/slog"
	"sync"
	"sync/atomic"
	"time"

	"olt-social/trade-relay/internal/events"
	"olt-social/trade-relay/internal/metrics"
	"olt-social/trade-relay/internal/protocol"
	"olt-social/trade-relay/internal/queue"
	"olt-social/trade-relay/internal/store"
)

var ErrRestart = errors.New("restart requested from Hub")

type Socket interface {
	Recv() ([][]byte, error)
	Send([]byte) error
	Close() error
}

type Dialer func(addr, identity string, hwm int, recvTimeout time.Duration) (Socket, error)

type Store interface {
	Config(ctx context.Context, instance string, knownVersion, knownAccounts int64) (store.Config, error)
	Events(ctx context.Context, instance string, events any) (store.Result, error)
	Status(ctx context.Context, instance string, status map[string]any) error
	Heartbeat(ctx context.Context, instance, version string, started time.Time, status, errText string,
		detail map[string]any) error
}

type Options struct {
	Store           Store
	Dial            Dialer
	Log             *slog.Logger
	Instance        string
	Version         string
	ConfigInterval  time.Duration
	StatusInterval  time.Duration
	FlushInterval   time.Duration
	BatchSize       int
	BufferSize      int
	RecvQueue       int
	RecvHWM         int
	RecvTimeout     time.Duration
	SilentReconnect time.Duration
	RequestTimeout  time.Duration
	RestartFlush    time.Duration
	RetryBackoff    time.Duration
	Now             func() time.Time
}

type roles struct {
	enabled bool
	sharers map[string]struct{}
	owners  map[string]struct{}
}

type connParams struct {
	addr      string
	identity  string
	heartbeat time.Duration
}

type Relay struct {
	opt      Options
	counters *metrics.Counters
	q        *queue.Queue[events.Event]
	recv     chan []byte
	started  time.Time

	roles  atomic.Pointer[roles]
	cipher atomic.Pointer[protocol.Cipher]

	mu              sync.Mutex
	conn            connParams
	version         int64
	accountsVersion int64
	appliedReconn   int64
	appliedRestart  int64
	configured      bool
	lastConfigOK    time.Time
	lastError       string
	state           string
	connected       bool

	reconnect chan struct{}
	restart   chan struct{}

	lastPacket   atomic.Int64
	lastRealtime atomic.Int64
	beats        sync.Map
}

func New(opt Options) *Relay {
	if opt.Now == nil {
		opt.Now = time.Now
	}
	if opt.RetryBackoff <= 0 {
		opt.RetryBackoff = time.Second
	}
	r := &Relay{
		opt:       opt,
		counters:  metrics.New(),
		q:         queue.New[events.Event](opt.BufferSize),
		recv:      make(chan []byte, opt.RecvQueue),
		started:   opt.Now(),
		reconnect: make(chan struct{}, 1),
		restart:   make(chan struct{}, 1),
		state:     "starting",
	}
	r.roles.Store(&roles{})
	return r
}

func (r *Relay) Counters() *metrics.Counters {
	return r.counters
}

func (r *Relay) beat(name string) {
	r.beats.Store(name, r.opt.Now().UnixNano())
}

func (r *Relay) Healthy(timeout time.Duration) (bool, string) {
	now := r.opt.Now()
	bad := ""
	r.beats.Range(func(k, v any) bool {
		if now.Sub(time.Unix(0, v.(int64))) > timeout {
			bad = k.(string)
			return false
		}
		return true
	})
	if bad != "" {
		return false, "loop " + bad + " stalled"
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.configured && now.Sub(r.lastConfigOK) > 5*time.Minute {
		return false, "config not refreshed for 5 minutes"
	}
	return true, ""
}

func (r *Relay) Gauges() map[string]float64 {
	r.mu.Lock()
	connected := r.connected
	r.mu.Unlock()
	g := map[string]float64{"queue_length": float64(r.q.Len()), "recv_queue_length": float64(len(r.recv))}
	if connected {
		g["connected"] = 1
	} else {
		g["connected"] = 0
	}
	return g
}

func (r *Relay) setError(msg string) {
	r.mu.Lock()
	r.lastError = msg
	r.mu.Unlock()
}

func (r *Relay) setState(state string, connected bool) {
	r.mu.Lock()
	r.state = state
	r.connected = connected
	r.mu.Unlock()
}

func signal(ch chan struct{}) {
	select {
	case ch <- struct{}{}:
	default:
	}
}

func (r *Relay) Run(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	var wg sync.WaitGroup
	loops := []func(context.Context){r.configLoop, r.socketLoop, r.decodeLoop, r.statusLoop}
	for _, loop := range loops {
		wg.Add(1)
		go func() {
			defer wg.Done()
			loop(ctx)
		}()
	}
	sendCtx, sendCancel := context.WithCancel(context.Background())
	sendDone := make(chan struct{})
	go func() {
		defer close(sendDone)
		r.sendLoop(sendCtx, ctx)
	}()
	var result error
	select {
	case <-ctx.Done():
	case <-r.restart:
		result = ErrRestart
		r.opt.Log.Info("Restart requested from Hub; flushing pending events")
	}
	cancel()
	wg.Wait()
	deadline := time.NewTimer(r.opt.RestartFlush)
	defer deadline.Stop()
	select {
	case <-sendDone:
	case <-deadline.C:
		sendCancel()
		<-sendDone
	}
	sendCancel()
	r.reportStatus(context.Background())
	return result
}

func (r *Relay) configLoop(ctx context.Context) {
	ticker := time.NewTicker(r.opt.ConfigInterval)
	defer ticker.Stop()
	for {
		r.beat("config")
		r.refreshConfig(ctx)
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
	}
}

func (r *Relay) refreshConfig(ctx context.Context) {
	r.mu.Lock()
	version, accounts := r.version, r.accountsVersion
	r.mu.Unlock()
	cctx, cancel := context.WithTimeout(ctx, r.opt.RequestTimeout)
	defer cancel()
	cfg, err := r.opt.Store.Config(cctx, r.opt.Instance, version, accounts)
	if err != nil {
		if ctx.Err() == nil {
			r.counters.Inc("config_errors")
			r.setError("config: " + err.Error())
			r.opt.Log.Warn("Could not refresh relay config", "error", err)
		}
		return
	}
	r.applyConfig(cfg)
}

func (r *Relay) applyConfig(cfg store.Config) {
	r.mu.Lock()
	defer r.mu.Unlock()
	first := !r.configured
	r.configured = true
	r.lastConfigOK = r.opt.Now()
	if cfg.HasConnection {
		next := connParams{addr: cfg.IProxyAddr, identity: cfg.Identity, heartbeat: time.Duration(cfg.HeartbeatSeconds) * time.Second}
		if next.heartbeat <= 0 {
			next.heartbeat = 4 * time.Second
		}
		if next != r.conn {
			r.conn = next
			signal(r.reconnect)
			r.opt.Log.Info("Relay connection settings changed", "configured", next.addr != "", "identity", next.identity)
		}
		var c *protocol.Cipher
		if cfg.AES != nil && cfg.AES.Key != "" {
			made, err := protocol.NewCipher(cfg.AES.Mode, cfg.AES.Key, cfg.AES.IV)
			if err != nil {
				r.lastError = "aes: " + err.Error()
				r.opt.Log.Error("Invalid AES settings from Hub", "error", err)
			} else {
				c = made
			}
		}
		r.cipher.Store(c)
		r.version = cfg.Version
	}
	current := r.roles.Load()
	next := &roles{enabled: cfg.Enabled, sharers: current.sharers, owners: current.owners}
	if cfg.Accounts != nil {
		next.sharers = toSet(cfg.Accounts.Sharers)
		next.owners = toSet(cfg.Accounts.Owners)
		r.accountsVersion = cfg.AccountsVersion
		r.opt.Log.Info("Relay account list refreshed", "sharers", len(next.sharers), "owners", len(next.owners),
			"accounts_version", cfg.AccountsVersion)
	}
	r.roles.Store(next)
	if first {
		r.appliedReconn = cfg.ReconnectGeneration
		r.appliedRestart = cfg.RestartGeneration
		return
	}
	if cfg.ReconnectGeneration > r.appliedReconn {
		r.appliedReconn = cfg.ReconnectGeneration
		r.counters.Inc("reconnects")
		r.opt.Log.Info("Reconnect requested from Hub", "generation", cfg.ReconnectGeneration)
		signal(r.reconnect)
	}
	if cfg.RestartGeneration > r.appliedRestart {
		r.appliedRestart = cfg.RestartGeneration
		signal(r.restart)
	}
}

func toSet(list []string) map[string]struct{} {
	out := make(map[string]struct{}, len(list))
	for _, v := range list {
		out[events.NormalizeCust(v)] = struct{}{}
	}
	return out
}

func (r *Relay) socketLoop(ctx context.Context) {
	var sock Socket
	var current connParams
	lastHeartbeat := time.Time{}
	lastFrame := r.opt.Now()
	backoff := time.Second
	closeSock := func() {
		if sock != nil {
			_ = sock.Close()
			sock = nil
		}
	}
	defer closeSock()
	for {
		r.beat("socket")
		if ctx.Err() != nil {
			return
		}
		select {
		case <-r.reconnect:
			closeSock()
		default:
		}
		r.mu.Lock()
		want := r.conn
		r.mu.Unlock()
		if want.addr == "" {
			closeSock()
			r.setState("not_configured", false)
			select {
			case <-ctx.Done():
				return
			case <-r.reconnect:
			case <-time.After(time.Second):
			}
			continue
		}
		if sock == nil || want != current {
			closeSock()
			s, err := r.opt.Dial(want.addr, want.identity, r.opt.RecvHWM, r.opt.RecvTimeout)
			if err != nil {
				r.setState("error", false)
				r.setError("connect: " + err.Error())
				r.opt.Log.Warn("Could not open iProxy socket", "error", err)
				select {
				case <-ctx.Done():
					return
				case <-time.After(backoff):
				}
				if backoff < 30*time.Second {
					backoff *= 2
				}
				continue
			}
			sock, current, backoff = s, want, time.Second
			lastFrame = r.opt.Now()
			lastHeartbeat = time.Time{}
			r.setState("connected", true)
			r.opt.Log.Info("Connected to iProxy", "identity", want.identity)
		}
		frames, err := sock.Recv()
		now := r.opt.Now()
		if err != nil {
			r.setError("recv: " + err.Error())
			r.opt.Log.Warn("iProxy receive failed; reconnecting", "error", err)
			closeSock()
			continue
		}
		if len(frames) == 0 {
			if now.Sub(lastHeartbeat) >= current.heartbeat {
				if err := sock.Send(protocol.Heartbeat(now.In(time.FixedZone("WIB", 7*3600)))); err == nil {
					lastHeartbeat = now
				}
			}
			if r.opt.SilentReconnect > 0 && now.Sub(lastFrame) > r.opt.SilentReconnect {
				r.opt.Log.Info("No frames from iProxy for a while; reconnecting", "silent_for", now.Sub(lastFrame).String())
				r.counters.Inc("reconnects")
				closeSock()
			}
			continue
		}
		lastFrame = now
		r.lastPacket.Store(now.UnixNano())
		for _, f := range frames {
			r.counters.Inc("received")
			select {
			case r.recv <- f:
			default:
				r.counters.Inc("recv_overflow")
			}
		}
	}
}

func (r *Relay) decodeLoop(ctx context.Context) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for {
		r.beat("decode")
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		case f := <-r.recv:
			r.Process(f)
		}
	}
}

func (r *Relay) Process(frame []byte) {
	id, ok := protocol.PeekPackageID(frame)
	if !ok {
		if len(frame) > 0 {
			r.counters.Inc("decode_errors")
		}
		return
	}
	switch id {
	case protocol.PkgHeartbeat:
		r.counters.Inc("heartbeats")
		return
	case protocol.PkgNewOrder, protocol.PkgAmendOrder, protocol.PkgTrade:
	default:
		r.counters.Inc("other")
		return
	}
	r.lastRealtime.Store(r.opt.Now().UnixNano())
	ro := r.roles.Load()
	if !ro.enabled || (len(ro.sharers) == 0 && len(ro.owners) == 0) {
		r.counters.Inc("filtered_out")
		return
	}
	h, err := protocol.ParseHeader(frame)
	if err != nil {
		r.counters.Inc("decode_errors")
		return
	}
	payload, err := protocol.Payload(frame, h, r.cipher.Load())
	if err != nil {
		switch {
		case errors.Is(err, protocol.ErrNoKey):
			r.counters.Inc("encrypted_no_key")
		case errors.Is(err, protocol.ErrDecompress):
			r.counters.Inc("decompress_errors")
		case errors.Is(err, protocol.ErrCipherText):
			r.counters.Inc("decrypt_errors")
		default:
			r.counters.Inc("decode_errors")
		}
		return
	}
	if id == protocol.PkgTrade {
		r.counters.Inc("trades")
		cust, err := protocol.TradeCustID(payload)
		if err != nil {
			r.counters.Inc("decode_errors")
			return
		}
		cust = events.NormalizeCust(cust)
		_, sharer := ro.sharers[cust]
		_, owner := ro.owners[cust]
		if !sharer && !owner {
			r.counters.Inc("filtered_out")
			return
		}
		t, err := protocol.DecodeTrade(payload)
		if err != nil {
			r.counters.Inc("decode_errors")
			return
		}
		e, err := events.FromTrade(t)
		if err != nil {
			r.counters.Inc("decode_errors")
			return
		}
		r.push(e, "forwarded_fill")
		return
	}
	r.counters.Inc("orders")
	cust, err := protocol.OrderCustID(payload)
	if err != nil {
		r.counters.Inc("decode_errors")
		return
	}
	if _, sharer := ro.sharers[events.NormalizeCust(cust)]; !sharer {
		r.counters.Inc("filtered_out")
		return
	}
	o, err := protocol.DecodeOrder(payload)
	if err != nil {
		r.counters.Inc("decode_errors")
		return
	}
	e, err := events.FromOrder(o)
	if err != nil {
		r.counters.Inc("decode_errors")
		return
	}
	r.push(e, "forwarded_order")
}

func (r *Relay) push(e events.Event, counter string) {
	if r.q.Push(e) {
		r.counters.Inc("buffer_overflow")
	}
	r.counters.Inc(counter)
}

func (r *Relay) sendLoop(sendCtx, runCtx context.Context) {
	ticker := time.NewTicker(r.opt.FlushInterval)
	defer ticker.Stop()
	backoff := r.opt.RetryBackoff
	for {
		r.beat("send")
		if sendCtx.Err() != nil {
			return
		}
		if runCtx.Err() != nil && r.q.Len() == 0 {
			return
		}
		batch := r.q.Peek(r.opt.BatchSize)
		if len(batch) == 0 {
			select {
			case <-sendCtx.Done():
				return
			case <-ticker.C:
			}
			continue
		}
		cctx, cancel := context.WithTimeout(sendCtx, r.opt.RequestTimeout)
		res, err := r.opt.Store.Events(cctx, r.opt.Instance, batch)
		cancel()
		if err != nil {
			if sendCtx.Err() != nil {
				return
			}
			if store.Rejected(err) {
				r.counters.Inc("send_rejected")
				r.q.Drop(len(batch))
				r.setError("events rejected: " + err.Error())
				r.opt.Log.Error("Event batch rejected by the database; dropping it", "error", err, "events", len(batch))
				continue
			}
			r.counters.Inc("send_errors")
			r.setError("events: " + err.Error())
			r.opt.Log.Warn("Could not deliver events; retrying", "error", err, "backoff", backoff.String())
			select {
			case <-sendCtx.Done():
				return
			case <-time.After(backoff):
			}
			if backoff < 30*time.Second {
				backoff *= 2
			}
			continue
		}
		backoff = r.opt.RetryBackoff
		r.q.Drop(len(batch))
		r.counters.Inc("sent_batches")
		for k, v := range res.Counts {
			switch k {
			case "accepted", "duplicate", "ignored", "invalid":
				r.counters.Add(k, v)
			default:
				r.counters.Add("dropped", v)
			}
		}
	}
}

func (r *Relay) statusLoop(ctx context.Context) {
	ticker := time.NewTicker(r.opt.StatusInterval)
	defer ticker.Stop()
	for {
		r.beat("status")
		r.reportStatus(ctx)
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
	}
}

func unixTime(v int64) any {
	if v == 0 {
		return nil
	}
	return time.Unix(0, v).UTC().Format(time.RFC3339)
}

func (r *Relay) StatusPayload() map[string]any {
	r.mu.Lock()
	defer r.mu.Unlock()
	return map[string]any{
		"version":           r.opt.Version,
		"connected":         r.connected,
		"state":             r.state,
		"last_packet_at":    unixTime(r.lastPacket.Load()),
		"last_realtime_at":  unixTime(r.lastRealtime.Load()),
		"counters":          r.counters.Snapshot(),
		"last_error":        r.lastError,
		"applied_reconnect": r.appliedReconn,
		"applied_restart":   r.appliedRestart,
		"started_at":        r.started.UTC().Format(time.RFC3339),
	}
}

func (r *Relay) reportStatus(ctx context.Context) {
	cctx, cancel := context.WithTimeout(ctx, r.opt.RequestTimeout)
	defer cancel()
	payload := r.StatusPayload()
	if err := r.opt.Store.Status(cctx, r.opt.Instance, payload); err != nil && ctx.Err() == nil {
		r.opt.Log.Warn("Could not report relay status", "error", err)
	}
	healthy, reason := r.Healthy(time.Minute)
	status := "ok"
	if !healthy {
		status = "error"
	} else if payload["state"] != "connected" && payload["state"] != "not_configured" {
		status = "degraded"
	}
	errText := reason
	if errText == "" {
		errText, _ = payload["last_error"].(string)
	}
	if status == "ok" {
		errText = ""
	}
	detail := map[string]any{"state": payload["state"], "queue": r.q.Len()}
	if err := r.opt.Store.Heartbeat(cctx, r.opt.Instance, r.opt.Version, r.started, status, errText, detail); err != nil &&
		ctx.Err() == nil {
		r.opt.Log.Warn("Could not send service heartbeat", "error", err)
	}
}
