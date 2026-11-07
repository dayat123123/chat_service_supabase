package routes

import (
	"cmp"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"olt-social/nasabah-gateway/internal/gateway"
)

const (
	duplicateScanPageSize = 100
	duplicateScanMaxPages = 300
	duplicateScanWorkers  = 4
	duplicateCacheTTL     = 5 * time.Minute
	minPhoneDigits        = 8
)

type DuplicateGroup struct {
	Value    string   `json:"value"`
	LoginIDs []string `json:"loginIds"`
}

type Duplicates struct {
	Email     []DuplicateGroup `json:"email"`
	Phone     []DuplicateGroup `json:"phone"`
	Users     []map[string]any `json:"users"`
	Scanned   int              `json:"scanned"`
	Complete  bool             `json:"complete"`
	CheckedAt time.Time        `json:"checkedAt"`
}

type DuplicateScanner struct {
	Now     func() time.Time
	mu      sync.Mutex
	cached  *Duplicates
	expires time.Time
}

func (s *DuplicateScanner) Compute(ctx context.Context, call gateway.Caller, _ *gateway.Request) (any, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	if s.Now != nil {
		now = s.Now()
	}
	if s.cached != nil && now.Before(s.expires) {
		return s.cached, nil
	}
	result, err := scanDuplicates(ctx, call, now)
	if err != nil {
		return nil, err
	}
	s.cached, s.expires = result, now.Add(duplicateCacheTTL)
	return result, nil
}

func scanDuplicates(ctx context.Context, call gateway.Caller, now time.Time) (*Duplicates, error) {
	first, totalPages, err := userPage(ctx, call, 1)
	if err != nil {
		return nil, err
	}
	pages := min(totalPages, duplicateScanMaxPages)
	results := make([][]map[string]any, max(pages, 1))
	results[0] = first
	errs := make([]error, len(results))
	next := make(chan int)
	var wg sync.WaitGroup
	for range duplicateScanWorkers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for page := range next {
				results[page-1], _, errs[page-1] = userPage(ctx, call, page)
			}
		}()
	}
	for page := 2; page <= pages; page++ {
		next <- page
	}
	close(next)
	wg.Wait()
	for _, err := range errs {
		if err != nil {
			return nil, err
		}
	}
	rows := slices.Concat(results...)
	out := groupDuplicates(rows)
	out.Scanned = len(rows)
	out.Complete = totalPages <= duplicateScanMaxPages
	out.CheckedAt = now.UTC()
	return out, nil
}

func userPage(ctx context.Context, call gateway.Caller, page int) ([]map[string]any, int, error) {
	status, payload, err := call.Get(ctx, "/online/get-list-online-user", url.Values{
		"page": {strconv.Itoa(page)}, "size": {strconv.Itoa(duplicateScanPageSize)},
	})
	if err != nil {
		return nil, 0, err
	}
	if status != http.StatusOK {
		return nil, 0, fmt.Errorf("duplicate scan page %d: status %d", page, status)
	}
	var envelope struct {
		Data       []map[string]any `json:"data"`
		Pagination struct {
			TotalPages int `json:"total_pages"`
		} `json:"pagination"`
	}
	if err := json.Unmarshal(payload, &envelope); err != nil {
		return nil, 0, fmt.Errorf("duplicate scan page %d: %w", page, err)
	}
	return envelope.Data, envelope.Pagination.TotalPages, nil
}

type duplicateIndex struct {
	keys  []string
	names map[string][]string
	seen  map[string]map[string]bool
}

func newDuplicateIndex() *duplicateIndex {
	return &duplicateIndex{names: map[string][]string{}, seen: map[string]map[string]bool{}}
}

func (d *duplicateIndex) add(key, loginID string) {
	if key == "" {
		return
	}
	if d.seen[key] == nil {
		d.seen[key] = map[string]bool{}
		d.keys = append(d.keys, key)
	}
	id := strings.ToLower(loginID)
	if d.seen[key][id] {
		return
	}
	d.seen[key][id] = true
	d.names[key] = append(d.names[key], loginID)
}

func (d *duplicateIndex) groups(members map[string]bool) []DuplicateGroup {
	out := []DuplicateGroup{}
	for _, key := range d.keys {
		ids := d.names[key]
		if len(ids) < 2 {
			continue
		}
		slices.SortFunc(ids, compareLoginIDs)
		for _, id := range ids {
			members[strings.ToLower(id)] = true
		}
		out = append(out, DuplicateGroup{Value: key, LoginIDs: ids})
	}
	slices.SortFunc(out, func(a, b DuplicateGroup) int { return strings.Compare(a.Value, b.Value) })
	return out
}

func groupDuplicates(rows []map[string]any) *Duplicates {
	emails, phones := newDuplicateIndex(), newDuplicateIndex()
	first := map[string]map[string]any{}
	for _, r := range rows {
		loginID := strings.TrimSpace(text(r["LoginId"]))
		if loginID == "" {
			continue
		}
		if _, ok := first[strings.ToLower(loginID)]; !ok {
			first[strings.ToLower(loginID)] = r
		}
		emails.add(emailKey(text(r["Email"])), loginID)
		phones.add(phoneKey(text(r["PhoneNumber"])), loginID)
	}
	members := map[string]bool{}
	out := &Duplicates{Email: emails.groups(members), Phone: phones.groups(members), Users: []map[string]any{}}
	for id := range members {
		out.Users = append(out.Users, first[id])
	}
	slices.SortFunc(out.Users, func(a, b map[string]any) int {
		return compareLoginIDs(strings.TrimSpace(text(a["LoginId"])), strings.TrimSpace(text(b["LoginId"])))
	})
	return out
}

func compareLoginIDs(a, b string) int {
	return cmp.Or(strings.Compare(strings.ToLower(a), strings.ToLower(b)), strings.Compare(a, b))
}

func emailKey(v string) string {
	email := strings.ToLower(strings.TrimSpace(v))
	if at := strings.IndexByte(email, '@'); at <= 0 || at == len(email)-1 {
		return ""
	}
	return email
}

func phoneKey(v string) string {
	digits := strings.Map(func(r rune) rune {
		if r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, v)
	switch {
	case strings.HasPrefix(digits, "62"):
		digits = "0" + digits[2:]
	case strings.HasPrefix(digits, "8"):
		digits = "0" + digits
	}
	if len(digits) < minPhoneDigits {
		return ""
	}
	return digits
}
