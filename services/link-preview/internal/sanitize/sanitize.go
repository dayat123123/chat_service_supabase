package sanitize

import (
	"errors"
	"fmt"

	"olt-social/link-preview/internal/sniff"
)

const (
	MaxSide   = 10000
	MaxPixels = 40_000_000
	MaxFrames = 500
)

var (
	ErrInvalidImage  = errors.New("invalid image")
	ErrImageTooLarge = errors.New("image too large")
	ErrTooManyFrames = fmt.Errorf("%w: more than %d frames", ErrImageTooLarge, MaxFrames)
	ErrUnsupported   = errors.New("unsupported image type")
)

type Info struct {
	Width   int
	Height  int
	Frames  int
	Removed int
}

func Image(data []byte) ([]byte, sniff.Kind, Info, error) {
	kind := sniff.Detect(data)
	var (
		out  []byte
		info Info
		err  error
	)
	switch kind {
	case sniff.JPEG:
		out, info, err = JPEG(data)
	case sniff.PNG:
		out, info, err = PNG(data)
	case sniff.WebP:
		out, info, err = WebP(data)
	case sniff.GIF:
		out, info, err = GIF(data)
	default:
		return nil, sniff.Unknown, Info{}, ErrUnsupported
	}
	if err != nil {
		return nil, kind, Info{}, err
	}
	return out, kind, info, nil
}

func invalid(reason string) error {
	return fmt.Errorf("%w: %s", ErrInvalidImage, reason)
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
