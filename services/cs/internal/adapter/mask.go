package adapter

import (
	"encoding/json"
	"strings"
	"unicode/utf8"
)

var profileMasks = map[string]func(string) string{
	"nik":         keepEdges(4, 4),
	"phone":       keepEdges(4, 3),
	"client_code": keepEdges(0, 4),
	"sid":         keepEdges(3, 3),
	"email":       maskEmail,
	"address":     maskAddress,
	"birth_date":  maskBirthDate,
}

var accountFields = []string{"rdn", "withdrawal_account"}

func maskProfile(raw json.RawMessage) (any, error) {
	var profile map[string]any
	if err := json.Unmarshal(raw, &profile); err != nil {
		return nil, err
	}
	for field, mask := range profileMasks {
		if v, ok := profile[field].(string); ok {
			profile[field] = mask(v)
		}
	}
	for _, field := range accountFields {
		if account, ok := profile[field].(map[string]any); ok {
			if number, ok := account["number"].(string); ok {
				account["number"] = keepEdges(0, 4)(number)
			}
		}
	}
	return profile, nil
}

func maskSessions(raw json.RawMessage) (any, error) {
	var data map[string]any
	if err := json.Unmarshal(raw, &data); err != nil {
		return nil, err
	}
	for _, key := range []string{"sessions", "logins"} {
		items, _ := data[key].([]any)
		for _, item := range items {
			if entry, ok := item.(map[string]any); ok {
				if ip, ok := entry["ip"].(string); ok {
					entry["ip"] = maskIP(ip)
				}
			}
		}
	}
	return data, nil
}

func passthrough(raw json.RawMessage) (any, error) {
	return raw, nil
}

func keepEdges(head, tail int) func(string) string {
	return func(v string) string {
		if v == "" || strings.Contains(v, "*") {
			return v
		}
		runes := []rune(v)
		if len(runes) <= head+tail {
			return strings.Repeat("*", len(runes))
		}
		return string(runes[:head]) + strings.Repeat("*", len(runes)-head-tail) + string(runes[len(runes)-tail:])
	}
}

func maskEmail(v string) string {
	at := strings.LastIndex(v, "@")
	if at <= 0 || strings.Contains(v, "*") {
		return keepEdges(0, 0)(v)
	}
	local := v[:at]
	visible := min(2, utf8.RuneCountInString(local)-1)
	return string([]rune(local)[:max(visible, 0)]) + "***" + v[at:]
}

func maskAddress(v string) string {
	if v == "" || strings.Contains(v, "*") {
		return v
	}
	if i := strings.LastIndex(v, ","); i >= 0 && i < len(v)-1 {
		return "***," + v[i+1:]
	}
	return "***"
}

func maskBirthDate(v string) string {
	if len(v) >= 4 && !strings.Contains(v, "*") {
		return v[:4] + "-**-**"
	}
	return v
}

func maskIP(v string) string {
	if strings.Contains(v, "*") {
		return v
	}
	if parts := strings.Split(v, "."); len(parts) == 4 {
		return parts[0] + "." + parts[1] + ".***.***"
	}
	if i := strings.Index(v, ":"); i > 0 {
		return v[:i] + ":****"
	}
	return "***"
}
