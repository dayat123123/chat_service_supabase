package document

import (
	"archive/zip"
	"bytes"
	"errors"
	"strings"
	"testing"
)

func pdf(body string) []byte {
	return []byte("%PDF-1.7\n" + body + "\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n")
}

func workbook(t *testing.T, files map[string]string) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for name, body := range files {
		w, err := zw.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := w.Write([]byte(body)); err != nil {
			t.Fatal(err)
		}
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

const contentTypes = `<Types><Override ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/></Types>`

func TestByMime(t *testing.T) {
	cases := map[string]Type{
		"application/pdf":            PDF,
		"application/pdf; charset=x": PDF,
		XLSX.Mime:                    XLSX,
	}
	for header, want := range cases {
		if got, ok := ByMime(header); !ok || got != want {
			t.Fatalf("ByMime(%q) = %v, %v", header, got, ok)
		}
	}
	for _, header := range []string{"", "application/zip", "application/vnd.ms-excel", "text/csv", "%%"} {
		if _, ok := ByMime(header); ok {
			t.Fatalf("ByMime(%q) accepted", header)
		}
	}
}

func TestValidName(t *testing.T) {
	for _, name := range []string{"", "  ", "Laporan Keuangan ITMG Q3 2026.pdf", strings.Repeat("a", MaxName)} {
		if !ValidName(name) {
			t.Fatalf("ValidName(%q) = false", name)
		}
	}
	for _, name := range []string{"a/b.pdf", `a\b.pdf`, "a\x00b", strings.Repeat("a", MaxName+1), "\xff"} {
		if ValidName(name) {
			t.Fatalf("ValidName(%q) = true", name)
		}
	}
}

func TestSniff(t *testing.T) {
	if !Sniff(PDF, []byte("%PDF-1.4")) || !Sniff(PDF, append(bytes.Repeat([]byte(" "), 100), "%PDF-1.4"...)) {
		t.Fatal("pdf header not recognized")
	}
	if Sniff(PDF, append(bytes.Repeat([]byte(" "), 2000), "%PDF-1.4"...)) || Sniff(PDF, []byte("PK\x03\x04")) {
		t.Fatal("pdf header accepted outside the first kilobyte or for a zip")
	}
	if !Sniff(XLSX, []byte("PK\x03\x04rest")) || Sniff(XLSX, []byte("%PDF-1.4")) {
		t.Fatal("xlsx sniffing is wrong")
	}
}

func TestCheckPDF(t *testing.T) {
	if err := Check(PDF, pdf("1 0 obj << /Type /Catalog /OpenAction 2 0 R /JSONData 3 >> endobj")); err != nil {
		t.Fatalf("plain pdf rejected: %v", err)
	}
	for name, body := range map[string]string{
		"javascript": "2 0 obj << /S /JavaScript /JS (app.alert(1)) >> endobj",
		"js":         "2 0 obj << /JS(app.alert(1)) >> endobj",
		"launch":     "2 0 obj << /S /Launch /F (cmd.exe) >> endobj",
	} {
		if err := Check(PDF, pdf(body)); !errors.Is(err, ErrActiveContent) {
			t.Fatalf("%s: err = %v", name, err)
		}
	}
	if err := Check(PDF, []byte("%PDF-1.7\ntruncated")); !errors.Is(err, ErrInvalid) {
		t.Fatalf("truncated pdf: %v", err)
	}
	if err := Check(PDF, []byte("<html>%%EOF")); !errors.Is(err, ErrInvalid) {
		t.Fatalf("html: %v", err)
	}
}

func TestCheckXLSX(t *testing.T) {
	good := workbook(t, map[string]string{"[Content_Types].xml": contentTypes, "xl/workbook.xml": "<workbook/>",
		"xl/worksheets/sheet1.xml": "<worksheet/>"})
	if err := Check(XLSX, good); err != nil {
		t.Fatalf("plain workbook rejected: %v", err)
	}
	macro := workbook(t, map[string]string{"[Content_Types].xml": contentTypes, "xl/workbook.xml": "<workbook/>",
		"xl/vbaProject.bin": "vba"})
	if err := Check(XLSX, macro); !errors.Is(err, ErrMacro) {
		t.Fatalf("vba project: %v", err)
	}
	enabled := workbook(t, map[string]string{"xl/workbook.xml": "<workbook/>",
		"[Content_Types].xml": `<Types><Override ContentType="application/vnd.ms-excel.sheet.macroEnabled.main+xml"/></Types>`})
	if err := Check(XLSX, enabled); !errors.Is(err, ErrMacro) {
		t.Fatalf("macro-enabled type: %v", err)
	}
	docx := workbook(t, map[string]string{"[Content_Types].xml": contentTypes, "word/document.xml": "<document/>"})
	if err := Check(XLSX, docx); !errors.Is(err, ErrInvalid) {
		t.Fatalf("docx accepted as workbook: %v", err)
	}
	if err := Check(XLSX, []byte("PK\x03\x04broken")); !errors.Is(err, ErrInvalid) {
		t.Fatalf("broken zip: %v", err)
	}
}
