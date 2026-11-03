package sanitize

import (
	"bytes"
	"encoding/binary"
	"errors"
	"image/jpeg"
	"testing"
)

func encodeJPEG(t *testing.T, w, h int) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, gradient(w, h), &jpeg.Options{Quality: 90}); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

var (
	jfifPlain    = []byte("JFIF\x00\x01\x02\x00\x00\x48\x00\x48\x00\x00")
	jfifThumb    = append([]byte("JFIF\x00\x01\x02\x00\x00\x48\x00\x48\x02\x01"), []byte("THUMB!")...)
	xmpPayload   = append([]byte("http://ns.adobe.com/xap/1.0/\x00"), []byte(`<x:xmpmeta>XMP-SECRET-CREATOR</x:xmpmeta>`)...)
	iptcPayload  = append([]byte("Photoshop 3.0\x008BIM\x04\x04"), []byte("IPTC-SECRET-CAPTION")...)
	iccPayload   = append([]byte("ICC_PROFILE\x00\x01\x01"), bytes.Repeat([]byte{0x42}, 32)...)
	mpfPayload   = append([]byte("MPF\x00"), []byte("MPF-SECRET-INDEX")...)
	adobePayload = []byte("Adobe\x00\x64\x00\x00\x00\x00\x01")
	ducky        = []byte("Ducky\x00APP12-SECRET")
	app11        = []byte("JP\x00\x00JUMBF-C2PA-SECRET")
)

func TestJPEGRemovesMetadataLosslessly(t *testing.T) {
	base := encodeJPEG(t, 17, 9)
	phone := insertAfterSOI(base,
		segment(0xE0, jfifPlain),
		segment(0xE1, exifPayload(binary.LittleEndian, 6)),
		segment(0xE1, xmpPayload),
		segment(0xE2, iccPayload),
		segment(0xE2, mpfPayload),
		segment(0xEB, app11),
		segment(0xEC, ducky),
		segment(0xED, iptcPayload),
		segment(0xEE, adobePayload),
		segment(0xFE, []byte("COM-SECRET-COMMENT")),
	)
	phone = append(phone, []byte("MOTION-PHOTO-SECRET-TRAILER")...)

	cases := map[string]struct {
		input       []byte
		orientation uint16
		width       int
		height      int
		removed     int
		keep        [][]byte
	}{
		"phone photo, Exif II, rotated 90": {phone, 6, 9, 17, 8, [][]byte{iccPayload, adobePayload, jfifPlain}},
		"Exif MM, rotated 180":             {insertAfterSOI(base, segment(0xE1, exifPayload(binary.BigEndian, 3))), 3, 17, 9, 1, nil},
		"Exif MM, mirrored and rotated":    {insertAfterSOI(base, segment(0xE1, exifPayload(binary.BigEndian, 8))), 8, 9, 17, 1, nil},
		"Exif with orientation 1":          {insertAfterSOI(base, segment(0xE1, exifPayload(binary.LittleEndian, 1))), 0, 17, 9, 1, nil},
		"Exif without orientation":         {insertAfterSOI(base, segment(0xE1, exifPayload(binary.BigEndian, 0))), 0, 17, 9, 1, nil},
		"Exif after APP0 with thumbnail": {insertAfterSOI(base, segment(0xE1, exifPayload(binary.BigEndian, 6)), segment(0xE0, jfifThumb)),
			6, 9, 17, 2, [][]byte{jfifPlain}},
		"JFXX thumbnail extension": {insertAfterSOI(base, segment(0xE0, jfifPlain), segment(0xE0, []byte("JFXX\x00\x10THUMB-SECRET"))), 0, 17, 9, 1, [][]byte{jfifPlain}},
		"trailing data only":       {append(append([]byte(nil), base...), "SECRET-TRAILER"...), 0, 17, 9, 1, nil},
	}
	original, err := jpeg.Decode(bytes.NewReader(base))
	if err != nil {
		t.Fatal(err)
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			input := append([]byte(nil), tc.input...)
			out, info, err := JPEG(input)
			if err != nil {
				t.Fatal(err)
			}
			if !bytes.Equal(input, tc.input) {
				t.Fatal("input was modified")
			}
			mustNotContain(t, out, "SECRET", "xap/1.0", "Photoshop", "MPF\x00", "THUMB")
			if info.Width != tc.width || info.Height != tc.height || info.Removed != tc.removed {
				t.Fatalf("info = %+v", info)
			}
			for _, keep := range tc.keep {
				if !bytes.Contains(out, keep) {
					t.Fatalf("output lost %q", keep)
				}
			}
			if !bytes.HasSuffix(out, []byte{0xFF, 0xD9}) {
				t.Fatal("output does not end with EOI")
			}
			cfg, err := jpeg.DecodeConfig(bytes.NewReader(out))
			if err != nil || cfg.Width != 17 || cfg.Height != 9 {
				t.Fatalf("config = %+v, %v", cfg, err)
			}
			img, err := jpeg.Decode(bytes.NewReader(out))
			if err != nil {
				t.Fatal(err)
			}
			samePixels(t, original, img)

			segments := headerSegments(t, out)
			var exif []jpegSegment
			for i, s := range segments {
				if s.marker == 0xE1 {
					exif = append(exif, s)
					if i > 0 && segments[i-1].marker != 0xE0 {
						t.Fatalf("Exif not placed right after APP0/SOI: %v", segments[i-1].marker)
					}
				}
				if s.marker == 0xE0 && i > 0 && segments[i-1].marker != 0xE0 {
					t.Fatal("APP0 must stay first")
				}
			}
			if tc.orientation == 0 {
				if len(exif) != 0 {
					t.Fatal("unexpected Exif segment")
				}
				return
			}
			if len(exif) != 1 || len(exif[0].payload) != 32 {
				t.Fatalf("exif segments = %d", len(exif))
			}
			if got, ok := exifOrientation(exif[0].payload); !ok || got != tc.orientation {
				t.Fatalf("orientation = %d (%v)", got, ok)
			}
		})
	}
}

func TestJPEGWithoutMetadataIsUnchanged(t *testing.T) {
	base := encodeJPEG(t, 8, 8)
	out, info, err := JPEG(base)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(out, base) || info.Removed != 0 || info.Width != 8 || info.Height != 8 {
		t.Fatalf("info = %+v, equal = %v", info, bytes.Equal(out, base))
	}
}

func patchFrame(t *testing.T, jpg []byte, w, h int) []byte {
	t.Helper()
	out := append([]byte(nil), jpg...)
	i := bytes.Index(out, []byte{0xFF, 0xC0})
	if i < 0 {
		t.Fatal("no SOF0")
	}
	binary.BigEndian.PutUint16(out[i+5:], uint16(h))
	binary.BigEndian.PutUint16(out[i+7:], uint16(w))
	return out
}

func TestJPEGRejects(t *testing.T) {
	base := encodeJPEG(t, 16, 16)
	sos := bytes.Index(base, []byte{0xFF, 0xDA})
	sof := bytes.Index(base, []byte{0xFF, 0xC0})
	cases := map[string]struct {
		data []byte
		want error
	}{
		"not a jpeg":        {[]byte("hello"), ErrInvalidImage},
		"only SOI":          {[]byte{0xFF, 0xD8, 0xFF, 0xD9}, ErrInvalidImage},
		"truncated scan":    {base[:len(base)-20], ErrInvalidImage},
		"missing EOI":       {base[:len(base)-2], ErrInvalidImage},
		"segment overflow":  {insertAfterSOI(base, []byte{0xFF, 0xE1, 0xFF, 0xFF, 'E'}), ErrInvalidImage},
		"short segment":     {insertAfterSOI(base, []byte{0xFF, 0xFE, 0x00, 0x01}), ErrInvalidImage},
		"garbage marker":    {insertAfterSOI(base, []byte{0x12, 0x34}), ErrInvalidImage},
		"reserved marker":   {insertAfterSOI(base, segment(0xF7, []byte("x"))), ErrInvalidImage},
		"scan before frame": {append(append([]byte(nil), base[:sof]...), base[sos:]...), ErrInvalidImage},
		"zero height":       {patchFrame(t, base, 16, 0), ErrInvalidImage},
		"too wide":          {patchFrame(t, base, 10001, 16), ErrImageTooLarge},
		"too many pixels":   {patchFrame(t, base, 8000, 6000), ErrImageTooLarge},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			if _, _, err := JPEG(tc.data); !errors.Is(err, tc.want) {
				t.Fatalf("err = %v, want %v", err, tc.want)
			}
		})
	}
}

func TestJPEGAcceptsTheLimits(t *testing.T) {
	base := encodeJPEG(t, 16, 16)
	for _, size := range [][2]int{{10000, 4000}, {4000, 10000}} {
		_, info, err := JPEG(patchFrame(t, base, size[0], size[1]))
		if errors.Is(err, ErrImageTooLarge) || (err == nil && info.Width != size[0]) {
			t.Fatalf("%v: err = %v info = %+v", size, err, info)
		}
	}
}

func TestScanEndSkipsStuffingRestartsAndFill(t *testing.T) {
	data := []byte{0x11, 0xFF, 0x00, 0x22, 0xFF, 0xD3, 0x33, 0xFF, 0xFF, 0xFF, 0xD9}
	if got := scanEnd(data, 0); got != 7 {
		t.Fatalf("scanEnd = %d", got)
	}
	if got := scanEnd([]byte{0x11, 0xFF, 0x00, 0x22}, 0); got != -1 {
		t.Fatalf("scanEnd = %d", got)
	}
}

func TestExifOrientationReadsBothByteOrders(t *testing.T) {
	for _, order := range []byteOrder{binary.LittleEndian, binary.BigEndian} {
		for v := uint16(1); v <= 8; v++ {
			got, ok := exifOrientation(exifPayload(order, v))
			if !ok || got != v {
				t.Fatalf("%v %d: got %d %v", order, v, got, ok)
			}
		}
	}
	if _, ok := exifOrientation(xmpPayload); ok {
		t.Fatal("XMP is not Exif")
	}
	broken := exifPayload(binary.BigEndian, 6)[:20]
	if got, ok := exifOrientation(broken); !ok || got != 0 {
		t.Fatalf("broken Exif = %d %v", got, ok)
	}
}
