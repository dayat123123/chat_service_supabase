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
	Code     string
	Name     string
	Initials string
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

const style = `*{box-sizing:border-box}html{color-scheme:light}body{margin:0;min-height:100vh;display:flex;flex-direction:column;background:#f3f5f8;color:#0f172a;font:15px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;-webkit-font-smoothing:antialiased}a{color:inherit}svg{flex:none}.wrap{width:100%;max-width:1040px;margin:0 auto;padding:0 16px}.nav{position:sticky;top:0;z-index:5;background:rgba(255,255,255,.92);border-bottom:1px solid #e6e9ef;backdrop-filter:saturate(1.4) blur(8px)}.navin{display:flex;align-items:center;justify-content:space-between;gap:12px;height:60px}.brand{display:flex;align-items:center;gap:10px;min-width:0;font-weight:700;font-size:16px;letter-spacing:-.01em;text-decoration:none}.brand b{color:#059669}.mark{display:flex;align-items:center;justify-content:center;width:32px;height:32px;border-radius:9px;background:linear-gradient(135deg,#10b981,#047857);color:#fff;font-weight:800;font-size:16px}.mark.lg{width:40px;height:40px;border-radius:11px;font-size:19px}.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;border-radius:10px;font-weight:600;text-decoration:none;cursor:pointer;transition:background-color .15s,border-color .15s,box-shadow .15s}.btn:focus-visible,.act:focus-visible,.stock:focus-visible,.more:focus-visible{outline:3px solid #6ee7b7;outline-offset:2px}.green{background:#059669;color:#fff}.green:hover{background:#047857}.navbtn{height:36px;padding:0 16px;font-size:14px}main{flex:1;padding:28px 0 48px}.grid{display:grid;gap:20px;align-items:start}.card{background:#fff;border:1px solid #e6e9ef;border-radius:16px;box-shadow:0 1px 2px rgba(15,23,42,.04),0 12px 32px -24px rgba(15,23,42,.25)}.post{padding:20px 20px 0}.head{display:flex;gap:12px;align-items:center}.avatar{width:44px;height:44px;border-radius:50%;object-fit:cover;background:#e2e8f0}.initials{display:flex;align-items:center;justify-content:center;background:#0f172a;color:#fff;font-weight:700;font-size:14px;letter-spacing:.02em}.who{min-width:0}.name{display:flex;flex-wrap:wrap;align-items:center;gap:6px;font-weight:700;overflow-wrap:anywhere}.badge{display:inline-flex;align-items:center;gap:3px;padding:1px 8px 1px 5px;border-radius:999px;background:#ecfdf5;color:#047857;font-size:11.5px;font-weight:600;line-height:19px}.badge svg{width:14px;height:14px}.meta{color:#64748b;font-size:13px}.body{margin:16px 0 0;font-size:16px;line-height:1.7;color:#1e293b;white-space:pre-wrap;overflow-wrap:anywhere}.body.fade{-webkit-mask-image:linear-gradient(180deg,#000 calc(100% - 3.4em),rgba(0,0,0,.15));mask-image:linear-gradient(180deg,#000 calc(100% - 3.4em),rgba(0,0,0,.15))}.tag{color:#059669;font-weight:600}.more{display:inline-flex;margin-top:6px;color:#047857;font-weight:600;font-size:14px;text-decoration:none}.more:hover{text-decoration:underline}.shot{display:block;width:100%;height:auto;margin-top:16px;border-radius:12px;border:1px solid #e6e9ef;background:#f1f5f9}.stocks{display:grid;gap:8px;margin-top:16px}.stock{display:flex;align-items:center;gap:12px;padding:12px 14px;border:1px solid #e6e9ef;border-radius:12px;text-decoration:none;transition:border-color .15s,background-color .15s}.stock:hover{border-color:#a7f3d0;background:#f8fffc}.sico{display:flex;align-items:center;justify-content:center;width:36px;height:36px;border-radius:9px;background:#fff1e6;color:#c2410c;font-weight:700;font-size:12.5px}.sinfo{display:flex;flex-direction:column;min-width:0;flex:1}.sinfo b{font-size:14.5px}.sinfo small{color:#64748b;font-size:12.5px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.slink{color:#047857;font-weight:600;font-size:13px}.acts{display:flex;gap:4px;margin:16px -20px 0;padding:6px 12px;border-top:1px solid #eef1f5}.act{display:inline-flex;align-items:center;gap:7px;padding:8px 10px;border:0;border-radius:8px;background:none;color:#475569;font:inherit;font-size:14px;text-decoration:none;cursor:pointer}.act:hover{background:#f1f5f9;color:#0f172a}.act svg{width:18px;height:18px}.act em{font-style:normal;color:#94a3b8}.empty{padding:40px 24px;text-align:center}.icon{display:inline-flex;align-items:center;justify-content:center;width:56px;height:56px;border-radius:16px;background:#ecfdf5;color:#059669;margin-bottom:14px}.icon svg{width:28px;height:28px}h1{font-size:20px;line-height:1.3;margin:0 0 6px;letter-spacing:-.01em}.empty p{margin:0;color:#475569}.side{display:grid;gap:16px}.cta{padding:20px;border-radius:16px;background:linear-gradient(160deg,#111c33,#0b1222);color:#fff;box-shadow:0 18px 40px -24px rgba(15,23,42,.7)}.ctah{display:flex;align-items:center;gap:12px}.ctah b{display:block;font-size:16px}.ctah small{display:block;color:#94a3b8;font-size:13px}.open{width:100%;height:48px;margin-top:18px;font-size:15px;box-shadow:0 10px 22px -12px rgba(16,185,129,.8)}.open svg{width:17px;height:17px}.or{display:flex;align-items:center;gap:10px;margin:18px 0 12px;color:#94a3b8;font-size:12.5px}.or:before,.or:after{content:"";flex:1;height:1px;background:rgba(148,163,184,.25)}.dls{display:grid;grid-template-columns:1fr 1fr;gap:8px}.dl{height:42px;padding:0 10px;border:1px solid rgba(148,163,184,.3);color:#fff;font-size:14px}.dl:hover{background:rgba(255,255,255,.07);border-color:rgba(148,163,184,.55)}.dl svg{width:17px;height:17px}.dl:last-child:nth-child(odd){grid-column:1/-1}.hint{margin:12px 0 0;color:#94a3b8;font-size:12.5px;text-align:center}.perks{padding:18px 20px}.perks h2{margin:0 0 12px;font-size:14.5px}.perk{display:flex;gap:12px;padding:8px 0}.pico{display:flex;align-items:center;justify-content:center;width:34px;height:34px;border-radius:9px}.pico svg{width:18px;height:18px}.p1{background:#ecfdf5;color:#059669}.p2{background:#eff6ff;color:#2563eb}.p3{background:#fff7ed;color:#ea580c}.perk b{display:block;font-size:14px}.perk small{display:block;color:#64748b;font-size:13px}.foot{border-top:1px solid #e6e9ef;background:#fff;color:#64748b;font-size:13px}.footin{display:flex;flex-wrap:wrap;justify-content:space-between;gap:8px;padding-top:18px;padding-bottom:18px}.copy{position:fixed;top:0;left:0;width:1px;height:1px;opacity:0;pointer-events:none}@media (min-width:880px){main{padding-top:40px}.grid{grid-template-columns:minmax(0,1fr) 330px;gap:24px}.side{position:sticky;top:84px}.post{padding:24px 24px 0}.acts{margin:18px -24px 0;padding:6px 16px}}@media (max-width:420px){.brand span{max-width:150px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}}`

const script = `(function(){var u=navigator.userAgent||"";var m=/Mobile|Android|iPhone|iPad/.test(u)||(/Macintosh/.test(u)&&navigator.maxTouchPoints>1);var w=/Windows NT/.test(u);var mac=/Macintosh/.test(u)&&/Chrome|Chromium|Edg|Firefox|OPR/.test(u);var a=document.getElementById("open");if(a&&!m&&(w||mac)){setTimeout(function(){window.location.href=a.getAttribute("href")},400)}var s=document.getElementById("share");if(!s)return;var t=s.querySelector("span");function done(){if(t){t.textContent="Tautan disalin";setTimeout(function(){t.textContent="Bagikan"},2000)}}function legacy(l){var f=document.createElement("textarea");f.value=l;f.setAttribute("readonly","");f.className="copy";document.body.appendChild(f);f.select();try{document.execCommand("copy");done()}catch(e){}document.body.removeChild(f)}s.addEventListener("click",function(){var l=window.location.href;if(m&&navigator.share){navigator.share({url:l}).catch(function(){});return}if(navigator.clipboard&&window.isSecureContext){navigator.clipboard.writeText(l).then(done,function(){legacy(l)});return}legacy(l)})})();`

const (
	iconCheck   = `<svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor" aria-hidden="true"><path d="M12 2l2.6 2.1 3.4-.3.9 3.3 2.9 1.9-1.2 3.2 1.2 3.2-2.9 1.9-.9 3.3-3.4-.3L12 22.4l-2.6-2.1-3.4.3-.9-3.3-2.9-1.9 1.2-3.2L2.2 9l2.9-1.9.9-3.3 3.4.3z"/><path d="M8.5 12.3l2.4 2.4 4.8-5" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`
	iconArrow   = `<svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M7 17L17 7M9 7h8v8"/></svg>`
	iconInfo    = `<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/></svg>`
	iconHeart   = `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" aria-hidden="true"><path d="M12 20s-7.5-4.6-7.5-10.2A4.2 4.2 0 0 1 12 7.3a4.2 4.2 0 0 1 7.5 2.5C19.5 15.4 12 20 12 20z"/></svg>`
	iconComment = `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" aria-hidden="true"><path d="M5 5h14a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1h-8l-4.5 3.5V16H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z"/></svg>`
	iconShare   = `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 15V4M8 8l4-4 4 4M5 13v6h14v-6"/></svg>`
	iconPhone   = `<svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="7" y="2.5" width="10" height="19" rx="2.2"/><path d="M11 18h2"/></svg>`
	iconDesktop = `<svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/></svg>`
	iconChat    = `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round" aria-hidden="true"><path d="M5 5h14a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1h-8l-4.5 3.5V16H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z"/></svg>`
	iconTrend   = `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 16l5-5 4 3 7-7M15 7h5v5"/></svg>`
	iconReceipt = `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M7 3h10v18l-2.5-1.5L12 21l-2.5-1.5L7 21z"/><path d="M10 8h4M10 12h4"/></svg>`
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
<header class="nav"><div class="wrap navin">
<div class="brand"><span class="mark" aria-hidden="true">{{.Brand}}</span><span>{{.BrandHead}}{{if .BrandTail}} <b>{{.BrandTail}}</b>{{end}}</span></div>
{{if .AppURL}}<a class="btn green navbtn" href="{{.AppURL}}">Buka aplikasi</a>{{end}}
</div></header>
<main><div class="wrap grid">
<div>
{{with .Post}}<article class="card post">
<div class="head">
{{if .AvatarURL}}<img class="avatar" src="{{.AvatarURL}}" alt="" width="44" height="44">{{else}}<div class="avatar initials" aria-hidden="true">{{.Initials}}</div>{{end}}
<div class="who">
<div class="name"><span>{{.DisplayName}}</span>{{if .Badge}}<span class="badge">{{icon "check"}}{{.Badge}}</span>{{end}}</div>
<div class="meta">@{{.Username}}{{if .Date}} · {{.Date}}{{end}}</div>
</div>
</div>
{{if .Body}}<p class="body{{if .More}} fade{{end}}">{{range .Body}}{{if .Tag}}<span class="tag">{{.Text}}</span>{{else}}{{.Text}}{{end}}{{end}}</p>
{{if .More}}{{if $.AppURL}}<a class="more" href="{{$.AppURL}}">Baca selengkapnya di aplikasi →</a>{{else}}<span class="more">Baca selengkapnya di aplikasi</span>{{end}}
{{end}}{{end}}{{if .ImageURL}}<img class="shot" src="{{.ImageURL}}" alt=""{{if .ImageWidth}} width="{{.ImageWidth}}" height="{{.ImageHeight}}"{{end}}>
{{end}}{{if .Stocks}}<div class="stocks">
{{range .Stocks}}<a class="stock" href="{{if $.AppURL}}{{$.AppURL}}{{else}}#{{end}}"><span class="sico" aria-hidden="true">{{.Initials}}</span><span class="sinfo"><b>${{.Code}}</b><small>{{if .Name}}{{.Name}}{{else}}Grafik dan diskusi saham ini{{end}}</small></span><span class="slink">Lihat saham</span></a>
{{end}}</div>
{{end}}<div class="acts">
<a class="act" href="{{if $.AppURL}}{{$.AppURL}}{{else}}#{{end}}">{{icon "heart"}}Suka{{if .Likes}} <em>{{.Likes}}</em>{{end}}</a>
<a class="act" href="{{if $.AppURL}}{{$.AppURL}}{{else}}#{{end}}">{{icon "comment"}}Komentar{{if .Comments}} <em>{{.Comments}}</em>{{end}}</a>
<button type="button" id="share" class="act">{{icon "share"}}<span>Bagikan</span></button>
</div>
</article>
{{else}}<section class="card empty">
<div class="icon">{{icon "info"}}</div>
<h1>{{.Heading}}</h1>
<p>{{.Message}}</p>
</section>
{{end}}</div>
<aside class="side">
{{if or .AppURL .Downloads}}<section class="cta">
<div class="ctah"><span class="mark lg" aria-hidden="true">{{.Brand}}</span><div><b>Lanjutkan di {{.SiteName}}</b><small>Ikut diskusi dan pantau sahamnya</small></div></div>
{{if .AppURL}}<a id="open" class="btn green open" href="{{.AppURL}}">Buka di aplikasi {{icon "arrow"}}</a>
{{end}}{{if .Downloads}}<div class="or">{{if .AppURL}}Belum punya aplikasinya?{{else}}Unduh aplikasinya{{end}}</div>
<div class="dls">
{{range .Downloads}}<a class="btn dl" href="{{.URL}}" rel="noopener" title="{{.Label}}">{{if or (eq .Kind "windows") (eq .Kind "mac")}}{{icon "desktop"}}{{else}}{{icon "phone"}}{{end}}{{.Name}}</a>
{{end}}</div>
{{if .AppURL}}<p class="hint">Sudah memasang? Tekan Buka di aplikasi.</p>{{end}}
{{else if .AppURL}}<p class="hint">Pastikan aplikasi {{.SiteName}} sudah terpasang di perangkat ini.</p>
{{end}}</section>
{{end}}<section class="card perks">
<h2>Di aplikasi {{.SiteName}} kamu bisa</h2>
<div class="perk"><span class="pico p1">{{icon "chat"}}</span><div><b>Diskusi di Stream</b><small>Balas dan ikuti obrolan per saham.</small></div></div>
<div class="perk"><span class="pico p2">{{icon "trend"}}</span><div><b>Pantau harga realtime</b><small>Chart, order book, dan watchlist.</small></div></div>
<div class="perk"><span class="pico p3">{{icon "receipt"}}</span><div><b>Trading saham IDX</b><small>Pasang order langsung dari aplikasi.</small></div></div>
</section>
</aside>
</div></main>
<footer class="foot"><div class="wrap footin"><span>© {{.SiteName}}</span>{{if .Post}}<span>Konten ini dibagikan dari Stream {{.SiteName}}</span>{{end}}</div></footer>
{{if or .AppURL .Post}}<script>{{.Script}}</script>{{end}}
</body>
</html>
`))

var icons = map[string]template.HTML{
	"check":   iconCheck,
	"arrow":   iconArrow,
	"info":    iconInfo,
	"heart":   iconHeart,
	"comment": iconComment,
	"share":   iconShare,
	"phone":   iconPhone,
	"desktop": iconDesktop,
	"chat":    iconChat,
	"trend":   iconTrend,
	"receipt": iconReceipt,
}

type view struct {
	Data
	Brand     string
	BrandHead string
	BrandTail string
	Style     template.CSS
	Script    template.JS
}

func Render(d Data) ([]byte, error) {
	head, tail := splitBrand(d.SiteName)
	v := view{Data: d, Brand: Initial(d.SiteName), BrandHead: head, BrandTail: tail,
		Style: template.CSS(style), Script: template.JS(script)}
	var b bytes.Buffer
	if err := tmpl.Execute(&b, v); err != nil {
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

func splitBrand(name string) (string, string) {
	name = strings.TrimSpace(name)
	i := strings.LastIndex(name, " ")
	if i <= 0 {
		return name, ""
	}
	return name[:i], name[i+1:]
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
