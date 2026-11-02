package fcm

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"olt-social/notifier/internal/push"
)

type verdict struct {
	delivery     push.Delivery
	unauthorized bool
}

type errorReply struct {
	Error struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Status  string `json:"status"`
		Details []struct {
			Type      string `json:"@type"`
			ErrorCode string `json:"errorCode"`
		} `json:"details"`
	} `json:"error"`
}

func classify(status int, header http.Header, body []byte, now time.Time) verdict {
	if status >= 200 && status < 300 {
		return verdict{delivery: push.Delivery{Result: push.Result{Outcome: push.Sent}, Healthy: true}}
	}
	var reply errorReply
	_ = json.Unmarshal(body, &reply)
	code := errorCode(reply)
	message := strings.TrimSpace(reply.Error.Message)
	text := firstNonEmpty(message, fmt.Sprintf("HTTP %d", status))
	switch code {
	case "UNREGISTERED", "SENDER_ID_MISMATCH":
		return outcome(push.Invalid, "Token perangkat tidak berlaku ("+code+")")
	case "INVALID_ARGUMENT":
		if strings.Contains(strings.ToLower(text), "registration token") {
			return outcome(push.Invalid, "Token perangkat tidak valid: "+text)
		}
		return outcome(push.Failed, text)
	case "THIRD_PARTY_AUTH_ERROR":
		v := outcome(push.Failed, text)
		v.delivery.Problem = problemThirdPartyAuth
		return v
	case "QUOTA_EXCEEDED", "UNAVAILABLE", "INTERNAL":
		return retry(code, message, header, now)
	case "PERMISSION_DENIED", "NOT_FOUND":
		return systemic(problemAccessDenied + text)
	case "UNAUTHENTICATED":
		return unauthorized(text)
	}
	switch {
	case status == http.StatusBadRequest:
		return outcome(push.Failed, text)
	case status == http.StatusUnauthorized:
		return unauthorized(text)
	case status == http.StatusForbidden, status == http.StatusNotFound:
		return systemic(problemAccessDenied + text)
	case status == http.StatusTooManyRequests, status >= 500:
		return retry(firstNonEmpty(code, "HTTP "+strconv.Itoa(status)), message, header, now)
	default:
		return outcome(push.Failed, text)
	}
}

func errorCode(reply errorReply) string {
	for _, detail := range reply.Error.Details {
		if strings.HasSuffix(detail.Type, "FcmError") && detail.ErrorCode != "" {
			return detail.ErrorCode
		}
	}
	return strings.TrimSpace(reply.Error.Status)
}

func outcome(o push.Outcome, text string) verdict {
	return verdict{delivery: push.Delivery{Result: push.Result{Outcome: o, Error: text}}}
}

func retry(code, message string, header http.Header, now time.Time) verdict {
	text := "Firebase sementara gagal (" + code + ")"
	if message != "" {
		text += ": " + message
	}
	v := outcome(push.Retry, text)
	v.delivery.Result.RetryAfter = retryAfter(header, now)
	return v
}

func systemic(problem string) verdict {
	return verdict{delivery: push.Delivery{
		Result:   push.Result{Outcome: push.Release, Error: problem},
		Problem:  problem,
		Systemic: true,
	}}
}

func unauthorized(text string) verdict {
	v := systemic(problemAccessDenied + text)
	v.unauthorized = true
	return v
}

func retryAfter(header http.Header, now time.Time) time.Duration {
	raw := strings.TrimSpace(header.Get("Retry-After"))
	if raw == "" {
		return 0
	}
	var wait time.Duration
	if secs, err := strconv.Atoi(raw); err == nil {
		wait = time.Duration(secs) * time.Second
	} else if at, err := http.ParseTime(raw); err == nil {
		wait = at.Sub(now)
	} else {
		return 0
	}
	return min(max(wait, time.Second), time.Hour)
}
