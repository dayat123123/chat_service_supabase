package sanitize

import (
	"bytes"
	"compress/zlib"
	"errors"
	"fmt"
	"strings"
	"testing"
)

func pdf(version string, objects ...string) []byte {
	var b strings.Builder
	fmt.Fprintf(&b, "%%PDF-%s\n%%\xE2\xE3\xCF\xD3\n", version)
	b.WriteString("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
	b.WriteString("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
	b.WriteString("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>\nendobj\n")
	b.WriteString("4 0 obj\n<< /Length 44 >>\nstream\nBT /F1 12 Tf 72 712 Td (Halo dunia) Tj ET\nendstream\nendobj\n")
	for i, o := range objects {
		fmt.Fprintf(&b, "%d 0 obj\n%s\nendobj\n", i+5, o)
	}
	b.WriteString("trailer\n<< /Size 9 /Root 1 0 R >>\nstartxref\n0\n%%EOF\n")
	return []byte(b.String())
}

func objectStream(t *testing.T, content string) string {
	t.Helper()
	var buf bytes.Buffer
	zw := zlib.NewWriter(&buf)
	_, _ = zw.Write([]byte(content))
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	return fmt.Sprintf("<< /Type /ObjStm /N 1 /First 4 /Filter /FlateDecode /Length %d >>\nstream\r\n%s\r\nendstream", buf.Len(), buf.String())
}

func TestPDFAcceptsDocumentsWithoutActiveContent(t *testing.T) {
	cases := map[string][]byte{
		"plain 1.4":             {},
		"version 2.0":           pdf("2.0"),
		"javascript in text":    pdf("1.7", "<< /Title (JavaScript and /JS are words here) >>"),
		"JS without a value":    pdf("1.7", "<< /Names /JS /Kind /Other >>"),
		"binary stream bytes":   pdf("1.7", "<< /Length 12 >>\nstream\n\x00/JS\x00\x01\x02/JS]\nendstream"),
		"clean object stream":   pdf("1.7", objectStream(t, "6 0 << /Type /Annot /Subtype /Link >>")),
		"repeated ObjStm names": pdf("1.7", strings.Repeat("/ObjStm ", 5000)+objectStream(t, "6 0 << /Type /Annot >>")),
		"broken stream after obj stream": pdf("1.7", objectStream(t, "6 0 << >>"),
			"<< /Length 4 >>\nstream\n\x01\x02\x03\x04\nendstream"),
		"longer names":             pdf("1.7", "<< /JSONData 1 /Launcher 2 /XFAX 3 /EncryptMetadata false >>"),
		"comment before value":     pdf("1.7", "<< /Producer (x) >> % /JS is mentioned in a comment"),
		"escaped harmless name":    pdf("1.7", "<< /A#20B 1 >>"),
		"EOF followed by newlines": append(pdf("1.6"), bytes.Repeat([]byte("\n"), 1000)...),
	}
	cases["plain 1.4"] = pdf("1.4")
	for name, data := range cases {
		t.Run(name, func(t *testing.T) {
			out, info, err := PDF(data)
			if err != nil {
				t.Fatal(err)
			}
			if !bytes.Equal(out, data) || info != (Info{}) {
				t.Fatal("a PDF must be passed through unchanged")
			}
		})
	}
}

func TestPDFRejects(t *testing.T) {
	cases := map[string]struct {
		data []byte
		want error
	}{
		"not a pdf":                {[]byte("%!PS-Adobe-3.0\n%%EOF"), ErrInvalidPDF},
		"unknown version":          {bytes.Replace(pdf("1.7"), []byte("%PDF-1.7"), []byte("%PDF-3.0"), 1), ErrInvalidPDF},
		"missing EOF":              {bytes.TrimSuffix(pdf("1.7"), []byte("%%EOF\n")), ErrInvalidPDF},
		"EOF too early":            {append(pdf("1.7"), bytes.Repeat([]byte("%"), 2100)...), ErrInvalidPDF},
		"encrypted":                {bytes.Replace(pdf("1.7"), []byte("/Root 1 0 R"), []byte("/Root 1 0 R /Encrypt 9 0 R"), 1), ErrPDFEncrypted},
		"encrypted, escaped":       {bytes.Replace(pdf("1.7"), []byte("/Root 1 0 R"), []byte("/Root 1 0 R /Encr#79pt 9 0 R"), 1), ErrPDFEncrypted},
		"open action javascript":   {pdf("1.7", "<< /S /JavaScript /JS (app.alert(1)) >>"), ErrPDFActiveContent},
		"escaped JavaScript":       {pdf("1.7", "<< /S /J#61vaScript /J#53 (app.alert(1)) >>"), ErrPDFActiveContent},
		"fully escaped JS":         {pdf("1.7", "<< /#4A#53 <6170702e616c657274283129> >>"), ErrPDFActiveContent},
		"JS stream reference":      {pdf("1.7", "<< /JS 12 0 R >>"), ErrPDFActiveContent},
		"JS after a comment":       {pdf("1.7", "<< /JS % hidden\n(app.alert(1)) >>"), ErrPDFActiveContent},
		"document javascript tree": {pdf("1.7", "<< /JavaScript 10 0 R >>"), ErrPDFActiveContent},
		"launch action":            {pdf("1.7", "<< /S /Launch /F (cmd.exe) >>"), ErrPDFActiveContent},
		"embedded file":            {pdf("1.7", "<< /Type /EmbeddedFile /Length 0 >>\nstream\n\nendstream"), ErrPDFActiveContent},
		"embedded files tree":      {pdf("1.7", "<< /EmbeddedFiles 11 0 R >>"), ErrPDFActiveContent},
		"rich media":               {pdf("1.7", "<< /Subtype /RichMedia >>"), ErrPDFActiveContent},
		"xfa form":                 {pdf("1.7", "<< /XFA 12 0 R >>"), ErrPDFActiveContent},
		"javascript in obj stream": {pdf("1.7", objectStream(t, "6 0 << /S /JavaScript /JS (app.alert(1)) >>")), ErrPDFActiveContent},
		"javascript in second obj stream": {pdf("1.7", objectStream(t, "6 0 << /Type /Annot >>"),
			objectStream(t, "7 0 << /S /JavaScript /JS (app.alert(1)) >>")), ErrPDFActiveContent},
		"obj streams after a broken one": {pdf("1.7", "<< /Type /ObjStm >>\nstream\nnot deflate\nendstream",
			objectStream(t, "7 0 << >>")), ErrInvalidPDF},
		"escaped obj stream type": {pdf("1.7", strings.Replace(objectStream(t, "6 0 << /S /Launch >>"), "/ObjStm", "/Obj#53tm", 1)), ErrPDFActiveContent},
		"obj stream not deflate":  {pdf("1.7", "<< /Type /ObjStm /Filter /LZWDecode /Length 6 >>\nstream\n\x80\x0b\x60\x50\x22\x0c\nendstream"), ErrInvalidPDF},
		"obj stream without data": {pdf("1.7", "<< /Type /ObjStm /N 0 >>"), ErrInvalidPDF},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			if _, _, err := PDF(tc.data); !errors.Is(err, tc.want) {
				t.Fatalf("err = %v, want %v", err, tc.want)
			}
		})
	}
}

func TestPDFLimitsObjectStreamInflation(t *testing.T) {
	var buf bytes.Buffer
	zw := zlib.NewWriter(&buf)
	_, _ = zw.Write(bytes.Repeat([]byte(" "), inflateBudget+1))
	_ = zw.Close()
	stream := fmt.Sprintf("<< /Type /ObjStm /Length %d >>\nstream\n%s\nendstream", buf.Len(), buf.String())
	if _, _, err := PDF(pdf("1.7", stream)); !errors.Is(err, ErrInvalidPDF) {
		t.Fatalf("err = %v", err)
	}
}
