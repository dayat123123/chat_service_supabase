package fcm

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"
	"time"

	"olt-social/notifier/internal/push"
)

func TestBuildMessage(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	badge := 3
	full := push.Job{
		ID: 41, Token: "device-token", Kind: "chat.message", Title: "Rina", Body: "Halo",
		Data: map[string]string{"kind": "chat.message", "room_id": "r1"}, CollapseKey: "room:r1",
		Badge: &badge, Priority: "high", TTLSeconds: 600,
	}
	bare := push.Job{ID: 42, Token: "device-token", Kind: "like", Title: "Suka", Priority: "normal", TTLSeconds: 0}
	cases := []struct {
		name     string
		job      push.Job
		platform string
		channel  string
		want     string
	}{
		{
			name: "android with every option", job: full, platform: push.Android, channel: "chat",
			want: `{"message":{"token":"device-token","notification":{"title":"Rina","body":"Halo"},
				"data":{"kind":"chat.message","room_id":"r1","push_id":"41"},
				"android":{"priority":"HIGH","ttl":"600s","collapse_key":"room:r1",
				"notification":{"tag":"room:r1","channel_id":"chat","notification_count":3}}}}`,
		},
		{
			name: "android without optional fields", job: bare, platform: push.Android,
			want: `{"message":{"token":"device-token","notification":{"title":"Suka"},"data":{"push_id":"42"},
				"android":{"priority":"NORMAL","ttl":"0s"}}}`,
		},
		{
			name: "android with only a channel", job: bare, platform: push.Android, channel: "general",
			want: `{"message":{"token":"device-token","notification":{"title":"Suka"},"data":{"push_id":"42"},
				"android":{"priority":"NORMAL","ttl":"0s","notification":{"channel_id":"general"}}}}`,
		},
		{
			name: "ios with every option", job: full, platform: push.IOS, channel: "chat",
			want: `{"message":{"token":"device-token","notification":{"title":"Rina","body":"Halo"},
				"data":{"kind":"chat.message","room_id":"r1","push_id":"41"},
				"apns":{"headers":{"apns-priority":"10","apns-expiration":"1800000600","apns-collapse-id":"room:r1"},
				"payload":{"aps":{"sound":"default","badge":3,"thread-id":"room:r1"}}}}}`,
		},
		{
			name: "ios without optional fields", job: bare, platform: push.IOS,
			want: `{"message":{"token":"device-token","notification":{"title":"Suka"},"data":{"push_id":"42"},
				"apns":{"headers":{"apns-priority":"5","apns-expiration":"1800000000"},
				"payload":{"aps":{"sound":"default"}}}}}`,
		},
		{
			name: "web high priority", job: full, platform: push.Web,
			want: `{"message":{"token":"device-token","notification":{"title":"Rina","body":"Halo"},
				"data":{"kind":"chat.message","room_id":"r1","push_id":"41"},
				"webpush":{"headers":{"TTL":"600","Urgency":"high"}}}}`,
		},
		{
			name: "web normal priority", job: bare, platform: push.Web,
			want: `{"message":{"token":"device-token","notification":{"title":"Suka"},"data":{"push_id":"42"},
				"webpush":{"headers":{"TTL":"0","Urgency":"normal"}}}}`,
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			job := tc.job
			job.Platform = tc.platform
			body, err := buildMessage(job, tc.channel, now)
			if err != nil {
				t.Fatal(err)
			}
			var got, want any
			if err := json.Unmarshal(body, &got); err != nil {
				t.Fatal(err)
			}
			if err := json.Unmarshal([]byte(tc.want), &want); err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(got, want) {
				t.Fatalf("message = %s", body)
			}
		})
	}
}

func TestBuildMessageDoesNotMutateJobData(t *testing.T) {
	data := map[string]string{"kind": "follow"}
	if _, err := buildMessage(push.Job{ID: 1, Platform: push.Web, Title: "x", Data: data}, "", time.Now()); err != nil {
		t.Fatal(err)
	}
	if len(data) != 1 {
		t.Fatalf("job data was modified: %v", data)
	}
}

func TestBuildMessageRejectsUnknownPlatforms(t *testing.T) {
	_, err := buildMessage(push.Job{ID: 1, Platform: "symbian", Title: "x"}, "", time.Now())
	if err == nil || !strings.Contains(err.Error(), "symbian") {
		t.Fatalf("err = %v", err)
	}
}
