package breaker

import (
	"testing"
	"time"
)

func TestBreakerOpensAfterThresholdAndRecovers(t *testing.T) {
	now := time.Unix(1000, 0)
	b := New(3, 30*time.Second)
	b.now = func() time.Time { return now }

	for i := 0; i < 2; i++ {
		if !b.Allow() {
			t.Fatalf("request %d harus diizinkan saat closed", i+1)
		}
		b.Failure()
	}
	if b.State() != Closed {
		t.Fatalf("state = %s, want closed sebelum threshold", b.State())
	}
	b.Allow()
	b.Failure()
	if b.State() != Open || b.Allow() {
		t.Fatalf("breaker harus terbuka dan menolak request setelah 3 kegagalan")
	}

	now = now.Add(31 * time.Second)
	if !b.Allow() {
		t.Fatal("setelah cooldown, satu request uji harus diizinkan")
	}
	if b.Allow() {
		t.Fatal("hanya satu request uji pada saat half-open")
	}
	b.Success()
	if b.State() != Closed || !b.Allow() {
		t.Fatal("request uji yang sukses harus menutup breaker")
	}
}

func TestBreakerReopensWhenProbeFails(t *testing.T) {
	now := time.Unix(1000, 0)
	b := New(1, 10*time.Second)
	b.now = func() time.Time { return now }

	b.Allow()
	b.Failure()
	now = now.Add(11 * time.Second)
	if !b.Allow() {
		t.Fatal("request uji harus diizinkan setelah cooldown")
	}
	b.Failure()
	if b.State() != Open || b.Allow() {
		t.Fatal("request uji yang gagal harus membuka breaker lagi")
	}
}

func TestReleaseFreesHalfOpenProbe(t *testing.T) {
	now := time.Unix(1000, 0)
	b := New(1, 10*time.Second)
	b.now = func() time.Time { return now }

	b.Allow()
	b.Failure()
	now = now.Add(11 * time.Second)
	if !b.Allow() {
		t.Fatal("request uji harus diizinkan setelah cooldown")
	}
	b.Release() // request uji dibatalkan klien
	if !b.Allow() {
		t.Fatal("setelah Release, request lain harus boleh menguji")
	}
}

func TestSuccessResetsFailureCount(t *testing.T) {
	b := New(2, time.Minute)
	b.Allow()
	b.Failure()
	b.Allow()
	b.Success()
	b.Allow()
	b.Failure()
	if b.State() != Closed {
		t.Fatal("kegagalan harus dihitung berturut-turut; sukses mengatur ulang hitungan")
	}
}
