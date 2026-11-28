package page

import (
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"html/template"
	"regexp"
	"strings"
	"time"
	"unicode"
)

type Link struct {
	Kind  string
	Name  string
	Label string
	URL   string
}

type Segment struct {
	Text string
	Tag  bool
}

type Stock struct {
	Code string
	Name string
}

type Post struct {
	DisplayName string
	Username    string
	Badge       string
	Initials    string
	AvatarURL   string
	Body        []Segment
	More        bool
	Date        string
	Likes       int
	Comments    int
	ImageURL    string
	ImageWidth  int
	ImageHeight int
	Stocks      []Stock
}

type Data struct {
	Title        string
	Description  string
	SiteName     string
	CanonicalURL string
	OGImageURL   string
	OGImageW     int
	OGImageH     int
	AppURL       template.URL
	Downloads    []Link
	Post         *Post
	Heading      string
	Message      string
}

const style = `*{box-sizing:border-box}html{color-scheme:light}body{margin:0;background:#fff;color:#161614;font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;-webkit-font-smoothing:antialiased}a{color:inherit}.col{max-width:600px;margin:0 auto;padding:0 20px}.top{border-bottom:1px solid #ebebe7}.top .col{display:flex;align-items:center;height:56px}.word{font-weight:650;font-size:16px;letter-spacing:-.01em}main .col{padding-top:32px;padding-bottom:40px}.head{display:flex;gap:12px;align-items:center}.avatar{width:44px;height:44px;flex:none;border-radius:50%;object-fit:cover;background:#efefeb}.initials{display:flex;align-items:center;justify-content:center;color:#55554f;font-weight:600;font-size:15px}.who{min-width:0;line-height:1.35}.name{font-weight:650;overflow-wrap:anywhere}.badge svg{width:15px;height:15px;margin-left:4px;color:#0b7a53;vertical-align:-2px}.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}.meta{color:#74746d;font-size:14px}.body{margin:18px 0 0;font-size:18px;line-height:1.6;white-space:pre-wrap;overflow-wrap:anywhere}.tag{color:#0b7a53;font-weight:600}.more{display:inline-block;margin-top:8px;color:#0b7a53;font-weight:600;font-size:15px;text-decoration:none}.more:hover{text-decoration:underline}.shot{display:block;width:100%;height:auto;margin-top:18px;border:1px solid #ebebe7;border-radius:12px;background:#f4f4f1}.chips{display:flex;flex-wrap:wrap;gap:8px;margin-top:18px}.chip{display:inline-flex;align-items:baseline;gap:6px;padding:5px 12px;border:1px solid #dadad4;border-radius:999px;font-size:14px;font-weight:600;text-decoration:none}a.chip:hover{border-color:#0b7a53;color:#0b7a53}.chip small{color:#74746d;font-size:13px;font-weight:400}.stats{display:flex;align-items:center;justify-content:space-between;gap:12px;min-height:48px;margin-top:20px;border-top:1px solid #ebebe7;border-bottom:1px solid #ebebe7;color:#74746d;font-size:14px}.copy-link{display:inline-flex;align-items:center;gap:6px;margin-left:auto;padding:8px 0;border:0;background:none;color:#161614;font:inherit;font-size:14px;font-weight:600;cursor:pointer}.copy-link svg{width:16px;height:16px}.copy-link:hover{color:#0b7a53}.cta{margin-top:28px}.open{display:flex;align-items:center;justify-content:center;height:48px;border-radius:10px;background:#0b7a53;color:#fff;font-weight:600;text-decoration:none}.open:hover{background:#08613f}.get{margin:14px 0 0;color:#74746d;font-size:14px;line-height:1.8;text-align:center}.get.left{text-align:left}.get a{color:#161614;font-weight:600;text-decoration:none;border-bottom:1px solid #cfcfc8}.get a:hover{color:#0b7a53;border-color:#0b7a53}.dot{margin:0 7px;color:#b8b8b0}h1{margin:0 0 8px;font-size:22px;line-height:1.3;letter-spacing:-.01em}.msg p{margin:0;color:#55554f}.fine{border-top:1px solid #ebebe7;color:#8b8b84;font-size:13px}.fine .col{padding-top:16px;padding-bottom:28px}a:focus-visible,button:focus-visible{outline:2px solid #0b7a53;outline-offset:3px;border-radius:6px}.copy{position:fixed;top:0;left:0;width:1px;height:1px;opacity:0;pointer-events:none}@media (min-width:640px){main .col{padding-top:56px}}`

const script = `(function(){var u=navigator.userAgent||"";var m=/Mobile|Android|iPhone|iPad/.test(u)||(/Macintosh/.test(u)&&navigator.maxTouchPoints>1);var w=/Windows NT/.test(u);var mac=/Macintosh/.test(u)&&/Chrome|Chromium|Edg|Firefox|OPR/.test(u);var a=document.getElementById("open");if(a&&!m&&(w||mac)){setTimeout(function(){window.location.href=a.getAttribute("href")},400)}if(a&&navigator.sendBeacon){var h=a.getAttribute("href"),b=location.pathname.replace(/\/+$/,"")+"/open";document.addEventListener("click",function(e){var x=e.target&&e.target.closest?e.target.closest("a"):null;if(x&&x.getAttribute("href")===h){navigator.sendBeacon(b)}})}var s=document.getElementById("share");if(!s)return;var t=s.querySelector("span");function done(){if(t){t.textContent="Tautan disalin";setTimeout(function(){t.textContent="Salin tautan"},2000)}}function legacy(l){var f=document.createElement("textarea");f.value=l;f.setAttribute("readonly","");f.className="copy";document.body.appendChild(f);f.select();try{document.execCommand("copy");done()}catch(e){}document.body.removeChild(f)}s.addEventListener("click",function(){var l=window.location.href;if(m&&navigator.share){navigator.share({url:l}).catch(function(){});return}if(navigator.clipboard&&window.isSecureContext){navigator.clipboard.writeText(l).then(done,function(){legacy(l)});return}legacy(l)})})();`

const (
	iconCheck = `<svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor" aria-hidden="true"><path d="M12 2l2.6 2.1 3.4-.3.9 3.3 2.9 1.9-1.2 3.2 1.2 3.2-2.9 1.9-.9 3.3-3.4-.3L12 22.4l-2.6-2.1-3.4.3-.9-3.3-2.9-1.9 1.2-3.2L2.2 9l2.9-1.9.9-3.3 3.4.3z"/><path d="M8.5 12.3l2.4 2.4 4.8-5" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`
	iconLink  = `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/></svg>`
)

var tmpl = template.Must(template.New("page").Funcs(template.FuncMap{
	"icon": func(name string) template.HTML { return icons[name] },
}).Parse(`<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow, noarchive">
<meta name="color-scheme" content="light">
<meta name="theme-color" content="#ffffff">
<title>{{.Title}}</title>
<meta name="description" content="{{.Description}}">
<meta property="og:type" content="article">
<meta property="og:title" content="{{.Title}}">
<meta property="og:description" content="{{.Description}}">
<meta property="og:site_name" content="{{.SiteName}}">
{{if .CanonicalURL}}<meta property="og:url" content="{{.CanonicalURL}}">
<link rel="canonical" href="{{.CanonicalURL}}">
{{end}}{{if .OGImageURL}}<meta property="og:image" content="{{.OGImageURL}}">
{{if .OGImageW}}<meta property="og:image:width" content="{{.OGImageW}}">
<meta property="og:image:height" content="{{.OGImageH}}">
{{end}}<meta name="twitter:card" content="summary_large_image">
{{else}}<meta name="twitter:card" content="summary">
{{end}}<style>{{.Style}}</style>
</head>
<body>
<header class="top"><div class="col"><span class="word">{{.SiteName}}</span></div></header>
<main><div class="col">
{{with .Post}}<article>
<div class="head">
{{if .AvatarURL}}<img class="avatar" src="{{.AvatarURL}}" alt="" width="44" height="44">{{else}}<div class="avatar initials" aria-hidden="true">{{.Initials}}</div>{{end}}
<div class="who">
<div class="name">{{.DisplayName}}{{if .Badge}}<span class="badge" title="{{.Badge}}">{{icon "check"}}<span class="sr">{{.Badge}}</span></span>{{end}}</div>
<div class="meta">@{{.Username}}{{if .Date}} · {{.Date}}{{end}}</div>
</div>
</div>
{{if .Body}}<p class="body">{{range .Body}}{{if .Tag}}<span class="tag">{{.Text}}</span>{{else}}{{.Text}}{{end}}{{end}}</p>
{{if .More}}{{if $.AppURL}}<a class="more" href="{{$.AppURL}}">Baca selengkapnya di aplikasi</a>{{else}}<span class="more">Baca selengkapnya di aplikasi</span>{{end}}
{{end}}{{end}}{{if .ImageURL}}<img class="shot" src="{{.ImageURL}}" alt=""{{if .ImageWidth}} width="{{.ImageWidth}}" height="{{.ImageHeight}}"{{end}}>
{{end}}{{if .Stocks}}<div class="chips">
{{range .Stocks}}<a class="chip"{{if $.AppURL}} href="{{$.AppURL}}"{{end}}>${{.Code}}{{if .Name}} <small>{{.Name}}</small>{{end}}</a>
{{end}}</div>
{{end}}<div class="stats">{{if or .Likes .Comments}}<span>{{if .Likes}}{{.Likes}} suka{{end}}{{if and .Likes .Comments}} · {{end}}{{if .Comments}}{{.Comments}} komentar{{end}}</span>{{end}}<button type="button" id="share" class="copy-link">{{icon "link"}}<span>Salin tautan</span></button></div>
</article>
{{else}}<section class="msg">
<h1>{{.Heading}}</h1>
<p>{{.Message}}</p>
</section>
{{end}}{{if or .AppURL .Downloads}}<div class="cta">
{{if .AppURL}}<a id="open" class="open" href="{{.AppURL}}">Buka di {{.SiteName}}</a>
{{end}}{{if .Downloads}}<p class="get{{if not .AppURL}} left{{end}}">{{if .AppURL}}Belum punya aplikasinya? Unduh untuk{{else}}Unduh {{.SiteName}} untuk{{end}} {{range $i, $d := .Downloads}}{{if $i}}<span class="dot" aria-hidden="true">·</span>{{end}}<a href="{{$d.URL}}" rel="noopener" title="{{$d.Label}}">{{$d.Name}}</a>{{end}}</p>
{{end}}</div>
{{end}}</div></main>
<footer class="fine"><div class="col">{{.SiteName}}{{if .Post}} · Konten ini pendapat pengguna, bukan rekomendasi investasi.{{end}}</div></footer>
{{if or .AppURL .Post}}<script>{{.Script}}</script>{{end}}
</body>
</html>
`))

var icons = map[string]template.HTML{
	"check": iconCheck,
	"link":  iconLink,
}

type view struct {
	Data
	Style  template.CSS
	Script template.JS
}

func Render(d Data) ([]byte, error) {
	var b bytes.Buffer
	if err := tmpl.Execute(&b, view{Data: d, Style: template.CSS(style), Script: template.JS(script)}); err != nil {
		return nil, err
	}
	return b.Bytes(), nil
}

func ContentSecurityPolicy() string {
	return fmt.Sprintf("default-src 'none'; img-src 'self'; style-src '%s'; script-src '%s'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
		hash(style), hash(script))
}

func hash(s string) string {
	sum := sha256.Sum256([]byte(s))
	return "sha256-" + base64.StdEncoding.EncodeToString(sum[:])
}

var months = [...]string{"Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"}

var wib = time.FixedZone("WIB", 7*3600)

func Date(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	local := t.In(wib)
	return fmt.Sprintf("%d %s %d", local.Day(), months[local.Month()-1], local.Year())
}

func Initials(name string) string {
	words := strings.FieldsFunc(name, func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) })
	switch {
	case len(words) == 0:
		return "?"
	case len(words) == 1:
		runes := []rune(words[0])
		if len(runes) > 2 {
			runes = runes[:2]
		}
		return strings.ToUpper(string(runes))
	default:
		return strings.ToUpper(string([]rune(words[0])[0]) + string([]rune(words[1])[0]))
	}
}

var cashtag = regexp.MustCompile(`\$[A-Za-z][A-Za-z0-9]{1,11}`)

func Segments(body string) []Segment {
	var out []Segment
	last := 0
	for _, m := range cashtag.FindAllStringIndex(body, -1) {
		start, end := m[0], m[1]
		if start > 0 && wordByte(body[start-1]) || end < len(body) && wordByte(body[end]) {
			continue
		}
		if start > last {
			out = append(out, Segment{Text: body[last:start]})
		}
		out = append(out, Segment{Text: body[start:end], Tag: true})
		last = end
	}
	if last < len(body) {
		out = append(out, Segment{Text: body[last:]})
	}
	return out
}

func wordByte(b byte) bool {
	return b == '_' || b == '$' || b >= '0' && b <= '9' || b >= 'A' && b <= 'Z' || b >= 'a' && b <= 'z'
}
