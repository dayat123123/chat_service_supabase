package state

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"slices"
	"time"
)

const (
	ActionRestart = "restart"
	ActionReport  = "report"
	ActionGiveUp  = "give_up"
	ActionSkip    = "skip"

	ResultOK         = "ok"
	ResultFailed     = "failed"
	ResultReportOnly = "report_only"
	ResultGaveUp     = "gave_up"
	ResultSkipped    = "skipped"

	ReasonUnhealthy    = "unhealthy"
	ReasonRestartLimit = "restart_limit"
	ReasonDB           = "db_unhealthy"
	ReasonPgBouncer    = "pgbouncer_unhealthy"
	ReasonSystemic     = "systemic"

	MaxEvents   = 200
	MaxEventAge = 7 * 24 * time.Hour
	maxFileSize = 4 << 20
)

type Rules struct {
	UnhealthySeconds      int     `json:"unhealthy_seconds"`
	MinUptimeSeconds      int     `json:"min_uptime_seconds"`
	MaxRestartsPerHour    int     `json:"max_restarts_per_hour"`
	GlobalCooldownSeconds int     `json:"global_cooldown_seconds"`
	SystemicFraction      float64 `json:"systemic_fraction"`
	IntervalSeconds       int     `json:"interval_seconds"`
}

type Event struct {
	ID        string    `json:"id"`
	At        time.Time `json:"at"`
	Service   string    `json:"service"`
	Container string    `json:"container"`
	Action    string    `json:"action"`
	Reason    string    `json:"reason"`
	Result    string    `json:"result"`
	Detail    string    `json:"detail,omitempty"`
	Error     string    `json:"error,omitempty"`
}

type GaveUp struct {
	Service  string    `json:"service"`
	Since    time.Time `json:"since"`
	Until    time.Time `json:"until"`
	Restarts int       `json:"restarts"`
}

type Skip struct {
	Reason   string    `json:"reason"`
	Since    time.Time `json:"since"`
	Services []string  `json:"services"`
}

type Unhealthy struct {
	Service   string    `json:"service"`
	Container string    `json:"container"`
	Since     time.Time `json:"since"`
}

type State struct {
	Version   string      `json:"version"`
	Project   string      `json:"project"`
	Enabled   bool        `json:"enabled"`
	StartedAt time.Time   `json:"started_at"`
	CheckedAt time.Time   `json:"checked_at"`
	Rules     Rules       `json:"rules"`
	Watched   int         `json:"watched"`
	Unhealthy []Unhealthy `json:"unhealthy"`
	Skip      *Skip       `json:"skip"`
	GaveUp    []GaveUp    `json:"gave_up"`
	Events    []Event     `json:"events"`
	Error     string      `json:"error,omitempty"`
}

func (s *State) Trim(now time.Time) {
	cutoff := now.Add(-MaxEventAge)
	s.Events = slices.DeleteFunc(s.Events, func(e Event) bool { return e.At.Before(cutoff) })
	slices.SortStableFunc(s.Events, func(a, b Event) int { return a.At.Compare(b.At) })
	if n := len(s.Events); n > MaxEvents {
		s.Events = slices.Clone(s.Events[n-MaxEvents:])
	}
}

func Load(path string) (State, error) {
	f, err := os.Open(path)
	if err != nil {
		return State{}, err
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, maxFileSize+1))
	if err != nil {
		return State{}, err
	}
	if len(data) > maxFileSize {
		return State{}, errors.New("state file larger than 4 MiB")
	}
	var s State
	if err := json.Unmarshal(data, &s); err != nil {
		return State{}, fmt.Errorf("decode state: %w", err)
	}
	return s, nil
}

func Save(path string, s State) error {
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	dir := filepath.Dir(path)
	tmp, err := os.CreateTemp(dir, "."+filepath.Base(path)+".*.tmp")
	if err != nil {
		return err
	}
	name := tmp.Name()
	cleanup := func() {
		_ = os.Remove(name)
	}
	if _, err := tmp.Write(append(data, '\n')); err != nil {
		tmp.Close()
		cleanup()
		return err
	}
	if err := tmp.Chmod(0o644); err != nil {
		tmp.Close()
		cleanup()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		cleanup()
		return err
	}
	if err := tmp.Close(); err != nil {
		cleanup()
		return err
	}
	if err := os.Rename(name, path); err != nil {
		cleanup()
		return err
	}
	return nil
}
