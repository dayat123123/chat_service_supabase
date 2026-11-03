package imageprep

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"image"
	"image/color"
	"image/gif"
	"image/jpeg"
	"image/png"
	"math"
	"testing"
)

const (
	webpLosslessRed   = "UklGRhwAAABXRUJQVlA4TA8AAAAvA4AAAAcQ/Y/+ByKi/wEA"
	webpLossyAlpha    = "UklGRmgAAABXRUJQVlA4WAoAAAAQAAAADwAADwAAQUxQSA8AAAABEBIQ/p+WZDUiJsAkfwEAVlA4IDIAAADwAQCdASoQABAAAMASJaACdLoB+AAETAAA/v5mof/60c/XRP9aOf+tHP/lKotU24oAAA=="
	webpAnimatedRedBl = "UklGRoQAAABXRUJQVlA4WAoAAAACAAAAAwAAAwAAQU5JTQYAAAAAAAAAAABBTk1GKAAAAAAAAAAAAAMAAAMAAGQAAAJWUDhMDwAAAC8DwAAABxD9j/4HIqL/AQBBTk1GKAAAAAAAAAAAAAMAAAMAAGQAAABWUDhMDwAAAC8DwAAABxDR//4HIqL/AQA="
)

var unit = Prep{Side: 8, CropPct: 0.875, Std: [3]float32{1, 1, 1}}

func b64(t *testing.T, s string) []byte {
	t.Helper()
	b, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func solid(w, h int, c color.Color) *image.NRGBA {
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.Set(x, y, c)
		}
	}
	return img
}

func encodePNG(t *testing.T, img image.Image) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func encodeJPEG(t *testing.T, img image.Image) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: 95}); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func paletted(w, h int, idx uint8, palette color.Palette) *image.Paletted {
	img := image.NewPaletted(image.Rect(0, 0, w, h), palette)
	for i := range img.Pix {
		img.Pix[i] = idx
	}
	return img
}

func encodeGIF(t *testing.T, frames []*image.Paletted, disposal []byte) []byte {
	t.Helper()
	var buf bytes.Buffer
	g := &gif.GIF{Image: frames, Delay: make([]int, len(frames)), Disposal: disposal}
	if err := gif.EncodeAll(&buf, g); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func mean(v []float32) float64 {
	var s float64
	for _, x := range v {
		s += float64(x)
	}
	return s / float64(len(v))
}

func channels(t *testing.T, view []float32, side int) [3]float64 {
	t.Helper()
	plane := side * side
	if len(view) != 3*plane {
		t.Fatalf("len = %d", len(view))
	}
	return [3]float64{mean(view[:plane]), mean(view[plane : 2*plane]), mean(view[2*plane:])}
}

func near(a, b float64) bool {
	return math.Abs(a-b) < 0.02
}

func expectRGB(t *testing.T, got [3]float64, r, g, b float64) {
	t.Helper()
	if !near(got[0], r) || !near(got[1], g) || !near(got[2], b) {
		t.Fatalf("rgb = %v, want %v %v %v", got, r, g, b)
	}
}

func TestDetect(t *testing.T) {
	cases := map[string]Kind{
		"\xFF\xD8\xFF\xE0": JPEG, "\x89PNG\r\n\x1a\nxx": PNG, "GIF89a..": GIF, "GIF87a..": GIF,
		"RIFF\x00\x00\x00\x00WEBPVP8L": WebP, "RIFF\x00\x00\x00\x00WAVE": "", "<svg/>": "", "": "",
	}
	for in, want := range cases {
		if got := Detect([]byte(in)); got != want {
			t.Fatalf("%q: %q", in, got)
		}
	}
}

func TestDecodeStillImages(t *testing.T) {
	red := solid(20, 10, color.NRGBA{R: 255, A: 255})
	cases := map[string]struct {
		data      []byte
		kind      Kind
		w, h      int
		r, g, b   float64
		tolerance bool
	}{
		"png":           {encodePNG(t, red), PNG, 20, 10, 1, 0, 0, false},
		"jpeg":          {encodeJPEG(t, red), JPEG, 20, 10, 1, 0, 0, true},
		"webp lossless": {b64(t, webpLosslessRed), WebP, 4, 3, 1, 0, 0, false},
		"gif":           {encodeGIF(t, []*image.Paletted{paletted(6, 4, 1, color.Palette{color.Black, color.RGBA{G: 255, A: 255}})}, nil), GIF, 6, 4, 0, 1, 0, false},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			d, err := Decode(tc.data)
			if err != nil {
				t.Fatal(err)
			}
			if d.Kind != tc.kind || d.Width != tc.w || d.Height != tc.h || d.TotalFrames != 1 || len(d.Frames) != 1 {
				t.Fatalf("decoded = %+v", d)
			}
			views := unit.Tensors(d.Frames[0])
			for _, v := range views {
				got := channels(t, v, unit.Side)
				if tc.tolerance {
					if math.Abs(got[0]-tc.r) > 0.1 || math.Abs(got[1]-tc.g) > 0.1 || math.Abs(got[2]-tc.b) > 0.1 {
						t.Fatalf("rgb = %v", got)
					}
					continue
				}
				expectRGB(t, got, tc.r, tc.g, tc.b)
			}
		})
	}
}

func TestDecodeWebPWithAlphaCompositesOverWhite(t *testing.T) {
	d, err := Decode(b64(t, webpLossyAlpha))
	if err != nil {
		t.Fatal(err)
	}
	if d.Width != 16 || d.Height != 16 {
		t.Fatalf("decoded = %+v", d)
	}
	views := Prep{Side: 16, CropPct: 1, Std: [3]float32{1, 1, 1}}.Tensors(d.Frames[0])
	if len(views) != 1 {
		t.Fatalf("square image with crop 1 must give one view, got %d", len(views))
	}
	plane := 16 * 16
	left, right := views[0][2*plane+2*16+1], views[0][16*16+5*16+14]
	if left < 0.9 || right < 0.95 || views[0][5*16+2] > 0.15 {
		t.Fatalf("left blue = %v, right green = %v, left red = %v", left, right, views[0][5*16+2])
	}
}

func TestDecodeAnimatedWebPUsesTheFirstFrame(t *testing.T) {
	d, err := Decode(b64(t, webpAnimatedRedBl))
	if err != nil {
		t.Fatal(err)
	}
	if d.Kind != WebP || d.TotalFrames != 2 || len(d.Frames) != 1 || d.Width != 4 || d.Height != 4 {
		t.Fatalf("decoded = %+v", d)
	}
	expectRGB(t, channels(t, unit.Tensors(d.Frames[0])[0], unit.Side), 1, 0, 0)
}

func webpChunk(id string, payload []byte) []byte {
	out := append([]byte(id), binary.LittleEndian.AppendUint32(nil, uint32(len(payload)))...)
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
	return append(append([]byte("RIFF"), binary.LittleEndian.AppendUint32(nil, uint32(len(body)))...), body...)
}

func TestDecodeAnimatedWebPFrameWithAlpha(t *testing.T) {
	still := b64(t, webpLossyAlpha)
	chunks, err := riffChunks(still[12:])
	if err != nil || len(chunks) != 3 || chunks[1].id != "ALPH" || chunks[2].id != "VP8 " {
		t.Fatalf("chunks = %v err = %v", len(chunks), err)
	}
	header := make([]byte, 16)
	putUint24(header[6:], 15)
	putUint24(header[9:], 15)
	frame := append(append(header, webpChunk("ALPH", chunks[1].data)...), webpChunk("VP8 ", chunks[2].data)...)
	vp8x := make([]byte, 10)
	vp8x[0] = 0x12
	putUint24(vp8x[4:], 15)
	putUint24(vp8x[7:], 15)
	data := riff(webpChunk("VP8X", vp8x), webpChunk("ANIM", make([]byte, 6)), webpChunk("ANMF", frame))
	d, err := Decode(data)
	if err != nil {
		t.Fatal(err)
	}
	if d.TotalFrames != 1 || d.Width != 16 {
		t.Fatalf("decoded = %+v", d)
	}
	if _, ok := d.Frames[0].(*image.NYCbCrA); !ok {
		t.Fatalf("frame type %T, want alpha", d.Frames[0])
	}
}

func TestDecodeAnimatedWebPRejectsBrokenFrames(t *testing.T) {
	vp8x := make([]byte, 10)
	vp8x[0] = 0x02
	cases := map[string][]byte{
		"no frames":    riff(webpChunk("VP8X", vp8x), webpChunk("ANIM", make([]byte, 6))),
		"no bitstream": riff(webpChunk("VP8X", vp8x), webpChunk("ANMF", make([]byte, 16))),
		"bad chunk":    append(riff(webpChunk("VP8X", vp8x)), "ANMF\xFF\xFF\x00\x00"...),
	}
	for name, data := range cases {
		binary.LittleEndian.PutUint32(data[4:], uint32(len(data)-8))
		if _, err := Decode(data); !errors.Is(err, ErrInvalid) {
			t.Fatalf("%s: err = %v", name, err)
		}
	}
}

func TestDecodeAnimatedGIFSamplesCompositedFrames(t *testing.T) {
	palette := color.Palette{color.Transparent, color.RGBA{R: 255, A: 255}, color.RGBA{G: 255, A: 255}, color.RGBA{B: 255, A: 255}}
	full := paletted(8, 8, 1, palette)
	var frames []*image.Paletted
	frames = append(frames, full)
	for i := 0; i < 5; i++ {
		f := image.NewPaletted(image.Rect(0, 0, 4, 8), palette)
		for j := range f.Pix {
			f.Pix[j] = uint8(2 + i%2)
		}
		frames = append(frames, f)
	}
	d, err := Decode(encodeGIF(t, frames, nil))
	if err != nil {
		t.Fatal(err)
	}
	if d.TotalFrames != 6 || len(d.Frames) != 4 {
		t.Fatalf("frames = %d sampled = %d", d.TotalFrames, len(d.Frames))
	}
	full8 := Prep{Side: 8, CropPct: 1, Std: [3]float32{1, 1, 1}}
	expectRGB(t, channels(t, full8.Tensors(d.Frames[0])[0], 8), 1, 0, 0)
	expectRGB(t, channels(t, full8.Tensors(d.Frames[3])[0], 8), 0.5, 0.5, 0)
}

func TestDecodeGIFDisposalBackgroundClearsToWhite(t *testing.T) {
	palette := color.Palette{color.Transparent, color.RGBA{R: 255, A: 255}, color.RGBA{B: 255, A: 255}}
	small := image.NewPaletted(image.Rect(0, 0, 2, 4), palette)
	for i := range small.Pix {
		small.Pix[i] = 2
	}
	d, err := Decode(encodeGIF(t, []*image.Paletted{paletted(4, 4, 1, palette), small, paletted(4, 4, 0, palette)},
		[]byte{gif.DisposalBackground, gif.DisposalNone, gif.DisposalNone}))
	if err != nil {
		t.Fatal(err)
	}
	p := Prep{Side: 4, CropPct: 1, Std: [3]float32{1, 1, 1}}
	expectRGB(t, channels(t, p.Tensors(d.Frames[len(d.Frames)-1])[0], 4), 0.5, 0.5, 1)
	expectRGB(t, channels(t, p.Tensors(d.Frames[0])[0], 4), 1, 0, 0)
}

func TestDecodeHugeAnimationUsesOnlyTheFirstFrame(t *testing.T) {
	palette := color.Palette{color.Black, color.White}
	frames := []*image.Paletted{paletted(1000, 1000, 1, palette)}
	for i := 0; i < 16; i++ {
		frames = append(frames, paletted(1000, 1000, 0, palette))
	}
	d, err := Decode(encodeGIF(t, frames, nil))
	if err != nil {
		t.Fatal(err)
	}
	if d.TotalFrames != 17 || len(d.Frames) != 1 {
		t.Fatalf("frames = %d sampled = %d", d.TotalFrames, len(d.Frames))
	}
}

func TestDecodeRejects(t *testing.T) {
	wide := encodePNG(t, image.NewGray(image.Rect(0, 0, MaxSide+1, 1)))
	pngData := encodePNG(t, solid(4, 4, color.White))
	gifData := encodeGIF(t, []*image.Paletted{paletted(2, 2, 0, color.Palette{color.Black})}, nil)
	cases := map[string]struct {
		data []byte
		want error
	}{
		"text":              {[]byte("hello"), ErrUnsupported},
		"truncated png":     {pngData[:40], ErrInvalid},
		"png too wide":      {wide, ErrTooLarge},
		"truncated jpeg":    {encodeJPEG(t, solid(8, 8, color.White))[:30], ErrInvalid},
		"gif header":        {[]byte("GIF89a\x01"), ErrInvalid},
		"gif without frame": {[]byte("GIF89a\x01\x00\x01\x00\x00\x00\x00\x3B"), ErrInvalid},
		"gif unknown block": {[]byte("GIF89a\x01\x00\x01\x00\x00\x00\x00\x99"), ErrInvalid},
		"gif truncated":     {gifData[:len(gifData)-4], ErrInvalid},
		"webp garbage":      {riff(webpChunk("VP8L", []byte{1, 2, 3})), ErrInvalid},
	}
	for name, tc := range cases {
		if _, err := Decode(tc.data); !errors.Is(err, tc.want) {
			t.Fatalf("%s: err = %v, want %v", name, err, tc.want)
		}
	}
}

func TestTensorsCropTheCenterAndKeepTheFullFrame(t *testing.T) {
	img := solid(300, 100, color.Black)
	for y := 0; y < 100; y++ {
		for x := 100; x < 200; x++ {
			img.Set(x, y, color.White)
		}
	}
	views := unit.Tensors(img)
	if len(views) != 2 {
		t.Fatalf("views = %d", len(views))
	}
	expectRGB(t, channels(t, views[0], 8), 1, 1, 1)
	expectRGB(t, channels(t, views[1], 8), 1.0/3, 1.0/3, 1.0/3)
}

func TestTensorsNormalizeAndHandleTransparency(t *testing.T) {
	p := Prep{Side: 4, CropPct: 1, Mean: [3]float32{0.5, 0.5, 0.5}, Std: [3]float32{0.5, 0.5, 0.5}}
	expectRGB(t, channels(t, p.Tensors(solid(4, 4, color.NRGBA{R: 255, A: 255}))[0], 4), 1, -1, -1)
	expectRGB(t, channels(t, p.Tensors(solid(4, 4, color.NRGBA{A: 0}))[0], 4), 1, 1, 1)

	half := image.NewRGBA(image.Rect(0, 0, 4, 4))
	for i := 0; i < len(half.Pix); i += 4 {
		half.Pix[i], half.Pix[i+3] = 128, 128
	}
	unitP := Prep{Side: 4, CropPct: 1, Std: [3]float32{1, 1, 1}}
	expectRGB(t, channels(t, unitP.Tensors(half)[0], 4), 1, 127.0/255, 127.0/255)

	gray := image.NewGray(image.Rect(0, 0, 4, 4))
	for i := range gray.Pix {
		gray.Pix[i] = 51
	}
	expectRGB(t, channels(t, unitP.Tensors(gray)[0], 4), 0.2, 0.2, 0.2)

	transparentIndex := paletted(4, 4, 0, color.Palette{color.Transparent, color.Black})
	expectRGB(t, channels(t, unitP.Tensors(transparentIndex)[0], 4), 1, 1, 1)

	cmyk := image.NewCMYK(image.Rect(0, 0, 4, 4))
	for i := 0; i < len(cmyk.Pix); i += 4 {
		cmyk.Pix[i+3] = 255
	}
	expectRGB(t, channels(t, unitP.Tensors(cmyk)[0], 4), 0, 0, 0)
}

func TestTensorsUpscaleTinyImages(t *testing.T) {
	views := Prep{Side: 32, CropPct: 0.875, Std: [3]float32{1, 1, 1}}.Tensors(solid(1, 1, color.NRGBA{B: 255, A: 255}))
	if len(views) != 1 {
		t.Fatalf("views = %d", len(views))
	}
	expectRGB(t, channels(t, views[0], 32), 0, 0, 1)
}

func TestSampleIndexes(t *testing.T) {
	cases := map[int][]int{1: {0}, 2: {0, 1}, 3: {0, 1, 2}, 4: {0, 1, 2, 3}, 10: {0, 3, 6, 9}, 500: {0, 166, 332, 499}}
	for n, want := range cases {
		got := sampleIndexes(n)
		if len(got) != len(want) {
			t.Fatalf("%d: %v", n, got)
		}
		for i := range got {
			if got[i] != want[i] {
				t.Fatalf("%d: %v", n, got)
			}
		}
	}
}
