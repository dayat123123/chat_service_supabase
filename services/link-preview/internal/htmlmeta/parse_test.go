package htmlmeta

import (
	"net/url"
	"strings"
	"testing"
	"unicode/utf8"
)

func page(t *testing.T, raw string) *url.URL {
	t.Helper()
	u, err := url.Parse(raw)
	if err != nil {
		t.Fatal(err)
	}
	return u
}

func TestOpenGraphWins(t *testing.T) {
	doc := `<!DOCTYPE html><html><head>
<meta charset="utf-8">
<title>Judul &amp; Biasa</title>
<meta name="description" content="Deskripsi biasa">
<meta property="og:title" content="BBCA Naik 5% &mdash; Analisa">
<meta property="og:description" content="  Saham   perbankan
  menguat  ">
<meta property="og:site_name" content="Berita Pasar">
<meta property="og:image" content="/img/bbca.png?v=2#x">
<meta name="twitter:title" content="Judul Twitter">
</head><body><h1>x</h1></body></html>`
	m := Parse([]byte(doc), "text/html", page(t, "https://berita.example.com/pasar/bbca"))
	want := Meta{Title: "BBCA Naik 5% — Analisa", Description: "Saham perbankan menguat", SiteName: "Berita Pasar",
		Image: "https://berita.example.com/img/bbca.png?v=2", Charset: "utf-8"}
	if m != want {
		t.Fatalf("got %+v\nwant %+v", m, want)
	}
}

func TestFallbacks(t *testing.T) {
	doc := `<html><head><TITLE>  Hanya
 Title </TITLE><META NAME=Description CONTENT='Dari meta description'>
<meta name="twitter:image:src" content="//cdn.example.net/a.jpg"></head></html>`
	m := Parse([]byte(doc), "", page(t, "http://www.contoh.co.id/a/b"))
	if m.Title != "Hanya Title" || m.Description != "Dari meta description" || m.SiteName != "contoh.co.id" ||
		m.Image != "http://cdn.example.net/a.jpg" {
		t.Fatalf("got %+v", m)
	}
}

func TestTwitterAndLinkImage(t *testing.T) {
	doc := `<head><meta name="twitter:title" content="TW"><meta name="twitter:description" content="TD">
<link rel="shortcut image_src" href="gambar/x.webp"><base href="https://static.example.org/root/"></head>`
	m := Parse([]byte(doc), "text/html", page(t, "https://example.org/artikel"))
	if m.Title != "TW" || m.Description != "TD" || m.Image != "https://static.example.org/root/gambar/x.webp" {
		t.Fatalf("got %+v", m)
	}
}

func TestIgnoresScriptsCommentsAndSVGTitles(t *testing.T) {
	doc := `<head><!-- <meta property="og:title" content="komentar"> -->
<script>var s = '<meta property="og:title" content="skrip">'; if (a < b) {}</script>
<style>title{color:red}</style>
<template><title>templat</title></template>
</head><body><svg><title>ikon svg</title></svg><title>Judul asli</title>
<textarea><meta property="og:description" content="textarea"></textarea></body>`
	m := Parse([]byte(doc), "text/html", page(t, "https://example.com/"))
	if m.Title != "Judul asli" || m.Description != "" {
		t.Fatalf("got %+v", m)
	}
}

func TestFirstNonEmptyMetaWins(t *testing.T) {
	doc := `<meta property="og:title" content=""><meta property="og:title" content="Kedua"><meta property="og:title" content="Ketiga">`
	if m := Parse([]byte(doc), "", page(t, "https://example.com/")); m.Title != "Kedua" {
		t.Fatalf("got %q", m.Title)
	}
}

func TestRejectsUnsafeImageURLs(t *testing.T) {
	for _, ref := range []string{"javascript:alert(1)", "data:image/png;base64,AAAA", "ftp://example.com/a.png", "//", "http://" + strings.Repeat("a", 2100) + ".com/"} {
		doc := `<meta property="og:image" content="` + ref + `">`
		if m := Parse([]byte(doc), "", page(t, "https://example.com/")); m.Image != "" {
			t.Fatalf("%q resolved to %q", ref, m.Image)
		}
	}
}

func TestCleansTextAndClips(t *testing.T) {
	doc := `<meta property="og:title" content="A&#8238;B&#x200B;C` + "\x01\x02" + `D">` +
		`<meta property="og:description" content="` + strings.Repeat("kata ", 400) + `">` +
		`<meta property="og:site_name" content="` + strings.Repeat("é", 150) + `">`
	m := Parse([]byte(doc), "", page(t, "https://example.com/"))
	if m.Title != "ABC D" {
		t.Fatalf("title %q", m.Title)
	}
	if n := utf8.RuneCountInString(m.Description); n > MaxDescription || n < MaxDescription-5 {
		t.Fatalf("description has %d runes", n)
	}
	if n := utf8.RuneCountInString(m.SiteName); n != MaxSiteName {
		t.Fatalf("site name has %d runes", n)
	}
}

func TestCharsets(t *testing.T) {
	latin := []byte("<title>Caf\xe9 \x93kutip\x94 \x80</title>")
	if m := Parse(latin, "text/html; charset=ISO-8859-1", page(t, "https://example.com/")); m.Title != "Café “kutip” €" || m.Charset != "windows-1252" {
		t.Fatalf("latin1 header: %+v", m)
	}
	meta := []byte("<head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=windows-1252\"><title>Se\xf1or</title>")
	if m := Parse(meta, "text/html", page(t, "https://example.com/")); m.Title != "Señor" {
		t.Fatalf("meta http-equiv: %+v", m)
	}
	short := []byte("<meta charset='latin1'><title>\xe0 la carte</title>")
	if m := Parse(short, "", page(t, "https://example.com/")); m.Title != "à la carte" {
		t.Fatalf("meta charset: %+v", m)
	}
	utf16 := []byte{0xFF, 0xFE}
	for _, r := range "<title>Ünï</title>" {
		utf16 = append(utf16, byte(r), byte(r>>8))
	}
	if m := Parse(utf16, "text/html; charset=utf-8", page(t, "https://example.com/")); m.Title != "Ünï" || m.Charset != "utf-16le" {
		t.Fatalf("utf-16 bom: %+v", m)
	}
	bomUTF8 := append([]byte{0xEF, 0xBB, 0xBF}, []byte("<title>Rp 1.000</title>")...)
	if m := Parse(bomUTF8, "text/html; charset=windows-1252", page(t, "https://example.com/")); m.Title != "Rp 1.000" {
		t.Fatalf("utf-8 bom: %+v", m)
	}
	broken := []byte("<title>ok \xff\xfe bad</title>")
	if m := Parse(broken, "", page(t, "https://example.com/")); !utf8.ValidString(m.Title) || !strings.HasPrefix(m.Title, "ok") {
		t.Fatalf("invalid utf-8: %+v", m)
	}
	unknown := []byte("<title>\x82\xa0</title>")
	if m := Parse(unknown, "text/html; charset=shift_jis", page(t, "https://example.com/")); !utf8.ValidString(m.Title) {
		t.Fatalf("unsupported charset must still produce valid utf-8: %+v", m)
	}
}

func TestMalformedMarkupDoesNotPanic(t *testing.T) {
	inputs := []string{
		"", "<", "<!--", "<!", "</", "<meta", "<meta content=", `<meta content="x`, "<title>", "<title>abc",
		"<script>", "<svg><svg></svg>", "<<<>>>", "<meta =x content=y property=og:title>", "<a/b/c/d>",
		"<meta property=og:title content=Tanpa-kutip>",
		strings.Repeat("<div>", 10000), strings.Repeat("<meta a=b ", 5000),
	}
	for _, in := range inputs {
		_ = Parse([]byte(in), "", page(t, "https://example.com/"))
	}
	if m := Parse([]byte("<meta property=og:title content=Tanpa-kutip>"), "", page(t, "https://example.com/")); m.Title != "Tanpa-kutip" {
		t.Fatalf("unquoted attribute: %+v", m)
	}
}

func TestLargeDocumentScansQuickly(t *testing.T) {
	doc := "<head><title>Besar</title></head><body>" + strings.Repeat("<p class='x'>teks &amp; lagi</p>", 30000) +
		`<meta property="og:image" content="/akhir.png"></body>`
	m := Parse([]byte(doc), "", page(t, "https://example.com/dir/"))
	if m.Title != "Besar" || m.Image != "https://example.com/akhir.png" {
		t.Fatalf("got %+v", m)
	}
}
