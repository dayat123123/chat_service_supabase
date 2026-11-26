package worker

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"
	"time"

	"olt-social/research/internal/document"
	"olt-social/research/internal/storage"
	"olt-social/research/internal/store"
)

const ResultReady = "ready"

func (w *Worker) processDocument(parent context.Context, job *store.DocumentJob) {
	start := time.Now()
	w.setBusy(true)
	defer w.setBusy(false)
	ctx, cancel := context.WithTimeout(parent, w.opts.JobTimeout)
	defer cancel()
	log := w.opts.Log.With("document_id", job.ID, "attempt", job.Attempts)

	sha, err := w.checkDocument(ctx, job)
	if err == nil {
		err = w.completeDocument(ctx, job, sha)
	}
	result := ResultReady
	var f *failure
	if err != nil {
		var stop bool
		result, f, stop = w.recordFailure(parent, err, log, func(ctx context.Context, code, detail string, retry bool) error {
			return w.opts.Store.FailDocument(ctx, job.ID, w.opts.Instance, code, detail, retry)
		})
		if stop {
			return
		}
	}
	w.countDocument(result)
	attrs := []any{"result", result, "mime", job.Mime, "size_bytes", job.SizeBytes,
		"duration_ms", time.Since(start).Milliseconds()}
	switch {
	case f != nil && f.retry:
		log.Warn("Research document will be retried", append(attrs, "code", f.code, "error", f.err.Error())...)
	case f != nil:
		log.Warn("Research document rejected", append(attrs, "code", f.code, "error", f.err.Error())...)
	case result == ResultLost:
		log.Warn("Lost the lease on a research document before finishing", append(attrs, "error", err.Error())...)
	default:
		log.Info("Research document ready", attrs...)
	}
}

func (w *Worker) checkDocument(ctx context.Context, job *store.DocumentJob) (string, error) {
	t, ok := document.ByMime(job.Mime)
	if !ok {
		return "", permanent("invalid_document", fmt.Errorf("unsupported document type %q", job.Mime))
	}
	data, err := w.opts.Objects.Get(ctx, storage.PostFiles, job.ObjectName, w.opts.MaxDocumentBytes)
	switch {
	case errors.Is(err, storage.ErrNotFound):
		return "", permanent("object_missing", err)
	case errors.Is(err, storage.ErrTooLarge):
		return "", permanent("file_too_large", err)
	case err != nil:
		return "", transient("storage_unavailable", err)
	}
	sum := sha256.Sum256(data)
	sha := hex.EncodeToString(sum[:])
	if job.SHA256 != "" && job.SHA256 != sha {
		return "", permanent("checksum_mismatch", fmt.Errorf("stored document hash %s differs from the submitted one", sha))
	}
	if err := document.Check(t, data); err != nil {
		switch {
		case errors.Is(err, document.ErrActiveContent):
			return "", permanent("active_content", err)
		case errors.Is(err, document.ErrMacro):
			return "", permanent("macro_not_allowed", err)
		}
		return "", permanent("invalid_document", err)
	}
	if w.opts.Scanner != nil {
		res, err := w.opts.Scanner.Scan(ctx, data)
		if err != nil {
			return "", transient("scanner_unavailable", err)
		}
		if res.Infected {
			return "", permanent("infected", fmt.Errorf("antivirus signature %s", res.Signature))
		}
	}
	return sha, nil
}

func (w *Worker) completeDocument(ctx context.Context, job *store.DocumentJob, sha string) error {
	err := w.opts.Store.CompleteDocument(ctx, job.ID, w.opts.Instance, sha)
	var api *store.APIError
	switch {
	case err == nil:
		return nil
	case errors.As(err, &api) && api.Status == http.StatusConflict:
		return err
	case errors.As(err, &api):
		return permanent(api.Code, err)
	}
	return transient("store_unavailable", err)
}
