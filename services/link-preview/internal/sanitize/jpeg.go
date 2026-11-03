package sanitize

import (
	"bytes"
	"encoding/binary"
	"image/jpeg"
)

const (
	markerSOI  = 0xD8
	markerEOI  = 0xD9
	markerSOS  = 0xDA
	markerAPP0 = 0xE0
	markerAPP1 = 0xE1
	markerAPP2 = 0xE2
	markerAPPE = 0xEE
	markerCOM  = 0xFE
	tagOrient  = 0x0112
)

var iccTag = []byte("ICC_PROFILE\x00")

type piece struct {
	marker byte
	data   []byte
}

func JPEG(data []byte) ([]byte, Info, error) {
	if len(data) < 4 || data[0] != 0xFF || data[1] != markerSOI {
		return nil, Info{}, invalid("missing SOI")
	}
	var (
		pieces      []piece
		info        Info
		orientation uint16
		exifSeen    bool
		frame       bool
		scanned     bool
	)
	pos := 2
	for {
		if pos >= len(data) || data[pos] != 0xFF {
			return nil, Info{}, invalid("expected a marker")
		}
		for pos < len(data) && data[pos] == 0xFF {
			pos++
		}
		if pos >= len(data) {
			return nil, Info{}, invalid("truncated marker")
		}
		m := data[pos]
		pos++
		if m == markerEOI {
			if !scanned {
				return nil, Info{}, invalid("no image data")
			}
			if pos < len(data) {
				info.Removed++
			}
			break
		}
		if !lengthMarker(m) {
			return nil, Info{}, invalid("unsupported marker")
		}
		if pos+2 > len(data) {
			return nil, Info{}, invalid("truncated segment")
		}
		n := int(binary.BigEndian.Uint16(data[pos:]))
		if n < 2 || pos+n > len(data) {
			return nil, Info{}, invalid("segment length")
		}
		segment := data[pos-2 : pos+n]
		payload := data[pos+2 : pos+n]
		pos += n
		switch {
		case m == markerAPP0:
			kept, changed := jfif(segment, payload)
			if kept == nil || changed {
				info.Removed++
			}
			if kept != nil {
				pieces = append(pieces, piece{m, kept})
			}
		case m == markerAPP1:
			if !exifSeen && !scanned {
				orientation, exifSeen = exifOrientation(payload)
			}
			info.Removed++
		case m == markerAPP2 && bytes.HasPrefix(payload, iccTag), m == markerAPPE:
			pieces = append(pieces, piece{m, segment})
		case m >= markerAPP0 && m <= 0xEF, m == markerCOM:
			info.Removed++
		case m == markerSOS:
			if !frame {
				return nil, Info{}, invalid("scan before frame header")
			}
			end := scanEnd(data, pos)
			if end < 0 {
				return nil, Info{}, invalid("unterminated scan")
			}
			pieces = append(pieces, piece{m, segment}, piece{0, data[pos:end]})
			pos = end
			scanned = true
		case startOfFrame(m):
			if !frame {
				if len(payload) < 6 {
					return nil, Info{}, invalid("frame header")
				}
				info.Height = int(binary.BigEndian.Uint16(payload[1:]))
				info.Width = int(binary.BigEndian.Uint16(payload[3:]))
				if err := checkSize(info.Width, info.Height); err != nil {
					return nil, Info{}, err
				}
				frame = true
			}
			pieces = append(pieces, piece{m, segment})
		default:
			pieces = append(pieces, piece{m, segment})
		}
	}

	out := make([]byte, 0, len(data))
	out = append(out, 0xFF, markerSOI)
	i := 0
	for ; i < len(pieces) && pieces[i].marker == markerAPP0; i++ {
		out = append(out, pieces[i].data...)
	}
	if orientation > 1 {
		out = append(out, orientationSegment(orientation)...)
	}
	for ; i < len(pieces); i++ {
		out = append(out, pieces[i].data...)
	}
	out = append(out, 0xFF, markerEOI)
	if _, err := jpeg.DecodeConfig(bytes.NewReader(out)); err != nil {
		return nil, Info{}, invalid("decode: " + err.Error())
	}
	if orientation >= 5 {
		info.Width, info.Height = info.Height, info.Width
	}
	return out, info, nil
}

func lengthMarker(m byte) bool {
	switch {
	case m == 0xC8:
		return false
	case m >= 0xC0 && m <= 0xCF:
		return true
	case m >= 0xDA && m <= 0xDF:
		return true
	case m >= markerAPP0 && m <= 0xEF, m == markerCOM:
		return true
	}
	return false
}

func startOfFrame(m byte) bool {
	return m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC
}

func scanEnd(data []byte, pos int) int {
	for {
		i := bytes.IndexByte(data[pos:], 0xFF)
		if i < 0 {
			return -1
		}
		i += pos
		j := i + 1
		for j < len(data) && data[j] == 0xFF {
			j++
		}
		if j >= len(data) {
			return -1
		}
		if next := data[j]; next == 0x00 || (next >= 0xD0 && next <= 0xD7) {
			pos = j + 1
			continue
		}
		return i
	}
}

func jfif(segment, payload []byte) ([]byte, bool) {
	if len(payload) < 14 || string(payload[:5]) != "JFIF\x00" {
		return nil, false
	}
	if len(payload) == 14 && payload[12] == 0 && payload[13] == 0 {
		return segment, false
	}
	out := make([]byte, 0, 18)
	out = append(out, 0xFF, markerAPP0, 0x00, 0x10)
	out = append(out, payload[:12]...)
	return append(out, 0, 0), true
}

func exifOrientation(payload []byte) (uint16, bool) {
	if len(payload) < 6 || string(payload[:5]) != "Exif\x00" {
		return 0, false
	}
	tiff := payload[6:]
	if len(tiff) < 8 {
		return 0, true
	}
	var order binary.ByteOrder
	switch string(tiff[:4]) {
	case "II*\x00":
		order = binary.LittleEndian
	case "MM\x00*":
		order = binary.BigEndian
	default:
		return 0, true
	}
	ifd := uint64(order.Uint32(tiff[4:]))
	if ifd < 8 || ifd+2 > uint64(len(tiff)) {
		return 0, true
	}
	count := uint64(order.Uint16(tiff[ifd:]))
	for k := uint64(0); k < count; k++ {
		entry := ifd + 2 + 12*k
		if entry+12 > uint64(len(tiff)) {
			return 0, true
		}
		if order.Uint16(tiff[entry:]) != tagOrient {
			continue
		}
		if order.Uint16(tiff[entry+2:]) != 3 || order.Uint32(tiff[entry+4:]) != 1 {
			return 0, true
		}
		if v := order.Uint16(tiff[entry+8:]); v >= 1 && v <= 8 {
			return v, true
		}
		return 0, true
	}
	return 0, true
}

func orientationSegment(v uint16) []byte {
	return []byte{
		0xFF, markerAPP1, 0x00, 0x22,
		'E', 'x', 'i', 'f', 0x00, 0x00,
		'M', 'M', 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08,
		0x00, 0x01,
		0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, byte(v >> 8), byte(v), 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00,
	}
}
