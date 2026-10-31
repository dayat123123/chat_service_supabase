package routes

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"

	"olt-social/nasabah-gateway/internal/gateway"
)

const (
	View       = "online_user.view"
	Manage     = "online_user.manage"
	Demo       = "online_user.demo"
	Approve    = "online_user.approve"
	ApproveOwn = "online_user.approve_own"
	Status     = "online_user.status"
	Opening    = "opening_account.send"
)

const demoLoginType = 0

var (
	pageRe  = regexp.MustCompile(`^[1-9][0-9]{0,5}$`)
	sizeRe  = regexp.MustCompile(`^([1-9]|[1-9][0-9]|100)$`)
	idRe    = regexp.MustCompile(`^[A-Za-z0-9._@-]{1,50}$`)
	emailRe = regexp.MustCompile(`^[A-Za-z0-9._@+-]{1,100}$`)
	smallRe = regexp.MustCompile(`^-?[0-9]{1,2}$`)
	numRe   = regexp.MustCompile(`^[0-9]{1,18}$`)
)

type query = map[string]*regexp.Regexp

var paging = query{"page": pageRe, "size": sizeRe}

func with(base query, extra query) query {
	out := query{}
	for k, v := range base {
		out[k] = v
	}
	for k, v := range extra {
		out[k] = v
	}
	return out
}

var readers = []string{View, Manage, Demo, Approve, ApproveOwn, Status}

var Online = []gateway.Route{
	{Method: http.MethodGet, Path: "/online/get-list-online-user", Action: "online_user.list", Permissions: readers,
		Query: with(paging, query{"loginId": idRe, "email": emailRe})},
	{Method: http.MethodGet, Path: "/online/get-linked-account-online-user", Action: "online_user.linked_accounts",
		Permissions: readers, Query: query{"loginId": idRe}, SubjectFields: []string{"loginId"}, Audit: true},
	{Method: http.MethodGet, Path: "/online/get-list-link-account", Action: "account.catalog", Permissions: []string{Manage},
		Query: query{}},
	{Method: http.MethodPost, Path: "/online/create-approval-login", Action: "approval.create",
		Permissions: []string{Manage, Demo}, Query: query{}, ActorFields: []string{"CreatedBy"},
		SubjectFields: []string{"LoginId", "ActionType", "LoginType"}, Guard: demoScope, Audit: true},
	{Method: http.MethodPost, Path: "/online/change-password-and-pin-online-user", Action: "online_user.reset_credential",
		Permissions: []string{Manage}, Query: query{}, ActorFields: []string{"ModifiedBy"},
		SubjectFields: []string{"LoginId", "ActionType"}, Guard: customerEmail, Audit: true},
	{Method: http.MethodPut, Path: "/online/update-status-online-user", Action: "online_user.status",
		Permissions: []string{Status}, Query: query{}, ActorFields: []string{"ModifiedBy"},
		SubjectFields: []string{"LoginId", "Status", "Reason"}, Guard: quickStatus, Audit: true},
	{Method: http.MethodGet, Path: "/online/get-list-approval-online-user", Action: "approval.list",
		Permissions: []string{Approve, ApproveOwn, Manage, Demo},
		Query:       with(paging, query{"status": smallRe, "actionType": smallRe, "loginId": idRe, "createdBy": idRe})},
	{Method: http.MethodGet, Path: "/online/get-approval-linked-account-online-user", Action: "approval.linked_accounts",
		Permissions: []string{Approve, ApproveOwn, Manage, Demo}, Query: query{"approvalId": numRe}},
	{Method: http.MethodPost, Path: "/online/approve-approval-login", Action: "approval.decide",
		Permissions: []string{Approve, ApproveOwn}, Query: query{}, ActorFields: []string{"ApprovedBy"},
		SubjectFields: []string{"ApprovalId", "LoginId", "Status"}, Guard: approvalDecision, Audit: true},
	{Method: http.MethodGet, Path: "/online/get-list-opening-rekening-online-user", Action: "opening_account.list",
		Permissions: []string{Opening}, Query: with(paging, query{"loginId": idRe, "custId": idRe})},
	{Method: http.MethodPost, Path: "/online/send-email-opening-account-with-rekening", Action: "opening_account.send_email",
		Permissions: []string{Opening}, Query: query{}, ActorFields: []string{"CSLoginId"},
		SubjectFields: []string{"LoginId", "CustId"}, Guard: openingPair, Audit: true},
}

func reject(status int, code, message string) error {
	return &gateway.Rejection{Status: status, Code: code, Message: message}
}

func demoScope(ctx context.Context, call gateway.Caller, req *gateway.Request) error {
	if req.Grant.Allows([]string{Manage}) {
		return nil
	}
	if number(req.Fields["LoginType"]) != demoLoginType {
		return reject(http.StatusForbidden, "demo_only", "This account may only manage demo logins")
	}
	if len(list(req.Fields["ArrayAccountLink"])) > 0 || len(list(req.Fields["ArrayAccountUnLink"])) > 0 {
		return reject(http.StatusForbidden, "demo_only", "Demo logins cannot be linked to customer accounts")
	}
	if number(req.Fields["ActionType"]) == 1 {
		return nil
	}
	user, err := findOnlineUser(ctx, call, text(req.Fields["LoginId"]))
	if err != nil {
		return err
	}
	if user == nil {
		return reject(http.StatusNotFound, "customer_not_found", "Online user was not found")
	}
	if number(user["LoginType"]) != demoLoginType {
		return reject(http.StatusForbidden, "demo_only", "This account may only manage demo logins")
	}
	return nil
}

func customerEmail(ctx context.Context, call gateway.Caller, req *gateway.Request) error {
	user, err := findOnlineUser(ctx, call, text(req.Fields["LoginId"]))
	if err != nil {
		return err
	}
	if user == nil {
		return reject(http.StatusNotFound, "customer_not_found", "Online user was not found")
	}
	email := strings.TrimSpace(text(user["Email"]))
	if email == "" {
		return reject(http.StatusConflict, "customer_email_missing", "Online user has no email address to receive the new credential")
	}
	req.Fields["LoginId"] = text(user["LoginId"])
	req.Fields["Email"] = email
	return nil
}

func quickStatus(ctx context.Context, call gateway.Caller, req *gateway.Request) error {
	status := number(req.Fields["Status"])
	if status < 0 || status > 3 {
		return reject(http.StatusBadRequest, "invalid_user_status", "Status must be 0, 1, 2 or 3")
	}
	reason := strings.TrimSpace(text(req.Fields["Reason"]))
	if n := len([]rune(reason)); n < 10 || n > 200 {
		return reject(http.StatusBadRequest, "status_reason_required", "A reason of 10-200 characters is required")
	}
	user, err := findOnlineUser(ctx, call, text(req.Fields["LoginId"]))
	if err != nil {
		return err
	}
	if user == nil {
		return reject(http.StatusNotFound, "customer_not_found", "Online user was not found")
	}
	req.Fields["LoginId"] = text(user["LoginId"])
	req.Fields["Status"] = status
	req.Fields["Reason"] = reason
	return nil
}

func approvalDecision(ctx context.Context, call gateway.Caller, req *gateway.Request) error {
	status := number(req.Fields["Status"])
	if status != 0 && status != 2 {
		return reject(http.StatusBadRequest, "invalid_decision", "Status must be 2 (approve) or 0 (reject)")
	}
	id := number(req.Fields["ApprovalId"])
	loginID := text(req.Fields["LoginId"])
	if id <= 0 || !idRe.MatchString(loginID) {
		return reject(http.StatusBadRequest, "invalid_approval", "ApprovalId and LoginId are required")
	}
	rows, err := lookup(ctx, call, "/online/get-list-approval-online-user", url.Values{
		"page": {"1"}, "size": {"100"}, "loginId": {loginID}, "status": {"1"}, "actionType": {"-1"},
	})
	if err != nil {
		return err
	}
	for _, row := range rows {
		if number(row["ApprovalId"]) != id {
			continue
		}
		own := strings.EqualFold(strings.TrimSpace(text(row["CreatedBy"])), req.Actor)
		if own && !req.Grant.Allows([]string{ApproveOwn}) {
			return reject(http.StatusForbidden, "self_approval", "The submitter of an approval cannot decide it")
		}
		if !own && !req.Grant.Allows([]string{Approve}) {
			return reject(http.StatusForbidden, "permission_denied", "This account may only decide its own submissions")
		}
		req.Fields["LoginId"] = text(row["LoginId"])
		req.Fields["ActionType"] = number(row["ActionType"])
		req.Fields["Email"] = text(row["Email"])
		req.Fields["ApprovalId"] = id
		req.Fields["Status"] = status
		return nil
	}
	return reject(http.StatusNotFound, "approval_not_found", "Approval is not pending for this online user")
}

func openingPair(ctx context.Context, call gateway.Caller, req *gateway.Request) error {
	loginID, custID := text(req.Fields["LoginId"]), text(req.Fields["CustId"])
	if !idRe.MatchString(loginID) || !idRe.MatchString(custID) {
		return reject(http.StatusBadRequest, "invalid_opening", "LoginId and CustId are required")
	}
	rows, err := lookup(ctx, call, "/online/get-list-opening-rekening-online-user", url.Values{
		"page": {"1"}, "size": {"100"}, "loginId": {loginID}, "custId": {custID},
	})
	if err != nil {
		return err
	}
	for _, row := range rows {
		if strings.EqualFold(strings.TrimSpace(text(row["LoginId"])), loginID) && strings.TrimSpace(text(row["CustId"])) == custID {
			req.Fields["LoginId"] = strings.TrimSpace(text(row["LoginId"]))
			req.Fields["CustId"] = custID
			return nil
		}
	}
	return reject(http.StatusNotFound, "opening_account_not_found", "This account is not linked to the online user")
}

func findOnlineUser(ctx context.Context, call gateway.Caller, loginID string) (map[string]any, error) {
	loginID = strings.TrimSpace(loginID)
	if !idRe.MatchString(loginID) {
		return nil, reject(http.StatusBadRequest, "invalid_login_id", "LoginId is required")
	}
	rows, err := lookup(ctx, call, "/online/get-list-online-user", url.Values{"page": {"1"}, "size": {"100"}, "loginId": {loginID}})
	if err != nil {
		return nil, err
	}
	for _, row := range rows {
		if strings.EqualFold(strings.TrimSpace(text(row["LoginId"])), loginID) {
			return row, nil
		}
	}
	return nil, nil
}

func lookup(ctx context.Context, call gateway.Caller, path string, query url.Values) ([]map[string]any, error) {
	status, payload, err := call.Get(ctx, path, query)
	if err != nil {
		return nil, err
	}
	if status != http.StatusOK {
		return nil, fmt.Errorf("lookup %s: status %d", path, status)
	}
	var envelope struct {
		Data []map[string]any `json:"data"`
	}
	if err := json.Unmarshal(payload, &envelope); err != nil {
		return nil, fmt.Errorf("lookup %s: %w", path, err)
	}
	return envelope.Data, nil
}

func text(v any) string {
	switch s := v.(type) {
	case string:
		return s
	case float64:
		return strconv.FormatFloat(s, 'f', -1, 64)
	}
	return ""
}

func number(v any) int64 {
	switch n := v.(type) {
	case float64:
		return int64(n)
	case int64:
		return n
	case string:
		i, err := strconv.ParseInt(strings.TrimSpace(n), 10, 64)
		if err == nil {
			return i
		}
	}
	return -1
}

func list(v any) []any {
	items, _ := v.([]any)
	return items
}
