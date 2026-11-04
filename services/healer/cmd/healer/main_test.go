package main

import (
	"path/filepath"
	"testing"
	"time"

	"olt-social/healer/internal/state"
)

func TestHealthcheckFollowsTheStateFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")
	t.Setenv("HEALER_STATE_FILE", path)
	t.Setenv("HEALER_INTERVAL_SECONDS", "10")
	now := time.Date(2026, 11, 4, 10, 0, 0, 0, time.UTC)
	if healthcheck(now) != 1 {
		t.Fatal("healthy without a state file")
	}
	if err := state.Save(path, state.State{CheckedAt: now.Add(-20 * time.Second)}); err != nil {
		t.Fatal(err)
	}
	if healthcheck(now) != 0 {
		t.Fatal("fresh state reported unhealthy")
	}
	if healthcheck(now.Add(time.Minute)) != 1 {
		t.Fatal("state older than three intervals reported healthy")
	}
	t.Setenv("HEALER_INTERVAL_SECONDS", "1")
	if healthcheck(now) != 1 {
		t.Fatal("invalid configuration reported healthy")
	}
}
