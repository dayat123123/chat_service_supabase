// Package ratelimit membatasi jumlah request per kunci (mis. IP) per jendela waktu.
package ratelimit

import (
	"sync"
	"time"
)

// Limiter adalah fixed-window limiter in-memory yang aman dipakai bersamaan.
type Limiter struct {
	limit  int
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

// New membuat Limiter: maksimal limit request per window untuk tiap kunci.
func New(limit int, window time.Duration) *Limiter {
	return &Limiter{limit: limit, window: window, now: time.Now, buckets: make(map[string]*bucket)}
}

// Allow mencatat satu request untuk key. Jika ditolak, retryAfter berisi
// sisa waktu sampai jendela berikutnya.
func (l *Limiter) Allow(key string) (allowed bool, retryAfter time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := l.now()
	l.sweep(now)

	b, ok := l.buckets[key]
	if !ok || !now.Before(b.resetAt) {
		b = &bucket{resetAt: now.Add(l.window)}
		l.buckets[key] = b
	}
	if b.count >= l.limit {
		return false, b.resetAt.Sub(now)
	}
	b.count++
	return true, 0
}

// sweep membuang bucket kedaluwarsa paling sering sekali per window.
func (l *Limiter) sweep(now time.Time) {
	if now.Sub(l.lastSweep) < l.window {
		return
	}
	for k, b := range l.buckets {
		if !now.Before(b.resetAt) {
			delete(l.buckets, k)
		}
	}
	l.lastSweep = now
}
