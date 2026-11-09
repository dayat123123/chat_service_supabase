package olt

import (
	"encoding/json"
	"strings"
)

const (
	MaxAccounts      = 200
	maxAccountLength = 32
)

func ParseAccounts(raw json.RawMessage) *AccountClaim {
	trimmed := strings.TrimSpace(string(raw))
	if trimmed == "" || trimmed == "null" {
		return nil
	}
	var items []json.RawMessage
	if err := json.Unmarshal(raw, &items); err != nil {
		return &AccountClaim{Malformed: true}
	}
	claim := &AccountClaim{IDs: []string{}}
	seen := make(map[string]struct{}, len(items))
	for _, item := range items {
		var id string
		if err := json.Unmarshal(item, &id); err != nil || !validAccount(id) || len(claim.IDs) >= MaxAccounts {
			claim.Ignored++
			continue
		}
		key := strings.ToUpper(id)
		if _, dup := seen[key]; dup {
			claim.Ignored++
			continue
		}
		seen[key] = struct{}{}
		claim.IDs = append(claim.IDs, id)
	}
	return claim
}

func validAccount(id string) bool {
	if id == "" || len(id) > maxAccountLength {
		return false
	}
	for i := 0; i < len(id); i++ {
		c := id[i]
		switch {
		case c >= 'A' && c <= 'Z', c >= 'a' && c <= 'z', c >= '0' && c <= '9', c == '.', c == '_', c == '-':
		default:
			return false
		}
	}
	return true
}
