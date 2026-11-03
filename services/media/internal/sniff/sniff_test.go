package sniff

import "testing"

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
