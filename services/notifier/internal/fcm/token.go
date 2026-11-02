package fcm

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"olt-social/notifier/internal/jwt"
)

const (
	messagingScope = "https://www.googleapis.com/auth/firebase.messaging"
	jwtBearerGrant = "urn:ietf:params:oauth:grant-type:jwt-bearer"
	refreshMargin  = 5 * time.Minute
)

type tokenSource struct {
	account ServiceAccount
	http    *http.Client
	timeout time.Duration
	now     func() time.Time

	mu        sync.Mutex
	token     string
	refreshAt time.Time
	pending   *tokenCall
}

type tokenCall struct {
	done  chan struct{}
	token string
	err   error
}

func newTokenSource(account ServiceAccount, client *http.Client, timeout time.Duration, now func() time.Time) *tokenSource {
	return &tokenSource{account: account, http: client, timeout: timeout, now: now}
}

func (t *tokenSource) Token(ctx context.Context) (string, bool, error) {
	t.mu.Lock()
	if t.token != "" && t.now().Before(t.refreshAt) {
		token := t.token
		t.mu.Unlock()
		return token, false, nil
	}
	call := t.pending
	leader := call == nil
	if leader {
		call = &tokenCall{done: make(chan struct{})}
		t.pending = call
	}
	t.mu.Unlock()

	if leader {
		token, lifetime, err := t.fetch(ctx)
		t.mu.Lock()
		if err == nil {
			t.token, t.refreshAt = token, t.now().Add(lifetime)
		}
		t.pending = nil
		t.mu.Unlock()
		call.token, call.err = token, err
		close(call.done)
		return token, err == nil, err
	}
	select {
	case <-call.done:
		return call.token, call.err == nil, call.err
	case <-ctx.Done():
		return "", false, ctx.Err()
	}
}

func (t *tokenSource) Invalidate(token string) {
	t.mu.Lock()
	if t.token == token {
		t.token = ""
	}
	t.mu.Unlock()
}

func (t *tokenSource) fetch(ctx context.Context) (string, time.Duration, error) {
	now := t.now()
	header := map[string]any{"alg": "RS256", "typ": "JWT"}
	if t.account.PrivateKeyID != "" {
		header["kid"] = t.account.PrivateKeyID
	}
	assertion, err := jwt.SignRS256(header, map[string]any{
		"iss":   t.account.ClientEmail,
		"scope": messagingScope,
		"aud":   t.account.TokenURI,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
	}, t.account.Key)
	if err != nil {
		return "", 0, problemError(problemKeyUnusable)
	}
	form := url.Values{"grant_type": {jwtBearerGrant}, "assertion": {assertion}}
	ctx, cancel := context.WithTimeout(ctx, t.timeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, t.account.TokenURI, strings.NewReader(form.Encode()))
	if err != nil {
		return "", 0, problemError(problemTokenUnreachable)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")
	resp, err := t.http.Do(req)
	if err != nil {
		return "", 0, problemError(problemTokenUnreachable)
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	if err != nil {
		return "", 0, problemError(problemTokenUnreachable)
	}
	var reply struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
		Error       string `json:"error"`
		Description string `json:"error_description"`
	}
	_ = json.Unmarshal(data, &reply)
	switch {
	case resp.StatusCode >= 500:
		return "", 0, problemError(problemTokenUnreachable)
	case resp.StatusCode >= 400:
		return "", 0, problemError(problemTokenRejected + firstNonEmpty(reply.Description, reply.Error, resp.Status))
	case reply.AccessToken == "":
		return "", 0, problemError(problemTokenResponse)
	}
	return reply.AccessToken, cacheLifetime(reply.ExpiresIn), nil
}

func cacheLifetime(expiresIn int) time.Duration {
	if expiresIn <= 0 {
		expiresIn = 3600
	}
	total := time.Duration(expiresIn) * time.Second
	return max(total-refreshMargin, total/2)
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v = strings.TrimSpace(v); v != "" {
			return v
		}
	}
	return ""
}
