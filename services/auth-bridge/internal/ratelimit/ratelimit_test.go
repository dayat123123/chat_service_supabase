package ratelimit

import (
	"testing"
	"time"
)

func TestLimiter(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	l := New(3, time.Minute)
	l.now = func() time.Time { return now }

	for i := range 3 {
		if ok, _ := l.Allow("1.2.3.4"); !ok {
			t.Fatalf("request ke-%d harus diizinkan", i+1)
		}
	}
	ok, retry := l.Allow("1.2.3.4")
	if ok || retry != time.Minute {
		t.Fatalf("request ke-4 harus ditolak dengan retry 1m, dapat ok=%v retry=%v", ok, retry)
	}
	if ok, _ := l.Allow("5.6.7.8"); !ok {
		t.Fatal("IP lain punya kuota sendiri")
	}

	now = now.Add(time.Minute)
	if ok, _ := l.Allow("1.2.3.4"); !ok {
		t.Fatal("kuota direset setelah jendela berakhir")
	}
	if len(l.buckets) != 1 {
		t.Fatalf("bucket kedaluwarsa harus dibersihkan, tersisa %d", len(l.buckets))
	}
}
