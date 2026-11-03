//go:build !linux

package disk

import (
	"errors"
	"testing"
)

func TestMeasureIsUnsupportedOutsideLinux(t *testing.T) {
	if _, err := Measure(Target{Name: "data", Path: t.TempDir()}); !errors.Is(err, ErrUnsupported) {
		t.Fatalf("err = %v", err)
	}
}
