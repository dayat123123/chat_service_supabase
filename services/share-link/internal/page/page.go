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

const style = `*{box-sizing:border-box}body{margin:0;background:#f4f5f7;color:#16181d;font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}main{max-width:560px;margin:0 auto;padding:24px 16px 40px}.site{font-weight:600;font-size:15px;color:#5b6270;margin:0 0 16px}.card{background:#fff;border:1px solid #e3e5ea;border-radius:14px;padding:16px}.head{display:flex;gap:12px;align-items:center}.avatar{width:44px;height:44px;border-radius:50%;object-fit:cover;flex:none;background:#dfe3ea}.initial{display:flex;align-items:center;justify-content:center;font-weight:600;color:#3d4452}.who{min-width:0}.name{font-weight:600;overflow-wrap:anywhere}.badge{display:inline-block;margin-left:6px;padding:0 6px;border-radius:6px;background:#e7efff;color:#1f4fbf;font-size:12px;font-weight:600;vertical-align:2px}.meta{color:#6b7280;font-size:14px}.body{margin:12px 0 0;white-space:pre-wrap;overflow-wrap:anywhere}.shot{display:block;width:100%;height:auto;margin-top:12px;border-radius:10px;background:#eef0f3}.stats{margin-top:12px;color:#6b7280;font-size:14px}.actions{display:flex;flex-direction:column;gap:10px;margin-top:20px}.btn{display:block;text-align:center;padding:12px 16px;border-radius:10px;text-decoration:none;font-weight:600}.primary{background:#1f4fbf;color:#fff}.secondary{background:#fff;color:#16181d;border:1px solid #d6d9e0}.note{margin-top:16px;color:#6b7280;font-size:14px;text-align:center}h1{font-size:20px;margin:0 0 8px}@media (prefers-color-scheme:dark){body{background:#0f1115;color:#e8eaee}.site,.meta,.stats,.note{color:#9aa1ad}.card,.secondary{background:#171a21;border-color:#2a2f3a;color:#e8eaee}.avatar,.shot{background:#262b35}.initial{color:#c9ced8}.badge{background:#1c2b4d;color:#a9c2ff}}`

const script = `(function(){var a=document.getElementById("open");if(!a)return;var u=navigator.userAgent||"";var m=/Mobile|Android|iPhone|iPad/.test(u)||(/Macintosh/.test(u)&&navigator.maxTouchPoints>1);var w=/Windows NT/.test(u);var mac=/Macintosh/.test(u)&&/Chrome|Chromium|Edg|Firefox|OPR/.test(u);if(!m&&(w||mac)){setTimeout(function(){window.location.href=a.getAttribute("href")},400)}})();`

var tmpl = template.Must(template.New("page").Parse(`<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow, noarchive">
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
<p class="site">{{.SiteName}}</p>
{{with .Post}}<article class="card">
<div class="head">
{{if .AvatarURL}}<img class="avatar" src="{{.AvatarURL}}" alt="" width="44" height="44">{{else}}<div class="avatar initial" aria-hidden="true">{{.Initial}}</div>{{end}}
<div class="who">
<div class="name">{{.DisplayName}}{{if .Badge}}<span class="badge">{{.Badge}}</span>{{end}}</div>
<div class="meta">@{{.Username}}{{if .Date}} · {{.Date}}{{end}}</div>
</div>
</div>
{{if .Body}}<p class="body">{{.Body}}</p>{{end}}
{{if .ImageURL}}<img class="shot" src="{{.ImageURL}}" alt=""{{if .ImageWidth}} width="{{.ImageWidth}}" height="{{.ImageHeight}}"{{end}}>{{end}}
{{if .Stats}}<div class="stats">{{.Stats}}</div>{{end}}
</article>
{{else}}<section class="card">
<h1>{{.Heading}}</h1>
<p>{{.Message}}</p>
</section>
{{end}}{{if or .AppURL .Downloads}}<div class="actions">
{{if .AppURL}}<a id="open" class="btn primary" href="{{.AppURL}}">{{.OpenLabel}}</a>{{end}}
{{range .Downloads}}<a class="btn secondary" href="{{.URL}}" rel="noopener">{{.Label}}</a>
{{end}}</div>
{{if .AppURL}}<p class="note">Belum punya aplikasinya? Unduh dulu, lalu buka tautan ini lagi.</p>{{end}}
{{end}}</main>
{{if .AppURL}}<script>{{.Script}}</script>{{end}}
</body>
</html>
`))

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
