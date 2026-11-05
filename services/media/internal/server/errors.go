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

	codeImageBlocked          = "image_blocked"
	codeClassifierUnavailable = "classifier_unavailable"
	codeModerationUnavailable = "moderation_unavailable"

	framesMessage = "GIF animations are limited to 500 frames."
)

var messages = map[string]string{
	codeInvalidToken:          "Session is invalid or has expired. Sign in again.",
	codeBucketNotAllowed:      "Upload destination is not allowed.",
	codeInvalidPath:           "Invalid file name or location.",
	codeEmptyFile:             "Empty file.",
	codeFileTooLarge:          "File exceeds the size limit.",
	codeUnsupportedType:       "File type is not supported for this destination.",
	codeInvalidImage:          "Image is corrupt or unreadable.",
	codeImageTooLarge:         "Image dimensions are too large (max 10000 pixels per side and 40 megapixels).",
	codeInvalidPDF:            "PDF is corrupt or unreadable.",
	codePDFEncrypted:          "Locked or encrypted PDFs are not accepted. Save it again without a password.",
	codePDFActiveContent:      "PDF contains active content (JavaScript, attachments, or multimedia) and is not accepted.",
	storage.CodeForbidden:     "You are not allowed to upload files to this location.",
	storage.CodeExists:        "A file with the same name already exists.",
	storage.CodeTooMany:       "Daily upload limit reached. Try again later.",
	storage.CodeError:         "Storage rejected the file. Try again later.",
	storage.CodeUnavailable:   "Storage is unreachable. Try again later.",
	codeBusy:                  "Server is busy. Try again shortly.",
	codeNotFound:              "Not found.",
	codeRequestTimeout:        "Upload took too long. Check the connection and try again.",
	codeInvalidRequest:        "Upload data could not be read.",
	codeInternal:              "Internal server error. Try again later.",
	codeCanceled:              "Upload canceled.",
	codeImageBlocked:          "This image cannot be uploaded because it violates the community guidelines.",
	codeClassifierUnavailable: "Image check is unavailable. Try again shortly.",
	codeModerationUnavailable: "Image check is unavailable. Try again shortly.",
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
	e.message = fmt.Sprintf("File exceeds the %d MB limit.", limit>>20)
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
