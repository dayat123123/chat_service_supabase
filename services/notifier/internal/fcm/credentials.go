package fcm

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"strings"
)

type ServiceAccount struct {
	ProjectID    string
	ClientEmail  string
	PrivateKeyID string
	Key          *rsa.PrivateKey
}

func ParseServiceAccount(data []byte) (ServiceAccount, error) {
	var raw struct {
		Type         string `json:"type"`
		ProjectID    string `json:"project_id"`
		ClientEmail  string `json:"client_email"`
		PrivateKey   string `json:"private_key"`
		PrivateKeyID string `json:"private_key_id"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return ServiceAccount{}, errors.New("isi kredensial bukan JSON akun layanan")
	}
	switch {
	case raw.Type != "service_account":
		return ServiceAccount{}, errors.New(`bukan kunci akun layanan (type harus "service_account")`)
	case strings.TrimSpace(raw.ProjectID) == "":
		return ServiceAccount{}, errors.New("project_id kosong")
	case strings.TrimSpace(raw.ClientEmail) == "":
		return ServiceAccount{}, errors.New("client_email kosong")
	case strings.TrimSpace(raw.PrivateKey) == "":
		return ServiceAccount{}, errors.New("private_key kosong")
	}
	key, err := parseRSAKey(raw.PrivateKey)
	if err != nil {
		return ServiceAccount{}, err
	}
	return ServiceAccount{
		ProjectID:    strings.TrimSpace(raw.ProjectID),
		ClientEmail:  strings.TrimSpace(raw.ClientEmail),
		PrivateKeyID: strings.TrimSpace(raw.PrivateKeyID),
		Key:          key,
	}, nil
}

func parseRSAKey(text string) (*rsa.PrivateKey, error) {
	block, _ := pem.Decode([]byte(text))
	if block == nil {
		block, _ = pem.Decode([]byte(strings.ReplaceAll(text, `\n`, "\n")))
	}
	if block == nil {
		return nil, errors.New("private_key bukan PEM")
	}
	if parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes); err == nil {
		key, ok := parsed.(*rsa.PrivateKey)
		if !ok {
			return nil, errors.New("private_key bukan kunci RSA")
		}
		return key, nil
	}
	if key, err := x509.ParsePKCS1PrivateKey(block.Bytes); err == nil {
		return key, nil
	}
	return nil, errors.New("private_key tidak bisa dibaca sebagai kunci RSA")
}
