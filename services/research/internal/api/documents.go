package api

import (
	"bufio"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"hash"
	"io"
	"net/http"
	"strings"
	"time"

	"olt-social/research/internal/document"
	"olt-social/research/internal/keys"
	"olt-social/research/internal/storage"
)

const sniffBytes = 1024

type countingReader struct {
	r   io.Reader
	sum hash.Hash
	n   int64
	err error
}

func (c *countingReader) Read(p []byte) (int, error) {
	n, err := c.r.Read(p)
	c.n += int64(n)
	c.sum.Write(p[:n])
	if err != nil && !errors.Is(err, io.EOF) {
		c.err = err
	}
	return n, err
}

func (s *Server) document(w http.ResponseWriter, r *http.Request, key *keys.Key, hash, id, ip string) outcome {
	if !fileID.MatchString(id) {
		return s.fail(w, http.StatusBadRequest, codeInvalidID, "", 0, key)
	}
	kind, ok := document.ByMime(r.Header.Get("Content-Type"))
	if !ok {
		return s.fail(w, http.StatusUnsupportedMediaType, codeUnsupportedDocument, "", 0, key)
	}
	name := strings.TrimSpace(r.URL.Query().Get("name"))
	if !document.ValidName(name) {
		return s.fail(w, http.StatusBadRequest, codeInvalidDocumentName, "", 0, key)
	}
	switch {
	case r.ContentLength < 0:
		return s.fail(w, http.StatusLengthRequired, codeLengthRequired, "", 0, key)
	case r.ContentLength == 0:
		return s.fail(w, http.StatusBadRequest, codeEmptyBody, messageEmptyDocument, 0, key)
	case r.ContentLength > s.opts.MaxDocumentBytes:
		return s.fail(w, http.StatusRequestEntityTooLarge, codeBodyTooLarge,
			fmt.Sprintf(messageDocumentTooLarge, s.opts.MaxDocumentBytes>>20), 0, key)
	}

	ctx, cancel := context.WithTimeout(r.Context(), s.opts.RequestTimeout)
	defer cancel()
	out, err := s.opts.Store.File(ctx, key.ID, id, ip)
	if res, failed := s.storeResult(w, r, err, key, hash); failed {
		return res
	}
	var file struct {
		Status string `json:"status"`
	}
	_ = json.Unmarshal(out, &file)
	if file.Status == "rejected" {
		return s.fail(w, http.StatusConflict, codeFileRejected, "", 0, key)
	}

	select {
	case s.slots <- struct{}{}:
	case <-time.After(s.opts.QueueWait):
		return s.fail(w, http.StatusServiceUnavailable, codeBusy, "", 5*time.Second, key)
	case <-r.Context().Done():
		return outcome{status: 499, code: codeCanceled, key: key}
	}
	defer func() { <-s.slots }()

	body := bufio.NewReaderSize(http.MaxBytesReader(w, r.Body, s.opts.MaxDocumentBytes), sniffBytes)
	head, _ := body.Peek(int(min(r.ContentLength, sniffBytes)))
	if !document.Sniff(kind, head) {
		return s.fail(w, http.StatusBadRequest, codeInvalidDocument, "", 0, key)
	}
	object := "research/" + objectID() + "/file." + kind.Ext
	reader := &countingReader{r: body, sum: sha256.New()}
	if err := s.opts.Objects.Put(ctx, storage.PostFiles, object, kind.Mime, reader, r.ContentLength); err != nil {
		switch {
		case r.Context().Err() != nil:
			return outcome{status: 499, code: codeCanceled, key: key, bytes: int(reader.n)}
		case reader.err != nil:
			res := s.fail(w, http.StatusBadRequest, codeIncompleteBody, "", 0, key)
			res.bytes = int(reader.n)
			return res
		}
		s.storeFailed(err)
		res := s.fail(w, http.StatusServiceUnavailable, codeUnavailable, "", 5*time.Second, key)
		res.bytes = int(reader.n)
		return res
	}
	if reader.n != r.ContentLength {
		s.discard(object)
		return s.fail(w, http.StatusBadRequest, codeIncompleteBody, "", 0, key)
	}
	sha := hex.EncodeToString(reader.sum.Sum(nil))
	out, err = s.opts.Store.SubmitDocument(ctx, key.ID, id, object, sha, name, ip)
	if res, failed := s.storeResult(w, r, err, key, hash); failed {
		s.discard(object)
		res.bytes = int(reader.n)
		return res
	}
	var doc struct {
		Status      string `json:"status"`
		Resubmitted bool   `json:"resubmitted"`
	}
	_ = json.Unmarshal(out, &doc)
	status := http.StatusAccepted
	if doc.Resubmitted {
		s.discard(object)
		status = http.StatusOK
	} else {
		s.opts.Accepted()
	}
	return s.reply(w, status, out, key, int(reader.n))
}

func (s *Server) discard(object string) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := s.opts.Objects.Remove(ctx, storage.PostFiles, object); err != nil {
		s.opts.Log.Warn("Could not remove an unused research document; the daily cleanup will remove it",
			"object", object, "error", err)
	}
}

func objectID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
}
