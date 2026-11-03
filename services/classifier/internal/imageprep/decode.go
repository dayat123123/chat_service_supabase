package imageprep

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/gif"
	"image/jpeg"
	"image/png"

	"golang.org/x/image/webp"
)

const (
	MaxSide   = 10000
	MaxPixels = 40_000_000
)

var (
	ErrUnsupported = errors.New("unsupported image type")
	ErrTooLarge    = errors.New("image too large")
	ErrInvalid     = errors.New("invalid image")
)

type Kind string

const (
	JPEG Kind = "jpeg"
	PNG  Kind = "png"
	GIF  Kind = "gif"
	WebP Kind = "webp"
)

type Decoded struct {
	Kind        Kind
	Width       int
	Height      int
	TotalFrames int
	Frames      []image.Image
}

func Detect(data []byte) Kind {
	switch {
	case len(data) >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF:
		return JPEG
	case bytes.HasPrefix(data, []byte("\x89PNG\r\n\x1a\n")):
		return PNG
	case bytes.HasPrefix(data, []byte("GIF87a")) || bytes.HasPrefix(data, []byte("GIF89a")):
		return GIF
	case len(data) >= 12 && string(data[:4]) == "RIFF" && string(data[8:12]) == "WEBP":
		return WebP
	}
	return ""
}

func Decode(data []byte) (d Decoded, err error) {
	defer func() {
		if r := recover(); r != nil {
			d, err = Decoded{}, fmt.Errorf("%w: decoder panic", ErrInvalid)
		}
	}()
	kind := Detect(data)
	switch kind {
	case "":
		return Decoded{}, ErrUnsupported
	case GIF:
		return decodeGIF(data)
	case WebP:
		frame, frames, err := firstWebPFrame(data)
		if err != nil {
			return Decoded{}, err
		}
		d, err := decodeStill(kind, frame)
		d.TotalFrames = frames
		return d, err
	}
	return decodeStill(kind, data)
}

func decodeStill(kind Kind, data []byte) (Decoded, error) {
	var cfg image.Config
	var err error
	switch kind {
	case JPEG:
		cfg, err = jpeg.DecodeConfig(bytes.NewReader(data))
	case PNG:
		cfg, err = png.DecodeConfig(bytes.NewReader(data))
	case WebP:
		cfg, err = webp.DecodeConfig(bytes.NewReader(data))
	}
	if err != nil {
		return Decoded{}, fmt.Errorf("%w: %v", ErrInvalid, err)
	}
	if err := checkSize(cfg.Width, cfg.Height); err != nil {
		return Decoded{}, err
	}
	var img image.Image
	switch kind {
	case JPEG:
		img, err = jpeg.Decode(bytes.NewReader(data))
	case PNG:
		img, err = png.Decode(bytes.NewReader(data))
	case WebP:
		img, err = webp.Decode(bytes.NewReader(data))
	}
	if err != nil {
		return Decoded{}, fmt.Errorf("%w: %v", ErrInvalid, err)
	}
	if img.Bounds().Empty() {
		return Decoded{}, fmt.Errorf("%w: empty image", ErrInvalid)
	}
	return Decoded{Kind: kind, Width: cfg.Width, Height: cfg.Height, TotalFrames: 1, Frames: []image.Image{img}}, nil
}

func checkSize(w, h int) error {
	switch {
	case w < 1 || h < 1:
		return fmt.Errorf("%w: zero dimension", ErrInvalid)
	case w > MaxSide || h > MaxSide || w*h > MaxPixels:
		return fmt.Errorf("%w: %dx%d", ErrTooLarge, w, h)
	}
	return nil
}

func decodeGIF(data []byte) (Decoded, error) {
	layout, err := scanGIF(data)
	if err != nil {
		return Decoded{}, err
	}
	if err := checkSize(layout.width, layout.height); err != nil {
		return Decoded{}, err
	}
	d := Decoded{Kind: GIF, Width: layout.width, Height: layout.height, TotalFrames: layout.frames}
	if layout.frames > 1 && layout.width*layout.height <= maxAnimationCanvas && layout.area <= maxAnimationPixels {
		all, err := gif.DecodeAll(bytes.NewReader(data))
		if err != nil {
			return Decoded{}, fmt.Errorf("%w: %v", ErrInvalid, err)
		}
		d.Frames = composite(all, sampleIndexes(len(all.Image)))
		return d, nil
	}
	first, err := gif.Decode(bytes.NewReader(data))
	if err != nil {
		return Decoded{}, fmt.Errorf("%w: %v", ErrInvalid, err)
	}
	if first.Bounds().Empty() {
		return Decoded{}, fmt.Errorf("%w: empty frame", ErrInvalid)
	}
	d.Frames = []image.Image{first}
	return d, nil
}
