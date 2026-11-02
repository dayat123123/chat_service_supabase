package fcm

import (
	"bytes"
	"context"
	"errors"
	"io"
	"net/http"
	"net/url"
	"sync"
	"time"

	"olt-social/notifier/internal/push"
)

const (
	problemInvalidCredentials = "Kredensial Firebase tidak valid: "
	problemKeyUnusable        = "Kunci privat Firebase tidak bisa dipakai menandatangani token"
	problemTokenRejected      = "Firebase menolak kredensial: "
	problemTokenUnreachable   = "Tidak bisa menghubungi Google untuk token Firebase"
	problemTokenResponse      = "Jawaban token Firebase dari Google tidak bisa dibaca"
	problemUnreachable        = "Tidak bisa menghubungi Firebase"
	problemAccessDenied       = "Firebase menolak akses: "
	problemThirdPartyAuth     = "Firebase ditolak APNs/Web Push (periksa sertifikat atau kunci APNs di Firebase)"
	problemSenderMismatch     = "Ada token perangkat dari project Firebase lain. Pastikan kunci yang diunggah berasal dari project Firebase aplikasi"
	errorNotConfigured        = "Kredensial Firebase belum dipasang"
	errorStopped              = "Pengiriman dihentikan karena notifier berhenti"
)

var verifyBody = []byte(`{"validate_only":true,"message":{"token":"olt-credentials-check","data":{"check":"credentials"}}}`)

type problemError string

func (p problemError) Error() string { return string(p) }

func problemOf(err error) problemError {
	var known problemError
	if errors.As(err, &known) {
		return known
	}
	return problemError(problemTokenUnreachable)
}

type Options struct {
	BaseURL     string
	TokenURL    string
	ChannelID   string
	SendTimeout time.Duration
}

type Client struct {
	baseURL     string
	tokenURL    string
	channelID   string
	sendTimeout time.Duration
	http        *http.Client
	now         func() time.Time

	mu      sync.Mutex
	account *ServiceAccount
	tokens  *tokenSource
}

func New(opts Options) *Client {
	return &Client{
		baseURL:     opts.BaseURL,
		tokenURL:    opts.TokenURL,
		channelID:   opts.ChannelID,
		sendTimeout: opts.SendTimeout,
		http:        &http.Client{},
		now:         time.Now,
	}
}

func (c *Client) Load(data []byte) push.Status {
	var status push.Status
	var account *ServiceAccount
	if data != nil {
		status.Configured = true
		parsed, err := ParseServiceAccount(data)
		if err != nil {
			status.Problem = problemInvalidCredentials + err.Error()
		} else {
			status.ProjectID = parsed.ProjectID
			account = &parsed
		}
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.account, c.tokens = account, nil
	if account != nil {
		c.tokens = newTokenSource(*account, c.tokenURL, c.http, c.sendTimeout, c.now)
	}
	return status
}

func (c *Client) Verify(ctx context.Context) error {
	account, tokens := c.current()
	if account == nil {
		return problemError(errorNotConfigured)
	}
	for attempt := 1; ; attempt++ {
		token, _, err := tokens.Token(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			return problemOf(err)
		}
		status, header, reply, err := c.post(ctx, account.ProjectID, token, verifyBody)
		if err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			return problemError(problemUnreachable)
		}
		v := classify(status, header, reply, c.now())
		if v.unauthorized && attempt == 1 {
			tokens.Invalidate(token)
			continue
		}
		switch {
		case v.delivery.Problem != "":
			return problemError(v.delivery.Problem)
		case v.delivery.Result.Outcome == push.Retry:
			return problemError(v.delivery.Result.Error)
		}
		return nil
	}
}

func (c *Client) current() (*ServiceAccount, *tokenSource) {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.account, c.tokens
}

func (c *Client) Send(ctx context.Context, job push.Job) push.Delivery {
	account, tokens := c.current()
	if account == nil {
		return push.Delivery{Result: push.Result{ID: job.ID, Outcome: push.Release, Error: errorNotConfigured, RetryAfter: time.Second}}
	}
	body, err := buildMessage(job, c.channelID, c.now())
	if err != nil {
		return push.Delivery{Result: push.Result{ID: job.ID, Outcome: push.Failed, Error: err.Error()}}
	}
	fetchedToken := false
	for attempt := 1; ; attempt++ {
		token, fetched, err := tokens.Token(ctx)
		if err != nil {
			return c.failure(ctx, job.ID, err)
		}
		fetchedToken = fetchedToken || fetched
		status, header, reply, err := c.post(ctx, account.ProjectID, token, body)
		if err != nil {
			return c.failure(ctx, job.ID, problemError(problemUnreachable))
		}
		v := classify(status, header, reply, c.now())
		if v.unauthorized && attempt == 1 {
			tokens.Invalidate(token)
			continue
		}
		d := v.delivery
		d.Result.ID = job.ID
		d.Healthy = d.Healthy || (fetchedToken && !d.Systemic)
		return d
	}
}

func (c *Client) failure(ctx context.Context, id int64, err error) push.Delivery {
	if ctx.Err() != nil {
		return push.Delivery{Result: push.Result{ID: id, Outcome: push.Release, Error: errorStopped, RetryAfter: time.Second}}
	}
	problem := string(problemOf(err))
	return push.Delivery{
		Result:   push.Result{ID: id, Outcome: push.Release, Error: problem},
		Problem:  problem,
		Systemic: true,
	}
}

func (c *Client) post(ctx context.Context, projectID, token string, body []byte) (int, http.Header, []byte, error) {
	ctx, cancel := context.WithTimeout(ctx, c.sendTimeout)
	defer cancel()
	endpoint := c.baseURL + "/v1/projects/" + url.PathEscape(projectID) + "/messages:send"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return 0, nil, nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return 0, nil, nil, err
	}
	defer resp.Body.Close()
	reply, err := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	if err != nil {
		return 0, nil, nil, err
	}
	return resp.StatusCode, resp.Header, reply, nil
}
