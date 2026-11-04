package store

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"olt-social/sentinel/internal/disk"
	"olt-social/sentinel/internal/healer"
	"olt-social/sentinel/internal/jwt"
	"olt-social/sentinel/internal/probe"
	"olt-social/sentinel/internal/scrape"
)

const (
	maxResponse = 1 << 20
	maxError    = 500

	UnknownRevision int64 = -1
)

type Error struct {
	Fn      string
	Status  int
	Code    string
	Message string
	Err     error
}

func (e *Error) Error() string {
	if e.Status == 0 {
		return fmt.Sprintf("rpc %s: %v", e.Fn, e.Err)
	}
	text := fmt.Sprintf("rpc %s: status %d", e.Fn, e.Status)
	if e.Code != "" {
		text += " " + e.Code
	}
	if e.Message != "" {
		text += ": " + e.Message
	}
	return text
}

func (e *Error) Unwrap() error {
	return e.Err
}

func Unreachable(err error) bool {
	var rpcErr *Error
	if !errors.As(err, &rpcErr) {
		return err != nil
	}
	return rpcErr.Status == 0 || rpcErr.Status >= 500
}

type Options struct {
	BaseURL string
	Secret  []byte
	Issuer  string
	Timeout time.Duration
	Observe func(error)
}

type PostgREST struct {
	baseURL string
	secret  []byte
	issuer  string
	http    *http.Client
	observe func(error)
	now     func() time.Time
}

func NewPostgREST(opts Options) *PostgREST {
	observe := opts.Observe
	if observe == nil {
		observe = func(error) {}
	}
	return &PostgREST{
		baseURL: opts.BaseURL,
		secret:  opts.Secret,
		issuer:  opts.Issuer,
		http:    &http.Client{Timeout: opts.Timeout},
		observe: observe,
		now:     time.Now,
	}
}

type Health struct {
	Instance  string
	Version   string
	StartedAt time.Time
	Probes    []probe.Result
	Disks     []disk.Usage
	Metrics   []scrape.Result
	Healer    *healer.Report
}

func (p *PostgREST) HealthReport(ctx context.Context, h Health) (time.Time, error) {
	probes, disks := h.Probes, h.Disks
	if probes == nil {
		probes = []probe.Result{}
	}
	if disks == nil {
		disks = []disk.Usage{}
	}
	args := map[string]any{
		"p_instance":   h.Instance,
		"p_version":    h.Version,
		"p_started_at": h.StartedAt.UTC().Format(time.RFC3339),
		"p_probes":     probes,
		"p_disks":      disks,
	}
	if h.Metrics != nil {
		args["p_metrics"] = h.Metrics
	}
	if h.Healer != nil {
		args["p_healer"] = h.Healer
	}
	var reply struct {
		EvaluatedAt time.Time `json:"evaluated_at"`
	}
	if err := p.rpc(ctx, "health_report", args, &reply); err != nil {
		return time.Time{}, err
	}
	return reply.EvaluatedAt, nil
}

type Telegram struct {
	BotToken string
	ChatIDs  []string
}

func (t Telegram) String() string {
	return fmt.Sprintf("telegram(chats=%d)", len(t.ChatIDs))
}

func (t Telegram) GoString() string {
	return t.String()
}

func (t Telegram) LogValue() slog.Value {
	return slog.GroupValue(slog.Int("chats", len(t.ChatIDs)))
}

type Email struct {
	Host     string
	Port     int
	Security string
	Username string
	Password string
	From     string
	To       []string
}

func (e Email) String() string {
	return fmt.Sprintf("email(host=%s port=%d security=%s recipients=%d)", e.Host, e.Port, e.Security, len(e.To))
}

func (e Email) GoString() string {
	return e.String()
}

func (e Email) LogValue() slog.Value {
	return slog.GroupValue(slog.String("host", e.Host), slog.Int("port", e.Port),
		slog.String("security", e.Security), slog.Int("recipients", len(e.To)))
}

type Channels struct {
	Revision  int64
	Unchanged bool
	Telegram  *Telegram
	Email     *Email
}

type chatIDs []string

func (c *chatIDs) UnmarshalJSON(data []byte) error {
	var raw []json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	ids := make([]string, 0, len(raw))
	for _, item := range raw {
		var text string
		if err := json.Unmarshal(item, &text); err == nil {
			if text = strings.TrimSpace(text); text != "" {
				ids = append(ids, text)
			}
			continue
		}
		var number json.Number
		if err := json.Unmarshal(item, &number); err != nil {
			return fmt.Errorf("chat id must be a string or a number")
		}
		ids = append(ids, number.String())
	}
	*c = ids
	return nil
}

type wireChannels struct {
	Revision  int64 `json:"revision"`
	Unchanged bool  `json:"unchanged"`
	Telegram  *struct {
		BotToken string  `json:"bot_token"`
		ChatIDs  chatIDs `json:"chat_ids"`
	} `json:"telegram"`
	Email *struct {
		Host     string   `json:"host"`
		Port     int      `json:"port"`
		Security string   `json:"security"`
		Username *string  `json:"username"`
		Password *string  `json:"password"`
		From     string   `json:"from"`
		To       []string `json:"to"`
	} `json:"email"`
}

func (p *PostgREST) Channels(ctx context.Context, known int64) (Channels, error) {
	args := map[string]any{"p_revision": nil}
	if known != UnknownRevision {
		args["p_revision"] = known
	}
	var reply wireChannels
	if err := p.rpc(ctx, "alert_channels", args, &reply); err != nil {
		return Channels{}, err
	}
	channels := Channels{Revision: reply.Revision, Unchanged: reply.Unchanged}
	if reply.Unchanged {
		return channels, nil
	}
	if t := reply.Telegram; t != nil {
		channels.Telegram = &Telegram{BotToken: strings.TrimSpace(t.BotToken), ChatIDs: []string(t.ChatIDs)}
	}
	if e := reply.Email; e != nil {
		channels.Email = &Email{
			Host:     strings.TrimSpace(e.Host),
			Port:     e.Port,
			Security: strings.ToLower(strings.TrimSpace(e.Security)),
			Username: deref(e.Username),
			Password: raw(e.Password),
			From:     strings.TrimSpace(e.From),
			To:       e.To,
		}
	}
	return channels, nil
}

type Alert struct {
	ID      int64  `json:"id"`
	Channel string `json:"channel"`
	Subject string `json:"subject"`
	Text    string `json:"text"`
}

func (p *PostgREST) Claim(ctx context.Context, instance string, limit int, lease time.Duration) ([]Alert, error) {
	var alerts []Alert
	args := map[string]any{"p_instance": instance, "p_limit": limit, "p_lease_seconds": seconds(lease)}
	if err := p.rpc(ctx, "alert_claim", args, &alerts); err != nil {
		return nil, err
	}
	return alerts, nil
}

type Result struct {
	ID    int64
	OK    bool
	Error string
	Retry bool
}

type wireResult struct {
	ID    int64   `json:"id"`
	OK    bool    `json:"ok"`
	Error *string `json:"error,omitempty"`
	Retry *bool   `json:"retry,omitempty"`
}

func (p *PostgREST) Report(ctx context.Context, instance string, results []Result) (int, error) {
	rows := make([]wireResult, 0, len(results))
	for _, r := range results {
		row := wireResult{ID: r.ID, OK: r.OK}
		if !r.OK {
			text, retry := clip(r.Error, maxError), r.Retry
			if text == "" {
				text = "Gagal dikirim"
			}
			row.Error, row.Retry = &text, &retry
		}
		rows = append(rows, row)
	}
	var updated int
	if err := p.rpc(ctx, "alert_report", map[string]any{"p_instance": instance, "p_results": rows}, &updated); err != nil {
		return 0, err
	}
	return updated, nil
}

func (p *PostgREST) Ping(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodHead, p.baseURL+"/", nil)
	if err != nil {
		return err
	}
	resp, err := p.http.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	if resp.StatusCode >= 500 {
		return fmt.Errorf("postgrest status %d", resp.StatusCode)
	}
	return nil
}

func (p *PostgREST) rpc(ctx context.Context, fn string, args map[string]any, out any) error {
	err := p.call(ctx, fn, args, out)
	if ctx.Err() == nil {
		p.observe(err)
	}
	return err
}

func (p *PostgREST) call(ctx context.Context, fn string, args map[string]any, out any) error {
	body, err := json.Marshal(args)
	if err != nil {
		return err
	}
	token, err := jwt.ServiceRole(p.secret, p.issuer, p.now())
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL+"/rpc/"+fn, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Profile", "public")
	req.Header.Set("Accept-Profile", "public")
	resp, err := p.http.Do(req)
	if err != nil {
		return &Error{Fn: fn, Err: err}
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxResponse+1))
	if err != nil {
		return &Error{Fn: fn, Err: fmt.Errorf("read response: %w", err)}
	}
	if resp.StatusCode >= 300 {
		code, message := reason(data)
		return &Error{Fn: fn, Status: resp.StatusCode, Code: code, Message: message}
	}
	if len(data) > maxResponse {
		return &Error{Fn: fn, Status: resp.StatusCode, Message: "response larger than 1 MiB"}
	}
	if len(data) == 0 {
		return nil
	}
	if err := json.Unmarshal(data, out); err != nil {
		return &Error{Fn: fn, Status: resp.StatusCode, Message: "decode response: " + err.Error()}
	}
	return nil
}

func reason(data []byte) (string, string) {
	var body struct {
		Code    any    `json:"code"`
		Message string `json:"message"`
	}
	if json.Unmarshal(data, &body) != nil {
		return "", ""
	}
	code := ""
	switch v := body.Code.(type) {
	case string:
		code = strings.TrimSpace(v)
	case float64:
		code = strconv.FormatFloat(v, 'f', -1, 64)
	}
	return clip(code, 40), clip(body.Message, maxError)
}

func clip(s string, n int) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return strings.TrimSpace(*s)
}

func raw(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func seconds(d time.Duration) int {
	return int((d + time.Second - 1) / time.Second)
}
