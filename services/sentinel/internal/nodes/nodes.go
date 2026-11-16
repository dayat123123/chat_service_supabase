package nodes

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log/slog"
	"os"
	"strings"
	"time"
	"unicode/utf8"
)

const (
	maxFileSize   = 1 << 20
	maxContainers = 200
)

type Host struct {
	Name          string `json:"name"`
	CPUs          int    `json:"cpus"`
	MemoryBytes   uint64 `json:"memory_bytes"`
	OS            string `json:"os"`
	DockerVersion string `json:"docker_version"`
}

type Container struct {
	Service          string     `json:"service"`
	Name             string     `json:"name"`
	Replica          int        `json:"replica"`
	Host             string     `json:"host"`
	State            string     `json:"state"`
	Health           string     `json:"health"`
	StartedAt        *time.Time `json:"started_at"`
	FinishedAt       *time.Time `json:"finished_at"`
	ExitCode         int        `json:"exit_code"`
	Restarts         int        `json:"restarts"`
	Image            string     `json:"image"`
	Autoheal         bool       `json:"autoheal"`
	CPUPercent       *float64   `json:"cpu_percent"`
	MemoryBytes      *uint64    `json:"memory_bytes"`
	MemoryLimitBytes *uint64    `json:"memory_limit_bytes"`
}

type Report struct {
	ReadError  string      `json:"read_error,omitempty"`
	Version    string      `json:"version,omitempty"`
	Project    string      `json:"project,omitempty"`
	CheckedAt  *time.Time  `json:"checked_at,omitempty"`
	Host       *Host       `json:"host,omitempty"`
	Containers []Container `json:"containers"`
	Error      string      `json:"error,omitempty"`
}

func Read(path string) Report {
	r, err := read(path)
	if err != nil {
		return Report{ReadError: clip(err.Error(), 300), Containers: []Container{}}
	}
	return r
}

func read(path string) (Report, error) {
	f, err := os.Open(path)
	if errors.Is(err, fs.ErrNotExist) {
		return Report{}, errors.New("node map file not found; is the healer running?")
	}
	if err != nil {
		return Report{}, fmt.Errorf("open node map file: %w", err)
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, maxFileSize+1))
	if err != nil {
		return Report{}, fmt.Errorf("read node map file: %w", err)
	}
	if len(data) > maxFileSize {
		return Report{}, errors.New("node map file larger than 1 MiB")
	}
	var r Report
	if err := json.Unmarshal(data, &r); err != nil {
		return Report{}, fmt.Errorf("decode node map file: %w", err)
	}
	if r.CheckedAt == nil || r.CheckedAt.IsZero() {
		return Report{}, errors.New("node map file has no checked_at")
	}
	r.ReadError = ""
	r.Version = clip(r.Version, 40)
	r.Project = clip(r.Project, 64)
	r.Error = clip(r.Error, 300)
	if r.Host != nil {
		r.Host.Name = clip(r.Host.Name, 128)
		r.Host.OS = clip(r.Host.OS, 100)
		r.Host.DockerVersion = clip(r.Host.DockerVersion, 40)
	}
	if len(r.Containers) > maxContainers {
		r.Containers = r.Containers[:maxContainers]
	}
	if r.Containers == nil {
		r.Containers = []Container{}
	}
	for i := range r.Containers {
		c := &r.Containers[i]
		c.Service = clip(c.Service, 64)
		c.Name = clip(c.Name, 128)
		c.Host = clip(c.Host, 128)
		c.State = clip(c.State, 20)
		c.Health = clip(c.Health, 20)
		c.Image = clip(c.Image, 200)
		if c.CPUPercent != nil && (*c.CPUPercent < 0 || *c.CPUPercent > 100000) {
			c.CPUPercent = nil
		}
	}
	return r, nil
}

type Store interface {
	NodesReport(ctx context.Context, instance string, r Report) error
}

type Options struct {
	Store    Store
	Log      *slog.Logger
	File     string
	Instance string
	Interval time.Duration
}

type Forwarder struct {
	opts     Options
	lastSent time.Time
	failed   bool
}

func NewForwarder(opts Options) *Forwarder {
	return &Forwarder{opts: opts}
}

func (f *Forwarder) Run(ctx context.Context) {
	timer := time.NewTimer(0)
	defer timer.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-timer.C:
		}
		f.Tick(ctx)
		timer.Reset(f.opts.Interval)
	}
}

func (f *Forwarder) Tick(ctx context.Context) bool {
	r := Read(f.opts.File)
	if r.CheckedAt != nil && r.CheckedAt.Equal(f.lastSent) {
		return false
	}
	if err := f.opts.Store.NodesReport(ctx, f.opts.Instance, r); err != nil {
		if !f.failed && ctx.Err() == nil {
			f.opts.Log.Warn("Could not send the node map", "error", err)
		}
		f.failed = true
		return false
	}
	if f.failed {
		f.opts.Log.Info("Node map is sent again")
		f.failed = false
	}
	if r.CheckedAt != nil {
		f.lastSent = *r.CheckedAt
	} else {
		f.lastSent = time.Time{}
	}
	return true
}

func clip(s string, n int) string {
	s = strings.Join(strings.Fields(s), " ")
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}
