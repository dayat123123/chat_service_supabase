package healer

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"strings"
	"time"
	"unicode/utf8"
)

const (
	MaxEvents   = 50
	maxFileSize = 4 << 20
	maxText     = 300
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

type Report struct {
	ReadError string      `json:"read_error,omitempty"`
	Version   string      `json:"version,omitempty"`
	Project   string      `json:"project,omitempty"`
	Enabled   *bool       `json:"enabled,omitempty"`
	StartedAt *time.Time  `json:"started_at,omitempty"`
	CheckedAt *time.Time  `json:"checked_at,omitempty"`
	Rules     *Rules      `json:"rules,omitempty"`
	Watched   int         `json:"watched"`
	Unhealthy []Unhealthy `json:"unhealthy"`
	Skip      *Skip       `json:"skip"`
	GaveUp    []GaveUp    `json:"gave_up"`
	Events    []Event     `json:"events"`
	Error     string      `json:"error,omitempty"`
}

func Read(path string) Report {
	r, err := read(path)
	if err != nil {
		return Report{ReadError: clip(err.Error()), Unhealthy: []Unhealthy{}, GaveUp: []GaveUp{}, Events: []Event{}}
	}
	return r
}

func read(path string) (Report, error) {
	f, err := os.Open(path)
	if errors.Is(err, fs.ErrNotExist) {
		return Report{}, errors.New("state file not found; is the healer running?")
	}
	if err != nil {
		return Report{}, fmt.Errorf("open state file: %w", err)
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, maxFileSize+1))
	if err != nil {
		return Report{}, fmt.Errorf("read state file: %w", err)
	}
	if len(data) > maxFileSize {
		return Report{}, errors.New("state file larger than 4 MiB")
	}
	var r Report
	if err := json.Unmarshal(data, &r); err != nil {
		return Report{}, fmt.Errorf("decode state file: %w", err)
	}
	if r.CheckedAt == nil || r.CheckedAt.IsZero() {
		return Report{}, errors.New("state file has no checked_at")
	}
	r.ReadError = ""
	r.Error = clip(r.Error)
	if n := len(r.Events); n > MaxEvents {
		r.Events = r.Events[n-MaxEvents:]
	}
	for i := range r.Events {
		r.Events[i].Detail = clip(r.Events[i].Detail)
		r.Events[i].Error = clip(r.Events[i].Error)
	}
	if r.Unhealthy == nil {
		r.Unhealthy = []Unhealthy{}
	}
	if r.GaveUp == nil {
		r.GaveUp = []GaveUp{}
	}
	if r.Events == nil {
		r.Events = []Event{}
	}
	return r, nil
}

func clip(s string) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= maxText {
		return s
	}
	return string([]rune(s)[:maxText])
}
