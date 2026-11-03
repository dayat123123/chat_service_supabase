package sanitize

import (
	"bytes"
	"errors"
	"image/png"
	"testing"

	"olt-social/link-preview/internal/sniff"
)

func TestImageDispatchesByMagicBytes(t *testing.T) {
	var buf bytes.Buffer
	if err := png.Encode(&buf, gradient(40, 30)); err != nil {
		t.Fatal(err)
	}
	out, kind, info, err := Image(buf.Bytes())
	if err != nil || kind != sniff.PNG || info.Width != 40 || info.Height != 30 || len(out) == 0 {
		t.Fatalf("png: kind=%v info=%+v err=%v", kind, info, err)
	}
	for name, data := range map[string][]byte{
		"svg":  []byte(`<svg xmlns="http://www.w3.org/2000/svg"/>`),
		"pdf":  []byte("%PDF-1.7\n"),
		"html": []byte("<!doctype html>"),
		"none": nil,
	} {
		if _, _, _, err := Image(data); !errors.Is(err, ErrUnsupported) {
			t.Fatalf("%s: err = %v", name, err)
		}
	}
	if _, _, _, err := Image([]byte("\x89PNG\r\n\x1a\nbroken")); !errors.Is(err, ErrInvalidImage) {
		t.Fatalf("broken png: %v", err)
	}
}
