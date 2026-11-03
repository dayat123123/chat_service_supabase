package imageprep

import (
	"encoding/binary"
	"fmt"
	"image"
	"image/draw"
	"image/gif"
	"slices"
)

const (
	maxSampledFrames   = 4
	maxAnimationCanvas = 4_000_000
	maxAnimationPixels = 16_000_000
	maxGIFFrames       = 10000
)

type gifLayout struct {
	width  int
	height int
	frames int
	area   int
}

func scanGIF(data []byte) (gifLayout, error) {
	invalid := func(reason string) (gifLayout, error) {
		return gifLayout{}, fmt.Errorf("%w: gif %s", ErrInvalid, reason)
	}
	if len(data) < 13 {
		return invalid("header")
	}
	l := gifLayout{width: int(binary.LittleEndian.Uint16(data[6:])), height: int(binary.LittleEndian.Uint16(data[8:]))}
	pos := 13
	if flags := data[10]; flags&0x80 != 0 {
		pos += 3 << (1 + flags&0x07)
	}
	skipBlocks := func() bool {
		for pos < len(data) {
			n := int(data[pos])
			pos++
			if n == 0 {
				return true
			}
			pos += n
		}
		return false
	}
	for pos < len(data) {
		switch data[pos] {
		case 0x3B:
			if l.frames == 0 {
				return invalid("without frames")
			}
			return l, nil
		case 0x21:
			pos += 2
			if pos > len(data) || !skipBlocks() {
				return invalid("extension")
			}
		case 0x2C:
			if pos+10 > len(data) {
				return invalid("descriptor")
			}
			w := int(binary.LittleEndian.Uint16(data[pos+5:]))
			h := int(binary.LittleEndian.Uint16(data[pos+7:]))
			flags := data[pos+9]
			pos += 10
			if flags&0x80 != 0 {
				pos += 3 << (1 + flags&0x07)
			}
			pos++
			if pos > len(data) || !skipBlocks() {
				return invalid("image data")
			}
			l.frames++
			l.area += w * h
			if l.frames > maxGIFFrames {
				return invalid("frame count")
			}
		default:
			return invalid("block")
		}
	}
	if l.frames == 0 {
		return invalid("without frames")
	}
	return l, nil
}

func sampleIndexes(n int) []int {
	if n <= 0 {
		return nil
	}
	picks := []int{0}
	for i := 1; i < maxSampledFrames; i++ {
		picks = append(picks, i*(n-1)/(maxSampledFrames-1))
	}
	return slices.Compact(picks)
}

func composite(all *gif.GIF, picks []int) []image.Image {
	canvas := image.NewRGBA(image.Rect(0, 0, all.Config.Width, all.Config.Height))
	var out []image.Image
	next := 0
	for i, frame := range all.Image {
		bounds := frame.Bounds().Intersect(canvas.Bounds())
		disposal := byte(0)
		if i < len(all.Disposal) {
			disposal = all.Disposal[i]
		}
		var saved *image.RGBA
		if disposal == gif.DisposalPrevious {
			saved = image.NewRGBA(bounds)
			draw.Draw(saved, bounds, canvas, bounds.Min, draw.Src)
		}
		overlay(canvas, frame, bounds)
		if next < len(picks) && picks[next] == i {
			snapshot := image.NewRGBA(canvas.Bounds())
			copy(snapshot.Pix, canvas.Pix)
			out = append(out, snapshot)
			next++
		}
		switch disposal {
		case gif.DisposalBackground:
			draw.Draw(canvas, bounds, image.Transparent, image.Point{}, draw.Src)
		case gif.DisposalPrevious:
			draw.Draw(canvas, bounds, saved, bounds.Min, draw.Src)
		}
	}
	return out
}

func overlay(canvas *image.RGBA, frame *image.Paletted, bounds image.Rectangle) {
	var palette [256][4]uint8
	for i, c := range frame.Palette {
		if i == len(palette) {
			break
		}
		r, g, b, a := c.RGBA()
		palette[i] = [4]uint8{uint8(r >> 8), uint8(g >> 8), uint8(b >> 8), uint8(a >> 8)}
	}
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		src := frame.PixOffset(bounds.Min.X, y)
		dst := canvas.PixOffset(bounds.Min.X, y)
		for x := bounds.Min.X; x < bounds.Max.X; x, src, dst = x+1, src+1, dst+4 {
			c := palette[frame.Pix[src]]
			if c[3] == 0 {
				continue
			}
			copy(canvas.Pix[dst:dst+4], c[:])
		}
	}
}

type riffChunk struct {
	id   string
	data []byte
}

func riffChunks(data []byte) ([]riffChunk, error) {
	var chunks []riffChunk
	for pos := 0; pos < len(data); {
		if pos+8 > len(data) {
			return nil, fmt.Errorf("%w: webp chunk header", ErrInvalid)
		}
		size := int(binary.LittleEndian.Uint32(data[pos+4:]))
		end := pos + 8 + size
		if size < 0 || end > len(data) || end < pos {
			return nil, fmt.Errorf("%w: webp chunk size", ErrInvalid)
		}
		chunks = append(chunks, riffChunk{id: string(data[pos : pos+4]), data: data[pos+8 : end]})
		pos = end + size&1
	}
	return chunks, nil
}

func firstWebPFrame(data []byte) ([]byte, int, error) {
	if len(data) < 12 {
		return nil, 0, fmt.Errorf("%w: webp header", ErrInvalid)
	}
	size := int(binary.LittleEndian.Uint32(data[4:]))
	body := data[12:]
	if size >= 4 && size-4 < len(body) {
		body = body[:size-4]
	}
	chunks, err := riffChunks(body)
	if err != nil {
		return nil, 0, err
	}
	if len(chunks) == 0 || chunks[0].id != "VP8X" || len(chunks[0].data) < 10 || chunks[0].data[0]&0x02 == 0 {
		return data, 1, nil
	}
	frames := 0
	var first []byte
	for _, c := range chunks {
		if c.id == "ANMF" {
			if frames == 0 {
				first = c.data
			}
			frames++
		}
	}
	if first == nil || len(first) < 16 {
		return nil, 0, fmt.Errorf("%w: webp animation without frames", ErrInvalid)
	}
	w := 1 + int(uint32(first[6])|uint32(first[7])<<8|uint32(first[8])<<16)
	h := 1 + int(uint32(first[9])|uint32(first[10])<<8|uint32(first[11])<<16)
	if err := checkSize(w, h); err != nil {
		return nil, 0, err
	}
	sub, err := riffChunks(first[16:])
	if err != nil {
		return nil, 0, err
	}
	var alpha, bitstream *riffChunk
	for i := range sub {
		switch sub[i].id {
		case "ALPH":
			if alpha == nil {
				alpha = &sub[i]
			}
		case "VP8 ", "VP8L":
			if bitstream == nil {
				bitstream = &sub[i]
			}
		}
	}
	if bitstream == nil {
		return nil, 0, fmt.Errorf("%w: webp frame without bitstream", ErrInvalid)
	}
	var out []riffChunk
	if alpha != nil && bitstream.id == "VP8 " {
		header := make([]byte, 10)
		header[0] = 0x10
		putUint24(header[4:], uint32(w-1))
		putUint24(header[7:], uint32(h-1))
		out = append(out, riffChunk{id: "VP8X", data: header}, *alpha)
	}
	out = append(out, *bitstream)
	return buildRIFF(out), frames, nil
}

func putUint24(b []byte, v uint32) {
	b[0], b[1], b[2] = byte(v), byte(v>>8), byte(v>>16)
}

func buildRIFF(chunks []riffChunk) []byte {
	out := []byte("RIFF\x00\x00\x00\x00WEBP")
	for _, c := range chunks {
		out = append(out, c.id...)
		out = binary.LittleEndian.AppendUint32(out, uint32(len(c.data)))
		out = append(out, c.data...)
		if len(c.data)%2 == 1 {
			out = append(out, 0)
		}
	}
	binary.LittleEndian.PutUint32(out[4:], uint32(len(out)-8))
	return out
}
