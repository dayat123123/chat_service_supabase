package env

import (
	"errors"
	"fmt"
	"log/slog"
	"os"
	"strconv"
	"strings"
	"time"
)

type Reader struct {
	errs []error
}

func (r *Reader) String(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && strings.TrimSpace(v) != "" {
		return strings.TrimSpace(v)
	}
	return def
}

func (r *Reader) Int(key string, def, floor int) int {
	raw := r.String(key, strconv.Itoa(def))
	n, err := strconv.Atoi(raw)
	if err != nil || n < floor {
		r.Fail(fmt.Errorf("%s harus bilangan bulat >= %d, dapat %q", key, floor, raw))
		return def
	}
	return n
}

func (r *Reader) Seconds(key string, def int) time.Duration {
	return time.Duration(r.Int(key, def, 1)) * time.Second
}

func (r *Reader) Secret(key string) string {
	path := os.Getenv(key + "_FILE")
	if path == "" {
		return strings.TrimSpace(os.Getenv(key))
	}
	b, err := os.ReadFile(path)
	if err != nil {
		r.Fail(fmt.Errorf("%s_FILE: %w", key, err))
		return ""
	}
	return strings.TrimSpace(string(b))
}

func (r *Reader) LogLevel(key string) slog.Level {
	var level slog.Level
	if err := level.UnmarshalText([]byte(r.String(key, "info"))); err != nil {
		r.Fail(fmt.Errorf("%s: %w", key, err))
	}
	return level
}

func (r *Reader) Fail(err error) {
	r.errs = append(r.errs, err)
}

func (r *Reader) Err() error {
	return errors.Join(r.errs...)
}
