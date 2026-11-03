package sanitize

import (
	"bytes"
	"encoding/binary"
	"errors"
	"image"
	"image/color/palette"
	"image/gif"
	"testing"
)

func encodeGIF(t *testing.T, frames, w, h int) []byte {
	t.Helper()
	anim := &gif.GIF{LoopCount: 0}
	for i := 0; i < frames; i++ {
		img := image.NewPaletted(image.Rect(0, 0, w, h), palette.Plan9)
		for p := range img.Pix {
			img.Pix[p] = uint8((p + i*13) % 256)
		}
		anim.Image = append(anim.Image, img)
		anim.Delay = append(anim.Delay, 5+i)
	}
	var buf bytes.Buffer
	if err := gif.EncodeAll(&buf, anim); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func gifExt(label byte, blocks ...[]byte) []byte {
	out := []byte{gifExtension, label}
	for _, b := range blocks {
		out = append(out, byte(len(b)))
		out = append(out, b...)
	}
	return append(out, 0)
}

func gifHeaderEnd(data []byte) int {
	return 13 + colorTable(data[10])
}

func splice(data []byte, at int, parts ...[]byte) []byte {
	out := append([]byte(nil), data[:at]...)
	for _, p := range parts {
		out = append(out, p...)
	}
	return append(out, data[at:]...)
}

func TestGIFRemovesCommentsAndForeignApplicationData(t *testing.T) {
	base := encodeGIF(t, 3, 6, 4)
	head := gifHeaderEnd(base)
	comment := gifExt(gifComment, []byte("SECRET COMMENT"))
	xmp := gifExt(gifApplication, []byte("XMP DataXMP"), []byte("<x:xmpmeta>XMP-SECRET</x:xmpmeta>"))
	icc := gifExt(gifApplication, []byte("ICCRGBG1012"), []byte("ICC-SECRET"))
	short := gifExt(gifApplication, []byte("SHORT"))
	animexts := gifExt(gifApplication, []byte("ANIMEXTS1.0"), []byte{0x01, 0x00, 0x00})

	cases := map[string]struct {
		input   []byte
		want    []byte
		removed int
	}{
		"comment, XMP, ICC and trailer": {
			append(splice(splice(base, len(base)-1, comment), head, xmp, icc, short), "SECRET-TRAILER"...),
			base, 5,
		},
		"ANIMEXTS kept": {splice(base, head, animexts, comment), splice(base, head, animexts), 1},
		"clean":         {base, base, 0},
	}
	original, err := gif.DecodeAll(bytes.NewReader(base))
	if err != nil {
		t.Fatal(err)
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			out, info, err := GIF(tc.input)
			if err != nil {
				t.Fatal(err)
			}
			mustNotContain(t, out, "SECRET", "XMP", "ICCRGBG")
			if !bytes.Equal(out, tc.want) {
				t.Fatalf("out  = %x\nwant = %x", out, tc.want)
			}
			if info.Width != 6 || info.Height != 4 || info.Frames != 3 || info.Removed != tc.removed {
				t.Fatalf("info = %+v", info)
			}
			got, err := gif.DecodeAll(bytes.NewReader(out))
			if err != nil {
				t.Fatal(err)
			}
			if len(got.Image) != 3 || got.LoopCount != original.LoopCount {
				t.Fatalf("frames = %d loop = %d", len(got.Image), got.LoopCount)
			}
			for i := range got.Image {
				if got.Delay[i] != original.Delay[i] {
					t.Fatalf("delay %d changed", i)
				}
				samePixels(t, original.Image[i], got.Image[i])
			}
		})
	}
}

func TestGIFFrameLimit(t *testing.T) {
	if _, info, err := GIF(encodeGIF(t, MaxFrames, 1, 1)); err != nil || info.Frames != MaxFrames {
		t.Fatalf("err = %v info = %+v", err, info)
	}
	_, _, err := GIF(encodeGIF(t, MaxFrames+1, 1, 1))
	if !errors.Is(err, ErrTooManyFrames) || !errors.Is(err, ErrImageTooLarge) {
		t.Fatalf("err = %v", err)
	}
}

func TestGIFRejects(t *testing.T) {
	base := encodeGIF(t, 2, 6, 4)
	head := gifHeaderEnd(base)
	size := func(w, h uint16) []byte {
		out := append([]byte(nil), base...)
		binary.LittleEndian.PutUint16(out[6:], w)
		binary.LittleEndian.PutUint16(out[8:], h)
		return out
	}
	cases := map[string]struct {
		data []byte
		want error
	}{
		"bad header":        {append([]byte("GIF88a"), base[6:]...), ErrInvalidImage},
		"missing trailer":   {base[:len(base)-1], ErrInvalidImage},
		"unknown block":     {splice(base, len(base)-1, []byte{0x99}), ErrInvalidImage},
		"no frames":         {append(append([]byte(nil), base[:head]...), gifTrailer), ErrInvalidImage},
		"truncated frame":   {base[:len(base)-6], ErrInvalidImage},
		"open extension":    {append(append([]byte(nil), base[:head]...), gifExtension, gifComment, 0x05, 'a'), ErrInvalidImage},
		"truncated palette": {base[:head-3], ErrInvalidImage},
		"zero width":        {size(0, 4), ErrInvalidImage},
		"too wide":          {size(10001, 4), ErrImageTooLarge},
		"too many pixels":   {size(9000, 9000), ErrImageTooLarge},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			if _, _, err := GIF(tc.data); !errors.Is(err, tc.want) {
				t.Fatalf("err = %v, want %v", err, tc.want)
			}
		})
	}
}
