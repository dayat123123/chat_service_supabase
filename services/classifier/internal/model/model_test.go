package model

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func manifest(data []byte) Manifest {
	sum := sha256.Sum256(data)
	return Manifest{
		ID: "test-model@1", File: "model.onnx", SHA256: hex.EncodeToString(sum[:]), Input: "input", Output: "output",
		Shape: []int64{3, 224, 224}, CropPct: 0.875, Mean: []float32{0, 0, 0}, Std: []float32{1, 1, 1},
		Activation: "softmax", Labels: []string{"drawings", "hentai", "neutral", "porn", "sexy"},
	}
}

func write(t *testing.T, dir string, m Manifest, data []byte) {
	t.Helper()
	raw, _ := json.Marshal(m)
	if err := os.WriteFile(filepath.Join(dir, ManifestFile), raw, 0o600); err != nil {
		t.Fatal(err)
	}
	if data != nil {
		if err := os.WriteFile(filepath.Join(dir, m.File), data, 0o600); err != nil {
			t.Fatal(err)
		}
	}
}

func TestLoadVerifiesTheChecksum(t *testing.T) {
	dir := t.TempDir()
	data := []byte("onnx bytes")
	write(t, dir, manifest(data), data)
	m, path, err := Load(dir)
	if err != nil {
		t.Fatal(err)
	}
	if path != filepath.Join(dir, "model.onnx") || m.ID != "test-model@1" || m.Side() != 224 {
		t.Fatalf("m = %+v path = %s", m, path)
	}

	_ = os.WriteFile(filepath.Join(dir, "model.onnx"), []byte("tampered"), 0o600)
	if _, _, err := Load(dir); !errors.Is(err, ErrMismatch) {
		t.Fatalf("err = %v", err)
	}
}

func TestLoadReportsMissingFiles(t *testing.T) {
	dir := t.TempDir()
	if _, _, err := Load(dir); !errors.Is(err, ErrMissing) {
		t.Fatalf("err = %v", err)
	}
	write(t, dir, manifest([]byte("x")), nil)
	if _, _, err := Load(dir); !errors.Is(err, ErrMissing) || !strings.Contains(err.Error(), "model.onnx") {
		t.Fatalf("err = %v", err)
	}
	_ = os.WriteFile(filepath.Join(dir, ManifestFile), []byte("{"), 0o600)
	if _, _, err := Load(dir); !errors.Is(err, ErrInvalid) {
		t.Fatalf("err = %v", err)
	}
}

func TestValidateRejectsBadManifests(t *testing.T) {
	cases := map[string]func(*Manifest){
		"id":             func(m *Manifest) { m.ID = "" },
		"file traversal": func(m *Manifest) { m.File = "../model.onnx" },
		"file manifest":  func(m *Manifest) { m.File = ManifestFile },
		"sha":            func(m *Manifest) { m.SHA256 = "abc" },
		"input":          func(m *Manifest) { m.Input = "" },
		"shape rank":     func(m *Manifest) { m.Shape = []int64{224, 224} },
		"shape channels": func(m *Manifest) { m.Shape = []int64{1, 1, 224, 224} },
		"shape square":   func(m *Manifest) { m.Shape = []int64{3, 224, 225} },
		"shape tiny":     func(m *Manifest) { m.Shape = []int64{3, 8, 8} },
		"crop":           func(m *Manifest) { m.CropPct = 0 },
		"std":            func(m *Manifest) { m.Std = []float32{1, 0, 1} },
		"mean":           func(m *Manifest) { m.Mean = []float32{0} },
		"activation":     func(m *Manifest) { m.Activation = "sigmoid" },
		"labels":         func(m *Manifest) { m.Labels = []string{"porn"} },
		"labels dup":     func(m *Manifest) { m.Labels = []string{"porn", "porn"} },
		"labels case":    func(m *Manifest) { m.Labels = []string{"Porn", "neutral"} },
	}
	for name, change := range cases {
		m := manifest([]byte("x"))
		change(&m)
		if err := m.Validate(); !errors.Is(err, ErrInvalid) {
			t.Fatalf("%s: err = %v", name, err)
		}
	}
	m := manifest([]byte("x"))
	m.Shape = []int64{1, 3, 256, 256}
	if err := m.Validate(); err != nil || m.Side() != 256 {
		t.Fatalf("batched shape: %v", err)
	}
}

func TestProbabilities(t *testing.T) {
	p := Probabilities([]float32{2, 1, 0}, "softmax")
	var sum float64
	for _, v := range p {
		sum += v
	}
	if math.Abs(sum-1) > 1e-9 || !(p[0] > p[1] && p[1] > p[2]) || math.Abs(p[0]-0.66524) > 1e-4 {
		t.Fatalf("p = %v", p)
	}
	big := Probabilities([]float32{1000, 1000}, "softmax")
	if math.Abs(big[0]-0.5) > 1e-9 {
		t.Fatalf("big = %v", big)
	}
	raw := Probabilities([]float32{-1, 0.25, 7, float32(math.NaN())}, "none")
	if raw[0] != 0 || raw[1] != 0.25 || raw[2] != 1 || raw[3] != 0 {
		t.Fatalf("raw = %v", raw)
	}
}

func TestMergeKeepsTheHighestScorePerLabel(t *testing.T) {
	scores := map[string]float64{}
	labels := []string{"neutral", "porn"}
	Merge(scores, labels, []float64{0.9, 0.1})
	Merge(scores, labels, []float64{0.3, 0.7})
	Merge(scores, labels, []float64{0.5})
	if scores["neutral"] != 0.9 || scores["porn"] != 0.7 || len(scores) != 2 {
		t.Fatalf("scores = %v", scores)
	}
}
