package olt

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"olt-social/auth-bridge/internal/breaker"
)

type countingVerifier struct {
	calls int
	err   error
}

func (c *countingVerifier) Verify(context.Context, string) (User, error) {
	c.calls++
	if c.err != nil {
		return User{}, c.err
	}
	return User{ID: "1"}, nil
}

func TestBreakerStopsCallingOLTWhenDown(t *testing.T) {
	next := &countingVerifier{err: fmt.Errorf("%w: dial: timeout", ErrUnavailable)}
	v := WithBreaker(next, breaker.New(3, time.Minute))

	for range 5 {
		if _, err := v.Verify(context.Background(), "t"); !errors.Is(err, ErrUnavailable) {
			t.Fatalf("err = %v, want ErrUnavailable", err)
		}
	}
	if next.calls != 3 {
		t.Fatalf("OLT dipanggil %d kali, want 3 (breaker terbuka setelah 3 kegagalan)", next.calls)
	}
}

func TestBreakerCountsRejectedTokenAsHealthy(t *testing.T) {
	next := &countingVerifier{err: ErrInvalidToken}
	b := breaker.New(2, time.Minute)
	v := WithBreaker(next, b)

	for range 5 {
		if _, err := v.Verify(context.Background(), "salah"); !errors.Is(err, ErrInvalidToken) {
			t.Fatalf("err = %v, want ErrInvalidToken", err)
		}
	}
	if b.State() != breaker.Closed || next.calls != 5 {
		t.Fatalf("token ditolak tidak boleh membuka breaker: state=%s calls=%d", b.State(), next.calls)
	}
}

func TestBreakerIgnoresCancelledRequests(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	next := &countingVerifier{err: fmt.Errorf("%w: dial: %v", ErrUnavailable, context.Canceled)}
	b := breaker.New(1, time.Minute)
	v := WithBreaker(next, b)

	for range 3 {
		_, _ = v.Verify(ctx, "t")
	}
	if b.State() != breaker.Closed {
		t.Fatalf("request yang dibatalkan klien tidak boleh membuka breaker, state=%s", b.State())
	}
}
