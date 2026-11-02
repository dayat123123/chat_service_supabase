package fcm

import (
	"bytes"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"io/fs"
	"net/url"
	"os"
	"path/filepath"
	"strings"
)

const (
	defaultTokenURI = "https://oauth2.googleapis.com/token"
	blankCheckLimit = 64 << 10
)

type ServiceAccount struct {
	ProjectID    string
	ClientEmail  string
	PrivateKeyID string
	TokenURI     string
	Key          *rsa.PrivateKey
}

func ParseServiceAccount(data []byte) (ServiceAccount, error) {
	var raw struct {
		Type         string `json:"type"`
		ProjectID    string `json:"project_id"`
		ClientEmail  string `json:"client_email"`
		PrivateKey   string `json:"private_key"`
		PrivateKeyID string `json:"private_key_id"`
		TokenURI     string `json:"token_uri"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return ServiceAccount{}, errors.New("isi file bukan JSON akun layanan")
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
	tokenURI := strings.TrimSpace(raw.TokenURI)
	if tokenURI == "" {
		tokenURI = defaultTokenURI
	}
	if u, err := url.Parse(tokenURI); err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.Host == "" {
		return ServiceAccount{}, errors.New("token_uri bukan URL http(s)")
	}
	return ServiceAccount{
		ProjectID:    strings.TrimSpace(raw.ProjectID),
		ClientEmail:  strings.TrimSpace(raw.ClientEmail),
		PrivateKeyID: strings.TrimSpace(raw.PrivateKeyID),
		TokenURI:     tokenURI,
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

type candidate struct {
	file       string
	size       int64
	modified   int64
	configured bool
	problem    string
}

func locate(path string, readFile func(string) ([]byte, error)) candidate {
	info, err := os.Stat(path)
	if errors.Is(err, fs.ErrNotExist) {
		return candidate{}
	}
	if err != nil {
		return candidate{configured: true, problem: problemUnreadableFile}
	}
	if !info.IsDir() {
		if blank(path, info, readFile) {
			return candidate{}
		}
		return fileCandidate(path, info)
	}
	entries, err := os.ReadDir(path)
	if err != nil {
		return candidate{configured: true, problem: problemUnreadableDir}
	}
	var found []candidate
	for _, entry := range entries {
		name := entry.Name()
		if strings.HasPrefix(name, ".") || !strings.EqualFold(filepath.Ext(name), ".json") {
			continue
		}
		file := filepath.Join(path, name)
		info, err := os.Stat(file)
		if err != nil || info.IsDir() || blank(file, info, readFile) {
			continue
		}
		found = append(found, fileCandidate(file, info))
	}
	switch len(found) {
	case 0:
		return candidate{}
	case 1:
		return found[0]
	default:
		return candidate{configured: true, problem: problemMultipleFiles}
	}
}

func blank(file string, info fs.FileInfo, readFile func(string) ([]byte, error)) bool {
	if info.Size() == 0 {
		return true
	}
	if info.Size() > blankCheckLimit {
		return false
	}
	data, err := readFile(file)
	return err == nil && isBlank(data)
}

func isBlank(data []byte) bool {
	return len(bytes.TrimSpace(data)) == 0
}

func fileCandidate(file string, info fs.FileInfo) candidate {
	return candidate{file: file, size: info.Size(), modified: info.ModTime().UnixNano(), configured: true}
}
