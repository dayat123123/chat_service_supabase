package push

import "time"

const (
	Android = "android"
	IOS     = "ios"
	Web     = "web"
)

type Job struct {
	ID          int64
	Token       string
	Platform    string
	Kind        string
	Title       string
	Body        string
	Data        map[string]string
	CollapseKey string
	Badge       *int
	Priority    string
	TTLSeconds  int
	Attempt     int
}

type Outcome string

const (
	Sent    Outcome = "sent"
	Retry   Outcome = "retry"
	Invalid Outcome = "invalid"
	Failed  Outcome = "failed"
	Release Outcome = "release"
)

var Outcomes = []Outcome{Sent, Retry, Invalid, Failed, Release}

type Result struct {
	ID         int64
	Outcome    Outcome
	Error      string
	RetryAfter time.Duration
}

type Delivery struct {
	Result   Result
	Healthy  bool
	Problem  string
	Systemic bool
}

type Status struct {
	Configured bool
	ProjectID  string
	Problem    string
}

type Credentials struct {
	Revision   int64
	Unchanged  bool
	Configured bool
	Data       []byte
	Problem    string
}

const UnknownRevision int64 = -1

type Heartbeat struct {
	Instance            string
	Version             string
	Configured          bool
	ProjectID           string
	Error               string
	StartedAt           time.Time
	CredentialsRevision int64
}
