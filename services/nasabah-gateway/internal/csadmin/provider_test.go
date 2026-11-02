package csadmin

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
)

type fakeSource struct {
	mu       sync.Mutex
	settings Settings
	err      error
	reads    int
}

func (f *fakeSource) Integration(context.Context) (Settings, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.reads++
	return f.settings, f.err
}

func (f *fakeSource) set(s Settings, err error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.settings, f.err = s, err
}

func newKey(t *testing.T) ed25519.PrivateKey {
	t.Helper()
	_, key, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	return key
}

func TestProviderPrefersWebSettingsOverServerValues(t *testing.T) {
	source := &fakeSource{settings: Settings{URL: "http://10.0.0.5:9001/csAdmin/", ClientID: "web-cs.prod"}}
	p := NewProvider(ProviderOptions{Source: source, Server: Settings{URL: "http://csadmin:8080", ClientID: "web-cs"}, Key: newKey(t)})

	s := p.Session(context.Background())
	if s.BaseURL() != "http://10.0.0.5:9001/csAdmin" || !s.Configured() {
		t.Fatalf("session must use the web settings, got %q", s.BaseURL())
	}
	want := Effective{URL: "http://10.0.0.5:9001/csAdmin", URLSource: SourceSettings, ClientID: "web-cs.prod", ClientIDSource: SourceSettings}
	if got := p.Effective(context.Background()); got != want {
		t.Fatalf("effective = %+v", got)
	}
}

func TestProviderFallsBackToServerValuesAndThenToNothing(t *testing.T) {
	source := &fakeSource{}
	p := NewProvider(ProviderOptions{Source: source, Server: Settings{URL: "http://csadmin:8080/", ClientID: "web-cs"}, Key: newKey(t)})
	want := Effective{URL: "http://csadmin:8080", URLSource: SourceServer, ClientID: "web-cs", ClientIDSource: SourceServer}
	if got := p.Effective(context.Background()); got != want {
		t.Fatalf("effective = %+v", got)
	}

	empty := NewProvider(ProviderOptions{Source: source, Key: newKey(t)})
	got := empty.Effective(context.Background())
	if got.URLSource != SourceNone || got.ClientID != DefaultClientID || empty.Session(context.Background()).Configured() {
		t.Fatalf("without any address the gateway must stay unconfigured, got %+v", got)
	}
}

func TestProviderIgnoresAnUnsafeStoredAddress(t *testing.T) {
	source := &fakeSource{settings: Settings{URL: "http://admin:secret@10.0.0.5", ClientID: "web cs"}}
	p := NewProvider(ProviderOptions{Source: source, Server: Settings{URL: "http://csadmin:8080", ClientID: "web-cs"}, Key: newKey(t)})
	if got := p.Effective(context.Background()); got.URLSource != SourceServer || got.ClientIDSource != SourceServer {
		t.Fatalf("invalid stored values must fall back to the server values, got %+v", got)
	}
}

func TestProviderReloadsAfterTheTTLAndOnlyReplacesTheSessionOnChange(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	source := &fakeSource{settings: Settings{URL: "http://10.0.0.5:8080"}}
	p := NewProvider(ProviderOptions{Source: source, Key: newKey(t), TTL: 15 * time.Second})
	p.now = func() time.Time { return now }

	first := p.Session(context.Background())
	source.set(Settings{URL: "http://10.0.0.6:8080"}, nil)
	now = now.Add(10 * time.Second)
	if p.Session(context.Background()) != first || source.reads != 1 {
		t.Fatalf("settings must be cached for the TTL, reads = %d", source.reads)
	}

	now = now.Add(10 * time.Second)
	second := p.Session(context.Background())
	if second == first || second.BaseURL() != "http://10.0.0.6:8080" {
		t.Fatalf("a changed address must start a new session, got %q", second.BaseURL())
	}

	now = now.Add(time.Minute)
	if p.Session(context.Background()) != second || source.reads != 3 {
		t.Fatalf("unchanged settings must keep the session and its token, reads = %d", source.reads)
	}
}

func TestProviderKeepsTheLastSessionWhenSettingsCannotBeRead(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	source := &fakeSource{settings: Settings{URL: "http://10.0.0.5:8080"}}
	p := NewProvider(ProviderOptions{Source: source, Server: Settings{URL: "http://csadmin:8080"}, Key: newKey(t)})
	p.now = func() time.Time { return now }

	first := p.Session(context.Background())
	source.set(Settings{}, errors.New("postgrest down"))
	now = now.Add(time.Minute)
	if p.Session(context.Background()) != first {
		t.Fatal("a failed read must keep the current session")
	}

	cold := NewProvider(ProviderOptions{Source: source, Server: Settings{URL: "http://csadmin:8080"}, Key: newKey(t)})
	if got := cold.Session(context.Background()).BaseURL(); got != "http://csadmin:8080" {
		t.Fatalf("a failed first read must use the server values, got %q", got)
	}
}

func statusServer(t *testing.T, status int) string {
	t.Helper()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(status)
		_, _ = w.Write([]byte(`{"message":"no","data":{}}`))
	}))
	t.Cleanup(server.Close)
	return server.URL
}

func TestCheckClassifiesTheTokenExchange(t *testing.T) {
	_, server, key := newIntegration(t, time.Now().Add(time.Hour))
	p := NewProvider(ProviderOptions{Key: key})
	unreachable := httptest.NewServer(http.NotFoundHandler())
	unreachable.Close()

	cases := map[string]struct {
		settings Settings
		provider *Provider
		want     string
		status   int
	}{
		"ok":          {Settings{URL: server.URL + "/csAdmin", ClientID: "web-cs"}, p, CheckOK, http.StatusOK},
		"wrong key":   {Settings{URL: server.URL + "/csAdmin", ClientID: "web-cs"}, NewProvider(ProviderOptions{Key: newKey(t)}), CheckRefused, http.StatusUnauthorized},
		"ip":          {Settings{URL: statusServer(t, http.StatusForbidden), ClientID: "web-cs"}, p, CheckIPNotAllowed, http.StatusForbidden},
		"disabled":    {Settings{URL: statusServer(t, http.StatusNotFound), ClientID: "web-cs"}, p, CheckDisabled, http.StatusNotFound},
		"unexpected":  {Settings{URL: statusServer(t, http.StatusInternalServerError), ClientID: "web-cs"}, p, CheckUnexpected, http.StatusInternalServerError},
		"unreachable": {Settings{URL: unreachable.URL, ClientID: "web-cs"}, p, CheckUnreachable, 0},
		"no address":  {Settings{ClientID: "web-cs"}, p, CheckNotConfigured, 0},
		"no key":      {Settings{URL: server.URL + "/csAdmin", ClientID: "web-cs"}, NewProvider(ProviderOptions{}), CheckNoKey, 0},
	}
	for name, c := range cases {
		got := c.provider.Check(context.Background(), c.settings)
		if got.Result != c.want || got.Status != c.status {
			t.Errorf("%s: got %+v, want %s/%d", name, got, c.want, c.status)
		}
	}
}

func TestValidURLAcceptsOnlyPlainHTTPAddresses(t *testing.T) {
	for _, ok := range []string{"http://10.0.0.5:8080", "https://csadmin.local/csAdmin/", "http://host:9001/csAdmin"} {
		if !ValidURL(ok) {
			t.Errorf("%q must be accepted", ok)
		}
	}
	for _, bad := range []string{"", "ftp://10.0.0.5", "http://", "http://user:pw@host", "http://host/?a=1", "http://host/#x", "javascript:alert(1)", "http://ho st"} {
		if ValidURL(bad) {
			t.Errorf("%q must be rejected", bad)
		}
	}
}
