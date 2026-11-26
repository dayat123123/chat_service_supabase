package ratelimit

import (
	"sync"
	"time"
)

type Limiter struct {
	window time.Duration
	now    func() time.Time

	mu        sync.Mutex
	buckets   map[string]*bucket
	lastSweep time.Time
}

type bucket struct {
	count   int
	resetAt time.Time
}

func New(window time.Duration) *Limiter {
	return &Limiter{window: window, now: time.Now, buckets: make(map[string]*bucket)}
}

func (l *Limiter) Allow(key string, limit int) (bool, time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()
	b, now := l.current(key)
	if b.count >= limit {
		return false, b.resetAt.Sub(now)
	}
	b.count++
	return true, 0
}

func (l *Limiter) Exceeded(key string, limit int) (bool, time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()
	b, now := l.current(key)
	if b.count >= limit {
		return true, b.resetAt.Sub(now)
	}
	return false, 0
}

func (l *Limiter) Hit(key string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	b, _ := l.current(key)
	b.count++
}

func (l *Limiter) current(key string) (*bucket, time.Time) {
	now := l.now()
	if now.Sub(l.lastSweep) >= l.window {
		for k, b := range l.buckets {
			if !now.Before(b.resetAt) {
				delete(l.buckets, k)
			}
		}
		l.lastSweep = now
	}
	b, ok := l.buckets[key]
	if !ok || !now.Before(b.resetAt) {
		b = &bucket{resetAt: now.Add(l.window)}
		l.buckets[key] = b
	}
	return b, now
}
