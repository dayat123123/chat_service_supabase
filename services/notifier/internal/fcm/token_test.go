package fcm

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

type tokenServer struct {
	*httptest.Server
	fetches atomic.Int32
	delay   time.Duration
	check   func(r *http.Request)
}

func newTokenServer(t *testing.T) *tokenServer {
	t.Helper()
	ts := &tokenServer{}
	ts.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		n := ts.fetches.Add(1)
		if ts.check != nil {
			ts.check(r)
		}
		time.Sleep(ts.delay)
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"access_token":"tok-%d","expires_in":3599,"token_type":"Bearer"}`, n)
	}))
	t.Cleanup(ts.Close)
	return ts
}

func testAccount() ServiceAccount {
	return ServiceAccount{
		ProjectID:    "demo-project",
		ClientEmail:  "notifier@demo-project.iam.gserviceaccount.com",
		PrivateKeyID: "kid-1",
		Key:          testKey(),
	}
}

func TestTokenSourceExchangesASignedAssertion(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	server := newTokenServer(t)
	var seen decodedJWT
	server.check = func(r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/token" ||
			r.Header.Get("Content-Type") != "application/x-www-form-urlencoded" {
			t.Errorf("request = %s %s %s", r.Method, r.URL.Path, r.Header.Get("Content-Type"))
		}
		if err := r.ParseForm(); err != nil {
			t.Error(err)
		}
		if r.PostForm.Get("grant_type") != "urn:ietf:params:oauth:grant-type:jwt-bearer" {
			t.Errorf("grant_type = %q", r.PostForm.Get("grant_type"))
		}
		seen = verifyRS256(t, r.PostForm.Get("assertion"), &testKey().PublicKey)
	}
	source := newTokenSource(testAccount(), server.URL+"/token", server.Client(), time.Second, func() time.Time { return now })

	token, fresh, err := source.Token(context.Background())
	if err != nil || token != "tok-1" || !fresh {
		t.Fatalf("token = %q fresh = %v err = %v", token, fresh, err)
	}
	if seen.header["alg"] != "RS256" || seen.header["typ"] != "JWT" || seen.header["kid"] != "kid-1" {
		t.Fatalf("header = %v", seen.header)
	}
	want := map[string]any{
		"iss":   "notifier@demo-project.iam.gserviceaccount.com",
		"scope": "https://www.googleapis.com/auth/firebase.messaging",
		"aud":   server.URL + "/token",
		"iat":   float64(now.Unix()),
		"exp":   float64(now.Unix() + 3600),
	}
	if fmt.Sprint(seen.claims) != fmt.Sprint(want) {
		t.Fatalf("claims = %v", seen.claims)
	}
}

func TestTokenSourceOmitsKidWithoutAKeyID(t *testing.T) {
	server := newTokenServer(t)
	var seen decodedJWT
	server.check = func(r *http.Request) {
		_ = r.ParseForm()
		seen = verifyRS256(t, r.PostForm.Get("assertion"), &testKey().PublicKey)
	}
	account := testAccount()
	account.PrivateKeyID = ""
	if _, _, err := newTokenSource(account, server.URL+"/token", server.Client(), time.Second, time.Now).Token(context.Background()); err != nil {
		t.Fatal(err)
	}
	if _, ok := seen.header["kid"]; ok {
		t.Fatalf("header = %v", seen.header)
	}
}

func TestTokenSourceCachesUntilFiveMinutesBeforeExpiry(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	server := newTokenServer(t)
	source := newTokenSource(testAccount(), server.URL+"/token", server.Client(), time.Second, func() time.Time { return now })
	expect := func(step, wantToken string, wantFresh bool) {
		t.Helper()
		token, fresh, err := source.Token(context.Background())
		if err != nil || token != wantToken || fresh != wantFresh {
			t.Fatalf("%s: token = %q fresh = %v err = %v, want %q fresh = %v", step, token, fresh, err, wantToken, wantFresh)
		}
	}

	expect("first", "tok-1", true)
	expect("cached", "tok-1", false)
	now = now.Add(54 * time.Minute)
	expect("before refresh window", "tok-1", false)
	now = now.Add(time.Minute)
	expect("inside refresh window", "tok-2", true)
	source.Invalidate("tok-1")
	expect("stale invalidation is ignored", "tok-2", false)
	source.Invalidate("tok-2")
	expect("after invalidation", "tok-3", true)
	if server.fetches.Load() != 3 {
		t.Fatalf("fetches = %d", server.fetches.Load())
	}
}

func TestTokenSourceSharesOneFetchBetweenConcurrentSenders(t *testing.T) {
	server := newTokenServer(t)
	server.delay = 100 * time.Millisecond
	source := newTokenSource(testAccount(), server.URL+"/token", server.Client(), time.Second, time.Now)

	var wg sync.WaitGroup
	tokens := make([]string, 20)
	for i := range tokens {
		wg.Add(1)
		go func() {
			defer wg.Done()
			tokens[i], _, _ = source.Token(context.Background())
		}()
	}
	wg.Wait()
	for _, token := range tokens {
		if token != "tok-1" {
			t.Fatalf("tokens = %v", tokens)
		}
	}
	if server.fetches.Load() != 1 {
		t.Fatalf("fetches = %d", server.fetches.Load())
	}
}

func TestTokenSourceExplainsFailures(t *testing.T) {
	cases := []struct {
		name   string
		status int
		body   string
		closed bool
		want   string
	}{
		{"invalid grant", 400, `{"error":"invalid_grant","error_description":"Invalid JWT Signature."}`, false, "Firebase menolak kredensial: Invalid JWT Signature."},
		{"error without description", 401, `{"error":"unauthorized_client"}`, false, "Firebase menolak kredensial: unauthorized_client"},
		{"bare rejection", 403, ``, false, "Firebase menolak kredensial: 403 Forbidden"},
		{"google outage", 503, `{"error":"backend"}`, false, "Tidak bisa menghubungi Google untuk token Firebase"},
		{"missing token", 200, `{"token_type":"Bearer"}`, false, "Jawaban token Firebase dari Google tidak bisa dibaca"},
		{"network error", 0, ``, true, "Tidak bisa menghubungi Google untuk token Firebase"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(tc.status)
				_, _ = w.Write([]byte(tc.body))
			}))
			if tc.closed {
				server.Close()
			} else {
				defer server.Close()
			}
			source := newTokenSource(testAccount(), server.URL+"/token", &http.Client{}, time.Second, time.Now)
			token, fresh, err := source.Token(context.Background())
			if err == nil || err.Error() != tc.want || token != "" || fresh {
				t.Fatalf("token = %q fresh = %v err = %v, want %q", token, fresh, err, tc.want)
			}
		})
	}
}
