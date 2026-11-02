package access

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"olt-social/nasabah-gateway/internal/jwt"
)

func TestPostgRESTGrantUsesServiceRoleAndCSAPIProfile(t *testing.T) {
	var seen struct {
		path, profile, role string
		args                map[string]any
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen.path = r.URL.Path
		seen.profile = r.Header.Get("Content-Profile")
		claims, err := jwt.Verify(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "), []byte("secret"), time.Now())
		if err == nil {
			seen.role, _ = claims["role"].(string)
		}
		_ = json.NewDecoder(r.Body).Decode(&seen.args)
		_, _ = w.Write([]byte(`{"agent_id":"a1","agent_code":"CS-0045","display_name":"Nadia","permissions":["online_user.view"]}`))
	}))
	defer server.Close()

	grant, err := NewPostgREST(server.URL, []byte("secret"), "supabase").Grant(context.Background(), "a1")
	if err != nil {
		t.Fatal(err)
	}
	if grant == nil || grant.AgentCode != "CS-0045" || !grant.Allows([]string{"online_user.view"}) {
		t.Fatalf("grant = %+v", grant)
	}
	if seen.path != "/rpc/nasabah_access" || seen.profile != "cs_api" || seen.role != "service_role" || seen.args["p_user_id"] != "a1" {
		t.Fatalf("request = %+v", seen)
	}
}

func TestPostgRESTGrantTreatsNullOrEmptyPermissionsAsNoAccess(t *testing.T) {
	for _, reply := range []string{`null`, `{"agent_id":"a1","permissions":[]}`} {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			_, _ = w.Write([]byte(reply))
		}))
		grant, err := NewPostgREST(server.URL, []byte("secret"), "supabase").Grant(context.Background(), "a1")
		server.Close()
		if err != nil || grant != nil {
			t.Fatalf("%s: grant = %+v, err = %v", reply, grant, err)
		}
	}
}

func TestPostgRESTReadsIntegrationSettingsAndSuperAdmins(t *testing.T) {
	var paths []string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		paths = append(paths, r.URL.Path)
		var args map[string]any
		_ = json.NewDecoder(r.Body).Decode(&args)
		switch r.URL.Path {
		case "/rpc/nasabah_integration":
			_, _ = w.Write([]byte(`{"url":" http://10.0.0.5:9001/csAdmin ","client_id":"web-cs.prod"}`))
		case "/rpc/nasabah_is_super_admin":
			_, _ = w.Write([]byte(map[bool]string{true: "true", false: "false"}[args["p_user_id"] == "sinta"]))
		}
	}))
	defer server.Close()
	store := NewPostgREST(server.URL, []byte("secret"), "supabase")

	settings, err := store.Integration(context.Background())
	if err != nil || settings.URL != "http://10.0.0.5:9001/csAdmin" || settings.ClientID != "web-cs.prod" {
		t.Fatalf("settings = %+v, err = %v", settings, err)
	}
	sinta, _ := store.IsSuperAdmin(context.Background(), "sinta")
	nadia, _ := store.IsSuperAdmin(context.Background(), "nadia")
	if !sinta || nadia {
		t.Fatalf("super admin check: sinta %v nadia %v", sinta, nadia)
	}
	if strings.Join(paths, ",") != "/rpc/nasabah_integration,/rpc/nasabah_is_super_admin,/rpc/nasabah_is_super_admin" {
		t.Fatalf("paths = %v", paths)
	}
}

type countingStore struct {
	calls atomic.Int32
	grant *Grant
}

func (s *countingStore) Grant(context.Context, string) (*Grant, error) {
	s.calls.Add(1)
	return s.grant, nil
}

func (s *countingStore) Audit(context.Context, string, string, map[string]any) error { return nil }

func TestCacheReusesGrantsAndExpiresDenialsSooner(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	store := &countingStore{grant: &Grant{Permissions: []string{"online_user.view"}}}
	cache := NewCache(store, 30*time.Second)
	cache.now = func() time.Time { return now }

	_, _ = cache.Grant(context.Background(), "a1")
	_, _ = cache.Grant(context.Background(), "a1")
	if store.calls.Load() != 1 {
		t.Fatalf("calls = %d, want 1", store.calls.Load())
	}
	now = now.Add(31 * time.Second)
	_, _ = cache.Grant(context.Background(), "a1")
	if store.calls.Load() != 2 {
		t.Fatalf("calls after ttl = %d, want 2", store.calls.Load())
	}

	store.grant = nil
	_, _ = cache.Grant(context.Background(), "b2")
	now = now.Add(6 * time.Second)
	_, _ = cache.Grant(context.Background(), "b2")
	if store.calls.Load() != 4 {
		t.Fatalf("denials must expire after 5s, calls = %d", store.calls.Load())
	}
}
