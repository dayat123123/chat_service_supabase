package sniff

import (
	"archive/zip"
	"bytes"
	"encoding/xml"
	"io"
	"strings"
	"unicode/utf8"
)

type Kind int

const (
	Unknown Kind = iota
	JPEG
	PNG
	WebP
	GIF
	PDF
	DOCX
	XLSX
	PPTX
	TXT
	CSV
	MP4
	MOV
	WebM
)

const maxContentTypes = 1 << 20

var kinds = map[Kind]struct{ name, mime, ext string }{
	Unknown: {"unknown", "application/octet-stream", ""},
	JPEG:    {"jpeg", "image/jpeg", "jpg"},
	PNG:     {"png", "image/png", "png"},
	WebP:    {"webp", "image/webp", "webp"},
	GIF:     {"gif", "image/gif", "gif"},
	PDF:     {"pdf", "application/pdf", "pdf"},
	DOCX:    {"docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "docx"},
	XLSX:    {"xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "xlsx"},
	PPTX:    {"pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation", "pptx"},
	TXT:     {"txt", "text/plain", "txt"},
	CSV:     {"csv", "text/csv", "csv"},
	MP4:     {"mp4", "video/mp4", "mp4"},
	MOV:     {"mov", "video/quicktime", "mov"},
	WebM:    {"webm", "video/webm", "webm"},
}

var officeMain = map[string]Kind{
	"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml":   DOCX,
	"application/vnd.ms-word.document.macroenabled.main+xml":                             DOCX,
	"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml":         XLSX,
	"application/vnd.ms-excel.sheet.macroenabled.main+xml":                               XLSX,
	"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml": PPTX,
	"application/vnd.ms-powerpoint.presentation.macroenabled.main+xml":                   PPTX,
}

var textExtensions = map[string]Kind{"txt": TXT, "log": TXT, "csv": CSV}

var mp4Brands = map[string]bool{
	"isom": true, "iso2": true, "iso3": true, "iso4": true, "iso5": true, "iso6": true, "iso7": true, "iso8": true,
	"iso9": true, "mp41": true, "mp42": true, "avc1": true, "mmp4": true, "M4V ": true, "M4VP": true, "MSNV": true,
	"dash": true, "f4v ": true, "XAVC": true, "3gp4": true, "3gp5": true, "3gp6": true, "3g2a": true, "av01": true,
	"hvc1": true, "hev1": true,
}

var stillBrands = map[string]bool{
	"heic": true, "heix": true, "heim": true, "heis": true, "hevc": true, "hevx": true, "mif1": true, "msf1": true,
	"avif": true, "avis": true, "M4A ": true, "M4B ": true, "M4P ": true, "jp2 ": true, "crx ": true,
}

var markup = []string{"<!doctype", "<html", "<svg", "<?xml", "<script", "<head", "<body", "<iframe", "<object"}

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
	case bytes.HasPrefix(b, []byte("%PDF-")):
		return PDF
	case bytes.HasPrefix(b, []byte("PK\x03\x04")):
		return office(b)
	case len(b) >= 12 && string(b[4:8]) == "ftyp":
		return isoMedia(b)
	case bytes.HasPrefix(b, []byte{0x1A, 0x45, 0xDF, 0xA3}):
		return ebml(b)
	}
	return Unknown
}

func DetectName(b []byte, name string) Kind {
	if k := Detect(b); k != Unknown {
		return k
	}
	k, ok := textExtensions[Extension(name)]
	if !ok || !Text(b) || Markup(b) {
		return Unknown
	}
	return k
}

func Extension(name string) string {
	i := strings.LastIndexByte(name, '.')
	if i < 0 || strings.ContainsRune(name[i:], '/') {
		return ""
	}
	return strings.ToLower(name[i+1:])
}

func TextExtension(name string) bool {
	_, ok := textExtensions[Extension(name)]
	return ok
}

func Text(b []byte) bool {
	b = bytes.TrimPrefix(b, []byte("\xEF\xBB\xBF"))
	return len(b) > 0 && bytes.IndexByte(b, 0) < 0 && utf8.Valid(b)
}

func Markup(b []byte) bool {
	head := bytes.TrimLeft(bytes.TrimPrefix(b, []byte("\xEF\xBB\xBF")), " \t\r\n\f")
	head = bytes.ToLower(head[:min(len(head), 16)])
	for _, m := range markup {
		if bytes.HasPrefix(head, []byte(m)) {
			return true
		}
	}
	return false
}

func office(b []byte) Kind {
	r, err := zip.NewReader(bytes.NewReader(b), int64(len(b)))
	if err != nil {
		return Unknown
	}
	for _, f := range r.File {
		if f.Name != "[Content_Types].xml" {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			return Unknown
		}
		kind := mainPart(io.LimitReader(rc, maxContentTypes))
		rc.Close()
		return kind
	}
	return Unknown
}

func mainPart(r io.Reader) Kind {
	var types struct {
		Overrides []struct {
			PartName    string `xml:"PartName,attr"`
			ContentType string `xml:"ContentType,attr"`
		} `xml:"Override"`
	}
	if err := xml.NewDecoder(r).Decode(&types); err != nil {
		return Unknown
	}
	found := Unknown
	for _, o := range types.Overrides {
		k, ok := officeMain[strings.ToLower(strings.TrimSpace(o.ContentType))]
		if !ok {
			continue
		}
		if found != Unknown && found != k {
			return Unknown
		}
		found = k
	}
	return found
}

func isoMedia(b []byte) Kind {
	size := int(uint32(b[0])<<24 | uint32(b[1])<<16 | uint32(b[2])<<8 | uint32(b[3]))
	if size < 16 || size > len(b) || size > 4096 {
		size = min(len(b), 64)
	}
	major := string(b[8:12])
	if major == "qt  " {
		return MOV
	}
	if stillBrands[major] {
		return Unknown
	}
	if mp4Brands[major] {
		return MP4
	}
	for i := 16; i+4 <= size; i += 4 {
		if mp4Brands[string(b[i:i+4])] {
			return MP4
		}
	}
	return Unknown
}

func ebml(b []byte) Kind {
	pos := 4
	size, n := vint(b[pos:], false)
	if n == 0 || size > 4096 {
		return Unknown
	}
	pos += n
	end := min(len(b), pos+int(size))
	for pos < end {
		id, idLen := vint(b[pos:], true)
		if idLen == 0 {
			return Unknown
		}
		pos += idLen
		length, lenLen := vint(b[pos:], false)
		if lenLen == 0 || pos+lenLen+int(length) > end {
			return Unknown
		}
		pos += lenLen
		if id == 0x4282 {
			if string(bytes.TrimRight(b[pos:pos+int(length)], "\x00")) == "webm" {
				return WebM
			}
			return Unknown
		}
		pos += int(length)
	}
	return Unknown
}

func vint(b []byte, keepMarker bool) (uint64, int) {
	if len(b) == 0 || b[0] == 0 {
		return 0, 0
	}
	n := 1
	for mask := byte(0x80); b[0]&mask == 0; mask >>= 1 {
		n++
	}
	if n > 8 || len(b) < n {
		return 0, 0
	}
	v := uint64(b[0])
	if !keepMarker {
		v &= uint64(0xFF >> n)
	}
	for i := 1; i < n; i++ {
		v = v<<8 | uint64(b[i])
	}
	return v, n
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

func (k Kind) Office() bool {
	return k == DOCX || k == XLSX || k == PPTX
}

func (k Kind) Video() bool {
	return k == MP4 || k == MOV || k == WebM
}
