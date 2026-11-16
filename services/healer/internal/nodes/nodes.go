package nodes

import (
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"time"

	"olt-social/healer/internal/docker"
)

const (
	maxContainers = 200
	maxError      = 300
	workers       = 6
)

type Docker interface {
	ListAll(ctx context.Context, labels ...string) ([]docker.Summary, error)
	Status(ctx context.Context, id string) (docker.Status, error)
	Usage(ctx context.Context, id string) (docker.Usage, error)
	Info(ctx context.Context) (docker.Info, error)
	Inspect(ctx context.Context, id string) (docker.Detail, error)
}

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
	Version    string      `json:"version"`
	Project    string      `json:"project"`
	CheckedAt  time.Time   `json:"checked_at"`
	Host       Host        `json:"host"`
	Containers []Container `json:"containers"`
	Error      string      `json:"error,omitempty"`
}

type Options struct {
	Docker   Docker
	Log      *slog.Logger
	Project  string
	Hostname string
	Interval time.Duration
	File     string
	Version  string
	Now      func() time.Time
}

type sample struct {
	cpu, system uint64
}

type Observer struct {
	opts      Options
	now       func() time.Time
	project   string
	host      Host
	previous  map[string]sample
	lastError string
}

func New(opts Options) *Observer {
	now := opts.Now
	if now == nil {
		now = time.Now
	}
	return &Observer{opts: opts, now: now, project: opts.Project, previous: map[string]sample{}}
}

func (o *Observer) Run(ctx context.Context) {
	timer := time.NewTimer(0)
	defer timer.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-timer.C:
		}
		started := time.Now()
		o.Cycle(ctx)
		timer.Reset(max(o.opts.Interval-time.Since(started), time.Second))
	}
}

func (o *Observer) Cycle(ctx context.Context) Report {
	r := Report{Version: o.opts.Version, CheckedAt: o.now().UTC(), Containers: []Container{}}
	if err := o.collect(ctx, &r); err != nil {
		r.Error = clip(err.Error())
		if r.Error != o.lastError {
			o.opts.Log.Warn("Cannot read the container list for the node map", "error", r.Error)
		}
		o.lastError = r.Error
	} else if o.lastError != "" {
		o.opts.Log.Info("Node map can read containers again")
		o.lastError = ""
	}
	r.Project = o.project
	r.Host = o.host
	if ctx.Err() == nil {
		if err := write(o.opts.File, r); err != nil {
			o.opts.Log.Error("Could not write the node map file", "path", o.opts.File, "error", err)
		}
	}
	return r
}

func (o *Observer) collect(ctx context.Context, r *Report) error {
	if err := o.resolve(ctx); err != nil {
		return err
	}
	if info, err := o.opts.Docker.Info(ctx); err == nil {
		o.host = Host{Name: info.Name, CPUs: info.CPUs, MemoryBytes: info.Memory, OS: info.OS, DockerVersion: info.ServerVersion}
	}
	list, err := o.opts.Docker.ListAll(ctx, docker.ProjectLabel+"="+o.project)
	if err != nil {
		return err
	}
	if len(list) > maxContainers {
		list = list[:maxContainers]
	}
	out := make([]Container, len(list))
	keep := make([]bool, len(list))
	fresh := make([]*sample, len(list))
	jobs := make(chan int)
	var wg sync.WaitGroup
	for range min(workers, max(len(list), 1)) {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range jobs {
				out[i], fresh[i], keep[i] = o.container(ctx, list[i])
			}
		}()
	}
	for i := range list {
		jobs <- i
	}
	close(jobs)
	wg.Wait()
	seen := make(map[string]sample, len(list))
	for i, s := range list {
		if fresh[i] != nil {
			seen[s.ID] = *fresh[i]
		}
		if keep[i] {
			r.Containers = append(r.Containers, out[i])
		}
	}
	o.previous = seen
	slices.SortFunc(r.Containers, func(a, b Container) int {
		return cmp.Or(cmp.Compare(a.Service, b.Service), cmp.Compare(a.Replica, b.Replica), cmp.Compare(a.Name, b.Name))
	})
	return nil
}

func (o *Observer) container(ctx context.Context, s docker.Summary) (Container, *sample, bool) {
	c := Container{
		Service:  cmp.Or(s.Service, s.Name),
		Name:     s.Name,
		Replica:  max(s.Number, 1),
		Host:     o.host.Name,
		State:    s.State,
		Autoheal: s.Labels["olt.autoheal"] == "true",
	}
	st, err := o.opts.Docker.Status(ctx, s.ID)
	if docker.NotFound(err) {
		return c, nil, false
	}
	if err == nil {
		c.State = cmp.Or(st.State, c.State)
		c.Health = st.Health
		c.ExitCode = st.ExitCode
		c.Restarts = st.RestartCount
		c.Image = st.Image
		c.StartedAt = timePtr(st.StartedAt)
		if !st.Running {
			c.FinishedAt = timePtr(st.FinishedAt)
		}
	}
	if c.State != "running" {
		return c, nil, true
	}
	u, err := o.opts.Docker.Usage(ctx, s.ID)
	if err != nil {
		return c, nil, true
	}
	mem, limit := u.Memory, u.MemoryLimit
	c.MemoryBytes = &mem
	if limit > 0 {
		c.MemoryLimitBytes = &limit
	}
	now := sample{cpu: u.CPUTotal, system: u.SystemTotal}
	if prev, ok := o.previous[s.ID]; ok && now.system > prev.system && now.cpu >= prev.cpu {
		cpus := float64(max(u.OnlineCPUs, 1))
		pct := float64(now.cpu-prev.cpu) / float64(now.system-prev.system) * cpus * 100
		pct = math.Round(pct*10) / 10
		c.CPUPercent = &pct
	}
	return c, &now, true
}

func (o *Observer) resolve(ctx context.Context) error {
	if o.project != "" {
		return nil
	}
	if o.opts.Hostname == "" {
		return errors.New("compose project unknown: set HEALER_PROJECT")
	}
	d, err := o.opts.Docker.Inspect(ctx, o.opts.Hostname)
	if err != nil {
		return fmt.Errorf("find own container: %w", err)
	}
	if d.Labels[docker.ProjectLabel] == "" {
		return errors.New("own container has no compose project label: set HEALER_PROJECT")
	}
	o.project = d.Labels[docker.ProjectLabel]
	return nil
}

func write(path string, r Report) error {
	data, err := json.Marshal(r)
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".nodes-*.json")
	if err != nil {
		return err
	}
	name := tmp.Name()
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		os.Remove(name)
		return err
	}
	if err := tmp.Chmod(0o644); err != nil {
		tmp.Close()
		os.Remove(name)
		return err
	}
	if err := tmp.Close(); err != nil {
		os.Remove(name)
		return err
	}
	if err := os.Rename(name, path); err != nil {
		os.Remove(name)
		return err
	}
	return nil
}

func timePtr(t time.Time) *time.Time {
	if t.IsZero() {
		return nil
	}
	u := t.UTC()
	return &u
}

func clip(s string) string {
	s = strings.Join(strings.Fields(s), " ")
	if len([]rune(s)) <= maxError {
		return s
	}
	return string([]rune(s)[:maxError])
}
