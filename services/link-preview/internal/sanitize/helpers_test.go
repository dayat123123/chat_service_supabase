package sanitize

import (
	"bytes"
	"encoding/binary"
	"image"
	"image/color"
	"testing"
)

func gradient(w, h int) *image.RGBA {
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.Set(x, y, color.RGBA{R: uint8(x * 255 / w), G: uint8(y * 255 / h), B: uint8((x + y) * 7), A: 255})
		}
	}
	return img
}

func samePixels(t *testing.T, a, b image.Image) {
	t.Helper()
	if a.Bounds() != b.Bounds() {
		t.Fatalf("bounds %v != %v", a.Bounds(), b.Bounds())
	}
	r := a.Bounds()
	for y := r.Min.Y; y < r.Max.Y; y++ {
		for x := r.Min.X; x < r.Max.X; x++ {
			ar, ag, ab, aa := a.At(x, y).RGBA()
			br, bg, bb, ba := b.At(x, y).RGBA()
			if ar != br || ag != bg || ab != bb || aa != ba {
				t.Fatalf("pixel (%d,%d) differs", x, y)
			}
		}
	}
}

func mustNotContain(t *testing.T, data []byte, secrets ...string) {
	t.Helper()
	for _, s := range secrets {
		if bytes.Contains(data, []byte(s)) {
			t.Fatalf("output still contains %q", s)
		}
	}
}

type ifdEntry struct {
	tag, kind uint16
	count     uint32
	value     []byte
}

type byteOrder interface {
	binary.ByteOrder
	binary.AppendByteOrder
}

func tiff(order byteOrder, ifd0, gps []ifdEntry) []byte {
	var head []byte
	if order == byteOrder(binary.LittleEndian) {
		head = []byte("II*\x00")
	} else {
		head = []byte("MM\x00*")
	}
	out := order.AppendUint32(head, 8)
	ifdSize := func(entries []ifdEntry) int { return 2 + 12*len(entries) + 4 }
	extra := func(entries []ifdEntry) int {
		n := 0
		for _, e := range entries {
			if len(e.value) > 4 {
				n += len(e.value)
			}
		}
		return n
	}
	if len(gps) > 0 {
		gpsAt := 8 + ifdSize(ifd0) + 12 + extra(ifd0)
		ifd0 = append(ifd0, ifdEntry{0x8825, 4, 1, order.AppendUint32(nil, uint32(gpsAt))})
	}
	write := func(out []byte, entries []ifdEntry, at int) []byte {
		data := at + ifdSize(entries)
		out = order.AppendUint16(out, uint16(len(entries)))
		var tail []byte
		for _, e := range entries {
			out = order.AppendUint16(out, e.tag)
			out = order.AppendUint16(out, e.kind)
			out = order.AppendUint32(out, e.count)
			if len(e.value) > 4 {
				out = order.AppendUint32(out, uint32(data+len(tail)))
				tail = append(tail, e.value...)
				continue
			}
			field := make([]byte, 4)
			copy(field, e.value)
			out = append(out, field...)
		}
		out = order.AppendUint32(out, 0)
		return append(out, tail...)
	}
	out = write(out, ifd0, 8)
	if len(gps) > 0 {
		out = write(out, gps, len(out))
	}
	return out
}

func exifPayload(order byteOrder, orientation uint16) []byte {
	ifd0 := []ifdEntry{{0x010F, 2, 12, []byte("SECRET-MAKE\x00")}}
	if orientation != 0 {
		ifd0 = append(ifd0, ifdEntry{0x0112, 3, 1, order.AppendUint16(nil, orientation)})
	}
	gps := []ifdEntry{
		{0x0001, 2, 2, []byte("S\x00")},
		{0x001B, 7, 19, []byte("GPS-SECRET-LOCATION")},
	}
	return append([]byte("Exif\x00\x00"), tiff(order, ifd0, gps)...)
}

func segment(marker byte, payload []byte) []byte {
	out := []byte{0xFF, marker}
	out = binary.BigEndian.AppendUint16(out, uint16(len(payload)+2))
	return append(out, payload...)
}

func insertAfterSOI(jpg []byte, segments ...[]byte) []byte {
	out := append([]byte(nil), jpg[:2]...)
	for _, s := range segments {
		out = append(out, s...)
	}
	return append(out, jpg[2:]...)
}

type jpegSegment struct {
	marker  byte
	payload []byte
}

func headerSegments(t *testing.T, jpg []byte) []jpegSegment {
	t.Helper()
	var out []jpegSegment
	pos := 2
	for pos+4 <= len(jpg) {
		if jpg[pos] != 0xFF {
			t.Fatalf("no marker at %d", pos)
		}
		m := jpg[pos+1]
		n := int(binary.BigEndian.Uint16(jpg[pos+2:]))
		out = append(out, jpegSegment{m, jpg[pos+4 : pos+2+n]})
		if m == 0xDA {
			break
		}
		pos += 2 + n
	}
	return out
}
