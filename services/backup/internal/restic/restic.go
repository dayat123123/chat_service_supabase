package restic

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"strconv"
	"strings"
	"time"

	"olt-social/backup/internal/runner"
)

const (
	Host       = "olt-social"
	TagBase    = "base"
	TagFiles   = "files"
	TagWAL     = "wal"
	exitIncomp = 3
	exitNoRepo = 10
	exitLocked = 11
	exitBadKey = 12
)

var (
	ErrNoRepository  = errors.New("restic repository does not exist")
	ErrWrongPassword = errors.New("restic repository password is wrong")
	ErrLocked        = errors.New("restic repository is locked")
	ErrIncomplete    = errors.New("restic snapshot is missing files that could not be read")
)

type Credentials struct {
	Repository      string
	Password        string
	AccessKeyID     string
	SecretAccessKey string
	Region          string
}

func (c Credentials) S3() bool {
	return strings.HasPrefix(c.Repository, "s3:")
}

func (c Credentials) Env() []string {
	env := []string{
		"RESTIC_REPOSITORY=" + c.Repository,
		"RESTIC_PASSWORD=" + c.Password,
	}
	if !c.S3() {
		return env
	}
	env = append(env, "AWS_ACCESS_KEY_ID="+c.AccessKeyID, "AWS_SECRET_ACCESS_KEY="+c.SecretAccessKey)
	if c.Region != "" {
		env = append(env, "AWS_DEFAULT_REGION="+c.Region)
	}
	return env
}

var Passthrough = []string{
	"RESTIC_REPOSITORY", "RESTIC_REPOSITORY_FILE", "RESTIC_PASSWORD", "RESTIC_PASSWORD_FILE",
	"AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_DEFAULT_REGION", "AWS_SESSION_TOKEN",
}

func FromEnv(getenv func(string) string) ([]string, error) {
	var env []string
	for _, key := range Passthrough {
		if v := getenv(key); v != "" {
			env = append(env, key+"="+v)
		}
	}
	var missing []string
	if getenv("RESTIC_REPOSITORY") == "" && getenv("RESTIC_REPOSITORY_FILE") == "" {
		missing = append(missing, "RESTIC_REPOSITORY")
	}
	if getenv("RESTIC_PASSWORD") == "" && getenv("RESTIC_PASSWORD_FILE") == "" {
		missing = append(missing, "RESTIC_PASSWORD atau RESTIC_PASSWORD_FILE")
	}
	if len(missing) > 0 {
		return nil, fmt.Errorf("env belum diisi: %s", strings.Join(missing, ", "))
	}
	return env, nil
}

type Client struct {
	Runner    runner.Runner
	Binary    string
	Env       []string
	NoCache   bool
	RetryLock time.Duration
}

func (c *Client) cmd(args ...string) runner.Cmd {
	binary := c.Binary
	if binary == "" {
		binary = "restic"
	}
	var global []string
	if c.NoCache {
		global = append(global, "--no-cache")
	}
	if c.RetryLock > 0 {
		global = append(global, "--retry-lock", c.RetryLock.String())
	}
	return runner.Cmd{Name: binary, Args: append(global, args...), Env: c.Env}
}

func (c *Client) run(ctx context.Context, args ...string) (runner.Result, error) {
	res, err := c.Runner.Run(ctx, c.cmd(args...))
	return res, classify(err)
}

func classify(err error) error {
	if err == nil {
		return nil
	}
	if strings.Contains(err.Error()+runner.Output(err), "bucket does not exist") {
		return fmt.Errorf("%w: %v", ErrNoRepository, err)
	}
	switch runner.Code(err) {
	case exitNoRepo:
		return fmt.Errorf("%w: %v", ErrNoRepository, err)
	case exitLocked:
		return fmt.Errorf("%w: %v", ErrLocked, err)
	case exitBadKey:
		return fmt.Errorf("%w: %v", ErrWrongPassword, err)
	}
	return err
}

func (c *Client) Open(ctx context.Context) error {
	_, err := c.run(ctx, "cat", "config", "--no-lock")
	return err
}

func (c *Client) Init(ctx context.Context) error {
	_, err := c.run(ctx, "init")
	return err
}

func (c *Client) Unlock(ctx context.Context) error {
	_, err := c.run(ctx, "unlock")
	return err
}

type BackupRequest struct {
	Paths []string
	Tags  []string
}

type Summary struct {
	SnapshotID          string  `json:"snapshot_id"`
	FilesNew            int64   `json:"files_new"`
	FilesChanged        int64   `json:"files_changed"`
	FilesUnmodified     int64   `json:"files_unmodified"`
	DataAdded           int64   `json:"data_added"`
	DataAddedPacked     int64   `json:"data_added_packed"`
	TotalFilesProcessed int64   `json:"total_files_processed"`
	TotalBytesProcessed int64   `json:"total_bytes_processed"`
	TotalDuration       float64 `json:"total_duration"`
}

func BackupArgs(req BackupRequest) []string {
	args := []string{"backup", "--json", "--quiet", "--host", Host}
	for _, tag := range req.Tags {
		args = append(args, "--tag", tag)
	}
	return append(args, req.Paths...)
}

func (c *Client) Backup(ctx context.Context, req BackupRequest) (Summary, error) {
	if len(req.Paths) == 0 {
		return Summary{}, errors.New("restic backup needs at least one path")
	}
	res, err := c.run(ctx, BackupArgs(req)...)
	summary, found := parseSummary(res.Stdout)
	if runner.Code(err) == exitIncomp && found {
		return summary, fmt.Errorf("%w: %s", ErrIncomplete, runner.Detail(err))
	}
	if err != nil {
		return summary, err
	}
	if !found || summary.SnapshotID == "" {
		return summary, errors.New("restic backup did not report a snapshot")
	}
	return summary, nil
}

func parseSummary(out []byte) (Summary, bool) {
	var summary Summary
	found := false
	scanner := bufio.NewScanner(bytes.NewReader(out))
	scanner.Buffer(make([]byte, 64<<10), 4<<20)
	for scanner.Scan() {
		line := bytes.TrimSpace(scanner.Bytes())
		if len(line) == 0 || line[0] != '{' {
			continue
		}
		var probe struct {
			MessageType string `json:"message_type"`
		}
		if json.Unmarshal(line, &probe) != nil || probe.MessageType != "summary" {
			continue
		}
		if json.Unmarshal(line, &summary) == nil {
			found = true
		}
	}
	return summary, found
}

type SnapshotSummary struct {
	TotalFilesProcessed int64 `json:"total_files_processed"`
	TotalBytesProcessed int64 `json:"total_bytes_processed"`
	DataAdded           int64 `json:"data_added"`
}

type Snapshot struct {
	ID       string           `json:"id"`
	ShortID  string           `json:"short_id"`
	Time     time.Time        `json:"time"`
	Paths    []string         `json:"paths"`
	Tags     []string         `json:"tags"`
	Hostname string           `json:"hostname"`
	Summary  *SnapshotSummary `json:"summary"`
}

func (s Snapshot) Has(tag string) bool {
	return slices.Contains(s.Tags, tag)
}

func (s Snapshot) Label() string {
	for _, tag := range s.Tags {
		if strings.HasPrefix(tag, "base-") {
			return tag
		}
	}
	return ""
}

func (s Snapshot) Bytes() int64 {
	if s.Summary == nil {
		return 0
	}
	return s.Summary.TotalBytesProcessed
}

func (s Snapshot) Short() string {
	if s.ShortID != "" {
		return s.ShortID
	}
	if len(s.ID) > 8 {
		return s.ID[:8]
	}
	return s.ID
}

func (c *Client) Snapshots(ctx context.Context, tag string) ([]Snapshot, error) {
	args := []string{"snapshots", "--json", "--no-lock"}
	if tag != "" {
		args = append(args, "--tag", tag)
	}
	res, err := c.run(ctx, args...)
	if err != nil {
		return nil, err
	}
	var snaps []Snapshot
	if trimmed := bytes.TrimSpace(res.Stdout); len(trimmed) > 0 && !bytes.Equal(trimmed, []byte("null")) {
		if err := json.Unmarshal(trimmed, &snaps); err != nil {
			return nil, fmt.Errorf("decode restic snapshots: %w", err)
		}
	}
	slices.SortStableFunc(snaps, func(a, b Snapshot) int { return a.Time.Compare(b.Time) })
	return snaps, nil
}

type Policy struct {
	Tag         string
	KeepDaily   int
	KeepWeekly  int
	KeepMonthly int
	KeepWithin  string
}

func ForgetArgs(p Policy) []string {
	args := []string{"forget", "--json", "--host", Host, "--group-by", "host", "--tag", p.Tag}
	keep := []struct {
		flag  string
		value int
	}{{"--keep-daily", p.KeepDaily}, {"--keep-weekly", p.KeepWeekly}, {"--keep-monthly", p.KeepMonthly}}
	for _, k := range keep {
		if k.value > 0 {
			args = append(args, k.flag, strconv.Itoa(k.value))
		}
	}
	if p.KeepWithin != "" {
		args = append(args, "--keep-within", p.KeepWithin)
	}
	return args
}

func (c *Client) Forget(ctx context.Context, p Policy) (int, error) {
	if p.KeepDaily <= 0 && p.KeepWeekly <= 0 && p.KeepMonthly <= 0 && p.KeepWithin == "" {
		return 0, errors.New("restic forget needs at least one keep rule")
	}
	res, err := c.run(ctx, ForgetArgs(p)...)
	if err != nil {
		return 0, err
	}
	trimmed := bytes.TrimSpace(res.Stdout)
	if len(trimmed) == 0 || bytes.Equal(trimmed, []byte("null")) {
		return 0, nil
	}
	var groups []struct {
		Remove []json.RawMessage `json:"remove"`
	}
	if err := json.Unmarshal(trimmed, &groups); err != nil {
		return 0, fmt.Errorf("decode restic forget: %w", err)
	}
	removed := 0
	for _, g := range groups {
		removed += len(g.Remove)
	}
	return removed, nil
}

func (c *Client) Prune(ctx context.Context) error {
	_, err := c.run(ctx, "prune")
	return err
}

func (c *Client) Check(ctx context.Context, subset string) error {
	args := []string{"check"}
	if subset != "" {
		args = append(args, "--read-data-subset="+subset)
	}
	_, err := c.run(ctx, args...)
	return err
}

func (c *Client) Restore(ctx context.Context, spec, target string) error {
	_, err := c.run(ctx, "restore", spec, "--target", target)
	return err
}
