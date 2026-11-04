package state

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"time"
)

type Job struct {
	LastOK      time.Time `json:"last_ok,omitzero"`
	LastAttempt time.Time `json:"last_attempt,omitzero"`
	Failures    int       `json:"failures,omitempty"`
	LastError   string    `json:"last_error,omitempty"`
}

type Base struct {
	Label      string    `json:"label"`
	Dir        string    `json:"dir"`
	StartWAL   string    `json:"start_wal"`
	SnapshotID string    `json:"snapshot_id"`
	StartedAt  time.Time `json:"started_at"`
	FinishedAt time.Time `json:"finished_at"`
	Bytes      int64     `json:"bytes"`
}

type Offsite struct {
	LastOKAt      time.Time `json:"last_ok_at,omitzero"`
	LastStartedAt time.Time `json:"last_started_at,omitzero"`
	SentFrom      time.Time `json:"sent_from,omitzero"`
	LastSnapshot  string    `json:"last_snapshot,omitempty"`
	LastRecordAt  time.Time `json:"last_record_at,omitzero"`
}

type Persisted struct {
	Repository string         `json:"repository,omitempty"`
	SystemID   string         `json:"system_id,omitempty"`
	NeedBase   bool           `json:"need_base,omitempty"`
	ResetAt    time.Time      `json:"reset_at,omitzero"`
	SlotLostAt time.Time      `json:"slot_lost_at,omitzero"`
	WeeklyFrom time.Time      `json:"weekly_from,omitzero"`
	Base       *Base          `json:"base,omitempty"`
	Offsite    Offsite        `json:"offsite"`
	Jobs       map[string]Job `json:"jobs"`
}

func (p *Persisted) Job(kind string) Job {
	return p.Jobs[kind]
}

func (p *Persisted) SetJob(kind string, j Job) {
	if p.Jobs == nil {
		p.Jobs = map[string]Job{}
	}
	p.Jobs[kind] = j
}

func Load(path string) (Persisted, error) {
	p := Persisted{Jobs: map[string]Job{}}
	data, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return p, nil
	}
	if err != nil {
		return p, err
	}
	if err := json.Unmarshal(data, &p); err != nil {
		return Persisted{Jobs: map[string]Job{}}, err
	}
	if p.Jobs == nil {
		p.Jobs = map[string]Job{}
	}
	return p, nil
}

func Save(path string, p Persisted) error {
	data, err := json.MarshalIndent(p, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".state-*.json")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), path)
}

type WAL struct {
	Streaming      bool       `json:"streaming"`
	SlotLost       bool       `json:"slot_lost"`
	LastSegment    *string    `json:"last_segment"`
	LastReceivedAt *time.Time `json:"last_received_at"`
	LocalBytes     int64      `json:"local_bytes"`
	Error          *string    `json:"error"`
}

type OffsiteReport struct {
	LastOKAt     *time.Time `json:"last_ok_at"`
	LastSnapshot *string    `json:"last_snapshot"`
	LastError    *string    `json:"last_error"`
	PendingBytes int64      `json:"pending_bytes"`
}

type LocalBase struct {
	Label      *string    `json:"label"`
	FinishedAt *time.Time `json:"finished_at"`
	Bytes      int64      `json:"bytes"`
}

type Disk struct {
	TotalBytes int64 `json:"total_bytes"`
	AvailBytes int64 `json:"avail_bytes"`
}

type Report struct {
	RepositoryReady bool          `json:"repository_ready"`
	WAL             WAL           `json:"wal"`
	Offsite         OffsiteReport `json:"offsite"`
	LocalBase       LocalBase     `json:"local_base"`
	Disk            Disk          `json:"disk"`
	RepositoryDisk  *Disk         `json:"repository_disk,omitempty"`
	Busy            *string       `json:"busy"`
	Error           *string       `json:"error"`
}

type Run struct {
	Kind       string         `json:"kind"`
	Status     string         `json:"status"`
	StartedAt  time.Time      `json:"started_at"`
	FinishedAt time.Time      `json:"finished_at"`
	Bytes      *int64         `json:"bytes"`
	SnapshotID *string        `json:"snapshot_id"`
	Detail     map[string]any `json:"detail"`
	Error      *string        `json:"error"`
}

const (
	StatusOK     = "ok"
	StatusFailed = "failed"
)

func Text(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func Time(t time.Time) *time.Time {
	if t.IsZero() {
		return nil
	}
	u := t.UTC()
	return &u
}

func Int(n int64) *int64 {
	return &n
}
