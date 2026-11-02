package fcm

import (
	"bytes"
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"sync"
	"time"

	"olt-social/notifier/internal/push"
)

const (
	problemMultipleFiles    = "Ada lebih dari satu file .json di folder kredensial Firebase"
	problemUnreadableFile   = "File kredensial Firebase tidak bisa dibaca (periksa izin file)"
	problemUnreadableDir    = "Folder kredensial Firebase tidak bisa dibaca (periksa izin folder)"
	problemInvalidFile      = "File kredensial Firebase tidak valid: "
	problemKeyUnusable      = "Kunci privat Firebase tidak bisa dipakai menandatangani token"
	problemTokenRejected    = "Firebase menolak kredensial: "
	problemTokenUnreachable = "Tidak bisa menghubungi Google untuk token Firebase"
	problemTokenResponse    = "Jawaban token Firebase dari Google tidak bisa dibaca"
	problemUnreachable      = "Tidak bisa menghubungi Firebase"
	problemAccessDenied     = "Firebase menolak akses: "
	problemThirdPartyAuth   = "Firebase ditolak APNs/Web Push (periksa sertifikat atau kunci APNs di Firebase)"
	errorNotConfigured      = "Kredensial Firebase belum dipasang"
	errorStopped            = "Pengiriman dihentikan karena notifier berhenti"
)

type problemError string

func (p problemError) Error() string { return string(p) }

type Options struct {
	Path        string
	BaseURL     string
	ChannelID   string
	SendTimeout time.Duration
	Log         *slog.Logger
}

type Client struct {
	path        string
	baseURL     string
	channelID   string
	sendTimeout time.Duration
	log         *slog.Logger
	http        *http.Client
	now         func() time.Time
	readFile    func(string) ([]byte, error)

	mu      sync.Mutex
	loaded  bool
	seen    candidate
	status  push.Status
	account *ServiceAccount
	tokens  *tokenSource
}

func New(opts Options) *Client {
	return &Client{
		path:        opts.Path,
		baseURL:     opts.BaseURL,
		channelID:   opts.ChannelID,
		sendTimeout: opts.SendTimeout,
		log:         opts.Log,
		http:        &http.Client{},
		now:         time.Now,
		readFile:    os.ReadFile,
	}
}

func (c *Client) Reload() (push.Status, bool) {
	found := locate(c.path, c.readFile)
	c.mu.Lock()
	defer c.mu.Unlock()
	unchanged := c.loaded && found == c.seen
	if unchanged && c.status.Problem != problemUnreadableFile {
		return c.status, false
	}
	status, account := c.load(found)
	if unchanged && status == c.status {
		return c.status, false
	}
	c.loaded, c.seen, c.status, c.account, c.tokens = true, found, status, account, nil
	if account != nil {
		c.tokens = newTokenSource(*account, c.http, c.sendTimeout, c.now)
	}
	switch {
	case !status.Configured:
		c.log.Info("No Firebase credentials yet; push delivery is idle", "path", c.path)
	case status.Problem != "":
		c.log.Warn("Firebase credentials cannot be used", "path", c.path, "error", status.Problem)
	default:
		c.log.Info("Firebase credentials loaded", "file", found.file, "project_id", status.ProjectID)
	}
	return status, true
}

func (c *Client) load(found candidate) (push.Status, *ServiceAccount) {
	status := push.Status{Configured: found.configured, Problem: found.problem}
	if !found.configured || found.problem != "" {
		return status, nil
	}
	data, err := c.readFile(found.file)
	if err != nil {
		status.Problem = problemUnreadableFile
		return status, nil
	}
	if isBlank(data) {
		return push.Status{}, nil
	}
	account, err := ParseServiceAccount(data)
	if err != nil {
		status.Problem = problemInvalidFile + err.Error()
		return status, nil
	}
	status.ProjectID = account.ProjectID
	return status, &account
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
	problem := problemTokenUnreachable
	var known problemError
	if errors.As(err, &known) {
		problem = string(known)
	}
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
