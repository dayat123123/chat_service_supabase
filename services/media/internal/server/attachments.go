package server

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"slices"
	"time"

	"olt-social/media/internal/attachments"
	"olt-social/media/internal/clamd"
	"olt-social/media/internal/sniff"
	"olt-social/media/internal/video"
)

const staleSignatures = 72 * time.Hour

func (s *Server) rule(b bucket) (int64, attachments.Rule, *apiError) {
	if b.policy == "" {
		return b.limit, attachments.Rule{}, nil
	}
	if s.opts.Attachments == nil {
		return 0, attachments.Rule{}, fail(http.StatusServiceUnavailable, codePolicyUnavailable, "no attachment policy source")
	}
	policy, loaded := s.opts.Attachments.Current()
	if !loaded {
		return 0, attachments.Rule{}, fail(http.StatusServiceUnavailable, codePolicyUnavailable, "attachment policy is not loaded")
	}
	rule, ok := policy[b.policy]
	if !ok || !rule.Enabled || rule.MaxBytes <= 0 {
		return 0, attachments.Rule{}, fail(http.StatusForbidden, codeKindDisabled, b.policy+" are turned off")
	}
	return min(b.limit, rule.MaxBytes), rule, nil
}

func typeError(b bucket, rule attachments.Rule, kind sniff.Kind, body []byte, name string) *apiError {
	if !slices.Contains(b.kinds, kind) {
		if b.policy == "documents" && kind == sniff.Unknown && sniff.TextExtension(name) && !sniff.Text(body) {
			return fail(http.StatusUnprocessableEntity, codeInvalidText, "text extension without valid UTF-8 text")
		}
		return fail(http.StatusUnsupportedMediaType, codeUnsupportedType, "detected "+kind.String())
	}
	if b.policy != "" && !rule.Allows(kind.String()) {
		return fail(http.StatusUnsupportedMediaType, codeUnsupportedType, "format "+kind.String()+" is turned off")
	}
	return nil
}

func (s *Server) scan(ctx context.Context, r *http.Request, body []byte) *apiError {
	if s.opts.Scanner == nil {
		return fail(http.StatusServiceUnavailable, codeScannerUnavailable, "no scanner configured")
	}
	result, err := s.opts.Scanner.Scan(ctx, body)
	if r.Context().Err() != nil {
		return fail(499, codeCanceled, "client went away while scanning")
	}
	s.noteScanner(err, result.Infected)
	switch {
	case err != nil:
		return fail(http.StatusServiceUnavailable, codeScannerUnavailable, err.Error())
	case result.Infected:
		return fail(http.StatusUnprocessableEntity, codeMalwareDetected, "signature "+result.Signature)
	}
	return nil
}

func (s *Server) process(ctx context.Context, r *http.Request, body []byte, kind sniff.Kind, maxSeconds float64) (video.Result, *apiError) {
	if s.opts.Video == nil {
		return video.Result{}, fail(http.StatusInternalServerError, codeInternal, "no video processor configured")
	}
	result, err := s.opts.Video.Process(ctx, body, kind, maxSeconds)
	switch {
	case err == nil:
		return result, nil
	case r.Context().Err() != nil:
		return video.Result{}, fail(499, codeCanceled, "client went away while processing the video")
	case errors.Is(err, context.DeadlineExceeded):
		return video.Result{}, fail(http.StatusRequestTimeout, codeRequestTimeout, err.Error())
	case errors.Is(err, video.ErrTooLong):
		e := fail(http.StatusUnprocessableEntity, codeVideoTooLong, err.Error())
		e.message = fmt.Sprintf("Video is longer than %s.", seconds(maxSeconds))
		return video.Result{}, e
	case errors.Is(err, video.ErrInvalid):
		return video.Result{}, fail(http.StatusUnprocessableEntity, codeInvalidVideo, err.Error())
	case errors.Is(err, video.ErrBusy):
		return video.Result{}, fail(http.StatusServiceUnavailable, codeBusy, err.Error())
	}
	return video.Result{}, fail(http.StatusInternalServerError, codeInternal, err.Error())
}

func seconds(v float64) string {
	total := int(v)
	if total%60 == 0 && total >= 60 {
		return fmt.Sprintf("%d minutes", total/60)
	}
	return fmt.Sprintf("%d seconds", total)
}

func (s *Server) noteScanner(err error, infected bool) {
	s.mu.Lock()
	before := s.scannerFails >= failThreshold
	if err == nil {
		s.scannerFails = 0
		s.scanned++
		if infected {
			s.infected++
		}
	} else {
		s.scannerFails++
	}
	after := s.scannerFails >= failThreshold
	fails := s.scannerFails
	s.mu.Unlock()
	if before == after {
		return
	}
	if after {
		s.opts.Log.Warn("Virus scanner cannot be used; CS document and video uploads are refused",
			"consecutive_failures", fails, "error", err)
	} else {
		s.opts.Log.Info("Virus scanner works again")
	}
	if s.opts.Notify != nil {
		s.opts.Notify()
	}
}

func (s *Server) ProbeScanner(ctx context.Context) {
	if s.opts.Scanner == nil {
		return
	}
	probe, cancel := context.WithTimeout(ctx, probeTimeout)
	version, err := s.opts.Scanner.Version(probe)
	cancel()
	if ctx.Err() != nil {
		return
	}
	if err != nil {
		s.opts.Log.Debug("Virus scanner probe failed", "error", err)
		s.noteScanner(err, false)
		return
	}
	s.mu.Lock()
	was := s.scannerFails >= failThreshold
	changed := s.scannerVersion != version
	s.scannerFails, s.scannerVersion = 0, version
	s.mu.Unlock()
	if changed {
		s.opts.Log.Info("Virus scanner version", "version", version)
	}
	if was {
		s.opts.Log.Info("Virus scanner works again")
		if s.opts.Notify != nil {
			s.opts.Notify()
		}
	}
}

func (s *Server) scannerProblems() []string {
	var problems []string
	if s.scannerFails >= failThreshold {
		problems = append(problems, fmt.Sprintf("Pemindai antivirus tidak bisa dihubungi (%d kali berturut-turut); upload dokumen dan video chat CS ditolak", s.scannerFails))
	} else if at, ok := clamd.SignatureDate(s.scannerVersion); ok && s.opts.Now().Sub(at) > staleSignatures {
		problems = append(problems, "Database virus pemindai antivirus belum diperbarui sejak "+at.Format("2 Jan 2006")+
			"; periksa akses internet container clamav (freshclam)")
	}
	if s.opts.Attachments != nil {
		if _, loaded := s.opts.Attachments.Current(); !loaded {
			problems = append(problems, "Kebijakan lampiran chat CS belum termuat; upload dokumen dan video chat CS ditolak")
		}
	}
	return problems
}
