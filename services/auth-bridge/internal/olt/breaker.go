package olt

import (
	"context"
	"errors"

	"olt-social/auth-bridge/internal/breaker"
)

// WithBreaker membungkus Verifier dengan circuit breaker. Saat breaker terbuka,
// verifikasi langsung gagal dengan ErrUnavailable tanpa menghubungi OLT.
// Token yang ditolak OLT (ErrInvalidToken) dihitung sukses: OLT sehat dan menjawab.
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
		// Request dibatalkan pemanggil (klien putus, server shutdown):
		// bukan sinyal kesehatan OLT.
		bv.breaker.Release()
	case errors.Is(err, ErrUnavailable), errors.Is(err, context.DeadlineExceeded):
		bv.breaker.Failure()
	default:
		bv.breaker.Release()
	}
	return u, err
}
