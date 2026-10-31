package routes

import (
	"context"
	"errors"
	"net/http"
	"net/url"
	"strings"
	"testing"

	"olt-social/nasabah-gateway/internal/access"
	"olt-social/nasabah-gateway/internal/gateway"
)

type write struct {
	method, path string
	query        url.Values
	body         any
}

type fakeCaller struct {
	replies map[string]string
	codes   map[string]int
	queries []url.Values
	writes  []write
	service string
}

func (f *fakeCaller) ServiceLoginID() string { return f.service }

func (f *fakeCaller) Do(_ context.Context, method, path string, query url.Values, body any) (int, []byte, error) {
	f.writes = append(f.writes, write{method: method, path: path, query: query, body: body})
	return f.status(path), []byte(`{"message":"ok","data":null}`), nil
}

func (f *fakeCaller) status(path string) int {
	if code, ok := f.codes[path]; ok {
		return code
	}
	return http.StatusOK
}

func (f *fakeCaller) Get(_ context.Context, path string, query url.Values) (int, []byte, error) {
	f.queries = append(f.queries, query)
	reply, ok := f.replies[path]
	if !ok {
		return http.StatusOK, []byte(`{"message": "No data available"}`), nil
	}
	return http.StatusOK, []byte(reply), nil
}

func request(perms []string, actor string, fields map[string]any) *gateway.Request {
	return &gateway.Request{Grant: &access.Grant{Permissions: perms}, Actor: actor, Fields: fields}
}

func rejection(t *testing.T, err error) string {
	t.Helper()
	var r *gateway.Rejection
	if !errors.As(err, &r) {
		t.Fatalf("expected rejection, got %v", err)
	}
	return r.Code
}

func route(path string) gateway.Route {
	for _, r := range Online {
		if r.Path == path {
			return r
		}
	}
	panic(path)
}

func TestOnlyStaffRoutesAreExposed(t *testing.T) {
	for _, r := range Online {
		if !strings.HasPrefix(r.Path, "/online/") && !strings.HasPrefix(r.Path, "/cs/") || len(r.Permissions) == 0 {
			t.Errorf("route %s %s must be an /online or /cs route with permissions", r.Method, r.Path)
		}
		if r.Query == nil {
			t.Errorf("route %s must declare its allowed query parameters", r.Path)
		}
		if r.Method != http.MethodGet && (len(r.ActorFields)+len(r.ActorQuery) == 0 || !r.Audit) {
			t.Errorf("write route %s must set the actor and be audited", r.Path)
		}
	}
	for _, blocked := range []string{"/online/send-email-opening-account",
		"/online/send-email-forget-password-and-pin-online-user", "/online/register-account-online-user",
		"/cs/login", "/cs/logout", "/cs/reset-password", "/cs/get-campaigns"} {
		for _, r := range Online {
			if r.Path == blocked {
				t.Errorf("%s must not be exposed", blocked)
			}
		}
	}
}

func TestQueryRulesRejectFilterInjection(t *testing.T) {
	cases := map[string]map[string]string{
		"/online/get-list-online-user":                    {"loginId": "a' OR '1'='1", "email": "x%' --"},
		"/online/get-list-approval-online-user":           {"status": "1; DROP", "createdBy": "x'"},
		"/online/get-approval-linked-account-online-user": {"approvalId": "1 OR 1=1"},
		"/online/get-list-opening-rekening-online-user":   {"custId": "C%"},
		"/cs/get-list-customer-service":                   {"loginId": "a'--", "size": "1000"},
		"/cs/get-customer-service-logs":                   {"logType": "1 OR 1=1", "csLoginId": "%"},
	}
	for path, params := range cases {
		rules := route(path).Query
		for key, value := range params {
			pattern, ok := rules[key]
			if !ok {
				t.Errorf("%s does not declare %s", path, key)
				continue
			}
			if pattern.MatchString(value) {
				t.Errorf("%s accepts %s=%q", path, key, value)
			}
		}
	}
	if !route("/cs/get-customer-service-logs").Query["logType"].MatchString("-1") ||
		!route("/online/get-list-online-user").Query["email"].MatchString("budi+1@olt.test") {
		t.Error("legitimate filters must stay accepted")
	}
}

func TestQuickStatusNeedsAReasonAndAnExistingUser(t *testing.T) {
	guard := route("/online/update-status-online-user").Guard
	users := &fakeCaller{replies: map[string]string{
		"/online/get-list-online-user": `{"data":[{"LoginId":"BUDI","Status":1}],"message":"ok"}`,
	}}
	req := request([]string{Status}, "CS-1", map[string]any{"LoginId": "budi", "Status": 3.0, "Reason": "  Laporan akses mencurigakan  "})
	if err := guard(context.Background(), users, req); err != nil {
		t.Fatal(err)
	}
	if req.Fields["LoginId"] != "BUDI" || req.Fields["Status"] != int64(3) || req.Fields["Reason"] != "Laporan akses mencurigakan" {
		t.Fatalf("fields = %v", req.Fields)
	}
	for name, fields := range map[string]map[string]any{
		"invalid_user_status":    {"LoginId": "budi", "Status": 4.0, "Reason": "Laporan akses mencurigakan"},
		"status_reason_required": {"LoginId": "budi", "Status": 1.0, "Reason": "singkat"},
		"customer_not_found":     {"LoginId": "ghost", "Status": 1.0, "Reason": "Laporan akses mencurigakan"},
	} {
		if code := rejection(t, guard(context.Background(), users, request([]string{Status}, "CS-1", fields))); code != name {
			t.Errorf("%s: got %s", name, code)
		}
	}
}

func TestCSAccountsAreValidatedAndTheServiceAccountIsLocked(t *testing.T) {
	create := route("/cs/create-customer-service-account").Guard
	update := route("/cs/update-customer-service-account").Guard
	caller := &fakeCaller{service: "gomi"}
	valid := func() map[string]any {
		return map[string]any{"LoginId": " sinta.w ", "EmployeeId": "E-01", "Email": "sinta@olt.test", "Permissions": 511.0,
			"Password": "Secret12", "Status": 2.0}
	}

	req := request([]string{CSManage}, "CS-1", valid())
	if err := create(context.Background(), caller, req); err != nil {
		t.Fatal(err)
	}
	if _, ok := req.Fields["Password"]; ok || req.Fields["Status"] != nil || req.Fields["LoginId"] != "sinta.w" {
		t.Fatalf("create must drop password/status and trim the login, got %v", req.Fields)
	}
	req = request([]string{CSManage}, "CS-1", valid())
	if err := update(context.Background(), caller, req); err != nil || req.Fields["Status"] != int64(2) {
		t.Fatalf("update: %v %v", err, req.Fields)
	}

	for code, mutate := range map[string]func(map[string]any){
		"invalid_login_id":       func(f map[string]any) { f["LoginId"] = "a'b" },
		"service_account_locked": func(f map[string]any) { f["LoginId"] = "GOMI" },
		"invalid_employee_id":    func(f map[string]any) { f["EmployeeId"] = " " },
		"invalid_email":          func(f map[string]any) { f["Email"] = "Sinta <sinta@olt.test>" },
		"invalid_permissions":    func(f map[string]any) { f["Permissions"] = 512.0 },
	} {
		fields := valid()
		mutate(fields)
		if got := rejection(t, update(context.Background(), caller, request([]string{CSManage}, "CS-1", fields))); got != code {
			t.Errorf("%s: got %s", code, got)
		}
	}
	fields := valid()
	fields["Status"] = 7.0
	if got := rejection(t, update(context.Background(), caller, request([]string{CSManage}, "CS-1", fields))); got != "invalid_user_status" {
		t.Errorf("status: got %s", got)
	}
}

func TestCSPasswordsFollowThePolicyAndSkipTheServiceAccount(t *testing.T) {
	guard := route("/cs/change-password-customer-service-account").Guard
	caller := &fakeCaller{service: "gomi"}
	if err := guard(context.Background(), caller, request([]string{CSManage}, "CS-1", map[string]any{"LoginId": "sinta", "Password": "Rahasia9"})); err != nil {
		t.Fatal(err)
	}
	for password, code := range map[string]string{"short": "weak_cs_password", "alllower99": "weak_cs_password", "Has Space1": "weak_cs_password",
		"Waytoolongpassword12345": "weak_cs_password"} {
		if got := rejection(t, guard(context.Background(), caller, request([]string{CSManage}, "CS-1", map[string]any{"LoginId": "sinta", "Password": password}))); got != code {
			t.Errorf("%q: got %s", password, got)
		}
	}
	if got := rejection(t, guard(context.Background(), caller, request([]string{CSManage}, "CS-1", map[string]any{"LoginId": "gomi", "Password": "Rahasia9"}))); got != "service_account_locked" {
		t.Errorf("service account: got %s", got)
	}
}

func TestCSDeleteNeedsALoginAndSkipsTheServiceAccount(t *testing.T) {
	guard := route("/cs/delete-customer-service-account").Guard
	caller := &fakeCaller{service: "gomi"}
	req := &gateway.Request{Grant: &access.Grant{Permissions: []string{CSManage}}, Actor: "CS-1", Query: url.Values{"loginId": {"sinta"}}}
	if err := guard(context.Background(), caller, req); err != nil {
		t.Fatal(err)
	}
	req.Query = url.Values{"loginId": {"Gomi"}}
	if got := rejection(t, guard(context.Background(), caller, req)); got != "service_account_locked" {
		t.Errorf("service account: got %s", got)
	}
	req.Query = url.Values{}
	if got := rejection(t, guard(context.Background(), caller, req)); got != "invalid_login_id" {
		t.Errorf("missing login: got %s", got)
	}
}

func TestNewCSAccountsReceiveARandomTemporaryPassword(t *testing.T) {
	after := route("/cs/create-customer-service-account").After
	caller := &fakeCaller{}
	req := request([]string{CSManage}, "CS-7", map[string]any{"LoginId": "sinta"})
	out, err := after(context.Background(), caller, req, []byte(`{"message":"Successfully created","data":{}}`))
	if err != nil {
		t.Fatal(err)
	}
	if len(caller.writes) != 1 || caller.writes[0].method != http.MethodPut || caller.writes[0].path != "/cs/change-password-customer-service-account" {
		t.Fatalf("writes = %+v", caller.writes)
	}
	body := caller.writes[0].body.(map[string]any)
	password, _ := body["Password"].(string)
	if body["LoginId"] != "sinta" || body["ModifiedBy"] != "CS-7" || !strongPassword(password) {
		t.Fatalf("password change body = %v", body)
	}
	if !strings.Contains(string(out), `"TemporaryPassword":"`+password+`"`) || !strings.Contains(string(out), "Successfully created") {
		t.Fatalf("response = %s", out)
	}

	failing := &fakeCaller{codes: map[string]int{"/cs/change-password-customer-service-account": http.StatusInternalServerError}}
	out, err = after(context.Background(), failing, req, []byte(`{"message":"Successfully created","data":{}}`))
	if err == nil || !strings.Contains(string(out), `"TemporaryPasswordError":true`) || strings.Contains(string(out), "TemporaryPassword\":\"") {
		t.Fatalf("failed follow-up: %v %s", err, out)
	}
}

func TestGeneratedPasswordsAreStrongAndUnique(t *testing.T) {
	seen := map[string]bool{}
	for range 200 {
		p, err := GeneratePassword()
		if err != nil {
			t.Fatal(err)
		}
		if !strongPassword(p) || len(p) != 14 || strings.ContainsAny(p, "0O1lI") || seen[p] {
			t.Fatalf("weak or repeated password %q", p)
		}
		seen[p] = true
	}
}

func TestDemoOnlyAccountsManageDemoLoginsOnly(t *testing.T) {
	guard := route("/online/create-approval-login").Guard
	users := &fakeCaller{replies: map[string]string{
		"/online/get-list-online-user": `{"data":[{"LoginId":"demo01","LoginType":0},{"LoginId":"budi","LoginType":1}],"message":"ok","pagination":{}}`,
	}}
	demo := []string{Demo}

	if err := guard(context.Background(), users, request(demo, "CS-1", map[string]any{"LoginId": "new01", "LoginType": 0.0, "ActionType": 1.0})); err != nil {
		t.Fatalf("creating a demo login: %v", err)
	}
	if code := rejection(t, guard(context.Background(), users, request(demo, "CS-1", map[string]any{"LoginId": "x", "LoginType": 1.0, "ActionType": 1.0}))); code != "demo_only" {
		t.Errorf("client login type: %s", code)
	}
	if code := rejection(t, guard(context.Background(), users, request(demo, "CS-1", map[string]any{"LoginId": "demo01", "LoginType": 0.0, "ActionType": 2.0, "ArrayAccountLink": []any{"C1"}}))); code != "demo_only" {
		t.Errorf("linking accounts: %s", code)
	}
	if err := guard(context.Background(), users, request(demo, "CS-1", map[string]any{"LoginId": "demo01", "LoginType": 0.0, "ActionType": 3.0})); err != nil {
		t.Errorf("deleting an existing demo login: %v", err)
	}
	if code := rejection(t, guard(context.Background(), users, request(demo, "CS-1", map[string]any{"LoginId": "budi", "LoginType": 0.0, "ActionType": 2.0}))); code != "demo_only" {
		t.Errorf("relabelling a client login as demo: %s", code)
	}
	if err := guard(context.Background(), users, request([]string{Manage}, "CS-1", map[string]any{"LoginId": "budi", "LoginType": 1.0, "ActionType": 2.0, "ArrayAccountLink": []any{"C1"}})); err != nil {
		t.Errorf("full managers are not limited: %v", err)
	}
}

func TestCredentialResetsAlwaysMailTheStoredAddress(t *testing.T) {
	guard := route("/online/change-password-and-pin-online-user").Guard
	users := &fakeCaller{replies: map[string]string{
		"/online/get-list-online-user": `{"data":[{"LoginId":"budi2","Email":"x@olt.test"},{"LoginId":"BUDI","Email":" budi@olt.test "},{"LoginId":"noemail","Email":""}],"message":"ok"}`,
	}}
	req := request([]string{Manage}, "CS-1", map[string]any{"LoginId": "budi", "ActionType": 0.0, "Email": "attacker@evil.test"})
	if err := guard(context.Background(), users, req); err != nil {
		t.Fatal(err)
	}
	if req.Fields["Email"] != "budi@olt.test" || req.Fields["LoginId"] != "BUDI" {
		t.Fatalf("fields = %v", req.Fields)
	}
	if users.queries[0].Get("loginId") != "budi" || users.queries[0].Has("email") {
		t.Fatalf("lookup must filter by loginId only, got %v", users.queries[0])
	}
	if code := rejection(t, guard(context.Background(), users, request([]string{Manage}, "CS-1", map[string]any{"LoginId": "noemail", "ActionType": 1.0}))); code != "customer_email_missing" {
		t.Errorf("missing email: %s", code)
	}
	if code := rejection(t, guard(context.Background(), users, request([]string{Manage}, "CS-1", map[string]any{"LoginId": "ghost", "ActionType": 1.0}))); code != "customer_not_found" {
		t.Errorf("unknown user: %s", code)
	}
}

func TestApprovalDecisionsUseThePendingApprovalAndForbidSelfApproval(t *testing.T) {
	guard := route("/online/approve-approval-login").Guard
	approvals := &fakeCaller{replies: map[string]string{
		"/online/get-list-approval-online-user": `{"data":[{"ApprovalId":41,"LoginId":"budi","ActionType":1,"Email":"budi@olt.test","CreatedBy":"CS-0045"},{"ApprovalId":42,"LoginId":"budi.s","ActionType":2,"Email":"s@olt.test","CreatedBy":"CS-0046"}],"message":"ok"}`,
	}}
	req := request([]string{Approve}, "CS-0045", map[string]any{"ApprovalId": 42.0, "LoginId": "budi", "Status": 2.0, "ActionType": 1.0})
	if err := guard(context.Background(), approvals, req); err != nil {
		t.Fatal(err)
	}
	if req.Fields["LoginId"] != "budi.s" || req.Fields["ActionType"] != int64(2) || req.Fields["Email"] != "s@olt.test" {
		t.Fatalf("decision must use the stored approval, got %v", req.Fields)
	}
	q := approvals.queries[0]
	if q.Get("status") != "1" || q.Get("actionType") != "-1" || q.Get("loginId") != "budi" {
		t.Fatalf("lookup query = %v", q)
	}
	if code := rejection(t, guard(context.Background(), approvals, request([]string{Approve}, "cs-0045", map[string]any{"ApprovalId": 41.0, "LoginId": "budi", "Status": 0.0}))); code != "self_approval" {
		t.Errorf("self approval: %s", code)
	}
	if code := rejection(t, guard(context.Background(), approvals, request([]string{Approve}, "CS-9", map[string]any{"ApprovalId": 99.0, "LoginId": "budi", "Status": 2.0}))); code != "approval_not_found" {
		t.Errorf("unknown approval: %s", code)
	}
	if code := rejection(t, guard(context.Background(), approvals, request([]string{Approve}, "CS-9", map[string]any{"ApprovalId": 41.0, "LoginId": "budi", "Status": 1.0}))); code != "invalid_decision" {
		t.Errorf("invalid status: %s", code)
	}
}

func TestOpeningEmailsRequireAnExistingLoginAccountPair(t *testing.T) {
	guard := route("/online/send-email-opening-account-with-rekening").Guard
	openings := &fakeCaller{replies: map[string]string{
		"/online/get-list-opening-rekening-online-user": `{"data":[{"LoginId":"budi","CustId":"C001  "}],"message":"ok"}`,
	}}
	req := request([]string{Opening}, "CS-1", map[string]any{"LoginId": "budi", "CustId": "C001"})
	if err := guard(context.Background(), openings, req); err != nil {
		t.Fatal(err)
	}
	if code := rejection(t, guard(context.Background(), openings, request([]string{Opening}, "CS-1", map[string]any{"LoginId": "budi", "CustId": "C999"}))); code != "opening_account_not_found" {
		t.Errorf("unknown pair: %s", code)
	}
	if code := rejection(t, guard(context.Background(), &fakeCaller{}, request([]string{Opening}, "CS-1", map[string]any{"LoginId": "budi", "CustId": "C001"}))); code != "opening_account_not_found" {
		t.Errorf("empty upstream list: %s", code)
	}
}
