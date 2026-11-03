package runnertest

import (
	"context"
	"slices"
	"sync"

	"olt-social/backup/internal/runner"
)

type Reply struct {
	Stdout string
	Err    error
}

type Fake struct {
	mu      sync.Mutex
	Calls   []runner.Cmd
	Respond func(runner.Cmd) Reply
}

func (f *Fake) Run(_ context.Context, cmd runner.Cmd) (runner.Result, error) {
	f.mu.Lock()
	f.Calls = append(f.Calls, cmd)
	respond := f.Respond
	f.mu.Unlock()
	if respond == nil {
		return runner.Result{}, nil
	}
	r := respond(cmd)
	return runner.Result{Stdout: []byte(r.Stdout)}, r.Err
}

func (f *Fake) Start(_ context.Context, cmd runner.Cmd, _ func(string)) (runner.Process, error) {
	f.mu.Lock()
	f.Calls = append(f.Calls, cmd)
	f.mu.Unlock()
	done := make(chan struct{})
	close(done)
	return doneProcess{done: done}, nil
}

func (f *Fake) Recorded() []runner.Cmd {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.Calls)
}

type doneProcess struct {
	done chan struct{}
}

func (p doneProcess) Done() <-chan struct{} { return p.done }
func (p doneProcess) Wait() error           { return nil }
func (p doneProcess) Interrupt()            {}
