package logstate

import "sync"

type Latch struct {
	mu      sync.Mutex
	failing bool
	last    string
}

func (l *Latch) Fail(text string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	changed := !l.failing || l.last != text
	l.failing, l.last = true, text
	return changed
}

func (l *Latch) Recover() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	was := l.failing
	l.failing, l.last = false, ""
	return was
}

func (l *Latch) Failing() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.failing
}
