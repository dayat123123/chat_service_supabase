package sanitize

import "encoding/binary"

const (
	webpFlagXMP  = 0x04
	webpFlagEXIF = 0x08
)

func WebP(data []byte) ([]byte, Info, error) {
	if len(data) < 12 || string(data[:4]) != "RIFF" || string(data[8:12]) != "WEBP" {
		return nil, Info{}, invalid("missing RIFF header")
	}
	size := uint64(binary.LittleEndian.Uint32(data[4:]))
	if size < 4 || size > uint64(len(data)-8) {
		return nil, Info{}, invalid("RIFF size")
	}
	var info Info
	if uint64(len(data)) > size+8 {
		info.Removed++
	}
	body := data[12 : size+8]
	var (
		chunks [][]byte
		image  bool
		canvas bool
	)
	for pos := 0; pos < len(body); {
		if pos+8 > len(body) {
			return nil, Info{}, invalid("truncated chunk")
		}
		fourcc := string(body[pos : pos+4])
		n := uint64(binary.LittleEndian.Uint32(body[pos+4:]))
		start := uint64(pos) + 8
		end := start + n + n&1
		if start+n > uint64(len(body)) {
			return nil, Info{}, invalid("chunk size")
		}
		payload := body[start : start+n]
		chunk := body[pos:min(end, uint64(len(body)))]
		pos = int(min(end, uint64(len(body))))
		if n&1 == 1 && uint64(len(chunk)) < 8+n+1 {
			chunk = append(append(make([]byte, 0, len(chunk)+1), chunk...), 0)
		}
		if len(chunks) == 0 && fourcc != "VP8X" && fourcc != "VP8 " && fourcc != "VP8L" {
			return nil, Info{}, invalid("unexpected first chunk")
		}
		switch fourcc {
		case "EXIF", "XMP ":
			info.Removed++
			continue
		case "VP8X":
			if len(chunks) > 0 || n < 10 {
				return nil, Info{}, invalid("VP8X header")
			}
			chunk = append([]byte(nil), chunk...)
			chunk[8] &^= webpFlagEXIF | webpFlagXMP
			info.Width = 1 + int(uint24(payload[4:]))
			info.Height = 1 + int(uint24(payload[7:]))
			canvas = true
		case "VP8 ", "VP8L":
			if image && !canvas {
				return nil, Info{}, invalid("more than one bitstream")
			}
			w, h, err := bitstreamSize(fourcc, payload)
			if err != nil {
				return nil, Info{}, err
			}
			if !canvas {
				info.Width, info.Height = w, h
			}
			image = true
		case "ANMF":
			if !canvas {
				return nil, Info{}, invalid("animation without VP8X")
			}
			info.Frames++
			image = true
		}
		chunks = append(chunks, chunk)
	}
	if !image {
		return nil, Info{}, invalid("no image data")
	}
	if err := checkSize(info.Width, info.Height); err != nil {
		return nil, Info{}, err
	}
	total := 4
	for _, c := range chunks {
		total += len(c)
	}
	out := make([]byte, 0, total+8)
	out = append(out, "RIFF"...)
	out = binary.LittleEndian.AppendUint32(out, uint32(total))
	out = append(out, "WEBP"...)
	for _, c := range chunks {
		out = append(out, c...)
	}
	return out, info, nil
}

func bitstreamSize(fourcc string, p []byte) (int, int, error) {
	if fourcc == "VP8L" {
		if len(p) < 5 || p[0] != 0x2F {
			return 0, 0, invalid("VP8L header")
		}
		bits := binary.LittleEndian.Uint32(p[1:])
		if bits>>29 != 0 {
			return 0, 0, invalid("VP8L version")
		}
		return 1 + int(bits&0x3FFF), 1 + int(bits>>14&0x3FFF), nil
	}
	if len(p) < 10 || p[0]&1 != 0 || p[3] != 0x9D || p[4] != 0x01 || p[5] != 0x2A {
		return 0, 0, invalid("VP8 header")
	}
	return int(binary.LittleEndian.Uint16(p[6:]) & 0x3FFF), int(binary.LittleEndian.Uint16(p[8:]) & 0x3FFF), nil
}

func uint24(b []byte) uint32 {
	return uint32(b[0]) | uint32(b[1])<<8 | uint32(b[2])<<16
}
