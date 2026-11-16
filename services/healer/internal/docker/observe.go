package docker

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

const (
	NumberLabel = "com.docker.compose.container-number"
	maxImage    = 200
)

type Summary struct {
	ID      string
	Name    string
	Service string
	Number  int
	State   string
	Labels  map[string]string
}

type Status struct {
	State        string
	Running      bool
	Health       string
	StartedAt    time.Time
	FinishedAt   time.Time
	ExitCode     int
	RestartCount int
	Image        string
}

type Usage struct {
	CPUTotal    uint64
	SystemTotal uint64
	OnlineCPUs  int
	Memory      uint64
	MemoryLimit uint64
	Read        time.Time
}

type Info struct {
	Name          string
	CPUs          int
	Memory        uint64
	OS            string
	ServerVersion string
}

type wireSummary struct {
	ID     string            `json:"Id"`
	Names  []string          `json:"Names"`
	State  string            `json:"State"`
	Labels map[string]string `json:"Labels"`
}

func (c *Client) ListAll(ctx context.Context, labels ...string) ([]Summary, error) {
	filters, err := json.Marshal(map[string][]string{"label": labels})
	if err != nil {
		return nil, err
	}
	var wire []wireSummary
	if err := c.do(ctx, c.requestTimeout, http.MethodGet, "/containers/json?all=1&filters="+url.QueryEscape(string(filters)), "list", &wire); err != nil {
		return nil, err
	}
	out := make([]Summary, 0, len(wire))
	for _, w := range wire {
		if !idPattern.MatchString(w.ID) {
			continue
		}
		name := ""
		if len(w.Names) > 0 {
			name = strings.TrimPrefix(w.Names[0], "/")
		}
		number, _ := strconv.Atoi(w.Labels[NumberLabel])
		out = append(out, Summary{
			ID:      w.ID,
			Name:    clip(name, 128),
			Service: clip(w.Labels[ServiceLabel], 64),
			Number:  number,
			State:   clip(w.State, 20),
			Labels:  w.Labels,
		})
	}
	return out, nil
}

type wireStatus struct {
	RestartCount int `json:"RestartCount"`
	State        struct {
		Status     string `json:"Status"`
		Running    bool   `json:"Running"`
		ExitCode   int    `json:"ExitCode"`
		StartedAt  string `json:"StartedAt"`
		FinishedAt string `json:"FinishedAt"`
		Health     *struct {
			Status string `json:"Status"`
		} `json:"Health"`
	} `json:"State"`
	Config struct {
		Image string `json:"Image"`
	} `json:"Config"`
}

func (c *Client) Status(ctx context.Context, id string) (Status, error) {
	if !idPattern.MatchString(id) {
		return Status{}, &Error{Op: "inspect", Err: errors.New("invalid container id")}
	}
	var wire wireStatus
	if err := c.do(ctx, c.requestTimeout, http.MethodGet, "/containers/"+id+"/json", "inspect", &wire); err != nil {
		return Status{}, err
	}
	s := Status{
		State:        clip(wire.State.Status, 20),
		Running:      wire.State.Running,
		ExitCode:     wire.State.ExitCode,
		RestartCount: wire.RestartCount,
		Image:        clip(wire.Config.Image, maxImage),
	}
	if wire.State.Health != nil {
		s.Health = clip(wire.State.Health.Status, 20)
	}
	s.StartedAt = engineTime(wire.State.StartedAt)
	s.FinishedAt = engineTime(wire.State.FinishedAt)
	return s, nil
}

type wireStats struct {
	Read     string `json:"read"`
	CPUStats struct {
		CPUUsage struct {
			TotalUsage uint64 `json:"total_usage"`
		} `json:"cpu_usage"`
		SystemUsage uint64 `json:"system_cpu_usage"`
		OnlineCPUs  int    `json:"online_cpus"`
	} `json:"cpu_stats"`
	MemoryStats struct {
		Usage uint64            `json:"usage"`
		Limit uint64            `json:"limit"`
		Stats map[string]uint64 `json:"stats"`
	} `json:"memory_stats"`
}

func (c *Client) Usage(ctx context.Context, id string) (Usage, error) {
	if !idPattern.MatchString(id) {
		return Usage{}, &Error{Op: "stats", Err: errors.New("invalid container id")}
	}
	var wire wireStats
	if err := c.do(ctx, c.requestTimeout, http.MethodGet, "/containers/"+id+"/stats?stream=false&one-shot=true", "stats", &wire); err != nil {
		return Usage{}, err
	}
	memory := wire.MemoryStats.Usage
	for _, key := range []string{"inactive_file", "total_inactive_file"} {
		if v, ok := wire.MemoryStats.Stats[key]; ok && v <= memory {
			memory -= v
			break
		}
	}
	return Usage{
		CPUTotal:    wire.CPUStats.CPUUsage.TotalUsage,
		SystemTotal: wire.CPUStats.SystemUsage,
		OnlineCPUs:  wire.CPUStats.OnlineCPUs,
		Memory:      memory,
		MemoryLimit: wire.MemoryStats.Limit,
		Read:        engineTime(wire.Read),
	}, nil
}

type wireInfo struct {
	Name            string `json:"Name"`
	NCPU            int    `json:"NCPU"`
	MemTotal        uint64 `json:"MemTotal"`
	OperatingSystem string `json:"OperatingSystem"`
	ServerVersion   string `json:"ServerVersion"`
}

func (c *Client) Info(ctx context.Context) (Info, error) {
	var wire wireInfo
	if err := c.do(ctx, c.requestTimeout, http.MethodGet, "/info", "info", &wire); err != nil {
		return Info{}, err
	}
	return Info{
		Name:          clip(wire.Name, 128),
		CPUs:          wire.NCPU,
		Memory:        wire.MemTotal,
		OS:            clip(wire.OperatingSystem, 100),
		ServerVersion: clip(wire.ServerVersion, 40),
	}, nil
}

func engineTime(value string) time.Time {
	t, err := time.Parse(time.RFC3339Nano, value)
	if err != nil || t.Year() < 2000 {
		return time.Time{}
	}
	return t
}
