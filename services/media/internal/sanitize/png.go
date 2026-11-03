package sanitize

import (
	"bytes"
	"encoding/binary"
	"hash/crc32"
	"image/png"
)

var (
	pngSignature = []byte("\x89PNG\r\n\x1a\n")
	pngMetadata  = map[string]bool{"tEXt": true, "zTXt": true, "iTXt": true, "eXIf": true, "tIME": true}
)

func PNG(data []byte) ([]byte, Info, error) {
	if !bytes.HasPrefix(data, pngSignature) {
		return nil, Info{}, invalid("missing signature")
	}
	var (
		chunks  [][]byte
		info    Info
		dropped bool
		idat    bool
	)
	pos := len(pngSignature)
	for {
		if pos+12 > len(data) {
			return nil, Info{}, invalid("truncated chunk")
		}
		n := uint64(binary.BigEndian.Uint32(data[pos:]))
		kind := string(data[pos+4 : pos+8])
		end := uint64(pos) + 12 + n
		if n > 0x7FFFFFFF || end > uint64(len(data)) || !chunkName(kind) {
			return nil, Info{}, invalid("chunk header")
		}
		if crc32.ChecksumIEEE(data[pos+4:end-4]) != binary.BigEndian.Uint32(data[end-4:]) {
			return nil, Info{}, invalid("chunk checksum")
		}
		chunk := data[pos:end]
		pos = int(end)
		if len(chunks) == 0 {
			if kind != "IHDR" || n != 13 {
				return nil, Info{}, invalid("IHDR must come first")
			}
			info.Width = int(binary.BigEndian.Uint32(chunk[8:]))
			info.Height = int(binary.BigEndian.Uint32(chunk[12:]))
			if err := checkSize(info.Width, info.Height); err != nil {
				return nil, Info{}, err
			}
		}
		if pngMetadata[kind] {
			info.Removed++
			dropped = true
			continue
		}
		switch kind {
		case "IDAT":
			idat = true
		case "IEND":
			if n != 0 {
				return nil, Info{}, invalid("IEND length")
			}
			if pos < len(data) {
				info.Removed++
			}
			chunks = append(chunks, chunk)
			if !idat {
				return nil, Info{}, invalid("no image data")
			}
			return renderPNG(chunks, dropped, info)
		}
		chunks = append(chunks, chunk)
	}
}

func renderPNG(chunks [][]byte, dropped bool, info Info) ([]byte, Info, error) {
	size := len(pngSignature)
	for _, c := range chunks {
		size += len(c)
	}
	out := make([]byte, 0, size)
	out = append(out, pngSignature...)
	for _, c := range chunks {
		if dropped && string(c[4:8]) == "iDOT" {
			continue
		}
		out = append(out, c...)
	}
	if _, err := png.DecodeConfig(bytes.NewReader(out)); err != nil {
		return nil, Info{}, invalid("decode: " + err.Error())
	}
	return out, info, nil
}

func chunkName(s string) bool {
	for i := 0; i < len(s); i++ {
		c := s[i]
		if (c < 'A' || c > 'Z') && (c < 'a' || c > 'z') {
			return false
		}
	}
	return true
}
