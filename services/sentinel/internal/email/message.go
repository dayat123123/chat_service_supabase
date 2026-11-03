package email

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"mime"
	"mime/quotedprintable"
	"net/mail"
	"strings"
	"time"
	"unicode/utf8"
)

const (
	maxSubject = 200
	maxLine    = 76
)

func Build(from *mail.Address, to []*mail.Address, subject, text string, now time.Time) []byte {
	var b bytes.Buffer
	header(&b, "From", from.String())
	recipients := make([]string, len(to))
	for i, addr := range to {
		recipients[i] = addr.String()
	}
	header(&b, "To", strings.Join(recipients, ",\r\n "))
	header(&b, "Subject", EncodeSubject(subject))
	header(&b, "Date", now.Format(time.RFC1123Z))
	header(&b, "Message-ID", messageID(from.Address))
	header(&b, "MIME-Version", "1.0")
	header(&b, "Content-Type", "text/plain; charset=utf-8")
	header(&b, "Content-Transfer-Encoding", "quoted-printable")
	header(&b, "Auto-Submitted", "auto-generated")
	b.WriteString("\r\n")
	body := quotedprintable.NewWriter(&b)
	_, _ = body.Write([]byte(normalize(text)))
	_ = body.Close()
	if !bytes.HasSuffix(b.Bytes(), []byte("\r\n")) {
		b.WriteString("\r\n")
	}
	return b.Bytes()
}

func EncodeSubject(subject string) string {
	subject = strings.Join(strings.Fields(subject), " ")
	if utf8.RuneCountInString(subject) > maxSubject {
		subject = string([]rune(subject)[:maxSubject-1]) + "…"
	}
	encoded := mime.QEncoding.Encode("utf-8", subject)
	if len("Subject: ")+len(encoded) <= maxLine+2 {
		return encoded
	}
	return strings.ReplaceAll(encoded, "?= =?", "?=\r\n =?")
}

func header(b *bytes.Buffer, name, value string) {
	b.WriteString(name)
	b.WriteString(": ")
	b.WriteString(value)
	b.WriteString("\r\n")
}

func normalize(text string) string {
	text = strings.ReplaceAll(text, "\r\n", "\n")
	text = strings.ReplaceAll(text, "\r", "\n")
	return text
}

func messageID(address string) string {
	domain := "sentinel.invalid"
	if at := strings.LastIndexByte(address, '@'); at >= 0 && at < len(address)-1 {
		domain = address[at+1:]
	}
	var id [16]byte
	_, _ = rand.Read(id[:])
	return "<" + hex.EncodeToString(id[:]) + "@" + domain + ">"
}
