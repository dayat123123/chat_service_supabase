package htmlmeta

import (
	"bytes"
	"mime"
	"strings"
	"unicode/utf16"
	"unicode/utf8"
)

const prescanBytes = 4096

var windows1252 = [32]rune{
	0x20AC, 0xFFFD, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
	0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0xFFFD, 0x017D, 0xFFFD,
	0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
	0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0xFFFD, 0x017E, 0x0178,
}

func Decode(body []byte, contentType string) (string, string) {
	if label, rest := bom(body); label != "" {
		return convert(rest, label), label
	}
	label := normalizeLabel(headerCharset(contentType))
	if label == "" {
		label = normalizeLabel(metaCharset(body[:min(len(body), prescanBytes)]))
		if label == "utf-16le" || label == "utf-16be" {
			label = "utf-8"
		}
	}
	if label == "" {
		label = "utf-8"
	}
	return convert(body, label), label
}

func bom(body []byte) (string, []byte) {
	switch {
	case bytes.HasPrefix(body, []byte{0xEF, 0xBB, 0xBF}):
		return "utf-8", body[3:]
	case bytes.HasPrefix(body, []byte{0xFF, 0xFE}):
		return "utf-16le", body[2:]
	case bytes.HasPrefix(body, []byte{0xFE, 0xFF}):
		return "utf-16be", body[2:]
	}
	return "", body
}

func headerCharset(contentType string) string {
	if contentType == "" {
		return ""
	}
	_, params, err := mime.ParseMediaType(contentType)
	if err != nil {
		return ""
	}
	return params["charset"]
}

func metaCharset(head []byte) string {
	text := asciiLower(string(head))
	for from := 0; from < len(text); {
		i := strings.Index(text[from:], "<meta")
		if i < 0 {
			return ""
		}
		at := from + i
		name, attrs, _, next := parseTag(text, at+1)
		if next >= len(text) && !strings.HasSuffix(text[at:], ">") {
			return ""
		}
		if name == "meta" {
			if cs := attrs["charset"]; cs != "" {
				return cs
			}
			if attrs["http-equiv"] == "content-type" {
				if cs := charsetFromContent(attrs["content"]); cs != "" {
					return cs
				}
			}
		}
		from = max(next, at+1)
	}
	return ""
}

func charsetFromContent(content string) string {
	i := strings.Index(strings.ToLower(content), "charset")
	if i < 0 {
		return ""
	}
	rest := strings.TrimLeft(content[i+len("charset"):], " \t")
	if !strings.HasPrefix(rest, "=") {
		return ""
	}
	rest = strings.Trim(strings.TrimLeft(rest[1:], " \t"), `"' `)
	if j := strings.IndexAny(rest, "; \t\"'"); j >= 0 {
		rest = rest[:j]
	}
	return rest
}

func normalizeLabel(label string) string {
	switch strings.ToLower(strings.TrimSpace(label)) {
	case "":
		return ""
	case "utf-8", "utf8", "unicode-1-1-utf-8", "unicode11utf8", "unicode20utf8", "x-unicode20utf8":
		return "utf-8"
	case "iso-8859-1", "iso8859-1", "iso_8859-1", "latin1", "l1", "cp819", "ibm819", "us-ascii", "ascii",
		"windows-1252", "cp1252", "x-cp1252", "iso-ir-100", "csisolatin1", "iso88591", "iso_8859-1:1987":
		return "windows-1252"
	case "utf-16", "utf-16le":
		return "utf-16le"
	case "utf-16be":
		return "utf-16be"
	}
	return "unsupported"
}

func convert(body []byte, label string) string {
	switch label {
	case "windows-1252":
		var b strings.Builder
		b.Grow(len(body))
		for _, c := range body {
			switch {
			case c < 0x80:
				b.WriteByte(c)
			case c < 0xA0:
				b.WriteRune(windows1252[c-0x80])
			default:
				b.WriteRune(rune(c))
			}
		}
		return b.String()
	case "utf-16le", "utf-16be":
		units := make([]uint16, 0, len(body)/2)
		for i := 0; i+1 < len(body); i += 2 {
			if label == "utf-16le" {
				units = append(units, uint16(body[i])|uint16(body[i+1])<<8)
			} else {
				units = append(units, uint16(body[i])<<8|uint16(body[i+1]))
			}
		}
		return string(utf16.Decode(units))
	}
	if utf8.Valid(body) {
		return string(body)
	}
	return strings.ToValidUTF8(string(body), "�")
}
