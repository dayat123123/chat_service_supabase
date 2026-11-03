package sanitize

import (
	"bytes"
	"encoding/binary"
	"errors"
	"hash/crc32"
	"image/png"
	"testing"
)

func encodePNG(t *testing.T, w, h int) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := png.Encode(&buf, gradient(w, h)); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func pngChunk(kind string, data []byte) []byte {
	out := binary.BigEndian.AppendUint32(nil, uint32(len(data)))
	out = append(out, kind...)
	out = append(out, data...)
	return binary.BigEndian.AppendUint32(out, crc32.ChecksumIEEE(out[4:]))
}

func afterIHDR(base []byte, chunks ...[]byte) []byte {
	out := append([]byte(nil), base[:33]...)
	for _, c := range chunks {
		out = append(out, c...)
	}
	return append(out, base[33:]...)
}

func pngChunkTypes(t *testing.T, data []byte) []string {
	t.Helper()
	var kinds []string
	for pos := 8; pos+12 <= len(data); {
		n := int(binary.BigEndian.Uint32(data[pos:]))
		kinds = append(kinds, string(data[pos+4:pos+8]))
		pos += 12 + n
	}
	return kinds
}

func ihdr(w, h uint32) []byte {
	data := binary.BigEndian.AppendUint32(nil, w)
	data = binary.BigEndian.AppendUint32(data, h)
	return pngChunk("IHDR", append(data, 8, 6, 0, 0, 0))
}

func TestPNGRemovesMetadataLosslessly(t *testing.T) {
	base := encodePNG(t, 13, 7)
	exif := exifPayload(binary.BigEndian, 6)[6:]
	cases := map[string]struct {
		input   []byte
		removed int
		kinds   []string
	}{
		"text, exif, time and trailer": {
			append(afterIHDR(base,
				pngChunk("pHYs", []byte{0, 0, 0x0B, 0x13, 0, 0, 0x0B, 0x13, 1}),
				pngChunk("iDOT", make([]byte, 28)),
				pngChunk("tEXt", []byte("Comment\x00SECRET-COMMENT")),
				pngChunk("zTXt", []byte("Author\x00\x00SECRET-AUTHOR")),
				pngChunk("iTXt", []byte("XML:com.adobe.xmp\x00\x00\x00\x00\x00<x>XMP-SECRET</x>")),
				pngChunk("eXIf", exif),
				pngChunk("tIME", []byte{0x07, 0xEA, 11, 3, 8, 30, 0}),
			), "SECRET-TRAILER"...),
			6, []string{"IHDR", "pHYs", "IDAT", "IEND"},
		},
		"trailer only keeps iDOT": {
			append(afterIHDR(base, pngChunk("iDOT", make([]byte, 28))), "SECRET-TRAILER"...),
			1, []string{"IHDR", "iDOT", "IDAT", "IEND"},
		},
	}
	original, err := png.Decode(bytes.NewReader(base))
	if err != nil {
		t.Fatal(err)
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			out, info, err := PNG(tc.input)
			if err != nil {
				t.Fatal(err)
			}
			mustNotContain(t, out, "SECRET", "tEXt", "zTXt", "iTXt", "eXIf", "tIME", "Exif")
			if info.Width != 13 || info.Height != 7 || info.Removed != tc.removed {
				t.Fatalf("info = %+v", info)
			}
			if got := pngChunkTypes(t, out); !equalStrings(got, tc.kinds) {
				t.Fatalf("chunks = %v", got)
			}
			img, err := png.Decode(bytes.NewReader(out))
			if err != nil {
				t.Fatal(err)
			}
			samePixels(t, original, img)
		})
	}
}

func equalStrings(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func TestPNGWithoutMetadataIsUnchanged(t *testing.T) {
	base := encodePNG(t, 4, 4)
	out, info, err := PNG(base)
	if err != nil || !bytes.Equal(out, base) || info.Removed != 0 {
		t.Fatalf("err = %v info = %+v", err, info)
	}
}

func TestPNGRejects(t *testing.T) {
	base := encodePNG(t, 4, 4)
	badCRC := append([]byte(nil), base...)
	badCRC[45] ^= 0xFF
	idat := bytes.Index(base, []byte("IDAT")) - 4
	iend := bytes.Index(base, []byte("IEND")) - 4
	noIDAT := append(append([]byte(nil), base[:idat]...), base[iend:]...)
	withHeader := func(w, h uint32) []byte {
		return append(append(append([]byte(nil), pngSignature...), ihdr(w, h)...), base[33:]...)
	}
	cases := map[string]struct {
		data []byte
		want error
	}{
		"not a png":         {[]byte("GIF89a"), ErrInvalidImage},
		"bad checksum":      {badCRC, ErrInvalidImage},
		"missing IEND":      {base[:len(base)-12], ErrInvalidImage},
		"truncated":         {base[:len(base)-30], ErrInvalidImage},
		"no IDAT":           {noIDAT, ErrInvalidImage},
		"text before IHDR":  {append(append(append([]byte(nil), pngSignature...), pngChunk("tEXt", []byte("a\x00b"))...), base[8:]...), ErrInvalidImage},
		"bad chunk name":    {afterIHDR(base, pngChunk("t3Xt", nil)), ErrInvalidImage},
		"huge chunk length": {afterIHDR(base, []byte{0xFF, 0xFF, 0xFF, 0xF0, 't', 'E', 'X', 't'}), ErrInvalidImage},
		"zero width":        {withHeader(0, 4), ErrInvalidImage},
		"too tall":          {withHeader(4, 10001), ErrImageTooLarge},
		"too many pixels":   {withHeader(7000, 7000), ErrImageTooLarge},
		"invalid IHDR":      {append(append(append([]byte(nil), pngSignature...), pngChunk("IHDR", append(binary.BigEndian.AppendUint32(binary.BigEndian.AppendUint32(nil, 4), 4), 7, 6, 0, 0, 0))...), base[33:]...), ErrInvalidImage},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			if _, _, err := PNG(tc.data); !errors.Is(err, tc.want) {
				t.Fatalf("err = %v, want %v", err, tc.want)
			}
		})
	}
}
