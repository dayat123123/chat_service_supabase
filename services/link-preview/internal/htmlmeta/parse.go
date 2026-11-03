package htmlmeta

import (
	"html"
	"net/url"
	"strings"
	"unicode"
	"unicode/utf8"
)

const (
	MaxTitle       = 300
	MaxDescription = 1000
	MaxSiteName    = 100
	maxImageURL    = 2048
)

type Meta struct {
	Title       string
	Description string
	SiteName    string
	Image       string
	Charset     string
}

type document struct {
	meta     map[string]string
	title    string
	hasTitle bool
	base     string
	imageSrc string
}

var rawText = map[string]bool{
	"script": true, "style": true, "textarea": true, "template": true, "xmp": true,
	"iframe": true, "noembed": true, "noframes": true,
}

func Parse(body []byte, contentType string, page *url.URL) Meta {
	text, label := Decode(body, contentType)
	d := scan(text)
	m := Meta{
		Title:       clean(first(d.meta["og:title"], d.meta["twitter:title"], d.title, d.meta["itemprop:name"]), MaxTitle),
		Description: clean(first(d.meta["og:description"], d.meta["twitter:description"], d.meta["description"], d.meta["itemprop:description"]), MaxDescription),
		SiteName:    clean(first(d.meta["og:site_name"], d.meta["application-name"]), MaxSiteName),
		Charset:     label,
	}
	if m.SiteName == "" && page != nil {
		m.SiteName = clean(strings.TrimPrefix(strings.ToLower(page.Hostname()), "www."), MaxSiteName)
	}
	image := first(d.meta["og:image:secure_url"], d.meta["og:image:url"], d.meta["og:image"], d.meta["twitter:image"],
		d.meta["twitter:image:src"], d.imageSrc, d.meta["itemprop:image"])
	if image != "" && page != nil {
		m.Image = resolve(page, d.base, image)
	}
	return m
}

func resolve(page *url.URL, baseHref, ref string) string {
	base := page
	if href := strings.TrimSpace(baseHref); href != "" {
		if b, err := page.Parse(href); err == nil && (b.Scheme == "http" || b.Scheme == "https") {
			base = b
		}
	}
	u, err := base.Parse(strings.TrimSpace(ref))
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		return ""
	}
	u.Fragment = ""
	out := u.String()
	if len(out) > maxImageURL || out == page.String() {
		return ""
	}
	return out
}

func scan(s string) document {
	lower := asciiLower(s)
	d := document{meta: map[string]string{}}
	svg := 0
	for i := 0; i < len(s); {
		j := strings.IndexByte(s[i:], '<')
		if j < 0 {
			break
		}
		i += j
		rest := lower[i:]
		switch {
		case strings.HasPrefix(rest, "<!--"):
			k := strings.Index(lower[i+4:], "-->")
			if k < 0 {
				return d
			}
			i += 4 + k + 3
		case strings.HasPrefix(rest, "<!"), strings.HasPrefix(rest, "<?"):
			k := strings.IndexByte(s[i:], '>')
			if k < 0 {
				return d
			}
			i += k + 1
		case strings.HasPrefix(rest, "</") && len(rest) > 2 && isLetter(rest[2]):
			name, _, _, next := parseTag(lower, i+2)
			if name == "svg" && svg > 0 {
				svg--
			}
			i = next
		case len(rest) > 1 && isLetter(rest[1]):
			name, attrs, self, next := parseTag(s, i+1)
			i = next
			switch {
			case name == "meta":
				d.addMeta(attrs)
			case name == "base":
				if d.base == "" {
					d.base = attrs["href"]
				}
			case name == "link":
				if d.imageSrc == "" && hasToken(attrs["rel"], "image_src") {
					d.imageSrc = attrs["href"]
				}
			case name == "svg":
				if !self {
					svg++
				}
			case name == "title":
				end := endTag(lower, i, "title")
				if svg == 0 && !d.hasTitle {
					d.title = html.UnescapeString(s[i:end])
					d.hasTitle = true
				}
				i = skipTag(s, end)
			case rawText[name]:
				i = skipTag(s, endTag(lower, i, name))
			case name == "plaintext":
				return d
			}
		default:
			i++
		}
	}
	return d
}

func (d *document) addMeta(attrs map[string]string) {
	content, ok := attrs["content"]
	if !ok || strings.TrimSpace(content) == "" {
		return
	}
	key := strings.ToLower(strings.TrimSpace(attrs["property"]))
	if key == "" {
		key = strings.ToLower(strings.TrimSpace(attrs["name"]))
	}
	if key == "" {
		if prop := strings.ToLower(strings.TrimSpace(attrs["itemprop"])); prop != "" {
			key = "itemprop:" + prop
		}
	}
	if key == "" {
		return
	}
	if _, seen := d.meta[key]; !seen {
		d.meta[key] = content
	}
}

func parseTag(s string, i int) (string, map[string]string, bool, int) {
	start := i
	for i < len(s) && !isSpace(s[i]) && s[i] != '>' && s[i] != '/' {
		i++
	}
	name := asciiLower(s[start:i])
	attrs := map[string]string{}
	self := false
	for i < len(s) {
		for i < len(s) && isSpace(s[i]) {
			i++
		}
		if i >= len(s) {
			break
		}
		switch s[i] {
		case '>':
			return name, attrs, self, i + 1
		case '/':
			self = true
			i++
			continue
		}
		self = false
		keyStart := i
		for i < len(s) && !isSpace(s[i]) && s[i] != '=' && s[i] != '>' && s[i] != '/' {
			i++
		}
		if i == keyStart {
			i++
		}
		key := asciiLower(s[keyStart:i])
		for i < len(s) && isSpace(s[i]) {
			i++
		}
		value := ""
		if i < len(s) && s[i] == '=' {
			i++
			for i < len(s) && isSpace(s[i]) {
				i++
			}
			if i < len(s) && (s[i] == '"' || s[i] == '\'') {
				quote := s[i]
				i++
				k := strings.IndexByte(s[i:], quote)
				if k < 0 {
					value, i = s[i:], len(s)
				} else {
					value, i = s[i:i+k], i+k+1
				}
			} else {
				valueStart := i
				for i < len(s) && !isSpace(s[i]) && s[i] != '>' {
					i++
				}
				value = s[valueStart:i]
			}
		}
		if _, dup := attrs[key]; !dup && key != "" && key != "=" {
			attrs[key] = html.UnescapeString(value)
		}
	}
	return name, attrs, self, len(s)
}

func endTag(lower string, from int, name string) int {
	needle := "</" + name
	for i := from; i < len(lower); {
		k := strings.Index(lower[i:], needle)
		if k < 0 {
			return len(lower)
		}
		at := i + k
		after := at + len(needle)
		if after >= len(lower) || isSpace(lower[after]) || lower[after] == '>' || lower[after] == '/' {
			return at
		}
		i = after
	}
	return len(lower)
}

func skipTag(s string, at int) int {
	if at >= len(s) {
		return len(s)
	}
	k := strings.IndexByte(s[at:], '>')
	if k < 0 {
		return len(s)
	}
	return at + k + 1
}

func clean(s string, limit int) string {
	if s == "" {
		return ""
	}
	s = strings.ToValidUTF8(s, "")
	var b strings.Builder
	b.Grow(min(len(s), limit*4))
	space := false
	n := 0
	for _, r := range s {
		switch {
		case invisible(r):
			continue
		case unicode.IsSpace(r), unicode.IsControl(r):
			space = true
			continue
		}
		if n >= limit {
			break
		}
		if space && b.Len() > 0 {
			if n+1 >= limit {
				break
			}
			b.WriteByte(' ')
			n++
		}
		space = false
		b.WriteRune(r)
		n++
	}
	out := b.String()
	if utf8.RuneCountInString(out) > limit {
		out = string([]rune(out)[:limit])
	}
	return strings.TrimSpace(out)
}

func invisible(r rune) bool {
	return r == 0xFEFF || r == 0x061C || r == 0x00AD ||
		(r >= 0x200B && r <= 0x200F) || (r >= 0x202A && r <= 0x202E) || (r >= 0x2060 && r <= 0x2069)
}

func first(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

func hasToken(list, token string) bool {
	for _, f := range strings.Fields(strings.ToLower(list)) {
		if f == token {
			return true
		}
	}
	return false
}

func asciiLower(s string) string {
	for i := 0; i < len(s); i++ {
		if c := s[i]; c >= 'A' && c <= 'Z' {
			b := []byte(s)
			for j := i; j < len(b); j++ {
				if b[j] >= 'A' && b[j] <= 'Z' {
					b[j] += 'a' - 'A'
				}
			}
			return string(b)
		}
	}
	return s
}

func isLetter(c byte) bool {
	return c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z'
}

func isSpace(c byte) bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f'
}
