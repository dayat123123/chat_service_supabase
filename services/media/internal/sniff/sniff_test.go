package sniff

import (
	"archive/zip"
	"bytes"
	"fmt"
	"strings"
	"testing"
)

func TestDetectUsesMagicBytes(t *testing.T) {
	cases := map[string]struct {
		data []byte
		want Kind
		mime string
		ext  string
	}{
		"jpeg":          {[]byte{0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10}, JPEG, "image/jpeg", "jpg"},
		"png":           {[]byte("\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR"), PNG, "image/png", "png"},
		"webp":          {[]byte("RIFF\x24\x00\x00\x00WEBPVP8L"), WebP, "image/webp", "webp"},
		"gif87a":        {[]byte("GIF87a\x01\x00"), GIF, "image/gif", "gif"},
		"gif89a":        {[]byte("GIF89a\x01\x00"), GIF, "image/gif", "gif"},
		"pdf":           {[]byte("%PDF-1.7\n"), PDF, "application/pdf", "pdf"},
		"empty":         {nil, Unknown, "application/octet-stream", ""},
		"text":          {[]byte("hello world"), Unknown, "application/octet-stream", ""},
		"html":          {[]byte("<!doctype html><svg>"), Unknown, "application/octet-stream", ""},
		"riff wave":     {[]byte("RIFF\x24\x00\x00\x00WAVEfmt "), Unknown, "application/octet-stream", ""},
		"short jpeg":    {[]byte{0xFF, 0xD8}, Unknown, "application/octet-stream", ""},
		"png lookalike": {[]byte("\x89PNG\r\n"), Unknown, "application/octet-stream", ""},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			got := Detect(tc.data)
			if got != tc.want || got.MIME() != tc.mime || got.Ext() != tc.ext {
				t.Fatalf("Detect = %v (%s, %s)", got, got.MIME(), got.Ext())
			}
		})
	}
}

func TestImageKinds(t *testing.T) {
	for _, k := range []Kind{JPEG, PNG, WebP, GIF} {
		if !k.Image() {
			t.Fatalf("%v should be an image", k)
		}
	}
	if PDF.Image() || Unknown.Image() {
		t.Fatal("pdf and unknown are not images")
	}
}

func zipWith(t *testing.T, files map[string]string) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for name, body := range files {
		w, err := zw.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		_, _ = w.Write([]byte(body))
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func contentTypes(types ...string) string {
	var b strings.Builder
	b.WriteString(`<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">`)
	for i, ct := range types {
		fmt.Fprintf(&b, `<Override PartName="/part%d.xml" ContentType="%s"/>`, i, ct)
	}
	b.WriteString(`</Types>`)
	return b.String()
}

func TestDetectOfficeByMainPart(t *testing.T) {
	cases := map[string]struct {
		types []string
		want  Kind
	}{
		"docx": {[]string{"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"}, DOCX},
		"docm": {[]string{"application/vnd.ms-word.document.macroEnabled.main+xml"}, DOCX},
		"xlsx": {[]string{"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml",
			"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"}, XLSX},
		"pptx":      {[]string{"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"}, PPTX},
		"no main":   {[]string{"application/xml"}, Unknown},
		"two mains": {[]string{"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"}, Unknown},
		"template":  {[]string{"application/vnd.openxmlformats-officedocument.wordprocessingml.template.main+xml"}, Unknown},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			b := zipWith(t, map[string]string{"[Content_Types].xml": contentTypes(tc.types...), "word/document.xml": "<a/>"})
			if got := Detect(b); got != tc.want {
				t.Fatalf("Detect = %v, want %v", got, tc.want)
			}
		})
	}
	if Detect(zipWith(t, map[string]string{"readme.txt": "hi"})) != Unknown {
		t.Fatal("a plain zip is not an office document")
	}
	if Detect([]byte("PK\x03\x04broken")) != Unknown {
		t.Fatal("a broken zip is unknown")
	}
	if DOCX.MIME() != "application/vnd.openxmlformats-officedocument.wordprocessingml.document" || XLSX.Ext() != "xlsx" ||
		!PPTX.Office() || PDF.Office() {
		t.Fatal("office kind metadata")
	}
}

func TestDetectVideoContainers(t *testing.T) {
	ftyp := func(major string, compatible ...string) []byte {
		body := []byte(major + "\x00\x00\x00\x00" + strings.Join(compatible, ""))
		size := 8 + len(body)
		return append(append([]byte{0, 0, 0, byte(size)}, "ftyp"...), append(body, make([]byte, 16)...)...)
	}
	ebmlDoc := func(doc string) []byte {
		inner := append([]byte{0x42, 0x86, 0x81, 0x01, 0x42, 0x82, 0x80 | byte(len(doc))}, doc...)
		return append([]byte{0x1A, 0x45, 0xDF, 0xA3, 0x80 | byte(len(inner))}, inner...)
	}
	cases := map[string]struct {
		data []byte
		want Kind
	}{
		"mp4 isom":          {ftyp("isom", "isom", "iso2", "avc1", "mp41"), MP4},
		"mp4 android":       {ftyp("mp42", "isom", "mp42"), MP4},
		"mp4 by compatible": {ftyp("xxxx", "mp42"), MP4},
		"iphone mov":        {ftyp("qt  ", "qt  "), MOV},
		"heic photo":        {ftyp("heic", "mif1", "heic"), Unknown},
		"avif photo":        {ftyp("avif", "mif1", "avif", "mp41"), Unknown},
		"m4a audio":         {ftyp("M4A ", "M4A ", "mp42", "isom"), Unknown},
		"unknown brand":     {ftyp("abcd", "efgh"), Unknown},
		"webm":              {ebmlDoc("webm"), WebM},
		"matroska":          {ebmlDoc("matroska"), Unknown},
		"broken ebml":       {[]byte{0x1A, 0x45, 0xDF, 0xA3, 0x00}, Unknown},
		"truncated ebml":    {[]byte{0x1A, 0x45, 0xDF, 0xA3, 0x8A, 0x42, 0x82}, Unknown},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			if got := Detect(tc.data); got != tc.want {
				t.Fatalf("Detect = %v, want %v", got, tc.want)
			}
		})
	}
	if MOV.MIME() != "video/quicktime" || WebM.Ext() != "webm" || !MP4.Video() || PDF.Video() || MP4.Image() {
		t.Fatal("video kind metadata")
	}
}

func TestDetectNameForText(t *testing.T) {
	cases := map[string]struct {
		data []byte
		name string
		want Kind
	}{
		"csv":           {[]byte("a,b\n1,2\n"), "data.CSV", CSV},
		"txt":           {[]byte("halo"), "catatan.txt", TXT},
		"log":           {[]byte("error"), "app.log", TXT},
		"bom":           {[]byte("\xEF\xBB\xBFhalo"), "a.txt", TXT},
		"no extension":  {[]byte("halo"), "catatan", Unknown},
		"script":        {[]byte("echo hi"), "run.sh", Unknown},
		"invalid utf-8": {[]byte("a,\xff\n"), "a.csv", Unknown},
		"nul":           {[]byte("a\x00b"), "a.txt", Unknown},
		"only bom":      {[]byte("\xEF\xBB\xBF"), "a.txt", Unknown},
		"html":          {[]byte("  <HTML><body>x"), "a.txt", Unknown},
		"svg":           {[]byte("<svg onload=alert(1)>"), "a.csv", Unknown},
		"binary wins":   {[]byte("%PDF-1.7\n"), "a.csv", PDF},
		"dir dot":       {[]byte("halo"), "v1.2/catatan", Unknown},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			if got := DetectName(tc.data, tc.name); got != tc.want {
				t.Fatalf("DetectName = %v, want %v", got, tc.want)
			}
		})
	}
	if !TextExtension("a.TXT") || TextExtension("a.pdf") || Extension("a.tar.GZ") != "gz" || Extension("noext") != "" {
		t.Fatal("extension helpers")
	}
	if CSV.MIME() != "text/csv" || TXT.Ext() != "txt" {
		t.Fatal("text kind metadata")
	}
}
