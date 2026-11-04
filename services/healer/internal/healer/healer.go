package healer

import (
	"cmp"
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"strings"
	"time"
	"unicode/utf8"

	"olt-social/healer/internal/docker"
	"olt-social/healer/internal/state"
)

const (
	AutohealLabel = "olt.autoheal"
	DBService     = "db"
	PoolService   = "pgbouncer"
	maxError      = 300
)

type Docker interface {
	List(ctx context.Context, labels ...string) ([]docker.Container, error)
	Inspect(ctx context.Context, id string) (docker.Detail, error)
	Restart(ctx context.Context, id string) error
}

type Options struct {
	Docker           Docker
	Log              *slog.Logger
	Project          string
	Hostname         string
	Enabled          bool
	Interval         time.Duration
	UnhealthyFor     time.Duration
	MinUptime        time.Duration
	MaxRestarts      int
	GlobalCooldown   time.Duration
	SystemicFraction float64
	Version          string
	StartedAt        time.Time
	StateFile        string
	Initial          state.State
	Save             func(path string, s state.State) error
	Now              func() time.Time
}

type Healer struct {
	opts        Options
	log         *slog.Logger
	now         func() time.Time
	save        func(path string, s state.State) error
	project     string
	self        string
	st          state.State
	since       map[string]time.Time
	reported    map[string]bool
	lastRestart time.Time
	lastError   string
	saveFailed  bool
}

func New(opts Options) *Healer {
	now := opts.Now
	if now == nil {
		now = time.Now
	}
	save := opts.Save
	if save == nil {
		save = state.Save
	}
	h := &Healer{
		opts:     opts,
		log:      opts.Log,
		now:      now,
		save:     save,
		project:  opts.Project,
		st:       opts.Initial,
		since:    map[string]time.Time{},
		reported: map[string]bool{},
	}
	if h.st.Project != "" && h.project != "" && h.st.Project != h.project {
		h.st = state.State{}
	}
	h.st.Skip = nil
	for _, e := range h.st.Events {
		if e.Action == state.ActionRestart && e.At.After(h.lastRestart) {
			h.lastRestart = e.At
		}
	}
	return h
}

func (h *Healer) Run(ctx context.Context) {
	timer := time.NewTimer(0)
	defer timer.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-timer.C:
		}
		started := time.Now()
		h.Cycle(ctx)
		timer.Reset(max(h.opts.Interval-time.Since(started), time.Second))
	}
}

func (h *Healer) State() state.State {
	s := h.st
	s.Events = slices.Clone(h.st.Events)
	s.GaveUp = slices.Clone(h.st.GaveUp)
	s.Unhealthy = slices.Clone(h.st.Unhealthy)
	return s
}

type guard struct {
	seen    bool
	healthy bool
}

func (h *Healer) Cycle(ctx context.Context) {
	now := h.now()
	if err := h.resolve(ctx); err != nil {
		h.fail(ctx, now, err)
		return
	}
	containers, err := h.opts.Docker.List(ctx, docker.ProjectLabel+"="+h.project)
	if err != nil {
		h.fail(ctx, now, err)
		return
	}
	guards := map[string]*guard{DBService: {}, PoolService: {}}
	var watched []docker.Detail
	for _, c := range containers {
		if h.self != "" && (c.ID == h.self || strings.HasPrefix(c.ID, h.self)) {
			continue
		}
		g, isGuard := guards[c.Service]
		if c.Labels[AutohealLabel] != "true" && !isGuard {
			continue
		}
		d, err := h.opts.Docker.Inspect(ctx, c.ID)
		if docker.NotFound(err) {
			continue
		}
		if err != nil {
			h.fail(ctx, now, err)
			return
		}
		if d.Labels[docker.ProjectLabel] != h.project {
			continue
		}
		if d.Service == "" {
			d.Service = d.Name
		}
		if isGuard {
			ok := d.Running && (d.Health == "healthy" || d.Health == "")
			g.healthy = ok && (!g.seen || g.healthy)
			g.seen = true
		}
		if d.Labels[AutohealLabel] == "true" && d.Running {
			watched = append(watched, d)
		}
	}
	unhealthy := h.track(now, watched)
	h.expire(now, unhealthy)
	reason := ""
	dbOK := guards[DBService].seen && guards[DBService].healthy
	poolOK := guards[PoolService].seen && guards[PoolService].healthy
	switch {
	case !dbOK:
		reason = state.ReasonDB
	case !poolOK:
		reason = state.ReasonPgBouncer
	case h.systemic(len(unhealthy), len(watched)):
		reason = state.ReasonSystemic
	}
	var allowed, blocked []docker.Detail
	for _, d := range unhealthy {
		if reason == "" || (reason == state.ReasonPgBouncer && d.Service == PoolService) {
			allowed = append(allowed, d)
		} else {
			blocked = append(blocked, d)
		}
	}
	h.hold(now, reason, blocked)
	h.heal(ctx, now, allowed)
	h.record(ctx, now, len(watched), unhealthy, "")
}

func (h *Healer) resolve(ctx context.Context) error {
	if h.project != "" && (h.self != "" || h.opts.Hostname == "") {
		return nil
	}
	if h.opts.Hostname == "" {
		return errors.New("compose project unknown: set HEALER_PROJECT")
	}
	d, err := h.opts.Docker.Inspect(ctx, h.opts.Hostname)
	if err != nil {
		if h.project != "" && docker.NotFound(err) {
			h.opts.Hostname = ""
			return nil
		}
		return fmt.Errorf("find own container: %w", err)
	}
	h.self = d.ID
	if h.project != "" {
		return nil
	}
	project := d.Labels[docker.ProjectLabel]
	if project == "" {
		return errors.New("own container has no compose project label: set HEALER_PROJECT")
	}
	h.project = project
	if h.st.Project != "" && h.st.Project != project {
		h.st = state.State{}
	}
	h.log.Info("Watching compose project", "project", project)
	return nil
}

func (h *Healer) track(now time.Time, watched []docker.Detail) []docker.Detail {
	present := make(map[string]bool, len(watched))
	var unhealthy []docker.Detail
	for _, d := range watched {
		present[d.ID] = true
		if d.Health == "unhealthy" {
			if _, ok := h.since[d.ID]; !ok {
				h.since[d.ID] = now
				h.log.Warn("Container is unhealthy", "service", d.Service, "container", d.Name, "check", d.Output)
			}
			unhealthy = append(unhealthy, d)
			continue
		}
		if _, ok := h.since[d.ID]; ok {
			delete(h.since, d.ID)
			if d.Health == "healthy" {
				h.log.Info("Container is healthy again", "service", d.Service, "container", d.Name)
			}
		}
		delete(h.reported, d.ID)
	}
	for id := range h.since {
		if !present[id] {
			delete(h.since, id)
		}
	}
	for id := range h.reported {
		if !present[id] {
			delete(h.reported, id)
		}
	}
	slices.SortFunc(unhealthy, func(a, b docker.Detail) int {
		return cmp.Or(h.since[a.ID].Compare(h.since[b.ID]), cmp.Compare(a.Name, b.Name))
	})
	return unhealthy
}

func (h *Healer) expire(now time.Time, unhealthy []docker.Detail) {
	sick := map[string]bool{}
	for _, d := range unhealthy {
		sick[d.Service] = true
	}
	h.st.GaveUp = slices.DeleteFunc(h.st.GaveUp, func(g state.GaveUp) bool {
		if !now.Before(g.Until) {
			h.log.Info("Restart window passed; trying the service again", "service", g.Service)
			return true
		}
		if !sick[g.Service] {
			h.log.Info("Service is no longer unhealthy; restarts allowed again", "service", g.Service)
			return true
		}
		return false
	})
}

func (h *Healer) systemic(unhealthy, watched int) bool {
	return unhealthy >= 2 && watched > 0 && float64(unhealthy) >= h.opts.SystemicFraction*float64(watched)
}

func (h *Healer) hold(now time.Time, reason string, blocked []docker.Detail) {
	if reason == "" || len(blocked) == 0 {
		if h.st.Skip != nil {
			h.log.Info("Restarts are allowed again", "previous_reason", h.st.Skip.Reason)
			h.st.Skip = nil
		}
		return
	}
	services := servicesOf(blocked)
	if h.st.Skip != nil && h.st.Skip.Reason == reason {
		h.st.Skip.Services = services
		return
	}
	h.st.Skip = &state.Skip{Reason: reason, Since: now, Services: services}
	h.add(state.Event{
		At:     now,
		Action: state.ActionSkip,
		Reason: reason,
		Result: state.ResultSkipped,
		Detail: "unhealthy: " + strings.Join(services, ", "),
	})
	h.log.Warn("Holding back restarts", "reason", reason, "unhealthy", services)
}

func (h *Healer) heal(ctx context.Context, now time.Time, allowed []docker.Detail) {
	for _, d := range allowed {
		sick := now.Sub(h.since[d.ID])
		uptime := now.Sub(d.StartedAt)
		if sick < h.opts.UnhealthyFor || d.StartedAt.IsZero() || uptime < h.opts.MinUptime {
			continue
		}
		if h.gaveUp(d.Service) {
			continue
		}
		detail := fmt.Sprintf("unhealthy %ds, uptime %ds", int(sick.Seconds()), int(uptime.Seconds()))
		if d.Output != "" {
			detail += ": " + d.Output
		}
		recent := h.restartsSince(d.Service, now.Add(-time.Hour))
		if len(recent) >= h.opts.MaxRestarts {
			until := recent[0].Add(time.Hour)
			h.st.GaveUp = append(h.st.GaveUp, state.GaveUp{Service: d.Service, Since: now, Until: until, Restarts: len(recent)})
			h.add(state.Event{
				At:        now,
				Service:   d.Service,
				Container: d.Name,
				Action:    state.ActionGiveUp,
				Reason:    state.ReasonRestartLimit,
				Result:    state.ResultGaveUp,
				Detail:    fmt.Sprintf("%d restarts in the last hour; next attempt after %s", len(recent), until.UTC().Format(time.RFC3339)),
			})
			h.log.Error("Giving up on an unhealthy service", "service", d.Service, "container", d.Name,
				"restarts_last_hour", len(recent), "retry_after", until.UTC().Format(time.RFC3339))
			continue
		}
		if !h.opts.Enabled {
			if !h.reported[d.ID] {
				h.reported[d.ID] = true
				h.add(state.Event{
					At:        now,
					Service:   d.Service,
					Container: d.Name,
					Action:    state.ActionReport,
					Reason:    state.ReasonUnhealthy,
					Result:    state.ResultReportOnly,
					Detail:    detail,
				})
				h.log.Warn("Would restart an unhealthy container (report-only mode)", "service", d.Service, "container", d.Name,
					"unhealthy_seconds", int(sick.Seconds()))
			}
			continue
		}
		if !h.lastRestart.IsZero() && now.Sub(h.lastRestart) < h.opts.GlobalCooldown {
			return
		}
		err := h.opts.Docker.Restart(ctx, d.ID)
		if ctx.Err() != nil {
			return
		}
		h.lastRestart = now
		delete(h.since, d.ID)
		e := state.Event{
			At:        now,
			Service:   d.Service,
			Container: d.Name,
			Action:    state.ActionRestart,
			Reason:    state.ReasonUnhealthy,
			Result:    state.ResultOK,
			Detail:    detail,
		}
		if err != nil {
			e.Result = state.ResultFailed
			e.Error = clip(err.Error(), maxError)
			h.log.Error("Could not restart an unhealthy container", "service", d.Service, "container", d.Name, "error", err)
		} else {
			h.log.Warn("Restarted an unhealthy container", "service", d.Service, "container", d.Name,
				"unhealthy_seconds", int(sick.Seconds()), "uptime_seconds", int(uptime.Seconds()),
				"restarts_last_hour", len(recent)+1)
		}
		h.add(e)
		return
	}
}

func (h *Healer) gaveUp(service string) bool {
	return slices.ContainsFunc(h.st.GaveUp, func(g state.GaveUp) bool { return g.Service == service })
}

func (h *Healer) restartsSince(service string, cutoff time.Time) []time.Time {
	var at []time.Time
	for _, e := range h.st.Events {
		if e.Action == state.ActionRestart && e.Service == service && e.At.After(cutoff) {
			at = append(at, e.At)
		}
	}
	slices.SortFunc(at, func(a, b time.Time) int { return a.Compare(b) })
	return at
}

func (h *Healer) add(e state.Event) {
	e.ID = eventID(e.At)
	h.st.Events = append(h.st.Events, e)
}

func (h *Healer) fail(ctx context.Context, now time.Time, err error) {
	text := clip(err.Error(), maxError)
	if text != h.lastError {
		h.log.Warn("Cannot read container state from Docker; nothing is restarted", "error", text)
	}
	h.lastError = text
	h.record(ctx, now, h.st.Watched, nil, text)
}

func (h *Healer) record(ctx context.Context, now time.Time, watched int, unhealthy []docker.Detail, failure string) {
	if failure == "" && h.lastError != "" {
		h.log.Info("Docker is reachable again")
		h.lastError = ""
	}
	h.st.Version = h.opts.Version
	h.st.Project = h.project
	h.st.Enabled = h.opts.Enabled
	h.st.StartedAt = h.opts.StartedAt
	h.st.CheckedAt = now
	h.st.Rules = state.Rules{
		UnhealthySeconds:      int(h.opts.UnhealthyFor.Seconds()),
		MinUptimeSeconds:      int(h.opts.MinUptime.Seconds()),
		MaxRestartsPerHour:    h.opts.MaxRestarts,
		GlobalCooldownSeconds: int(h.opts.GlobalCooldown.Seconds()),
		SystemicFraction:      h.opts.SystemicFraction,
		IntervalSeconds:       int(h.opts.Interval.Seconds()),
	}
	h.st.Watched = watched
	h.st.Error = failure
	if failure == "" {
		h.st.Unhealthy = make([]state.Unhealthy, 0, len(unhealthy))
		for _, d := range unhealthy {
			if since, ok := h.since[d.ID]; ok {
				h.st.Unhealthy = append(h.st.Unhealthy, state.Unhealthy{Service: d.Service, Container: d.Name, Since: since})
			}
		}
	}
	if h.st.Unhealthy == nil {
		h.st.Unhealthy = []state.Unhealthy{}
	}
	if h.st.GaveUp == nil {
		h.st.GaveUp = []state.GaveUp{}
	}
	h.st.Trim(now)
	if h.st.Events == nil {
		h.st.Events = []state.Event{}
	}
	if ctx.Err() != nil {
		return
	}
	if err := h.save(h.opts.StateFile, h.st); err != nil {
		if !h.saveFailed {
			h.log.Error("Could not write the state file", "path", h.opts.StateFile, "error", err)
		}
		h.saveFailed = true
		return
	}
	if h.saveFailed {
		h.log.Info("State file can be written again", "path", h.opts.StateFile)
		h.saveFailed = false
	}
}

func servicesOf(list []docker.Detail) []string {
	var names []string
	for _, d := range list {
		names = append(names, d.Service)
	}
	slices.Sort(names)
	return slices.Compact(names)
}

func eventID(at time.Time) string {
	var suffix [4]byte
	_, _ = rand.Read(suffix[:])
	return fmt.Sprintf("%x-%s", at.UnixNano(), hex.EncodeToString(suffix[:]))
}

func clip(s string, n int) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}
