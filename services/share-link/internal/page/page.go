package page

import (
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"html/template"
	"strings"
	"time"
)

type Link struct {
	Label string
	URL   string
}

type Post struct {
	DisplayName string
	Username    string
	Badge       string
	Initial     string
	AvatarURL   string
	Body        string
	Date        string
	Stats       string
	ImageURL    string
	ImageWidth  int
	ImageHeight int
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
	OpenLabel    string
	Downloads    []Link
	Post         *Post
	Heading      string
	Message      string
}

const style = `*{box-sizing:border-box}html{color-scheme:light}body{margin:0;min-height:100vh;background:#f5f7fb linear-gradient(180deg,#e6eeff 0,#f5f7fb 380px) no-repeat;color:#0f172a;font:16px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;-webkit-font-smoothing:antialiased}main{max-width:580px;margin:0 auto;padding:28px 16px 48px}.top{display:flex;align-items:center;gap:10px;margin:0 0 20px}.mark{display:flex;align-items:center;justify-content:center;width:36px;height:36px;border-radius:11px;background:linear-gradient(135deg,#3b82f6,#1d4ed8);color:#fff;font-weight:700;font-size:17px;box-shadow:0 6px 14px -6px rgba(29,78,216,.6)}.site{font-weight:700;font-size:17px;letter-spacing:-.01em}.card{background:#fff;border:1px solid #e5e9f2;border-radius:20px;padding:20px;box-shadow:0 1px 2px rgba(15,23,42,.04),0 18px 40px -22px rgba(15,23,42,.22)}.head{display:flex;gap:12px;align-items:center}.avatar{width:48px;height:48px;border-radius:50%;object-fit:cover;flex:none;background:#e2e8f0;box-shadow:0 0 0 2px #fff,0 0 0 3px #e2e8f0}.initial{display:flex;align-items:center;justify-content:center;font-weight:700;font-size:18px;color:#1d4ed8;background:#dbeafe}.who{min-width:0}.name{display:flex;flex-wrap:wrap;align-items:center;gap:6px;font-weight:700;overflow-wrap:anywhere}.badge{display:inline-flex;align-items:center;gap:4px;padding:1px 9px 1px 5px;border-radius:999px;background:#eff6ff;color:#1d4ed8;font-size:12px;font-weight:600;line-height:20px}.badge svg{width:15px;height:15px}.meta{color:#64748b;font-size:14px}.body{margin:14px 0 0;font-size:16.5px;line-height:1.6;color:#1e293b;white-space:pre-wrap;overflow-wrap:anywhere}.shot{display:block;width:100%;height:auto;margin-top:14px;border-radius:14px;border:1px solid #e5e9f2;background:#f1f5f9}.stats{margin-top:14px;padding-top:12px;border-top:1px solid #eef1f6;color:#64748b;font-size:14px}.empty{text-align:center;padding:36px 24px}.icon{display:inline-flex;align-items:center;justify-content:center;width:56px;height:56px;border-radius:16px;background:#eff6ff;color:#1d4ed8;margin-bottom:14px}.icon svg{width:28px;height:28px}h1{font-size:20px;line-height:1.3;margin:0 0 6px;letter-spacing:-.01em}.empty p{margin:0;color:#475569}.actions{margin-top:20px}.btn{display:flex;align-items:center;justify-content:center;gap:8px;min-height:48px;padding:12px 16px;border-radius:12px;text-decoration:none;font-weight:600;transition:background-color .15s,border-color .15s,box-shadow .15s}.btn svg{width:18px;height:18px;flex:none}.primary{min-height:54px;font-size:16.5px;background:linear-gradient(135deg,#2563eb,#1d4ed8);color:#fff;box-shadow:0 12px 24px -12px rgba(37,99,235,.75)}.primary:hover{background:#1e40af}.note{margin:16px 0 12px;color:#64748b;font-size:14px;text-align:center}.stores{display:grid;gap:10px}.store{background:#fff;color:#0f172a;border:1px solid #dfe4ee;font-size:15px}.store svg{color:#2563eb}.store:hover{background:#f8fafc;border-color:#bfccdf}.btn:focus-visible{outline:3px solid #93c5fd;outline-offset:2px}@media (min-width:480px){main{padding-top:44px}.stores{grid-template-columns:1fr 1fr}.store:last-child:nth-child(odd){grid-column:1/-1}}`

const script = `(function(){var a=document.getElementById("open");if(!a)return;var u=navigator.userAgent||"";var m=/Mobile|Android|iPhone|iPad/.test(u)||(/Macintosh/.test(u)&&navigator.maxTouchPoints>1);var w=/Windows NT/.test(u);var mac=/Macintosh/.test(u)&&/Chrome|Chromium|Edg|Firefox|OPR/.test(u);if(!m&&(w||mac)){setTimeout(function(){window.location.href=a.getAttribute("href")},400)}})();`

var tmpl = template.Must(template.New("page").Parse(`<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow, noarchive">
<meta name="color-scheme" content="light">
<meta name="theme-color" content="#e6eeff">
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
<main>
<header class="top"><span class="mark" aria-hidden="true">{{.Brand}}</span><span class="site">{{.SiteName}}</span></header>
{{with .Post}}<article class="card">
<div class="head">
{{if .AvatarURL}}<img class="avatar" src="{{.AvatarURL}}" alt="" width="48" height="48">{{else}}<div class="avatar initial" aria-hidden="true">{{.Initial}}</div>{{end}}
<div class="who">
<div class="name"><span>{{.DisplayName}}</span>{{if .Badge}}<span class="badge"><svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor" aria-hidden="true"><path d="M12 2l2.6 2.1 3.4-.3.9 3.3 2.9 1.9-1.2 3.2 1.2 3.2-2.9 1.9-.9 3.3-3.4-.3L12 22.4l-2.6-2.1-3.4.3-.9-3.3-2.9-1.9 1.2-3.2L2.2 9l2.9-1.9.9-3.3 3.4.3z"/><path d="M8.5 12.3l2.4 2.4 4.8-5" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>{{.Badge}}</span>{{end}}</div>
<div class="meta">@{{.Username}}{{if .Date}} · {{.Date}}{{end}}</div>
</div>
</div>
{{if .Body}}<p class="body">{{.Body}}</p>{{end}}
{{if .ImageURL}}<img class="shot" src="{{.ImageURL}}" alt=""{{if .ImageWidth}} width="{{.ImageWidth}}" height="{{.ImageHeight}}"{{end}}>{{end}}
{{if .Stats}}<div class="stats">{{.Stats}}</div>{{end}}
</article>
{{else}}<section class="card empty">
<div class="icon" aria-hidden="true"><svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/></svg></div>
<h1>{{.Heading}}</h1>
<p>{{.Message}}</p>
</section>
{{end}}{{if .AppURL}}<div class="actions">
<a id="open" class="btn primary" href="{{.AppURL}}">{{.OpenLabel}}<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M7 17L17 7M9 7h8v8"/></svg></a>
</div>
{{end}}{{if .Downloads}}<p class="note">{{if .AppURL}}Belum punya aplikasinya? Unduh dulu, lalu buka tautan ini lagi.{{else}}Unduh aplikasi {{.SiteName}}{{end}}</p>
<div class="stores">
{{range .Downloads}}<a class="btn store" href="{{.URL}}" rel="noopener"><svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4v11M7.5 10.5L12 15l4.5-4.5M5 19h14"/></svg>{{.Label}}</a>
{{end}}</div>
{{else if .AppURL}}<p class="note">Pastikan aplikasi {{.SiteName}} sudah terpasang di perangkat ini.</p>
{{end}}</main>
{{if .AppURL}}<script>{{.Script}}</script>{{end}}
</body>
</html>
`))

type view struct {
	Data
	Brand  string
	Style  template.CSS
	Script template.JS
}

func Render(d Data) ([]byte, error) {
	var b bytes.Buffer
	if err := tmpl.Execute(&b, view{Data: d, Brand: Initial(d.SiteName), Style: template.CSS(style), Script: template.JS(script)}); err != nil {
		return nil, err
	}
	return b.Bytes(), nil
}

func ContentSecurityPolicy() string {
	return fmt.Sprintf("default-src 'none'; img-src 'self'; style-src '%s'; script-src '%s'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
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

func Initial(name string) string {
	for _, r := range strings.TrimSpace(name) {
		return strings.ToUpper(string(r))
	}
	return "?"
}
