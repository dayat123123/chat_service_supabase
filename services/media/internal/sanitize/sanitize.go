package sanitize

import (
	"errors"
	"fmt"
)

const (
	MaxSide   = 10000
	MaxPixels = 40_000_000
	MaxFrames = 500
)

var (
	ErrInvalidImage     = errors.New("invalid image")
	ErrImageTooLarge    = errors.New("image too large")
	ErrTooManyFrames    = fmt.Errorf("%w: more than %d frames", ErrImageTooLarge, MaxFrames)
	ErrInvalidPDF       = errors.New("invalid pdf")
	ErrPDFEncrypted     = errors.New("pdf is encrypted")
	ErrPDFActiveContent = errors.New("pdf has active content")
)

type Info struct {
	Width   int
	Height  int
	Frames  int
	Removed int
}

func invalid(reason string) error {
	return fmt.Errorf("%w: %s", ErrInvalidImage, reason)
}

func invalidPDF(reason string) error {
	return fmt.Errorf("%w: %s", ErrInvalidPDF, reason)
}

func checkSize(w, h int) error {
	if w <= 0 || h <= 0 {
		return invalid("zero dimension")
	}
	if w > MaxSide || h > MaxSide || w*h > MaxPixels {
		return fmt.Errorf("%w: %dx%d", ErrImageTooLarge, w, h)
	}
	return nil
}
