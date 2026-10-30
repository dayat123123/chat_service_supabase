package letter

import (
	"bytes"
	"errors"
	"fmt"
	"strings"
	"time"

	"codeberg.org/go-pdf/fpdf"
	"golang.org/x/image/font/gofont/gobold"
	"golang.org/x/image/font/gofont/goregular"
)

type Company struct {
	Name    string `json:"name"`
	Address string `json:"address"`
	Contact string `json:"contact"`
}

type Field struct {
	Label string `json:"label"`
	Value string `json:"value"`
}

type Letter struct {
	Title            string    `json:"title"`
	Number           string    `json:"number"`
	VerificationCode string    `json:"verification_code"`
	Language         string    `json:"language"`
	IssuedAt         time.Time `json:"issued_at"`
	IssuedAtText     string    `json:"issued_at_text"`
	Draft            bool      `json:"draft"`
	Company          Company   `json:"company"`
	Fields           []Field   `json:"fields"`
	Paragraphs       []string  `json:"paragraphs"`
}

const (
	family       = "go"
	margin       = 20.0
	bottomMargin = 26.0
	labelWidth   = 52.0
	fieldLine    = 4.8
	padding      = 2.0
)

type texts struct {
	number, issued, verification, footer, draft, page string
}

func textsFor(language string) texts {
	if language == "en" {
		return texts{
			number:       "Number",
			issued:       "Issued",
			verification: "Verification code",
			footer:       "This document is issued electronically. Verify its authenticity in the OLT app using the number and verification code.",
			draft:        "DRAFT: this template has not been reviewed by the compliance team",
			page:         "Page",
		}
	}
	return texts{
		number:       "Nomor",
		issued:       "Diterbitkan",
		verification: "Kode verifikasi",
		footer:       "Dokumen ini diterbitkan secara elektronik. Keasliannya dapat dicek di aplikasi OLT dengan nomor dan kode verifikasi.",
		draft:        "DRAF: template ini belum ditinjau tim kepatuhan",
		page:         "Halaman",
	}
}

func Render(l Letter) ([]byte, error) {
	if strings.TrimSpace(l.Title) == "" || strings.TrimSpace(l.Number) == "" {
		return nil, errors.New("surat tidak lengkap: judul dan nomor wajib ada")
	}
	t := textsFor(l.Language)
	pdf := fpdf.New("P", "mm", "A4", "")
	pdf.AddUTF8FontFromBytes(family, "", goregular.TTF)
	pdf.AddUTF8FontFromBytes(family, "B", gobold.TTF)
	pdf.SetMargins(margin, margin, margin)
	pdf.SetAutoPageBreak(true, bottomMargin)
	pdf.SetTitle(l.Title, true)
	pdf.SetSubject(l.Number, true)
	pdf.SetAuthor(l.Company.Name, true)
	pdf.SetCreator("OLT Customer Service", true)
	pdf.SetCatalogSort(true)
	if !l.IssuedAt.IsZero() {
		pdf.SetCreationDate(l.IssuedAt)
		pdf.SetModificationDate(l.IssuedAt)
	}
	pdf.AliasNbPages("")
	pdf.SetFooterFunc(func() {
		pdf.SetY(-bottomMargin + 6)
		pdf.SetFont(family, "", 7.5)
		pdf.SetTextColor(110, 110, 110)
		pdf.MultiCell(0, 3.6, t.footer, "", "L", false)
		pdf.CellFormat(0, 4, fmt.Sprintf("%s: %s · %s %d/{nb}", t.verification, l.VerificationCode, t.page, pdf.PageNo()),
			"", 0, "L", false, 0, "")
	})
	pdf.AddPage()

	pageWidth, _ := pdf.GetPageSize()
	content := pageWidth - 2*margin
	letterhead(pdf, l.Company, content)
	if l.Draft {
		pdf.SetFont(family, "B", 9)
		pdf.SetTextColor(160, 30, 30)
		pdf.SetDrawColor(160, 30, 30)
		pdf.MultiCell(content, 6, t.draft, "1", "C", false)
		pdf.Ln(4)
	}

	pdf.SetFont(family, "B", 15)
	pdf.SetTextColor(20, 20, 20)
	pdf.MultiCell(content, 7, l.Title, "", "L", false)
	pdf.Ln(1)
	pdf.SetFont(family, "", 9)
	pdf.SetTextColor(70, 70, 70)
	pdf.MultiCell(content, 4.6, t.number+": "+l.Number, "", "L", false)
	if l.IssuedAtText != "" {
		pdf.MultiCell(content, 4.6, t.issued+": "+l.IssuedAtText, "", "L", false)
	}
	pdf.Ln(4)

	for _, f := range l.Fields {
		field(pdf, f, content)
	}
	pdf.Ln(6)

	pdf.SetFont(family, "", 10)
	pdf.SetTextColor(25, 25, 25)
	for _, p := range l.Paragraphs {
		if strings.TrimSpace(p) == "" {
			continue
		}
		pdf.MultiCell(content, 5.5, p, "", "L", false)
		pdf.Ln(2.5)
	}

	var buf bytes.Buffer
	if err := pdf.Output(&buf); err != nil {
		return nil, fmt.Errorf("render PDF: %w", err)
	}
	return buf.Bytes(), nil
}

func letterhead(pdf *fpdf.Fpdf, c Company, content float64) {
	pdf.SetFont(family, "B", 13)
	pdf.SetTextColor(20, 20, 20)
	pdf.MultiCell(content, 6, c.Name, "", "L", false)
	pdf.SetFont(family, "", 8.5)
	pdf.SetTextColor(90, 90, 90)
	for _, line := range []string{c.Address, c.Contact} {
		if strings.TrimSpace(line) != "" {
			pdf.MultiCell(content, 4.2, line, "", "L", false)
		}
	}
	pdf.Ln(2)
	pdf.SetDrawColor(30, 30, 30)
	y := pdf.GetY()
	pdf.Line(margin, y, margin+content, y)
	pdf.Ln(6)
}

func field(pdf *fpdf.Fpdf, f Field, content float64) {
	value := strings.TrimSpace(f.Value)
	if value == "" {
		value = "-"
	}
	valueWidth := content - labelWidth
	pdf.SetFont(family, "B", 9)
	labelLines := len(pdf.SplitText(f.Label, labelWidth-2*padding))
	pdf.SetFont(family, "", 9.5)
	valueLines := len(pdf.SplitText(value, valueWidth-2*padding))
	height := float64(max(labelLines, valueLines, 1))*fieldLine + 2*padding*0.6

	_, pageHeight := pdf.GetPageSize()
	if pdf.GetY()+height > pageHeight-bottomMargin {
		pdf.AddPage()
	}
	x, y := pdf.GetX(), pdf.GetY()
	pdf.SetFillColor(242, 244, 243)
	pdf.Rect(x, y, labelWidth, height, "F")
	pdf.SetDrawColor(215, 220, 217)
	pdf.Rect(x, y, content, height, "D")

	pdf.SetXY(x+padding, y+padding*0.6)
	pdf.SetFont(family, "B", 9)
	pdf.SetTextColor(60, 60, 60)
	pdf.MultiCell(labelWidth-2*padding, fieldLine, f.Label, "", "L", false)

	pdf.SetXY(x+labelWidth+padding, y+padding*0.6)
	pdf.SetFont(family, "", 9.5)
	pdf.SetTextColor(20, 20, 20)
	pdf.MultiCell(valueWidth-2*padding, fieldLine, value, "", "L", false)
	pdf.SetXY(x, y+height)
}
