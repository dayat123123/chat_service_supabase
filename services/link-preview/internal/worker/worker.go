package worker

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"encoding/hex"
	"errors"
	"log/slog"
	"maps"
	"mime"
	"net"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"olt-social/link-preview/internal/heartbeat"
	"olt-social/link-preview/internal/htmlmeta"
	"olt-social/link-preview/internal/metrics"
	"olt-social/link-preview/internal/moderation"
	"olt-social/link-preview/internal/safehttp"
	"olt-social/link-preview/internal/sanitize"
	"olt-social/link-preview/internal/store"
)

const (
	acceptHTML    = "text/html,application/xhtml+xml;q=0.9,image/webp,image/png,image/jpeg,image/gif;q=0.8,*/*;q=0.1"
	acceptImage   = "image/webp,image/png,image/jpeg,image/gif;q=0.9"
	minImageSide  = 32
	leaseMargin   = 5 * time.Second
	reportTimeout = 15 * time.Second
	degradedAfter = 3
	scoreCacheMax = 2048
	cacheTimeout  = 5 * time.Second
)

type Store interface {
	Claim(ctx context.Context, instance string, limit int, lease time.Duration) ([]store.Entry, error)
	Report(ctx context.Context, instance string, results []store.Result) (int, error)
}

type Fetcher interface {
	Get(ctx context.Context, rawURL, accept string, limit int64, allowTruncated bool) (*safehttp.Response, error)
}

type Uploader interface {
	Upload(ctx context.Context, path, contentType string, body []byte) error
}

type Classifier interface {
	Classify(ctx context.Context, mime string, body []byte, requestID string) (moderation.Result, error)
	Ping(ctx context.Context) error
}

type Policy interface {
	Current() (moderation.Thresholds, bool)
}

type ScoreCache interface {
	CachedScores(ctx context.Context, sha256 string) (moderation.Result, bool, error)
}

type Options struct {
	Store           Store
	Fetcher         Fetcher
	Uploader        Uploader
	Classifier      Classifier
	Policy          Policy
	Scores          ScoreCache
	Log             *slog.Logger
	Instance        string
	BatchSize       int
	Concurrency     int
	Lease           time.Duration
	PollInterval    time.Duration
	FetchTimeout    time.Duration
	RequestTimeout  time.Duration
	ClassifyTimeout time.Duration
	ShutdownTimeout time.Duration
	MaxHTMLBytes    int64
	MaxImageBytes   int64
	Nonce           func() string
}

type Worker struct {
	opts         Options
	log          *slog.Logger
	backoffMin   time.Duration
	backoffMax   time.Duration
	reportDelays []time.Duration

	mu                sync.Mutex
	results           map[string]uint64
	images            map[string]uint64
	blocked           map[string]uint64
	fetchSeconds      float64
	fetches           uint64
	claimErrors       uint64
	reportErrors      uint64
	consecutiveClaims int
	inflight          int
	lastClaim         time.Time
	storedBytes       uint64
	lastError         string
	verdicts          map[string]uint64
	cacheHits         uint64
	classifySeconds   float64
	classifications   uint64
	classifierFails   int
	classifierError   string
	scoreCache        map[string]moderation.Result
}

func New(opts Options) *Worker {
	if opts.Nonce == nil {
		opts.Nonce = nonce
	}
	return &Worker{
		opts:         opts,
		log:          opts.Log,
		backoffMin:   time.Second,
		backoffMax:   time.Minute,
		reportDelays: []time.Duration{250 * time.Millisecond, 500 * time.Millisecond, time.Second},
		results:      map[string]uint64{},
		images:       map[string]uint64{},
		blocked:      map[string]uint64{},
		verdicts:     map[string]uint64{},
		scoreCache:   map[string]moderation.Result{},
	}
}

func (w *Worker) Run(ctx context.Context) {
	work, cancelWork := context.WithCancel(context.WithoutCancel(ctx))
	defer cancelWork()
	go w.enforceShutdown(ctx, work, cancelWork)
	var backoff time.Duration
	for ctx.Err() == nil {
		more, err := w.round(ctx, work)
		switch {
		case err != nil:
			backoff = grow(backoff, w.backoffMin, w.backoffMax)
			if ctx.Err() == nil {
				w.log.Warn("Could not claim links to preview", "error", err, "retry_in", backoff.String())
			}
			idle(ctx, backoff)
		case more:
			backoff = 0
		default:
			backoff = 0
			idle(ctx, w.opts.PollInterval)
		}
	}
}

func (w *Worker) Metrics() metrics.Snapshot {
	_, loaded := w.opts.Policy.Current()
	w.mu.Lock()
	defer w.mu.Unlock()
	return metrics.Snapshot{
		Results:         maps.Clone(w.results),
		Images:          maps.Clone(w.images),
		Blocked:         maps.Clone(w.blocked),
		FetchSeconds:    w.fetchSeconds,
		Fetches:         w.fetches,
		ClaimErrors:     w.claimErrors,
		ReportErrors:    w.reportErrors,
		Inflight:        w.inflight,
		Concurrency:     w.opts.Concurrency,
		LastClaim:       w.lastClaim,
		StoredImageSize: w.storedBytes,
		Verdicts:        maps.Clone(w.verdicts),
		CacheHits:       w.cacheHits,
		ClassifySeconds: w.classifySeconds,
		Classifications: w.classifications,
		ClassifierFails: w.classifierFails,
		ThresholdsSet:   loaded,
	}
}

func (w *Worker) Report() heartbeat.Report {
	_, loaded := w.opts.Policy.Current()
	w.mu.Lock()
	defer w.mu.Unlock()
	detail := map[string]any{
		"fetched":             w.fetches,
		"ok":                  w.results[store.StatusOK],
		"empty":               w.results[store.StatusEmpty],
		"blocked":             w.results[store.StatusBlocked],
		"failed":              w.results[store.StatusFailed],
		"retry":               w.results[store.StatusRetry],
		"images":              w.images["stored"],
		"inflight":            w.inflight,
		"claim_errors":        w.claimErrors,
		"report_errors":       w.reportErrors,
		"images_allowed":      w.verdicts[store.VerdictAllow],
		"images_held":         w.verdicts[store.VerdictHold],
		"images_blocked":      w.verdicts[store.VerdictBlock],
		"images_unchecked":    w.verdicts[store.VerdictUnavailable],
		"classifier_failures": w.classifierFails,
		"thresholds_loaded":   loaded,
	}
	if w.consecutiveClaims >= degradedAfter {
		return heartbeat.Report{Status: heartbeat.StatusDegraded, Error: w.lastError, Detail: detail}
	}
	if w.classifierFails >= degradedAfter {
		return heartbeat.Report{Status: heartbeat.StatusDegraded, Error: "classifier: " + w.classifierError, Detail: detail}
	}
	return heartbeat.Report{Status: heartbeat.StatusOK, Detail: detail}
}

func (w *Worker) enforceShutdown(ctx, work context.Context, cancelWork context.CancelFunc) {
	select {
	case <-work.Done():
		return
	case <-ctx.Done():
	}
	timer := time.NewTimer(w.opts.ShutdownTimeout)
	defer timer.Stop()
	select {
	case <-timer.C:
		w.log.Warn("Shutdown timeout reached; releasing links still in flight", "timeout", w.opts.ShutdownTimeout.String())
		cancelWork()
	case <-work.Done():
	}
}

func (w *Worker) round(ctx, work context.Context) (bool, error) {
	w.probeClassifier(ctx)
	claimedAt := time.Now()
	entries, err := w.opts.Store.Claim(work, w.opts.Instance, w.opts.BatchSize, w.opts.Lease)
	w.mu.Lock()
	if err != nil {
		w.claimErrors++
		w.consecutiveClaims++
		w.lastError = "claim: " + err.Error()
	} else {
		w.consecutiveClaims = 0
		w.lastClaim = time.Now()
	}
	w.mu.Unlock()
	if err != nil {
		return false, err
	}
	if len(entries) == 0 {
		return false, nil
	}
	budget := 2*w.opts.FetchTimeout + w.opts.ClassifyTimeout + w.opts.RequestTimeout + leaseMargin
	starting, stopStarting := context.WithDeadline(ctx, claimedAt.Add(w.opts.Lease-budget))
	defer stopStarting()
	slots := make(chan struct{}, w.opts.Concurrency)
	var (
		wg       sync.WaitGroup
		mu       sync.Mutex
		released []store.Result
		counts   = map[string]int{}
	)
	for _, entry := range entries {
		select {
		case slots <- struct{}{}:
		case <-starting.Done():
		}
		if starting.Err() != nil {
			released = append(released, store.Result{URLHash: entry.URLHash, Status: store.StatusRelease})
			continue
		}
		wg.Add(1)
		go func() {
			defer wg.Done()
			defer func() { <-slots }()
			result := w.Process(work, entry)
			mu.Lock()
			counts[result.Status]++
			mu.Unlock()
			w.report(ctx, []store.Result{result})
		}()
	}
	wg.Wait()
	if len(released) > 0 {
		w.count(store.Result{Status: store.StatusRelease}, 0, len(released))
		counts[store.StatusRelease] += len(released)
		w.report(ctx, released)
	}
	w.log.Info("Link preview round finished", "links", len(entries), "ok", counts[store.StatusOK],
		"empty", counts[store.StatusEmpty], "blocked", counts[store.StatusBlocked], "failed", counts[store.StatusFailed],
		"retry", counts[store.StatusRetry], "released", counts[store.StatusRelease],
		"took_ms", time.Since(claimedAt).Milliseconds())
	return len(entries) >= w.opts.BatchSize, nil
}

func (w *Worker) Process(ctx context.Context, entry store.Entry) store.Result {
	w.mu.Lock()
	w.inflight++
	w.mu.Unlock()
	start := time.Now()
	result := w.process(ctx, entry)
	took := time.Since(start)
	w.mu.Lock()
	w.inflight--
	w.mu.Unlock()
	w.count(result, took, 1)
	w.log.Debug("Link preview fetched", "url_hash", entry.URLHash, "host", hostOf(entry.URL), "status", result.Status,
		"error", result.Error, "image", result.ImagePath != "", "took_ms", took.Milliseconds())
	return result
}

func (w *Worker) process(ctx context.Context, entry store.Entry) store.Result {
	result := store.Result{URLHash: entry.URLHash}
	resp, err := w.opts.Fetcher.Get(ctx, entry.URL, acceptHTML, w.opts.MaxHTMLBytes, true)
	if err != nil {
		result.Status, result.Error = classify(ctx, err)
		if resp != nil && resp.URL != nil {
			result.FinalURL = resp.URL.String()
		}
		return result
	}
	result.Status = store.StatusOK
	result.FinalURL = resp.URL.String()
	switch kind := mediaType(resp.ContentType); {
	case kind == "text/html" || kind == "application/xhtml+xml" || (kind == "" && looksHTML(resp.Body)):
		meta := htmlmeta.Parse(resp.Body, resp.ContentType, resp.URL)
		result.Title, result.Description, result.SiteName = meta.Title, meta.Description, meta.SiteName
		if meta.Image != "" {
			w.attachImage(ctx, &result, meta.Image)
		}
	case strings.HasPrefix(kind, "image/"):
		result.SiteName = htmlmeta.Parse(nil, "", resp.URL).SiteName
		body := resp.Body
		if resp.Truncated {
			w.attachImage(ctx, &result, resp.URL.String())
			break
		}
		w.storeImage(ctx, &result, body)
	default:
		result.Status = store.StatusEmpty
	}
	return result
}

func (w *Worker) attachImage(ctx context.Context, result *store.Result, imageURL string) {
	resp, err := w.opts.Fetcher.Get(ctx, imageURL, acceptImage, w.opts.MaxImageBytes, false)
	if err != nil {
		event := "failed"
		var blocked *safehttp.BlockedError
		if errors.As(err, &blocked) {
			event = "blocked"
			w.mu.Lock()
			w.blocked["image_"+blocked.Reason]++
			w.mu.Unlock()
		}
		w.image(event, 0)
		return
	}
	w.storeImage(ctx, result, resp.Body)
}

func (w *Worker) storeImage(ctx context.Context, result *store.Result, body []byte) {
	clean, kind, info, err := sanitize.Image(body)
	if err != nil {
		w.image("rejected", 0)
		return
	}
	if info.Width < minImageSide || info.Height < minImageSide {
		w.image("skipped", 0)
		return
	}
	if !w.screen(ctx, result, kind.MIME(), clean) {
		w.image("unsafe", 0)
		return
	}
	path := result.URLHash + "/" + w.opts.Nonce() + "/preview." + kind.Ext()
	upload, cancel := context.WithTimeout(ctx, w.opts.RequestTimeout)
	defer cancel()
	if err := w.opts.Uploader.Upload(upload, path, kind.MIME(), clean); err != nil {
		w.image("failed", 0)
		w.log.Warn("Could not store preview image", "url_hash", result.URLHash, "error", err)
		return
	}
	result.ImagePath, result.ImageWidth, result.ImageHeight = path, info.Width, info.Height
	w.image("stored", len(clean))
}

func (w *Worker) screen(ctx context.Context, result *store.Result, mime string, clean []byte) bool {
	sum := sha256.Sum256(clean)
	check := store.ImageCheck{ImageSHA256: hex.EncodeToString(sum[:])}
	defer func() {
		result.ImageCheck = check
		w.mu.Lock()
		w.verdicts[check.ImageVerdict]++
		w.mu.Unlock()
		w.log.Debug("Preview image checked", "url_hash", result.URLHash, "image_sha256", check.ImageSHA256,
			"verdict", check.ImageVerdict, "category", check.ImageCategory)
	}()
	thresholds, loaded := w.opts.Policy.Current()
	if !loaded {
		check.ImageVerdict = store.VerdictUnavailable
		return false
	}
	scores, fresh, err := w.scores(ctx, check.ImageSHA256, mime, clean, result.URLHash)
	switch {
	case errors.Is(err, moderation.ErrUnreadable):
		check.ImageVerdict = store.VerdictUnreadable
		return false
	case err != nil:
		check.ImageVerdict = store.VerdictUnavailable
		return false
	}
	if fresh {
		check.ImageModel, check.ImageScores = scores.Model, scores.Scores
	}
	decision := moderation.Decide(scores.Scores, thresholds)
	check.ImageVerdict = string(decision.Verdict)
	check.ImageCategory = decision.Category
	check.ThresholdsRevision = thresholds.Revision
	if decision.Category != "" {
		score := decision.Score
		check.ImageScore = &score
	}
	return decision.Verdict == moderation.Allow
}

func (w *Worker) scores(ctx context.Context, sha, mime string, clean []byte, urlHash string) (moderation.Result, bool, error) {
	w.mu.Lock()
	cached, ok := w.scoreCache[sha]
	w.mu.Unlock()
	if !ok && w.opts.Scores != nil {
		lookup, cancel := context.WithTimeout(ctx, cacheTimeout)
		var err error
		cached, ok, err = w.opts.Scores.CachedScores(lookup, sha)
		cancel()
		if err != nil {
			w.log.Debug("Cached image scores could not be read; classifying again", "image_sha256", sha, "error", err)
		}
		if ok {
			w.remember(sha, cached)
		}
	}
	if ok {
		w.mu.Lock()
		w.cacheHits++
		w.mu.Unlock()
		return cached, false, nil
	}
	started := time.Now()
	result, err := w.opts.Classifier.Classify(ctx, mime, clean, "link-preview-"+urlHash[:min(len(urlHash), 16)])
	w.noteClassifier(err, time.Since(started))
	if err != nil {
		return moderation.Result{}, false, err
	}
	w.remember(sha, result)
	return result, true, nil
}

func (w *Worker) remember(sha string, result moderation.Result) {
	w.mu.Lock()
	defer w.mu.Unlock()
	if len(w.scoreCache) >= scoreCacheMax {
		clear(w.scoreCache)
	}
	w.scoreCache[sha] = result
}

func (w *Worker) probeClassifier(ctx context.Context) {
	w.mu.Lock()
	failing := w.classifierFails >= degradedAfter
	w.mu.Unlock()
	if !failing {
		return
	}
	probe, cancel := context.WithTimeout(ctx, cacheTimeout)
	err := w.opts.Classifier.Ping(probe)
	cancel()
	if err == nil {
		w.noteClassifier(nil, 0)
	}
}

func (w *Worker) noteClassifier(err error, took time.Duration) {
	answered := err == nil || errors.Is(err, moderation.ErrUnreadable)
	w.mu.Lock()
	before := w.classifierFails
	if answered {
		w.classifierFails, w.classifierError = 0, ""
		w.classifySeconds += took.Seconds()
		w.classifications++
	} else {
		w.classifierFails++
		w.classifierError = err.Error()
	}
	after := w.classifierFails
	w.mu.Unlock()
	switch {
	case after == degradedAfter:
		w.log.Warn("Classifier cannot be used; preview images are dropped until it answers again",
			"consecutive_failures", after, "error", err)
	case answered && before >= degradedAfter:
		w.log.Info("Classifier works again")
	}
}

func (w *Worker) image(event string, size int) {
	w.mu.Lock()
	w.images[event]++
	w.storedBytes += uint64(size)
	w.mu.Unlock()
}

func (w *Worker) count(result store.Result, took time.Duration, n int) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.results[result.Status] += uint64(n)
	if result.Status == store.StatusBlocked {
		w.blocked[result.Error] += uint64(n)
	}
	if took > 0 {
		w.fetchSeconds += took.Seconds()
		w.fetches += uint64(n)
	}
}

func (w *Worker) report(ctx context.Context, results []store.Result) {
	ctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), reportTimeout)
	defer cancel()
	var err error
	for attempt := 0; ; attempt++ {
		var updated int
		if updated, err = w.opts.Store.Report(ctx, w.opts.Instance, results); err == nil {
			if updated < len(results) {
				w.log.Warn("Some link preview results were not applied; their lease may have ended",
					"results", len(results), "updated", updated)
			}
			return
		}
		if attempt == len(w.reportDelays) {
			break
		}
		timer := time.NewTimer(w.reportDelays[attempt])
		select {
		case <-ctx.Done():
			timer.Stop()
		case <-timer.C:
		}
	}
	w.mu.Lock()
	w.reportErrors++
	w.lastError = "report: " + err.Error()
	w.mu.Unlock()
	w.log.Error("Could not report link preview results; the links return to the queue when the lease ends",
		"error", err, "results", len(results))
}

func classify(ctx context.Context, err error) (string, string) {
	var (
		blocked *safehttp.BlockedError
		status  *safehttp.StatusError
		dnsErr  *net.DNSError
		netErr  net.Error
		certErr *tls.CertificateVerificationError
		unknown x509.UnknownAuthorityError
		invalid x509.CertificateInvalidError
		host    x509.HostnameError
	)
	switch {
	case errors.As(err, &blocked):
		return store.StatusBlocked, blocked.Reason
	case ctx.Err() != nil || errors.Is(err, context.Canceled):
		return store.StatusRelease, "shutdown"
	case errors.Is(err, safehttp.ErrTooManyRedirects):
		return store.StatusFailed, "too_many_redirects"
	case errors.As(err, &status):
		code := "http_" + strconv.Itoa(status.Code)
		if status.Code == 408 || status.Code == 425 || status.Code == 429 || status.Code >= 500 {
			return store.StatusRetry, code
		}
		return store.StatusFailed, code
	case errors.As(err, &dnsErr):
		if dnsErr.IsNotFound {
			return store.StatusFailed, "dns_not_found"
		}
		return store.StatusRetry, "dns_error"
	case errors.As(err, &certErr), errors.As(err, &unknown), errors.As(err, &invalid), errors.As(err, &host):
		return store.StatusFailed, "tls_certificate"
	case errors.Is(err, context.DeadlineExceeded), errors.As(err, &netErr) && netErr.Timeout():
		return store.StatusRetry, "timeout"
	case errors.Is(err, safehttp.ErrTooLarge):
		return store.StatusFailed, "too_large"
	}
	return store.StatusRetry, "fetch_error"
}

func mediaType(contentType string) string {
	if contentType == "" {
		return ""
	}
	kind, _, err := mime.ParseMediaType(contentType)
	if err != nil {
		return ""
	}
	return strings.ToLower(kind)
}

func looksHTML(body []byte) bool {
	head := strings.ToLower(strings.TrimSpace(string(body[:min(len(body), 512)])))
	return strings.HasPrefix(head, "<!doctype html") || strings.HasPrefix(head, "<html") || strings.Contains(head, "<head")
}

func hostOf(raw string) string {
	u, err := url.Parse(raw)
	if err != nil {
		return ""
	}
	return u.Hostname()
}

func nonce() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func idle(ctx context.Context, wait time.Duration) {
	timer := time.NewTimer(wait)
	defer timer.Stop()
	select {
	case <-ctx.Done():
	case <-timer.C:
	}
}

func grow(current, lo, hi time.Duration) time.Duration {
	if current <= 0 {
		return min(lo, hi)
	}
	return min(current*2, hi)
}
