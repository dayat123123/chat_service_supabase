package sanitize

import (
	"bytes"
	"encoding/binary"
	"image/gif"
)

const (
	gifExtension   = 0x21
	gifImage       = 0x2C
	gifTrailer     = 0x3B
	gifComment     = 0xFE
	gifApplication = 0xFF
)

func GIF(data []byte) ([]byte, Info, error) {
	if len(data) < 13 || (string(data[:6]) != "GIF87a" && string(data[:6]) != "GIF89a") {
		return nil, Info{}, invalid("missing GIF header")
	}
	info := Info{
		Width:  int(binary.LittleEndian.Uint16(data[6:])),
		Height: int(binary.LittleEndian.Uint16(data[8:])),
	}
	if err := checkSize(info.Width, info.Height); err != nil {
		return nil, Info{}, err
	}
	pos := 13 + colorTable(data[10])
	if pos > len(data) {
		return nil, Info{}, invalid("global color table")
	}
	out := make([]byte, 0, len(data))
	out = append(out, data[:pos]...)
	for {
		if pos >= len(data) {
			return nil, Info{}, invalid("missing trailer")
		}
		switch data[pos] {
		case gifExtension:
			if pos+2 > len(data) {
				return nil, Info{}, invalid("truncated extension")
			}
			end, ok := skipSubBlocks(data, pos+2)
			if !ok {
				return nil, Info{}, invalid("extension data")
			}
			if dropExtension(data[pos+1], data[pos+2:end]) {
				info.Removed++
			} else {
				out = append(out, data[pos:end]...)
			}
			pos = end
		case gifImage:
			if pos+10 > len(data) {
				return nil, Info{}, invalid("truncated image descriptor")
			}
			lzw := pos + 10 + colorTable(data[pos+9])
			if lzw >= len(data) {
				return nil, Info{}, invalid("local color table")
			}
			end, ok := skipSubBlocks(data, lzw+1)
			if !ok {
				return nil, Info{}, invalid("image data")
			}
			info.Frames++
			if info.Frames > MaxFrames {
				return nil, Info{}, ErrTooManyFrames
			}
			out = append(out, data[pos:end]...)
			pos = end
		case gifTrailer:
			if info.Frames == 0 {
				return nil, Info{}, invalid("no image data")
			}
			if pos+1 < len(data) {
				info.Removed++
			}
			out = append(out, gifTrailer)
			if _, err := gif.DecodeConfig(bytes.NewReader(out)); err != nil {
				return nil, Info{}, invalid("decode: " + err.Error())
			}
			return out, info, nil
		default:
			return nil, Info{}, invalid("unknown block")
		}
	}
}

func colorTable(packed byte) int {
	if packed&0x80 == 0 {
		return 0
	}
	return 3 << (packed&0x07 + 1)
}

func skipSubBlocks(data []byte, pos int) (int, bool) {
	for pos < len(data) {
		n := int(data[pos])
		pos++
		if n == 0 {
			return pos, true
		}
		pos += n
	}
	return 0, false
}

func dropExtension(label byte, blocks []byte) bool {
	switch label {
	case gifComment:
		return true
	case gifApplication:
		if len(blocks) < 12 || blocks[0] != 11 {
			return true
		}
		id := string(blocks[1:12])
		return id != "NETSCAPE2.0" && id != "ANIMEXTS1.0"
	}
	return false
}
