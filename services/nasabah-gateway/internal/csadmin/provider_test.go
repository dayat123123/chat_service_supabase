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
	mu     sync.Mutex
	record Record
	err    error
	reads  int
}

func (f *fakeSource) Integration(context.Context) (Record, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.reads++
	return f.record, f.err
}

func (f *fakeSource) set(r Record, err error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.record, f.err = r, err
}

func newKey(t *testing.T) ed25519.PrivateKey {
	t.Helper()
	_, key, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	return key
}

func active(url, clientID string) Record {
	return Record{URL: url, ClientID: clientID, Configured: true}
}

func TestProviderUsesOnlyTheVerifiedConsoleSettings(t *testing.T) {
	source := &fakeSource{record: active("http://10.0.0.5:9001/csAdmin/", "web-cs.prod")}
	p := NewProvider(ProviderOptions{Source: source, Key: newKey(t)})
	if s := p.Session(context.Background()); s.BaseURL() != "http://10.0.0.5:9001/csAdmin" || !s.Configured() {
		t.Fatalf("session must use the console settings, got %q", s.BaseURL())
	}

	for name, record := range map[string]Record{
		"nothing saved":  {},
		"not verified":   {URL: "http://10.0.0.5:8080", ClientID: "web-cs"},
		"no client id":   {URL: "http://10.0.0.5:8080", Configured: true},
		"unsafe address": active("http://admin:secret@10.0.0.5", "web-cs"),
		"invalid client": active("http://10.0.0.5:8080", "web cs"),
	} {
		empty := NewProvider(ProviderOptions{Source: &fakeSource{record: record}, Key: newKey(t)})
		if empty.Session(context.Background()).Configured() {
			t.Errorf("%s: there is no default address, the gateway must stay unconfigured", name)
		}
	}
	if NewProvider(ProviderOptions{Key: newKey(t)}).Session(context.Background()).Configured() {
		t.Error("without a settings source the gateway must stay unconfigured")
	}
}

func TestProviderReloadsAfterTheTTLAndOnlyReplacesTheSessionOnChange(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	source := &fakeSource{record: active("http://10.0.0.5:8080", "web-cs")}
	p := NewProvider(ProviderOptions{Source: source, Key: newKey(t), TTL: 15 * time.Second})
	p.now = func() time.Time { return now }

	first := p.Session(context.Background())
	source.set(active("http://10.0.0.6:8080", "web-cs"), nil)
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

	source.set(Record{}, nil)
	p.Refresh(context.Background())
	if p.Session(context.Background()).Configured() {
		t.Fatal("a cleared integration must take effect on refresh")
	}
}

func TestProviderKeepsTheLastSessionWhenSettingsCannotBeRead(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	source := &fakeSource{record: active("http://10.0.0.5:8080", "web-cs")}
	p := NewProvider(ProviderOptions{Source: source, Key: newKey(t)})
	p.now = func() time.Time { return now }

	first := p.Session(context.Background())
	source.set(Record{}, errors.New("postgrest down"))
	now = now.Add(time.Minute)
	if p.Session(context.Background()) != first {
		t.Fatal("a failed read must keep the current session")
	}

	cold := NewProvider(ProviderOptions{Source: source, Key: newKey(t)})
	if cold.Session(context.Background()).Configured() {
		t.Fatal("a failed first read must leave the gateway unconfigured")
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
		"ok":           {Settings{URL: server.URL + "/csAdmin", ClientID: "web-cs"}, p, CheckOK, http.StatusOK},
		"wrong key":    {Settings{URL: server.URL + "/csAdmin", ClientID: "web-cs"}, NewProvider(ProviderOptions{Key: newKey(t)}), CheckRefused, http.StatusUnauthorized},
		"ip":           {Settings{URL: statusServer(t, http.StatusForbidden), ClientID: "web-cs"}, p, CheckIPNotAllowed, http.StatusForbidden},
		"disabled":     {Settings{URL: statusServer(t, http.StatusNotFound), ClientID: "web-cs"}, p, CheckDisabled, http.StatusNotFound},
		"unexpected":   {Settings{URL: statusServer(t, http.StatusInternalServerError), ClientID: "web-cs"}, p, CheckUnexpected, http.StatusInternalServerError},
		"unreachable":  {Settings{URL: unreachable.URL, ClientID: "web-cs"}, p, CheckUnreachable, 0},
		"no address":   {Settings{ClientID: "web-cs"}, p, CheckNotConfigured, 0},
		"no client id": {Settings{URL: server.URL + "/csAdmin"}, p, CheckNotConfigured, 0},
		"no key":       {Settings{URL: server.URL + "/csAdmin", ClientID: "web-cs"}, NewProvider(ProviderOptions{}), CheckNoKey, 0},
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
