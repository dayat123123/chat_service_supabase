package sanitize

import (
	"archive/zip"
	"bytes"
	"errors"
	"fmt"
	"testing"
)

const (
	officeTypes = `<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">` +
		`<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>%s` +
		`<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>`
	relsHead = `<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">`
	relType  = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
)

type entry struct {
	name  string
	body  []byte
	store bool
}

func officeArchive(t *testing.T, extraTypes string, entries ...entry) []byte {
	t.Helper()
	base := []entry{
		{name: "[Content_Types].xml", body: []byte(fmt.Sprintf(officeTypes, extraTypes))},
		{name: "_rels/.rels", body: []byte(relsHead + `<Relationship Id="rId1" Type="` + relType + `officeDocument" Target="word/document.xml"/></Relationships>`)},
		{name: "word/document.xml", body: []byte(`<w:document xmlns:w="w"><w:body/></w:document>`)},
	}
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for _, e := range append(base, entries...) {
		method := zip.Deflate
		if e.store {
			method = zip.Store
		}
		w, err := zw.CreateHeader(&zip.FileHeader{Name: e.name, Method: method})
		if err != nil {
			t.Fatal(err)
		}
		_, _ = w.Write(e.body)
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func rels(items string) []byte {
	return []byte(relsHead + items + `</Relationships>`)
}

func relEntry(kind, target string) entry {
	return entry{name: "word/_rels/document.xml.rels", body: rels(`<Relationship Id="r9" Type="` + relType + kind +
		`" Target="` + target + `" TargetMode="External"/>`)}
}

func TestOfficeKeepsSafeDocumentsUnchanged(t *testing.T) {
	doc := officeArchive(t, "",
		entry{name: "word/_rels/document.xml.rels", body: rels(`<Relationship Id="rId5" Type="` + relType +
			`hyperlink" Target="https://olt.example/bantuan" TargetMode="External"/><Relationship Id="rId6" Type="` + relType +
			`hyperlink" Target="mailto:cs@olt.example" TargetMode="External"/><Relationship Id="rId7" Type="` + relType +
			`image" Target="media/image1.png"/>`)},
		entry{name: "word/media/image1.png", body: []byte("\x89PNG\r\n\x1a\n")},
		entry{name: "word/embeddings/Microsoft_Excel_Worksheet.xlsx", body: []byte("PK")},
	)
	out, _, err := Office(doc)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(out, doc) {
		t.Fatal("safe document must be returned byte for byte")
	}
}

func TestOfficeRejectsUnsafeContent(t *testing.T) {
	many := make([]entry, 0, MaxArchiveEntries)
	for i := range MaxArchiveEntries {
		many = append(many, entry{name: fmt.Sprintf("word/media/p%04d.xml", i), body: []byte("<a/>")})
	}
	large := make([]entry, 0, 110)
	for i := range 110 {
		large = append(large, entry{name: fmt.Sprintf("word/media/big%03d.xml", i), body: make([]byte, 1<<20-1)})
	}
	cases := map[string]struct {
		doc  []byte
		want error
	}{
		"vba project":          {officeArchive(t, "", entry{name: "word/vbaProject.bin", body: []byte("vba")}), ErrOfficeMacro},
		"vba in xl":            {officeArchive(t, "", entry{name: "xl/VBAPROJECT.BIN", body: []byte("vba")}), ErrOfficeMacro},
		"macro content type":   {officeArchive(t, `<Default Extension="bin" ContentType="application/vnd.ms-office.vbaProject"/>`), ErrOfficeMacro},
		"macro-enabled main":   {officeArchive(t, `<Override PartName="/x.xml" ContentType="application/vnd.ms-excel.sheet.macroEnabled.main+xml"/>`), ErrOfficeMacro},
		"embedded xlsm":        {officeArchive(t, "", entry{name: "word/embeddings/sheet.xlsm", body: []byte("PK")}), ErrOfficeMacro},
		"vba relationship":     {officeArchive(t, "", entry{name: "word/_rels/document.xml.rels", body: rels(`<Relationship Id="r" Type="http://schemas.microsoft.com/office/2006/relationships/vbaProject" Target="vbaProject.bin"/>`)}), ErrOfficeMacro},
		"ole object":           {officeArchive(t, "", entry{name: "word/embeddings/oleObject1.bin", body: []byte("ole")}), ErrOfficeUnsafe},
		"ole content type":     {officeArchive(t, `<Default Extension="bin" ContentType="application/vnd.openxmlformats-officedocument.oleObject"/>`), ErrOfficeUnsafe},
		"activex":              {officeArchive(t, "", entry{name: "word/activeX/activeX1.xml", body: []byte("<ax/>")}), ErrOfficeUnsafe},
		"embedded exe":         {officeArchive(t, "", entry{name: "word/media/setup.exe", body: []byte("MZ")}), ErrOfficeUnsafe},
		"embedded legacy doc":  {officeArchive(t, "", entry{name: "word/embeddings/old.doc", body: []byte("\xd0\xcf")}), ErrOfficeUnsafe},
		"external file target": {officeArchive(t, "", relEntry("hyperlink", "file:///C:/Windows/System32/calc.exe")), ErrOfficeUnsafe},
		"external unc target":  {officeArchive(t, "", relEntry("image", `\\evil\share\a.png`)), ErrOfficeUnsafe},
		"external ms-msdt":     {officeArchive(t, "", relEntry("hyperlink", "ms-msdt:/id PCWDiagnostic")), ErrOfficeUnsafe},
		"remote template":      {officeArchive(t, "", relEntry("attachedTemplate", "https://evil.example/t.dotm")), ErrOfficeUnsafe},
		"remote ole object":    {officeArchive(t, "", relEntry("oleObject", "https://evil.example/x.html!")), ErrOfficeUnsafe},
		"broken rels":          {officeArchive(t, "", entry{name: "word/_rels/document.xml.rels", body: []byte("<Relationships")}), ErrOfficeUnsafe},
		"path traversal":       {officeArchive(t, "", entry{name: "../evil.xml", body: []byte("<a/>")}), ErrOfficeUnsafe},
		"too many entries":     {officeArchive(t, "", many...), ErrArchiveBomb},
		"compression ratio":    {officeArchive(t, "", entry{name: "word/media/zeros.xml", body: make([]byte, 2<<20)}), ErrArchiveBomb},
		"unpacked size":        {officeArchive(t, "", large...), ErrArchiveBomb},
		"legacy ole file":      {[]byte("\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1 legacy ole"), ErrOfficeUnsafe},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			_, _, err := Office(tc.doc)
			if !errors.Is(err, tc.want) {
				t.Fatalf("err = %v, want %v", err, tc.want)
			}
		})
	}
}

func TestOfficeAllowsLargeIncompressibleEntries(t *testing.T) {
	noise := make([]byte, 2<<20)
	state := uint32(2463534242)
	for i := range noise {
		state ^= state << 13
		state ^= state >> 17
		state ^= state << 5
		noise[i] = byte(state)
	}
	doc := officeArchive(t, "", entry{name: "word/media/clip.png", body: noise, store: true})
	if _, _, err := Office(doc); err != nil {
		t.Fatal(err)
	}
}

func TestTextAcceptsOnlyUTF8(t *testing.T) {
	for name, body := range map[string]string{"plain": "nama,saldo\nbudi,100\n", "bom": "\xEF\xBB\xBFhalo", "unicode": "Rp 1.000 – ok ✓"} {
		out, _, err := Text([]byte(body))
		if err != nil || string(out) != body {
			t.Fatalf("%s: %v", name, err)
		}
	}
	for name, body := range map[string]string{"latin1": "caf\xe9", "nul": "a\x00b", "utf16": "\xff\xfeh\x00i\x00", "empty": "", "only bom": "\xEF\xBB\xBF"} {
		if _, _, err := Text([]byte(body)); !errors.Is(err, ErrInvalidText) {
			t.Fatalf("%s: err = %v", name, err)
		}
	}
}
