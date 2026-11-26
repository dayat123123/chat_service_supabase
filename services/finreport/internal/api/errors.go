package api

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
	codeUnsupportedType     = "unsupported_media_type"
	codeEmptyBody           = "empty_body"
	codeBodyTooLarge        = "body_too_large"
	codeNotZip              = "not_zip"
	codeZipUnsafe           = "zip_unsafe"
	codeNoInstance          = "no_instance"
	codeInvalidID           = "invalid_id"
	codeBusy                = "busy"
	codeUnavailable         = "unavailable"
	codeCanceled            = "canceled"
	codeInternal            = "internal_error"
)

var messages = map[string]string{
	codeNotFound:            "Alamat tidak ditemukan.",
	codeMissingKey:          "Header Authorization: Bearer <API key integrasi> wajib diisi.",
	codeInvalidKey:          "API key integrasi tidak dikenal, nonaktif, atau sudah dicabut.",
	codeIPNotAllowed:        "Alamat IP pengirim tidak diizinkan untuk API key ini.",
	codeScopeForbidden:      "API key ini tidak punya izin Kirim laporan keuangan.",
	codeRateLimited:         "Batas request per menit untuk API key ini terlampaui. Coba lagi setelah Retry-After.",
	codeTooManyAuthFailures: "Terlalu banyak percobaan dengan API key yang salah dari alamat ini. Coba lagi nanti.",
	codeUnsupportedType:     "Kirim file instance.zip apa adanya dengan Content-Type: application/zip.",
	codeEmptyBody:           "Body kosong. Kirim isi file instance.zip.",
	codeBodyTooLarge:        "File melebihi batas ukuran 8 MiB.",
	codeNotZip:              "File bukan zip yang valid.",
	codeZipUnsafe:           "Isi zip melebihi batas keamanan (jumlah file, ukuran, atau rasio kompresi).",
	codeNoInstance:          "Zip tidak berisi file .xbrl (instance.xbrl dari IDX).",
	codeInvalidID:           "Id file laporan tidak valid.",
	codeBusy:                "Server sedang sibuk menerima file lain. Coba lagi setelah Retry-After.",
	codeUnavailable:         "Penyimpanan atau database sedang tidak bisa dihubungi. Coba lagi setelah Retry-After.",
	codeInternal:            "Terjadi kesalahan di server. Kirim ulang file yang sama.",
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
