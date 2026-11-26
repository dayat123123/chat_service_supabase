package xbrl

import (
	"archive/zip"
	"bytes"
	"errors"
	"fmt"
	"io"
	"path"
	"strings"
)

var (
	ErrNotZip     = errors.New("not a zip archive")
	ErrUnsafeZip  = errors.New("zip archive exceeds safety limits")
	ErrNoInstance = errors.New("zip archive has no XBRL instance")
)

type Limits struct {
	MaxEntries       int
	MaxInstanceBytes int64
	MaxRatio         int64
}

func DefaultLimits() Limits {
	return Limits{MaxEntries: 16, MaxInstanceBytes: 32 << 20, MaxRatio: 200}
}

func Inspect(data []byte, limits Limits) (*zip.File, error) {
	archive, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrNotZip, err)
	}
	if len(archive.File) == 0 {
		return nil, ErrNoInstance
	}
	if len(archive.File) > limits.MaxEntries {
		return nil, fmt.Errorf("%w: %d entries, at most %d allowed", ErrUnsafeZip, len(archive.File), limits.MaxEntries)
	}
	var instance *zip.File
	for _, f := range archive.File {
		if f.FileInfo().IsDir() {
			continue
		}
		if f.UncompressedSize64 > uint64(limits.MaxInstanceBytes) {
			return nil, fmt.Errorf("%w: %s is %d bytes uncompressed", ErrUnsafeZip, f.Name, f.UncompressedSize64)
		}
		if f.CompressedSize64 > 0 && f.UncompressedSize64/f.CompressedSize64 > uint64(limits.MaxRatio) {
			return nil, fmt.Errorf("%w: %s compression ratio above %d:1", ErrUnsafeZip, f.Name, limits.MaxRatio)
		}
		if !strings.EqualFold(path.Ext(f.Name), ".xbrl") {
			continue
		}
		if instance != nil {
			return nil, fmt.Errorf("%w: more than one .xbrl file", ErrUnsafeZip)
		}
		instance = f
	}
	if instance == nil {
		return nil, ErrNoInstance
	}
	return instance, nil
}

func Open(data []byte, limits Limits) (io.ReadCloser, error) {
	instance, err := Inspect(data, limits)
	if err != nil {
		return nil, err
	}
	rc, err := instance.Open()
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrNotZip, err)
	}
	return &limited{ReadCloser: rc, left: limits.MaxInstanceBytes}, nil
}

type limited struct {
	io.ReadCloser
	left int64
}

func (l *limited) Read(p []byte) (int, error) {
	if l.left <= 0 {
		var probe [1]byte
		if n, err := l.ReadCloser.Read(probe[:]); n == 0 && errors.Is(err, io.EOF) {
			return 0, io.EOF
		}
		return 0, fmt.Errorf("%w: instance larger than the limit", ErrUnsafeZip)
	}
	if int64(len(p)) > l.left {
		p = p[:l.left]
	}
	n, err := l.ReadCloser.Read(p)
	l.left -= int64(n)
	return n, err
}
