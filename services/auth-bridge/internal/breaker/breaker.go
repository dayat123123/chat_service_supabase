// Package breaker menyediakan circuit breaker sederhana untuk dependensi
// eksternal (server OLT). Bila OLT gagal berturut-turut, breaker "terbuka" dan
// request langsung ditolak tanpa menunggu timeout, sehingga auth-bridge tidak
// ikut tumbang saat OLT lambat. Setelah cooldown, satu request uji diizinkan
// (half-open): sukses menutup breaker, gagal membukanya lagi.
//
// State disimpan per instance: setiap replika mengamati kesehatan OLT sendiri.
// Ini sengaja; state breaker adalah sinyal sesaat, bukan data aplikasi.
package breaker

import (
	"sync"
	"time"
)

// State adalah kondisi breaker.
type State string

const (
	Closed   State = "closed"
	Open     State = "open"
	HalfOpen State = "half_open"
)

// Breaker aman dipakai bersamaan.
type Breaker struct {
	threshold int
	cooldown  time.Duration
	now       func() time.Time

	mu        sync.Mutex
	state     State
	failures  int
	openUntil time.Time
	probing   bool
}

// New membuat breaker yang terbuka setelah threshold kegagalan berturut-turut.
func New(threshold int, cooldown time.Duration) *Breaker {
	return &Breaker{threshold: threshold, cooldown: cooldown, now: time.Now, state: Closed}
}

// Allow menentukan apakah request boleh diteruskan ke dependensi.
func (b *Breaker) Allow() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	switch b.state {
	case Open:
		if b.now().Before(b.openUntil) {
			return false
		}
		b.state = HalfOpen
		b.probing = true
		return true
	case HalfOpen:
		// Hanya satu request uji pada satu waktu.
		if b.probing {
			return false
		}
		b.probing = true
		return true
	default:
		return true
	}
}

// Success mencatat request yang berhasil (dependensi menjawab).
func (b *Breaker) Success() {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.state = Closed
	b.failures = 0
	b.probing = false
}

// Failure mencatat request yang gagal karena dependensi bermasalah.
func (b *Breaker) Failure() {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.probing = false
	b.failures++
	if b.state == HalfOpen || b.failures >= b.threshold {
		b.state = Open
		b.openUntil = b.now().Add(b.cooldown)
	}
}

// Release melepas request yang hasilnya bukan sinyal kesehatan dependensi
// (mis. dibatalkan klien) tanpa mencatat sukses/gagal. Tanpa ini, request uji
// half-open yang dibatalkan membuat breaker macet menolak semua request.
func (b *Breaker) Release() {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.probing = false
}

// State mengembalikan kondisi saat ini (untuk metrik & readiness).
func (b *Breaker) State() State {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.state == Open && !b.now().Before(b.openUntil) {
		return HalfOpen
	}
	return b.state
}
