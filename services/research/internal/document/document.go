package document

import (
	"archive/zip"
	"bytes"
	"errors"
	"fmt"
	"io"
	"mime"
	"strings"
	"unicode"
	"unicode/utf8"
)

const (
	MaxName        = 120
	maxEntries     = 10000
	maxUnpacked    = 512 << 20
	maxContentType = 1 << 20
	pdfHeaderSpan  = 1024
	pdfTrailerSpan = 4096
)

var (
	ErrInvalid       = errors.New("document is not a valid file of its type")
	ErrActiveContent = errors.New("document contains active content")
	ErrMacro         = errors.New("document contains macros")
)

type Type struct {
	Ext  string
	Mime string
}

var (
	PDF  = Type{Ext: "pdf", Mime: "application/pdf"}
	XLSX = Type{Ext: "xlsx", Mime: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}
)

func ByMime(header string) (Type, bool) {
	media, _, err := mime.ParseMediaType(header)
	if err != nil {
		return Type{}, false
	}
	switch media {
	case PDF.Mime:
		return PDF, true
	case XLSX.Mime:
		return XLSX, true
	}
	return Type{}, false
}

func ValidName(name string) bool {
	name = strings.TrimSpace(name)
	if name == "" {
		return true
	}
	if !utf8.ValidString(name) || utf8.RuneCountInString(name) > MaxName {
		return false
	}
	for _, r := range name {
		if r == '/' || r == '\\' || unicode.IsControl(r) {
			return false
		}
	}
	return true
}

func Sniff(t Type, head []byte) bool {
	switch t {
	case PDF:
		return bytes.Contains(head[:min(len(head), pdfHeaderSpan)], []byte("%PDF-"))
	case XLSX:
		return bytes.HasPrefix(head, []byte("PK\x03\x04"))
	}
	return false
}

func Check(t Type, data []byte) error {
	if !Sniff(t, data) {
		return ErrInvalid
	}
	switch t {
	case PDF:
		return checkPDF(data)
	case XLSX:
		return checkXLSX(data)
	}
	return ErrInvalid
}

var activeNames = [][]byte{[]byte("/JavaScript"), []byte("/JS"), []byte("/Launch")}

func checkPDF(data []byte) error {
	if !bytes.Contains(data[max(0, len(data)-pdfTrailerSpan):], []byte("%%EOF")) {
		return fmt.Errorf("%w: missing end-of-file marker", ErrInvalid)
	}
	for _, name := range activeNames {
		for rest := data; ; {
			i := bytes.Index(rest, name)
			if i < 0 {
				break
			}
			end := i + len(name)
			if end == len(rest) || delimiter(rest[end]) {
				return fmt.Errorf("%w: %s", ErrActiveContent, name[1:])
			}
			rest = rest[end:]
		}
	}
	return nil
}

func delimiter(c byte) bool {
	switch c {
	case ' ', '\t', '\r', '\n', '\f', 0, '(', ')', '<', '>', '[', ']', '{', '}', '/', '%':
		return true
	}
	return false
}

func checkXLSX(data []byte) error {
	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return fmt.Errorf("%w: %v", ErrInvalid, err)
	}
	if len(zr.File) > maxEntries {
		return fmt.Errorf("%w: %d entries", ErrInvalid, len(zr.File))
	}
	var unpacked uint64
	var types *zip.File
	workbook := false
	for _, f := range zr.File {
		unpacked += f.UncompressedSize64
		name := strings.ToLower(f.Name)
		switch {
		case strings.HasSuffix(name, "vbaproject.bin"):
			return fmt.Errorf("%w: %s", ErrMacro, f.Name)
		case name == "[content_types].xml":
			types = f
		case name == "xl/workbook.xml":
			workbook = true
		}
	}
	if unpacked > maxUnpacked {
		return fmt.Errorf("%w: %d bytes unpacked", ErrInvalid, unpacked)
	}
	if types == nil || !workbook {
		return fmt.Errorf("%w: not a workbook", ErrInvalid)
	}
	rc, err := types.Open()
	if err != nil {
		return fmt.Errorf("%w: %v", ErrInvalid, err)
	}
	defer rc.Close()
	body, err := io.ReadAll(io.LimitReader(rc, maxContentType))
	if err != nil {
		return fmt.Errorf("%w: %v", ErrInvalid, err)
	}
	if bytes.Contains(bytes.ToLower(body), []byte("macroenabled")) {
		return fmt.Errorf("%w: macro-enabled content type", ErrMacro)
	}
	return nil
}
