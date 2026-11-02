package fcm

import (
	"encoding/json"
	"fmt"
	"maps"
	"strconv"
	"time"

	"olt-social/notifier/internal/push"
)

type envelope struct {
	Message message `json:"message"`
}

type message struct {
	Token        string            `json:"token"`
	Notification notification      `json:"notification"`
	Data         map[string]string `json:"data"`
	Android      *androidConfig    `json:"android,omitempty"`
	APNS         *apnsConfig       `json:"apns,omitempty"`
	Webpush      *webpushConfig    `json:"webpush,omitempty"`
}

type notification struct {
	Title string `json:"title"`
	Body  string `json:"body,omitempty"`
}

type androidConfig struct {
	Priority     string               `json:"priority"`
	TTL          string               `json:"ttl"`
	CollapseKey  string               `json:"collapse_key,omitempty"`
	Notification *androidNotification `json:"notification,omitempty"`
}

type androidNotification struct {
	Tag               string `json:"tag,omitempty"`
	ChannelID         string `json:"channel_id,omitempty"`
	NotificationCount *int   `json:"notification_count,omitempty"`
}

type apnsConfig struct {
	Headers map[string]string `json:"headers"`
	Payload apnsPayload       `json:"payload"`
}

type apnsPayload struct {
	APS aps `json:"aps"`
}

type aps struct {
	Sound    string `json:"sound"`
	Badge    *int   `json:"badge,omitempty"`
	ThreadID string `json:"thread-id,omitempty"`
}

type webpushConfig struct {
	Headers map[string]string `json:"headers"`
}

func buildMessage(job push.Job, channelID string, now time.Time) ([]byte, error) {
	data := make(map[string]string, len(job.Data)+1)
	maps.Copy(data, job.Data)
	data["push_id"] = strconv.FormatInt(job.ID, 10)
	msg := message{
		Token:        job.Token,
		Notification: notification{Title: job.Title, Body: job.Body},
		Data:         data,
	}
	high := job.Priority != "normal"
	ttl := max(job.TTLSeconds, 0)
	switch job.Platform {
	case push.Android:
		android := &androidConfig{
			Priority:    choose(high, "HIGH", "NORMAL"),
			TTL:         strconv.Itoa(ttl) + "s",
			CollapseKey: job.CollapseKey,
		}
		extra := androidNotification{Tag: job.CollapseKey, ChannelID: channelID, NotificationCount: job.Badge}
		if extra != (androidNotification{}) {
			android.Notification = &extra
		}
		msg.Android = android
	case push.IOS:
		headers := map[string]string{
			"apns-priority":   choose(high, "10", "5"),
			"apns-expiration": strconv.FormatInt(now.Unix()+int64(ttl), 10),
		}
		if job.CollapseKey != "" {
			headers["apns-collapse-id"] = job.CollapseKey
		}
		msg.APNS = &apnsConfig{
			Headers: headers,
			Payload: apnsPayload{APS: aps{Sound: "default", Badge: job.Badge, ThreadID: job.CollapseKey}},
		}
	case push.Web:
		msg.Webpush = &webpushConfig{Headers: map[string]string{
			"TTL":     strconv.Itoa(ttl),
			"Urgency": choose(high, "high", "normal"),
		}}
	default:
		return nil, fmt.Errorf("platform perangkat tidak dikenal: %q", job.Platform)
	}
	return json.Marshal(envelope{Message: msg})
}

func choose(high bool, ifHigh, otherwise string) string {
	if high {
		return ifHigh
	}
	return otherwise
}
