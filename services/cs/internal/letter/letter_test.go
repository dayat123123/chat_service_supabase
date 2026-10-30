package letter

import (
	"bytes"
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"
)

func sample() Letter {
	return Letter{
		Title:            "Bukti Penerimaan Pengaduan",
		Number:           "PGD-2026-000123/BT/1",
		VerificationCode: "K7Q2M-9XAB3",
		Language:         "id",
		IssuedAt:         time.Date(2026, 10, 30, 3, 20, 0, 0, time.UTC),
		IssuedAtText:     "30 Oktober 2026 pukul 10.20 WIB",
		Draft:            true,
		Company:          Company{Name: "PT Uji Sekuritas", Address: "Jl. Uji No. 1, Jakarta", Contact: "pengaduan@uji.test"},
		Fields: []Field{
			{Label: "Nomor pengaduan", Value: "PGD-2026-000123"},
			{Label: "Kategori", Value: "Dana (RDN) › Deposit belum masuk"},
			{Label: "Ringkasan", Value: ""},
		},
		Paragraphs: []string{"Yth. Budi Santoso,", "Pengaduan Anda telah kami terima.", "  "},
	}
}

func TestRenderProducesPDF(t *testing.T) {
	pdf, err := Render(sample())
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.HasPrefix(pdf, []byte("%PDF-")) || !bytes.Contains(pdf[len(pdf)-32:], []byte("%%EOF")) {
		t.Fatal("bukan dokumen PDF utuh")
	}
	if n := pages(t, pdf); n != 1 {
		t.Fatalf("surat pendek harus satu halaman, dapat %d", n)
	}
}

func pages(t *testing.T, pdf []byte) int {
	t.Helper()
	m := regexp.MustCompile(`/Count (\d+)`).FindSubmatch(pdf)
	if m == nil {
		t.Fatal("PDF tanpa jumlah halaman")
	}
	n, _ := strconv.Atoi(string(m[1]))
	return n
}

func TestRenderIsDeterministic(t *testing.T) {
	first, err := Render(sample())
	if err != nil {
		t.Fatal(err)
	}
	second, _ := Render(sample())
	if !bytes.Equal(first, second) {
		t.Fatal("isi yang sama harus menghasilkan PDF identik (hash bisa diverifikasi ulang)")
	}
}

func TestLongLetterBreaksPages(t *testing.T) {
	l := sample()
	for i := 0; i < 40; i++ {
		l.Fields = append(l.Fields, Field{Label: "Baris", Value: strings.Repeat("isi panjang ", 30)})
	}
	pdf, err := Render(l)
	if err != nil {
		t.Fatal(err)
	}
	if n := pages(t, pdf); n < 2 {
		t.Fatalf("isi panjang harus berlanjut ke halaman berikutnya, dapat %d halaman", n)
	}
}

func TestRenderRejectsIncompleteLetter(t *testing.T) {
	l := sample()
	l.Number = " "
	if _, err := Render(l); err == nil {
		t.Fatal("surat tanpa nomor harus ditolak")
	}
}
