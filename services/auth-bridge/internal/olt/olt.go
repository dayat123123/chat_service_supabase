package olt

import (
	"context"
	"errors"
	"strings"
)

type User struct {
	ID          string
	Username    string
	Email       string
	DisplayName string
}

var (
	ErrInvalidToken = errors.New("token OLT tidak valid")
	ErrUnavailable  = errors.New("server OLT tidak dapat dihubungi")
)

type Verifier interface {
	Verify(ctx context.Context, token string) (User, error)
}

type MockVerifier struct{}

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
