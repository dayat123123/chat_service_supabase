package sanitize

import (
	"bytes"
	"compress/zlib"
	"errors"
	"io"
	"strings"
)

const (
	pdfTailWindow   = 2048
	objStreamWindow = 64 << 10
	inflateBudget   = 16 << 20
	nameBuffer      = 32
)

var activeNamePrefixes = []string{"JavaScript", "EmbeddedFile", "RichMedia"}

type pdfFindings struct {
	encrypted     bool
	active        bool
	objectStreams []int
}

func PDF(data []byte) ([]byte, Info, error) {
	if !bytes.HasPrefix(data, []byte("%PDF-1.")) && !bytes.HasPrefix(data, []byte("%PDF-2.")) {
		return nil, Info{}, invalidPDF("header")
	}
	if !bytes.Contains(data[max(0, len(data)-pdfTailWindow):], []byte("%%EOF")) {
		return nil, Info{}, invalidPDF("missing %%EOF near the end")
	}
	found := scanNames(data)
	if err := found.err(); err != nil {
		return nil, Info{}, err
	}
	inflater := objectStreams{budget: inflateBudget, done: -1}
	for _, at := range found.objectStreams {
		inner, err := inflater.next(data, at)
		if err != nil {
			return nil, Info{}, err
		}
		if err := scanNames(inner).err(); err != nil {
			return nil, Info{}, err
		}
	}
	return data, Info{}, nil
}

type objectStreams struct {
	reader io.ReadCloser
	budget int
	done   int
}

func (o *objectStreams) next(data []byte, at int) ([]byte, error) {
	if at < o.done {
		return nil, nil
	}
	start := streamStart(data[:min(len(data), at+objStreamWindow)], at)
	if start < 0 {
		return nil, invalidPDF("object stream without data")
	}
	o.done = start
	src := bytes.NewReader(data[start:])
	var err error
	if o.reader == nil {
		o.reader, err = zlib.NewReader(src)
	} else {
		err = o.reader.(zlib.Resetter).Reset(src, nil)
	}
	if err != nil {
		o.reader = nil
		return nil, invalidPDF("object stream is not Flate encoded")
	}
	inner, err := io.ReadAll(io.LimitReader(o.reader, int64(o.budget)+1))
	if err != nil && !errors.Is(err, zlib.ErrChecksum) {
		return nil, invalidPDF("object stream: " + err.Error())
	}
	if len(inner) > o.budget {
		return nil, invalidPDF("object streams inflate beyond the limit")
	}
	o.budget -= len(inner)
	return inner, nil
}

func (f pdfFindings) err() error {
	switch {
	case f.encrypted:
		return ErrPDFEncrypted
	case f.active:
		return ErrPDFActiveContent
	}
	return nil
}

func scanNames(data []byte) pdfFindings {
	var found pdfFindings
	for pos := 0; pos < len(data); {
		i := bytes.IndexByte(data[pos:], '/')
		if i < 0 {
			break
		}
		name, end := pdfName(data, pos+i+1)
		pos = end
		switch {
		case name == "Encrypt":
			found.encrypted = true
		case name == "JS":
			found.active = found.active || valueFollows(data, end)
		case name == "Launch", name == "XFA", hasActivePrefix(name):
			found.active = true
		case name == "ObjStm":
			found.objectStreams = append(found.objectStreams, end)
		}
	}
	return found
}

func hasActivePrefix(name string) bool {
	for _, prefix := range activeNamePrefixes {
		if strings.HasPrefix(name, prefix) {
			return true
		}
	}
	return false
}

func pdfName(data []byte, pos int) (string, int) {
	var buf [nameBuffer]byte
	n := 0
	for pos < len(data) && pdfRegular(data[pos]) {
		c := data[pos]
		if c == '#' && pos+2 < len(data) && isHex(data[pos+1]) && isHex(data[pos+2]) {
			c = unhex(data[pos+1])<<4 | unhex(data[pos+2])
			pos += 3
		} else {
			pos++
		}
		if n < len(buf) {
			buf[n] = c
			n++
		}
	}
	return string(buf[:n]), pos
}

func valueFollows(data []byte, pos int) bool {
	for pos < len(data) {
		c := data[pos]
		switch {
		case pdfSpace(c):
			pos++
		case c == '%':
			for pos < len(data) && data[pos] != '\n' && data[pos] != '\r' {
				pos++
			}
		default:
			return c == '(' || c == '<' || (c >= '0' && c <= '9')
		}
	}
	return false
}

func streamStart(data []byte, from int) int {
	for from < len(data) {
		i := bytes.Index(data[from:], []byte("stream"))
		if i < 0 {
			return -1
		}
		i += from
		from = i + len("stream")
		if i >= 3 && string(data[i-3:i]) == "end" {
			continue
		}
		switch {
		case from+1 < len(data) && data[from] == '\r' && data[from+1] == '\n':
			return from + 2
		case from < len(data) && (data[from] == '\n' || data[from] == '\r'):
			return from + 1
		}
	}
	return -1
}

func pdfSpace(c byte) bool {
	return c == 0 || c == '\t' || c == '\n' || c == '\f' || c == '\r' || c == ' '
}

func pdfRegular(c byte) bool {
	if pdfSpace(c) {
		return false
	}
	switch c {
	case '(', ')', '<', '>', '[', ']', '{', '}', '/', '%':
		return false
	}
	return true
}

func isHex(c byte) bool {
	return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

func unhex(c byte) byte {
	switch {
	case c >= 'a':
		return c - 'a' + 10
	case c >= 'A':
		return c - 'A' + 10
	}
	return c - '0'
}
