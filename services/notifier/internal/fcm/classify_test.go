package fcm

import (
	"net/http"
	"testing"
	"time"

	"olt-social/notifier/internal/push"
)

func fcmError(status, errorCode, message string) string {
	details := ""
	if errorCode != "" {
		details = `,"details":[{"@type":"type.googleapis.com/google.rpc.BadRequest"},{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"` + errorCode + `"}]`
	}
	return `{"error":{"code":0,"message":"` + message + `","status":"` + status + `"` + details + `}}`
}

func TestClassify(t *testing.T) {
	now := time.Date(2026, 11, 2, 8, 0, 0, 0, time.UTC)
	cases := []struct {
		name         string
		status       int
		retryAfter   string
		body         string
		outcome      push.Outcome
		err          string
		wait         time.Duration
		problem      string
		systemic     bool
		healthy      bool
		unauthorized bool
	}{
		{name: "delivered", status: 200, body: `{"name":"projects/demo/messages/1"}`, outcome: push.Sent, healthy: true},
		{name: "unregistered", status: 404, body: fcmError("NOT_FOUND", "UNREGISTERED", "Requested entity was not found."),
			outcome: push.Invalid, err: "Token perangkat tidak berlaku (UNREGISTERED)"},
		{name: "sender id mismatch", status: 403, body: fcmError("PERMISSION_DENIED", "SENDER_ID_MISMATCH", "SenderId mismatch"),
			outcome: push.Invalid, err: "Token perangkat tidak berlaku (SENDER_ID_MISMATCH)"},
		{name: "malformed registration token", status: 400,
			body:    fcmError("INVALID_ARGUMENT", "INVALID_ARGUMENT", "The registration token is not a valid FCM Registration Token"),
			outcome: push.Invalid, err: "Token perangkat tidak valid: The registration token is not a valid FCM Registration Token"},
		{name: "invalid argument from status only", status: 400,
			body:    fcmError("INVALID_ARGUMENT", "", "Invalid registration token provided"),
			outcome: push.Invalid, err: "Token perangkat tidak valid: Invalid registration token provided"},
		{name: "payload problem", status: 400,
			body:    fcmError("INVALID_ARGUMENT", "INVALID_ARGUMENT", "Invalid value at 'message.data[0].value' (TYPE_STRING)"),
			outcome: push.Failed, err: "Invalid value at 'message.data[0].value' (TYPE_STRING)"},
		{name: "bare 400", status: 400, body: `oops`, outcome: push.Failed, err: "HTTP 400"},
		{name: "third party auth", status: 401, body: fcmError("UNAUTHENTICATED", "THIRD_PARTY_AUTH_ERROR", "Auth error from APNS or Web Push Service"),
			outcome: push.Failed, err: "Auth error from APNS or Web Push Service", problem: problemThirdPartyAuth},
		{name: "quota with seconds", status: 429, retryAfter: "120", body: fcmError("RESOURCE_EXHAUSTED", "QUOTA_EXCEEDED", "Quota exceeded"),
			outcome: push.Retry, err: "Firebase sementara gagal (QUOTA_EXCEEDED): Quota exceeded", wait: 2 * time.Minute},
		{name: "unavailable with http date", status: 503, retryAfter: "Mon, 02 Nov 2026 08:00:45 GMT",
			body:    fcmError("UNAVAILABLE", "UNAVAILABLE", "The service is currently unavailable."),
			outcome: push.Retry, err: "Firebase sementara gagal (UNAVAILABLE): The service is currently unavailable.", wait: 45 * time.Second},
		{name: "retry-after in the past", status: 503, retryAfter: "Mon, 02 Nov 2026 07:00:00 GMT",
			body: fcmError("UNAVAILABLE", "", "busy"), outcome: push.Retry, err: "Firebase sementara gagal (UNAVAILABLE): busy", wait: time.Second},
		{name: "retry-after capped", status: 429, retryAfter: "86400", body: ``,
			outcome: push.Retry, err: "Firebase sementara gagal (HTTP 429)", wait: time.Hour},
		{name: "unparseable retry-after", status: 503, retryAfter: "soon", body: fcmError("UNAVAILABLE", "", "busy"),
			outcome: push.Retry, err: "Firebase sementara gagal (UNAVAILABLE): busy"},
		{name: "internal", status: 500, body: fcmError("INTERNAL", "INTERNAL", "Internal error encountered."),
			outcome: push.Retry, err: "Firebase sementara gagal (INTERNAL): Internal error encountered."},
		{name: "other 5xx", status: 502, body: `<html>bad gateway</html>`,
			outcome: push.Retry, err: "Firebase sementara gagal (HTTP 502)"},
		{name: "expired access token", status: 401,
			body:    fcmError("UNAUTHENTICATED", "", "Request had invalid authentication credentials."),
			outcome: push.Release, err: "Firebase menolak akses: Request had invalid authentication credentials.",
			problem: "Firebase menolak akses: Request had invalid authentication credentials.", systemic: true, unauthorized: true},
		{name: "bare 401", status: 401, body: ``, outcome: push.Release, err: "Firebase menolak akses: HTTP 401",
			problem: "Firebase menolak akses: HTTP 401", systemic: true, unauthorized: true},
		{name: "permission denied", status: 403,
			body:    fcmError("PERMISSION_DENIED", "", "Firebase Cloud Messaging API has not been used in project demo"),
			outcome: push.Release, err: "Firebase menolak akses: Firebase Cloud Messaging API has not been used in project demo",
			problem: "Firebase menolak akses: Firebase Cloud Messaging API has not been used in project demo", systemic: true},
		{name: "wrong project", status: 404, body: fcmError("NOT_FOUND", "", "Requested entity was not found."),
			outcome: push.Release, err: "Firebase menolak akses: Requested entity was not found.",
			problem: "Firebase menolak akses: Requested entity was not found.", systemic: true},
		{name: "unknown 4xx", status: 409, body: fcmError("ABORTED", "", "conflict"), outcome: push.Failed, err: "conflict"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			header := http.Header{}
			if tc.retryAfter != "" {
				header.Set("Retry-After", tc.retryAfter)
			}
			v := classify(tc.status, header, []byte(tc.body), now)
			d := v.delivery
			if d.Result.Outcome != tc.outcome || d.Result.Error != tc.err || d.Result.RetryAfter != tc.wait ||
				d.Problem != tc.problem || d.Systemic != tc.systemic || d.Healthy != tc.healthy || v.unauthorized != tc.unauthorized {
				t.Fatalf("verdict = %+v unauthorized = %v", d, v.unauthorized)
			}
		})
	}
}
