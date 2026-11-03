package sanitize

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"testing"
)

func decode64(t *testing.T, s string) []byte {
	t.Helper()
	b, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func webpChunk(fourcc string, payload []byte) []byte {
	out := append([]byte(fourcc), binary.LittleEndian.AppendUint32(nil, uint32(len(payload)))...)
	out = append(out, payload...)
	if len(payload)%2 == 1 {
		out = append(out, 0)
	}
	return out
}

func riff(chunks ...[]byte) []byte {
	body := []byte("WEBP")
	for _, c := range chunks {
		body = append(body, c...)
	}
	out := append([]byte("RIFF"), binary.LittleEndian.AppendUint32(nil, uint32(len(body)))...)
	return append(out, body...)
}

func vp8x(flags byte, w, h int) []byte {
	p := []byte{flags, 0, 0, 0}
	p = append(p, byte(w-1), byte((w-1)>>8), byte((w-1)>>16))
	p = append(p, byte(h-1), byte((h-1)>>8), byte((h-1)>>16))
	return webpChunk("VP8X", p)
}

func TestWebPRemovesMetadata(t *testing.T) {
	lossless := decode64(t, "UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==")
	lossy := decode64(t, "UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA")
	bitstream := lossless[12:]
	exif := exifPayload(binary.LittleEndian, 6)
	xmp := []byte(`<x:xmpmeta>XMP-SECRET-CREATOR</x:xmpmeta>`)
	frame := webpChunk("ANMF", append(make([]byte, 16), bitstream...))
	anim := webpChunk("ANIM", make([]byte, 6))
	unpadded := append([]byte(nil), lossless[:len(lossless)-1]...)
	binary.LittleEndian.PutUint32(unpadded[4:], uint32(len(unpadded)-8))

	cases := map[string]struct {
		input   []byte
		want    []byte
		width   int
		height  int
		frames  int
		removed int
	}{
		"extended with EXIF and XMP": {
			append(riff(vp8x(0x10|webpFlagEXIF|webpFlagXMP, 1, 1), bitstream, webpChunk("EXIF", exif), webpChunk("XMP ", xmp)), "SECRET-TRAILER"...),
			riff(vp8x(0x10, 1, 1), bitstream), 1, 1, 0, 3,
		},
		"metadata before bitstream, ICC kept": {
			riff(vp8x(0x20|webpFlagEXIF, 640, 480), webpChunk("ICCP", []byte("ICC-PROFILE")), webpChunk("EXIF", exif), bitstream),
			riff(vp8x(0x20, 640, 480), webpChunk("ICCP", []byte("ICC-PROFILE")), bitstream), 640, 480, 0, 1,
		},
		"animated": {
			riff(vp8x(0x02|webpFlagEXIF, 3, 2), anim, frame, frame, webpChunk("EXIF", exif)),
			riff(vp8x(0x02, 3, 2), anim, frame, frame), 3, 2, 2, 1,
		},
		"simple lossless with trailer": {append(append([]byte(nil), lossless...), "SECRET"...), lossless, 1, 1, 0, 1},
		"simple lossy":                 {lossy, lossy, 1, 1, 0, 0},
		"missing final pad byte":       {unpadded, lossless, 1, 1, 0, 0},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			input := append([]byte(nil), tc.input...)
			out, info, err := WebP(input)
			if err != nil {
				t.Fatal(err)
			}
			if !bytes.Equal(input, tc.input) {
				t.Fatal("input was modified")
			}
			mustNotContain(t, out, "SECRET", "EXIF", "XMP ")
			if !bytes.Equal(out, tc.want) {
				t.Fatalf("out  = %x\nwant = %x", out, tc.want)
			}
			if got := binary.LittleEndian.Uint32(out[4:]); int(got) != len(out)-8 {
				t.Fatalf("RIFF size %d for %d bytes", got, len(out))
			}
			if info.Width != tc.width || info.Height != tc.height || info.Frames != tc.frames || info.Removed != tc.removed {
				t.Fatalf("info = %+v", info)
			}
		})
	}
}

func TestWebPRejects(t *testing.T) {
	lossless := decode64(t, "UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==")
	bitstream := lossless[12:]
	vp8l := func(header []byte) []byte { return webpChunk("VP8L", append(header, 0x07, 0x10, 0x11, 0x11)) }
	vp8 := func(tag byte, code []byte) []byte {
		return webpChunk("VP8 ", append(append([]byte{tag, 0x01, 0x00}, code...), 0x01, 0x00, 0x01, 0x00, 0x0E, 0xC0))
	}
	oversized := append([]byte(nil), lossless...)
	binary.LittleEndian.PutUint32(oversized[4:], uint32(len(oversized)))
	cases := map[string]struct {
		data []byte
		want error
	}{
		"not riff":            {[]byte("RIFX\x00\x00\x00\x00WEBP"), ErrInvalidImage},
		"riff size too large": {oversized, ErrInvalidImage},
		"riff size too small": {append([]byte("RIFF\x02\x00\x00\x00WEBP"), bitstream...), ErrInvalidImage},
		"EXIF first":          {riff(webpChunk("EXIF", []byte("x")), bitstream), ErrInvalidImage},
		"VP8X only":           {riff(vp8x(0, 1, 1)), ErrInvalidImage},
		"VP8X not first":      {riff(bitstream, vp8x(0, 1, 1)), ErrInvalidImage},
		"short VP8X":          {riff(webpChunk("VP8X", []byte{0, 0, 0, 0})), ErrInvalidImage},
		"bad VP8L signature":  {riff(vp8l([]byte{0x2E, 0, 0, 0, 0x10})), ErrInvalidImage},
		"bad VP8L version":    {riff(vp8l([]byte{0x2F, 0, 0, 0, 0x30})), ErrInvalidImage},
		"bad VP8 start code":  {riff(vp8(0x30, []byte{0x9D, 0x01, 0x2B})), ErrInvalidImage},
		"VP8 not a keyframe":  {riff(vp8(0x31, []byte{0x9D, 0x01, 0x2A})), ErrInvalidImage},
		"two bitstreams":      {riff(bitstream, bitstream), ErrInvalidImage},
		"frame without VP8X":  {riff(bitstream, webpChunk("ANMF", make([]byte, 16))), ErrInvalidImage},
		"chunk past the end":  {riff(bitstream[:8]), ErrInvalidImage},
		"canvas too wide":     {riff(vp8x(0, 10001, 1), bitstream), ErrImageTooLarge},
		"canvas too large":    {riff(vp8x(0, 8000, 8000), bitstream), ErrImageTooLarge},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			if _, _, err := WebP(tc.data); !errors.Is(err, tc.want) {
				t.Fatalf("err = %v, want %v", err, tc.want)
			}
		})
	}
}
