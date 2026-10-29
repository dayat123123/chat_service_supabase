// Package olt memverifikasi token login OLT dan mengambil data user-nya.
package olt

import (
	"context"
	"errors"
	"strings"
)

// User adalah data user OLT hasil verifikasi token.
type User struct {
	ID          string
	Username    string
	Email       string
	DisplayName string
}

var (
	// ErrInvalidToken: token ditolak OLT (salah, kedaluwarsa, atau sesi berakhir).
	ErrInvalidToken = errors.New("token OLT tidak valid")
	// ErrUnavailable: server OLT tidak bisa dihubungi atau tidak menjawab tepat waktu.
	ErrUnavailable = errors.New("server OLT tidak dapat dihubungi")
)

// Verifier memverifikasi token OLT.
type Verifier interface {
	Verify(ctx context.Context, token string) (User, error)
}

// MockVerifier menerima token dummy "mock:<olt_user_id>:<username>[:<nama tampilan>]".
// Hanya untuk development; config menolaknya saat APP_ENV=production.
type MockVerifier struct{}

// Verify mengurai token mock.
func (MockVerifier) Verify(_ context.Context, token string) (User, error) {
	parts := strings.SplitN(token, ":", 4)
	if len(parts) < 3 || parts[0] != "mock" || parts[1] == "" || parts[2] == "" {
		return User{}, ErrInvalidToken
	}
	u := User{ID: parts[1], Username: parts[2]}
	if len(parts) == 4 {
		u.DisplayName = parts[3]
	}
	return u, nil
}
