package server

import (
	"errors"
	"fmt"
	"net/http"

	"olt-social/media/internal/sanitize"
	"olt-social/media/internal/storage"
)

const (
	codeInvalidToken     = "invalid_token"
	codeBucketNotAllowed = "bucket_not_allowed"
	codeInvalidPath      = "invalid_path"
	codeEmptyFile        = "empty_file"
	codeFileTooLarge     = "file_too_large"
	codeUnsupportedType  = "unsupported_type"
	codeInvalidImage     = "invalid_image"
	codeImageTooLarge    = "image_too_large"
	codeInvalidPDF       = "invalid_pdf"
	codePDFEncrypted     = "pdf_encrypted"
	codePDFActiveContent = "pdf_active_content"
	codeBusy             = "busy"
	codeNotFound         = "not_found"
	codeRequestTimeout   = "request_timeout"
	codeInvalidRequest   = "invalid_request"
	codeInternal         = "internal_error"
	codeCanceled         = "canceled"

	framesMessage = "Animasi GIF maksimal 500 frame."
)

var messages = map[string]string{
	codeInvalidToken:        "Sesi tidak valid atau sudah kedaluwarsa. Silakan masuk ulang.",
	codeBucketNotAllowed:    "Tujuan upload tidak diizinkan.",
	codeInvalidPath:         "Nama atau lokasi file tidak valid.",
	codeEmptyFile:           "File kosong.",
	codeFileTooLarge:        "Ukuran file melebihi batas.",
	codeUnsupportedType:     "Jenis file tidak didukung untuk tujuan ini.",
	codeInvalidImage:        "Gambar rusak atau tidak bisa dibaca.",
	codeImageTooLarge:       "Dimensi gambar terlalu besar (maksimal 10000 piksel per sisi dan 40 megapiksel).",
	codeInvalidPDF:          "PDF rusak atau tidak bisa dibaca.",
	codePDFEncrypted:        "PDF terkunci atau terenkripsi tidak bisa diterima. Simpan ulang tanpa kata sandi.",
	codePDFActiveContent:    "PDF berisi konten aktif (JavaScript, lampiran, atau multimedia) dan tidak bisa diterima.",
	storage.CodeForbidden:   "Anda tidak diizinkan mengunggah file ke lokasi ini.",
	storage.CodeExists:      "File dengan nama yang sama sudah ada.",
	storage.CodeTooMany:     "Batas upload harian sudah tercapai. Coba lagi nanti.",
	storage.CodeError:       "Penyimpanan menolak file. Coba lagi nanti.",
	storage.CodeUnavailable: "Penyimpanan sedang tidak bisa dihubungi. Coba lagi nanti.",
	codeBusy:                "Server sedang sibuk. Coba lagi sebentar lagi.",
	codeNotFound:            "Alamat tidak ditemukan.",
	codeRequestTimeout:      "Upload terlalu lama. Periksa koneksi lalu coba lagi.",
	codeInvalidRequest:      "Data upload tidak bisa dibaca.",
	codeInternal:            "Terjadi kesalahan di server. Coba lagi nanti.",
	codeCanceled:            "Upload dibatalkan.",
}

type apiError struct {
	status  int
	code    string
	message string
	detail  string
}

type errorBody struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func fail(status int, code, detail string) *apiError {
	return &apiError{status: status, code: code, message: messages[code], detail: detail}
}

func tooLarge(limit int64, detail string) *apiError {
	e := fail(http.StatusRequestEntityTooLarge, codeFileTooLarge, detail)
	e.message = fmt.Sprintf("Ukuran file melebihi batas %d MB.", limit>>20)
	return e
}

func sanitizeError(err error) *apiError {
	status := http.StatusUnprocessableEntity
	switch {
	case errors.Is(err, sanitize.ErrTooManyFrames):
		e := fail(status, codeImageTooLarge, err.Error())
		e.message = framesMessage
		return e
	case errors.Is(err, sanitize.ErrImageTooLarge):
		return fail(status, codeImageTooLarge, err.Error())
	case errors.Is(err, sanitize.ErrPDFEncrypted):
		return fail(status, codePDFEncrypted, err.Error())
	case errors.Is(err, sanitize.ErrPDFActiveContent):
		return fail(status, codePDFActiveContent, err.Error())
	case errors.Is(err, sanitize.ErrInvalidPDF):
		return fail(status, codeInvalidPDF, err.Error())
	}
	return fail(status, codeInvalidImage, err.Error())
}
