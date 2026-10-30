package olt

import (
	"context"
	"errors"

	"olt-social/auth-bridge/internal/breaker"
)

func WithBreaker(v Verifier, b *breaker.Breaker) Verifier {
	return breakerVerifier{next: v, breaker: b}
}

type breakerVerifier struct {
	next    Verifier
	breaker *breaker.Breaker
}

func (bv breakerVerifier) Verify(ctx context.Context, token string) (User, error) {
	if !bv.breaker.Allow() {
		return User{}, ErrUnavailable
	}
	u, err := bv.next.Verify(ctx, token)
	switch {
	case err == nil, errors.Is(err, ErrInvalidToken):
		bv.breaker.Success()
	case ctx.Err() != nil:
		bv.breaker.Release()
	case errors.Is(err, ErrUnavailable), errors.Is(err, context.DeadlineExceeded):
		bv.breaker.Failure()
	default:
		bv.breaker.Release()
	}
	return u, err
}
