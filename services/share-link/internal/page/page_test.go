package page

import (
	"regexp"
	"strings"
	"testing"
	"time"
)

func TestCSPHashesMatchTheRenderedInlineBlocks(t *testing.T) {
	out, err := Render(Data{Title: "t", SiteName: "OLT", AppURL: "olt://p/Ab12Cd34Ef"})
	if err != nil {
		t.Fatal(err)
	}
	html := string(out)
	csp := ContentSecurityPolicy()
	for _, tag := range []string{"style", "script"} {
		m := regexp.MustCompile(`(?s)<` + tag + `>(.*?)</` + tag + `>`).FindStringSubmatch(html)
		if m == nil {
			t.Fatalf("no <%s> block", tag)
		}
		if !strings.Contains(csp, hash(m[1])) {
			t.Errorf("CSP does not allow the rendered <%s> block", tag)
		}
	}
	if !strings.Contains(html, `href="olt://p/Ab12Cd34Ef"`) {
		t.Fatal("app link was rewritten by the template")
	}
}

func TestAutoOpenCoversWindowsAndMacButNotSafariOrPhones(t *testing.T) {
	for _, want := range []string{`/Windows NT/`, `/Macintosh/`, `Chrome|Chromium|Edg|Firefox|OPR`, `Mobile|Android|iPhone|iPad`, `maxTouchPoints>1`} {
		if !strings.Contains(script, want) {
			t.Errorf("auto-open script is missing %q", want)
		}
	}
}

func TestPageIsLightOnly(t *testing.T) {
	out, err := Render(Data{Title: "t", SiteName: "Rendezvous OLT", AppURL: "rendezvous-olt://p/Ab12Cd34Ef",
		Downloads: []Link{{Kind: "windows", Name: "Windows", Label: "Unduh untuk Windows", URL: "https://example.com/olt.exe"}},
		Post:      &Post{DisplayName: "OLT Research", Username: "olt_research", Initials: "OR", Body: Segments("$BBNI naik"), More: true}})
	if err != nil {
		t.Fatal(err)
	}
	html := string(out)
	if strings.Contains(style, "prefers-color-scheme") {
		t.Fatal("the share page must not switch to a dark theme")
	}
	for _, want := range []string{
		`<meta name="color-scheme" content="light">`,
		`<span class="mark" aria-hidden="true">R</span><span>Rendezvous <b>OLT</b></span>`,
		`<a class="btn dl" href="https://example.com/olt.exe" rel="noopener" title="Unduh untuk Windows">`,
		`<span class="tag">$BBNI</span> naik`,
		`Baca selengkapnya di aplikasi`,
		`Lanjutkan di Rendezvous OLT`,
		`id="share"`,
	} {
		if !strings.Contains(html, want) {
			t.Errorf("page is missing %q", want)
		}
	}
	if strings.Contains(html, " style=") {
		t.Fatal("inline style attributes are blocked by the CSP")
	}
}

func TestSegmentsMarkCashtagsOnly(t *testing.T) {
	got := Segments("Beli $BBCA, bukan US$5 atau $X atau $$BBRI_ lalu $tlkm.")
	var tags []string
	for _, s := range got {
		if s.Tag {
			tags = append(tags, s.Text)
		}
	}
	if strings.Join(tags, ",") != "$BBCA,$tlkm" {
		t.Fatalf("tags = %v", tags)
	}
	var joined strings.Builder
	for _, s := range got {
		joined.WriteString(s.Text)
	}
	if joined.String() != "Beli $BBCA, bukan US$5 atau $X atau $$BBRI_ lalu $tlkm." {
		t.Fatal("segments must keep the whole text")
	}
}

func TestInitials(t *testing.T) {
	for in, want := range map[string]string{"OLT Research": "OR", "hidayat": "HI", " ": "?", "Ani": "AN", "a.b": "AB"} {
		if got := Initials(in); got != want {
			t.Errorf("Initials(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestNoScriptWithoutAppLink(t *testing.T) {
	out, err := Render(Data{Title: "t", SiteName: "OLT", Heading: "h", Message: "m"})
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(out), "<script>") {
		t.Fatal("pages without an app link need no script")
	}
}

func TestDateUsesWIB(t *testing.T) {
	if got := Date(time.Date(2026, 12, 31, 17, 30, 0, 0, time.UTC)); got != "1 Jan 2027" {
		t.Fatalf("Date = %q", got)
	}
	if Date(time.Time{}) != "" || Initial(" ani") != "A" || Initial("") != "?" {
		t.Fatal("helpers")
	}
}
