package ratelimit

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"time"

	"github.com/redis/go-redis/v9"
)

var slidingWindow = redis.NewScript(`
local key = KEYS[1]
local now = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local limit = tonumber(ARGV[3])
redis.call('ZREMRANGEBYSCORE', key, 0, now - window)
if redis.call('ZCARD', key) >= limit then
  local oldest = redis.call('ZRANGE', key, 0, 0, 'WITHSCORES')
  local retry = window
  if oldest[2] then retry = tonumber(oldest[2]) + window - now end
  return {0, retry}
end
redis.call('ZADD', key, now, ARGV[4])
redis.call('PEXPIRE', key, window)
return {1, 0}
`)

type Valkey struct {
	client   redis.UniversalClient
	limit    int
	window   time.Duration
	prefix   string
	timeout  time.Duration
	fallback *Limiter
	now      func() time.Time

	OnError func(error)
}

func NewValkey(client redis.UniversalClient, prefix string, limit int, window time.Duration) *Valkey {
	return &Valkey{
		client:   client,
		limit:    limit,
		window:   window,
		prefix:   prefix,
		timeout:  300 * time.Millisecond,
		fallback: New(limit, window),
		now:      time.Now,
	}
}

func (v *Valkey) Allow(key string) (bool, time.Duration) {
	ctx, cancel := context.WithTimeout(context.Background(), v.timeout)
	defer cancel()

	var member [8]byte
	_, _ = rand.Read(member[:])
	res, err := slidingWindow.Run(ctx, v.client, []string{v.prefix + key},
		v.now().UnixMilli(), v.window.Milliseconds(), v.limit, hex.EncodeToString(member[:])).Int64Slice()
	if err != nil || len(res) != 2 {
		if v.OnError != nil && err != nil {
			v.OnError(err)
		}
		return v.fallback.Allow(key)
	}
	if res[0] == 1 {
		return true, 0
	}
	return false, time.Duration(res[1]) * time.Millisecond
}
