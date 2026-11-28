package page

import (
	"regexp"
	"strings"
	"testing"
	"time"
)

func TestCSPHashesMatchTheRenderedInlineBlocks(t *testing.T) {
	out, err := Render(Data{Title: "t", SiteName: "OLT", AppURL: "olt://p/Ab12Cd34Ef", OpenLabel: "Buka"})
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
