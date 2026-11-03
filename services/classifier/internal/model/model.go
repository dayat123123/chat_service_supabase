package model

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"slices"
)

const ManifestFile = "manifest.json"

var (
	ErrMissing  = errors.New("model missing")
	ErrInvalid  = errors.New("model invalid")
	ErrMismatch = errors.New("model checksum mismatch")

	idPattern    = regexp.MustCompile(`^[A-Za-z0-9._@:+-]{1,100}$`)
	filePattern  = regexp.MustCompile(`^[A-Za-z0-9._-]{1,100}$`)
	namePattern  = regexp.MustCompile(`^[A-Za-z0-9._:/-]{1,100}$`)
	labelPattern = regexp.MustCompile(`^[a-z][a-z0-9_]{0,31}$`)
	hexPattern   = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

type Manifest struct {
	ID         string    `json:"id"`
	File       string    `json:"file"`
	SHA256     string    `json:"sha256"`
	Input      string    `json:"input"`
	Output     string    `json:"output"`
	Shape      []int64   `json:"shape"`
	CropPct    float64   `json:"crop_pct"`
	Mean       []float32 `json:"mean"`
	Std        []float32 `json:"std"`
	Activation string    `json:"activation"`
	Labels     []string  `json:"labels"`
	Source     string    `json:"source"`
	License    string    `json:"license"`
}

type Model interface {
	Infer(input []float32) ([]float32, error)
	Close() error
}

func (m Manifest) Side() int {
	return int(m.Shape[len(m.Shape)-1])
}

func (m Manifest) Validate() error {
	var problems []string
	check := func(ok bool, problem string) {
		if !ok {
			problems = append(problems, problem)
		}
	}
	check(idPattern.MatchString(m.ID), "id")
	check(filePattern.MatchString(m.File) && m.File != ManifestFile, "file")
	check(hexPattern.MatchString(m.SHA256), "sha256")
	check(namePattern.MatchString(m.Input), "input")
	check(namePattern.MatchString(m.Output), "output")
	check(validShape(m.Shape), "shape")
	check(m.CropPct > 0.5 && m.CropPct <= 1, "crop_pct")
	check(len(m.Mean) == 3 && len(m.Std) == 3 && !slices.ContainsFunc(m.Std, func(v float32) bool { return v <= 0 }), "mean/std")
	check(m.Activation == "softmax" || m.Activation == "none", "activation")
	check(validLabels(m.Labels), "labels")
	if len(problems) > 0 {
		return fmt.Errorf("%w: %v", ErrInvalid, problems)
	}
	return nil
}

func validShape(shape []int64) bool {
	switch {
	case len(shape) == 3 && shape[0] == 3:
	case len(shape) == 4 && shape[0] == 1 && shape[1] == 3:
	default:
		return false
	}
	h, w := shape[len(shape)-2], shape[len(shape)-1]
	return h == w && w >= 32 && w <= 1024
}

func validLabels(labels []string) bool {
	if len(labels) < 2 || len(labels) > 32 {
		return false
	}
	seen := map[string]bool{}
	for _, l := range labels {
		if !labelPattern.MatchString(l) || seen[l] {
			return false
		}
		seen[l] = true
	}
	return true
}

func Load(dir string) (Manifest, string, error) {
	raw, err := os.ReadFile(filepath.Join(dir, ManifestFile))
	if errors.Is(err, fs.ErrNotExist) {
		return Manifest{}, "", fmt.Errorf("%w: %s not found", ErrMissing, ManifestFile)
	}
	if err != nil {
		return Manifest{}, "", fmt.Errorf("%w: read manifest: %v", ErrInvalid, err)
	}
	var m Manifest
	if err := json.Unmarshal(raw, &m); err != nil {
		return Manifest{}, "", fmt.Errorf("%w: manifest is not valid JSON", ErrInvalid)
	}
	if err := m.Validate(); err != nil {
		return Manifest{}, "", err
	}
	path := filepath.Join(dir, m.File)
	sum, err := fileSHA256(path)
	if errors.Is(err, fs.ErrNotExist) {
		return Manifest{}, "", fmt.Errorf("%w: %s not found", ErrMissing, m.File)
	}
	if err != nil {
		return Manifest{}, "", fmt.Errorf("%w: read model: %v", ErrInvalid, err)
	}
	if sum != m.SHA256 {
		return Manifest{}, "", fmt.Errorf("%w: %s has sha256 %s", ErrMismatch, m.File, sum)
	}
	return m, path, nil
}

func fileSHA256(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func Probabilities(raw []float32, activation string) []float64 {
	out := make([]float64, len(raw))
	if activation != "softmax" {
		for i, v := range raw {
			out[i] = clamp(float64(v))
		}
		return out
	}
	top := math.Inf(-1)
	for _, v := range raw {
		top = math.Max(top, float64(v))
	}
	var sum float64
	for i, v := range raw {
		out[i] = math.Exp(float64(v) - top)
		sum += out[i]
	}
	for i := range out {
		out[i] /= sum
	}
	return out
}

func clamp(v float64) float64 {
	if math.IsNaN(v) {
		return 0
	}
	return math.Min(1, math.Max(0, v))
}

func Merge(scores map[string]float64, labels []string, probs []float64) {
	for i, label := range labels {
		if i < len(probs) {
			scores[label] = math.Max(scores[label], probs[i])
		}
	}
}
