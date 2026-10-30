package server

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"olt-social/dummy-olt/internal/customers"
)

type customerPayload struct {
	UserID         string   `json:"user_id"`
	CorrelationID  string   `json:"correlation_id"`
	Field          string   `json:"field"`
	OrderID        string   `json:"order_id"`
	TransactionID  string   `json:"transaction_id"`
	From           string   `json:"from"`
	To             string   `json:"to"`
	Status         []string `json:"status"`
	Code           string   `json:"code"`
	Cursor         string   `json:"cursor"`
	Limit          int      `json:"limit"`
	Actions        []string `json:"actions"`
	IdempotencyKey string   `json:"idempotency_key"`
}

var errNotFound = errors.New("data tidak ditemukan")

func (s *Server) customerRequest(ctx context.Context, req request, authorized bool) message {
	kind := req.Type + "_result"
	fail := func(code, msg string) message {
		return message{Type: kind, RequestID: req.RequestID, Status: "ERROR", Error: &apiError{code, msg}}
	}
	if !authorized {
		s.log.Info("permintaan data nasabah ditolak", "type", req.Type, "code", CodeUnauthorized)
		return fail(CodeUnauthorized, "Kredensial layanan tidak valid")
	}
	var p customerPayload
	if len(req.Payload) == 0 || json.Unmarshal(req.Payload, &p) != nil || p.UserID == "" {
		return fail(CodeInvalidRequest, "payload wajib berisi user_id")
	}
	if u, ok := s.users.Find(p.UserID); ok && u.SlowLogin {
		select {
		case <-time.After(s.cfg.SlowDelay):
		case <-ctx.Done():
			return fail(CodeInvalidRequest, "koneksi ditutup")
		}
	}
	data, err := s.customerData(req.Type, p)
	switch {
	case errors.Is(err, errNotFound):
		return fail(CodeNotFound, "Data tidak ditemukan")
	case err != nil:
		return fail(CodeInvalidRequest, err.Error())
	}
	s.log.Info("permintaan data nasabah", "type", req.Type, "user_id", p.UserID, "correlation_id", p.CorrelationID)
	return message{Type: kind, RequestID: req.RequestID, Status: "OK", Data: data}
}

func (s *Server) customerData(kind string, p customerPayload) (any, error) {
	store := s.customers
	switch kind {
	case "customer_profile":
		return found(store.Profile(p.UserID))
	case "customer_reveal":
		if _, ok := store.Profile(p.UserID); !ok {
			return nil, errNotFound
		}
		value, ok := store.Reveal(p.UserID, p.Field)
		if !ok {
			return nil, errors.New("field tidak bisa dibuka")
		}
		return map[string]string{"field": p.Field, "value": value}, nil
	case "customer_orders":
		f, err := filter(p)
		if err != nil {
			return nil, err
		}
		orders, next, ok := store.Orders(p.UserID, f)
		if !ok {
			return nil, errNotFound
		}
		return map[string]any{"orders": orders, "next_cursor": nullable(next)}, nil
	case "customer_order":
		return found(store.Order(p.UserID, p.OrderID))
	case "customer_cash_transactions":
		f, err := filter(p)
		if err != nil {
			return nil, err
		}
		txs, next, ok := store.CashTransactions(p.UserID, f)
		if !ok {
			return nil, errNotFound
		}
		return map[string]any{"transactions": txs, "next_cursor": nullable(next)}, nil
	case "customer_cash_transaction":
		return found(store.CashTransaction(p.UserID, p.TransactionID))
	case "customer_portfolio":
		return found(store.Portfolio(p.UserID))
	case "customer_sessions":
		sessions, logins, ok := store.Sessions(p.UserID)
		if !ok {
			return nil, errNotFound
		}
		return map[string]any{"sessions": sessions, "logins": logins}, nil
	case "customer_security":
		return found(store.Security(p.UserID))
	case "secure_account":
		if len(p.Actions) == 0 {
			return nil, errors.New("actions wajib diisi")
		}
		results, ok := store.SecureAccount(p.UserID, p.Actions, p.IdempotencyKey)
		if !ok {
			return nil, errNotFound
		}
		return map[string]any{"results": results}, nil
	}
	return nil, errors.New("type tidak dikenal")
}

func found[T any](v T, ok bool) (any, error) {
	if !ok {
		return nil, errNotFound
	}
	return v, nil
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func filter(p customerPayload) (customers.Filter, error) {
	f := customers.Filter{Statuses: p.Status, Code: p.Code, Cursor: p.Cursor, Limit: p.Limit}
	for _, v := range []struct {
		raw  string
		dest *time.Time
	}{{p.From, &f.From}, {p.To, &f.To}} {
		if v.raw == "" {
			continue
		}
		t, err := time.Parse(time.RFC3339, v.raw)
		if err != nil {
			return f, errors.New("from/to harus RFC 3339")
		}
		*v.dest = t
	}
	return f, nil
}

func (s *Server) handleDevCustomer(w http.ResponseWriter, r *http.Request) {
	u, ok := s.users.Find(r.PathValue("user"))
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]any{"error": apiError{CodeNotFound, "user tidak dikenal"}})
		return
	}
	userID := strconv.FormatInt(u.ID, 10)
	orders, _, _ := s.customers.Orders(userID, customers.Filter{Limit: 50})
	txs, _, _ := s.customers.CashTransactions(userID, customers.Filter{Limit: 50})
	security, _ := s.customers.Security(userID)
	writeJSON(w, http.StatusOK, map[string]any{
		"user_id": userID, "username": u.Username,
		"orders": orders, "cash_transactions": txs, "security": security,
	})
}
