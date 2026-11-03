package runner

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"regexp"
	"slices"
	"strings"
	"sync"
	"time"
)

type Cmd struct {
	Name    string
	Args    []string
	Env     []string
	Dir     string
	LogFile string
}

func (c Cmd) String() string {
	return strings.TrimSpace(c.Name + " " + strings.Join(c.Args, " "))
}

type Result struct {
	Stdout []byte
	Stderr string
}

type ExitError struct {
	Name   string
	Code   int
	Stderr string
	Output string
}

func (e *ExitError) Error() string {
	msg := fmt.Sprintf("%s exited with status %d", e.Name, e.Code)
	if e.Stderr != "" {
		msg += ": " + e.Stderr
	}
	return msg
}

type StopError struct {
	Name   string
	Cause  error
	Stderr string
	Output string
}

func (e *StopError) Error() string {
	if e.Stderr == "" {
		return fmt.Sprintf("%s: %v", e.Name, e.Cause)
	}
	return fmt.Sprintf("%s: %v: %s", e.Name, e.Cause, e.Stderr)
}

func (e *StopError) Unwrap() error {
	return e.Cause
}

func Code(err error) int {
	var exit *ExitError
	if errors.As(err, &exit) {
		return exit.Code
	}
	return -1
}

func Output(err error) string {
	var exit *ExitError
	if errors.As(err, &exit) {
		return exit.Output
	}
	var stop *StopError
	if errors.As(err, &stop) {
		return stop.Output
	}
	return ""
}

func Detail(err error) string {
	var exit *ExitError
	if errors.As(err, &exit) && exit.Stderr != "" {
		return exit.Stderr
	}
	if err == nil {
		return ""
	}
	return err.Error()
}

type Process interface {
	Done() <-chan struct{}
	Wait() error
	Interrupt()
}

type Runner interface {
	Run(ctx context.Context, cmd Cmd) (Result, error)
	Start(ctx context.Context, cmd Cmd, line func(string)) (Process, error)
}

type Exec struct {
	MaxStdout  int
	StderrTail int
	WaitDelay  time.Duration
}

func (e Exec) maxStdout() int {
	if e.MaxStdout > 0 {
		return e.MaxStdout
	}
	return 64 << 20
}

func (e Exec) tailSize() int {
	if e.StderrTail > 0 {
		return e.StderrTail
	}
	return 16 << 10
}

func (e Exec) command(ctx context.Context, cmd Cmd) *exec.Cmd {
	c := exec.CommandContext(ctx, cmd.Name, cmd.Args...)
	c.Env = append([]string{}, cmd.Env...)
	c.Dir = cmd.Dir
	c.Cancel = func() error { return c.Process.Signal(os.Interrupt) }
	c.WaitDelay = e.WaitDelay
	if c.WaitDelay <= 0 {
		c.WaitDelay = 30 * time.Second
	}
	return c
}

func (e Exec) Run(ctx context.Context, cmd Cmd) (Result, error) {
	c := e.command(ctx, cmd)
	out := &limitBuffer{max: e.maxStdout()}
	tail := &tailBuffer{max: e.tailSize()}
	c.Stdout = out
	c.Stderr = tail
	err := c.Run()
	res := Result{Stdout: out.Bytes(), Stderr: Redact(tail.String(), cmd.Env)}
	if out.overflow && err == nil {
		return res, fmt.Errorf("%s: output larger than %d bytes", cmd.Name, out.max)
	}
	return res, wrap(ctx, cmd, err, res.Stderr)
}

func (e Exec) Start(ctx context.Context, cmd Cmd, line func(string)) (Process, error) {
	c := e.command(ctx, cmd)
	p := &process{cmd: c, ctx: ctx, spec: cmd, done: make(chan struct{}), tail: &tailBuffer{max: e.tailSize()}}
	var reader io.ReadCloser
	if cmd.LogFile != "" {
		f, err := os.OpenFile(cmd.LogFile, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
		if err != nil {
			return nil, err
		}
		c.Stdout, c.Stderr = f, f
		p.closer = f
	} else {
		r, w, err := os.Pipe()
		if err != nil {
			return nil, err
		}
		c.Stdout, c.Stderr = w, w
		reader, p.closer = r, w
	}
	if err := c.Start(); err != nil {
		p.closer.Close()
		if reader != nil {
			reader.Close()
		}
		return nil, wrap(ctx, cmd, err, "")
	}
	p.closer.Close()
	p.scanned = make(chan struct{})
	go func() {
		defer close(p.scanned)
		if reader == nil {
			return
		}
		defer reader.Close()
		scanner := bufio.NewScanner(reader)
		scanner.Buffer(make([]byte, 64<<10), 1<<20)
		for scanner.Scan() {
			text := Redact(scanner.Text(), cmd.Env)
			p.tail.Write([]byte(text + "\n"))
			if line != nil {
				line(text)
			}
		}
	}()
	go func() {
		p.err = c.Wait()
		<-p.scanned
		close(p.done)
	}()
	return p, nil
}

type process struct {
	cmd     *exec.Cmd
	ctx     context.Context
	spec    Cmd
	done    chan struct{}
	scanned chan struct{}
	closer  io.Closer
	tail    *tailBuffer
	err     error
	once    sync.Once
}

func (p *process) Done() <-chan struct{} {
	return p.done
}

func (p *process) Wait() error {
	<-p.done
	return wrap(p.ctx, p.spec, p.err, p.tail.String())
}

func (p *process) Interrupt() {
	p.once.Do(func() {
		if p.cmd.Process != nil {
			_ = p.cmd.Process.Signal(os.Interrupt)
		}
	})
}

func wrap(ctx context.Context, cmd Cmd, err error, stderr string) error {
	if err == nil {
		return nil
	}
	if ctx.Err() != nil {
		return &StopError{Name: cmd.Name, Cause: ctx.Err(), Stderr: LastLines(stderr, 2), Output: stderr}
	}
	var exit *exec.ExitError
	if errors.As(err, &exit) {
		return &ExitError{Name: cmd.Name, Code: exit.ExitCode(), Stderr: LastLines(stderr, 3), Output: stderr}
	}
	return fmt.Errorf("%s: %w", cmd.Name, err)
}

func LastLines(text string, n int) string {
	lines := strings.Split(strings.TrimSpace(text), "\n")
	kept := make([]string, 0, n)
	for i := len(lines) - 1; i >= 0 && len(kept) < n; i-- {
		if l := strings.TrimSpace(lines[i]); l != "" {
			kept = append(kept, l)
		}
	}
	slices.Reverse(kept)
	return strings.Join(kept, " | ")
}

var sensitive = []string{"PGPASSWORD", "RESTIC_PASSWORD", "AWS_SECRET_ACCESS_KEY", "AWS_ACCESS_KEY_ID", "AWS_SESSION_TOKEN"}

var userinfo = regexp.MustCompile(`(://)[^/@\s]+@`)

const Redacted = "[redacted]"

func Redact(text string, env []string) string {
	for _, kv := range env {
		key, value, ok := strings.Cut(kv, "=")
		if ok && len(value) >= 4 && slices.Contains(sensitive, key) {
			text = strings.ReplaceAll(text, value, Redacted)
		}
	}
	return userinfo.ReplaceAllString(text, "${1}"+Redacted+"@")
}

func RedactValues(text string, values ...string) string {
	for _, v := range values {
		if len(v) >= 4 {
			text = strings.ReplaceAll(text, v, Redacted)
		}
	}
	return userinfo.ReplaceAllString(text, "${1}"+Redacted+"@")
}

type limitBuffer struct {
	buf      bytes.Buffer
	max      int
	overflow bool
}

func (b *limitBuffer) Write(p []byte) (int, error) {
	room := b.max - b.buf.Len()
	if room < len(p) {
		b.overflow = true
		if room > 0 {
			b.buf.Write(p[:room])
		}
		return len(p), nil
	}
	return b.buf.Write(p)
}

func (b *limitBuffer) Bytes() []byte {
	return b.buf.Bytes()
}

type tailBuffer struct {
	mu  sync.Mutex
	buf []byte
	max int
}

func (b *tailBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.buf = append(b.buf, p...)
	if over := len(b.buf) - b.max; over > 0 {
		b.buf = append(b.buf[:0], b.buf[over:]...)
	}
	return len(p), nil
}

func (b *tailBuffer) String() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return string(b.buf)
}

func Env(base []string, extra ...string) []string {
	out := make([]string, 0, len(base)+len(extra))
	seen := map[string]int{}
	for _, kv := range append(slices.Clone(base), extra...) {
		key, _, _ := strings.Cut(kv, "=")
		if i, ok := seen[key]; ok {
			out[i] = kv
			continue
		}
		seen[key] = len(out)
		out = append(out, kv)
	}
	return out
}

func Lookup(env []string, key string) string {
	for i := len(env) - 1; i >= 0; i-- {
		if k, v, ok := strings.Cut(env[i], "="); ok && k == key {
			return v
		}
	}
	return ""
}
