package routes

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"sync"
	"testing"
	"time"
)

type pagedCaller struct {
	mu     sync.Mutex
	pages  [][]map[string]any
	status int
	calls  []url.Values
}

func (p *pagedCaller) Get(_ context.Context, path string, query url.Values) (int, []byte, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.calls = append(p.calls, query)
	if path != "/online/get-list-online-user" {
		return http.StatusNotFound, nil, nil
	}
	if p.status != 0 {
		return p.status, []byte(`{"message":"down"}`), nil
	}
	page, _ := strconv.Atoi(query.Get("page"))
	if page < 1 || page > len(p.pages) {
		return http.StatusOK, []byte(`{"message": "No data available"}`), nil
	}
	body, _ := json.Marshal(map[string]any{
		"data":       p.pages[page-1],
		"pagination": map[string]any{"current_page": page, "per_page": 100, "total_pages": len(p.pages)},
	})
	return http.StatusOK, body, nil
}

func row(loginID, email, phone string) map[string]any {
	return map[string]any{"LoginId": loginID, "Email": email, "PhoneNumber": phone}
}

func scan(t *testing.T, caller *pagedCaller) *Duplicates {
	t.Helper()
	s := &DuplicateScanner{Now: func() time.Time { return time.Unix(1_800_000_000, 0) }}
	out, err := s.Compute(context.Background(), caller, request([]string{View}, "CS-1", nil))
	if err != nil {
		t.Fatal(err)
	}
	return out.(*Duplicates)
}

func TestDuplicatesGroupSameEmailAndPhoneAcrossPages(t *testing.T) {
	caller := &pagedCaller{pages: [][]map[string]any{
		{row("Hidayat", "Hidayat@Gmail.com ", "0812-3456-789"), row("Budi", "budi@olt.test", "081111111111"), row("Kosong", "", "")},
		{row("Hidayat2", "hidayat@gmail.com", "+62 812 3456 789"), row("Sari", "sari@olt.test", "6281111111111"), row("Tanpa", "-", "0")},
	}}
	got := scan(t, caller)

	if len(caller.calls) != 2 || caller.calls[0].Get("size") != "100" {
		t.Fatalf("expected two full-size page reads, got %v", caller.calls)
	}
	if !got.Complete || got.Scanned != 6 {
		t.Fatalf("complete=%v scanned=%d", got.Complete, got.Scanned)
	}
	wantEmail := []DuplicateGroup{{Value: "hidayat@gmail.com", LoginIDs: []string{"Hidayat", "Hidayat2"}}}
	if fmt.Sprint(got.Email) != fmt.Sprint(wantEmail) {
		t.Errorf("email groups %v, want %v", got.Email, wantEmail)
	}
	wantPhone := []DuplicateGroup{
		{Value: "081111111111", LoginIDs: []string{"Budi", "Sari"}},
		{Value: "08123456789", LoginIDs: []string{"Hidayat", "Hidayat2"}},
	}
	if fmt.Sprint(got.Phone) != fmt.Sprint(wantPhone) {
		t.Errorf("phone groups %v, want %v", got.Phone, wantPhone)
	}
	var users []string
	for _, u := range got.Users {
		users = append(users, text(u["LoginId"]))
	}
	if fmt.Sprint(users) != "[Budi Hidayat Hidayat2 Sari]" {
		t.Errorf("users %v", users)
	}
}

func TestDuplicatesIgnoreTheSameLoginIdListedTwice(t *testing.T) {
	caller := &pagedCaller{pages: [][]map[string]any{
		{row("Budi", "budi@olt.test", ""), row("budi ", "BUDI@olt.test", "")},
	}}
	got := scan(t, caller)
	if len(got.Email) != 0 || len(got.Users) != 0 {
		t.Fatalf("one Online ID is not a duplicate: %v %v", got.Email, got.Users)
	}
}

func TestDuplicatesStopAtThePageLimitAndSayItIsPartial(t *testing.T) {
	pages := make([][]map[string]any, duplicateScanMaxPages+5)
	for i := range pages {
		pages[i] = []map[string]any{row(fmt.Sprintf("U%04d", i), "", "")}
	}
	caller := &pagedCaller{pages: pages}
	got := scan(t, caller)
	if got.Complete || len(caller.calls) != duplicateScanMaxPages {
		t.Fatalf("complete=%v calls=%d", got.Complete, len(caller.calls))
	}
}

func TestDuplicatesAreCachedUntilTheyExpire(t *testing.T) {
	caller := &pagedCaller{pages: [][]map[string]any{{row("A", "a@olt.test", "")}}}
	clock := time.Unix(1_800_000_000, 0)
	s := &DuplicateScanner{Now: func() time.Time { return clock }}
	req := request([]string{View}, "CS-1", nil)
	for range 3 {
		if _, err := s.Compute(context.Background(), caller, req); err != nil {
			t.Fatal(err)
		}
	}
	if len(caller.calls) != 1 {
		t.Fatalf("cached scan must not call csAdmin again, got %d calls", len(caller.calls))
	}
	clock = clock.Add(duplicateCacheTTL + time.Second)
	if _, err := s.Compute(context.Background(), caller, req); err != nil {
		t.Fatal(err)
	}
	if len(caller.calls) != 2 {
		t.Fatalf("expired cache must rescan, got %d calls", len(caller.calls))
	}
}

func TestDuplicatesFailWhenCsAdminFails(t *testing.T) {
	s := &DuplicateScanner{}
	if _, err := s.Compute(context.Background(), &pagedCaller{status: http.StatusInternalServerError}, request([]string{View}, "CS-1", nil)); err == nil {
		t.Fatal("expected an error")
	}
}

func TestDuplicatesRouteIsReadOnlyForEveryReader(t *testing.T) {
	r := route("/online/duplicates")
	if r.Method != http.MethodGet || r.Compute == nil || r.Audit || len(r.Query) != 0 {
		t.Fatalf("unexpected route %+v", r)
	}
	if fmt.Sprint(r.Permissions) != fmt.Sprint(readers) {
		t.Fatalf("permissions %v", r.Permissions)
	}
}
