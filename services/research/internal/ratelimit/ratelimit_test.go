package ratelimit

import (
	"testing"
	"time"
)

func TestAllowUsesTheLimitOfEachKey(t *testing.T) {
	l := New(time.Minute)
	now := time.Unix(1_800_000_000, 0)
	l.now = func() time.Time { return now }

	for i := range 3 {
		if ok, _ := l.Allow("a", 3); !ok {
			t.Fatalf("request %d harus lolos", i+1)
		}
	}
	ok, retry := l.Allow("a", 3)
	if ok || retry != time.Minute {
		t.Fatalf("request ke-4: ok=%v retry=%v", ok, retry)
	}
	if ok, _ := l.Allow("b", 1); !ok {
		t.Fatal("key lain punya kuota sendiri")
	}

	now = now.Add(time.Minute)
	if ok, _ := l.Allow("a", 3); !ok {
		t.Fatal("jendela baru harus mengizinkan lagi")
	}
}

func TestFailureCounting(t *testing.T) {
	l := New(time.Minute)
	now := time.Unix(1_800_000_000, 0)
	l.now = func() time.Time { return now }
	for range 2 {
		if blocked, _ := l.Exceeded("ip", 2); blocked {
			t.Fatal("belum melewati batas")
		}
		l.Hit("ip")
	}
	blocked, retry := l.Exceeded("ip", 2)
	if !blocked || retry <= 0 {
		t.Fatalf("blocked=%v retry=%v", blocked, retry)
	}
	now = now.Add(2 * time.Minute)
	if blocked, _ := l.Exceeded("ip", 2); blocked {
		t.Fatal("hitungan gagal harus reset setelah jendela")
	}
	if len(l.buckets) != 1 {
		t.Fatalf("bucket lama harus disapu, len = %d", len(l.buckets))
	}
}
