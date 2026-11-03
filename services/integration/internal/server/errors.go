package server

import (
	"encoding/json"
	"net/http"
)

const (
	codeNotFound            = "not_found"
	codeMethodNotAllowed    = "method_not_allowed"
	codeMissingKey          = "missing_key"
	codeInvalidKey          = "invalid_key"
	codeIPNotAllowed        = "ip_not_allowed"
	codeScopeForbidden      = "scope_forbidden"
	codeRateLimited         = "rate_limited"
	codeTooManyAuthFailures = "too_many_auth_failures"
	codeInvalidJSON         = "invalid_json"
	codeInvalidBatch        = "invalid_batch"
	codeBodyTooLarge        = "body_too_large"
	codeBusy                = "busy"
	codeUnavailable         = "unavailable"
	codeCanceled            = "canceled"
	codeInternal            = "internal_error"
)

var messages = map[string]string{
	codeNotFound:            "Alamat tidak ditemukan.",
	codeMethodNotAllowed:    "Gunakan metode POST.",
	codeMissingKey:          "Header Authorization: Bearer <API key integrasi> wajib diisi.",
	codeInvalidKey:          "API key integrasi tidak dikenal, nonaktif, atau sudah dicabut.",
	codeIPNotAllowed:        "Alamat IP pengirim tidak diizinkan untuk API key ini.",
	codeScopeForbidden:      "API key ini tidak punya izin untuk endpoint ini.",
	codeRateLimited:         "Batas request per menit untuk API key ini terlampaui. Coba lagi setelah Retry-After.",
	codeTooManyAuthFailures: "Terlalu banyak percobaan dengan API key yang salah dari alamat ini. Coba lagi nanti.",
	codeInvalidJSON:         "Body harus satu objek JSON yang valid.",
	codeInvalidBatch:        "Body harus memuat array messages (1–500 pesan) atau posts (1–50 postingan).",
	codeBodyTooLarge:        "Ukuran body melebihi batas. Pecah menjadi beberapa batch.",
	codeBusy:                "Server sedang sibuk. Coba lagi setelah Retry-After.",
	codeUnavailable:         "Database sedang tidak bisa dihubungi. Kirim ulang batch yang sama setelah Retry-After.",
	codeInternal:            "Terjadi kesalahan di server. Kirim ulang batch yang sama.",
}

func writeError(w http.ResponseWriter, status int, code, detail string) {
	message := detail
	if message == "" {
		message = messages[code]
	}
	if message == "" {
		message = code
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": code, "message": message})
}
