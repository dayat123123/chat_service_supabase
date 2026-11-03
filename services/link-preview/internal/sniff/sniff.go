package sniff

import "bytes"

type Kind int

const (
	Unknown Kind = iota
	JPEG
	PNG
	WebP
	GIF
)

var kinds = map[Kind]struct{ name, mime, ext string }{
	Unknown: {"unknown", "application/octet-stream", ""},
	JPEG:    {"jpeg", "image/jpeg", "jpg"},
	PNG:     {"png", "image/png", "png"},
	WebP:    {"webp", "image/webp", "webp"},
	GIF:     {"gif", "image/gif", "gif"},
}

func Detect(b []byte) Kind {
	switch {
	case len(b) >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF:
		return JPEG
	case bytes.HasPrefix(b, []byte("\x89PNG\r\n\x1a\n")):
		return PNG
	case len(b) >= 12 && string(b[:4]) == "RIFF" && string(b[8:12]) == "WEBP":
		return WebP
	case bytes.HasPrefix(b, []byte("GIF87a")), bytes.HasPrefix(b, []byte("GIF89a")):
		return GIF
	}
	return Unknown
}

func (k Kind) String() string {
	return kinds[k].name
}

func (k Kind) MIME() string {
	return kinds[k].mime
}

func (k Kind) Ext() string {
	return kinds[k].ext
}

func (k Kind) Image() bool {
	return k == JPEG || k == PNG || k == WebP || k == GIF
}
