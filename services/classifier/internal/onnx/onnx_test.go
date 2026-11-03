package onnx

import (
	"image"
	"image/color"
	"math"
	"os"
	"sync"
	"testing"

	"olt-social/classifier/internal/imageprep"
	"olt-social/classifier/internal/model"
)

func open(t *testing.T) (*Session, model.Manifest) {
	t.Helper()
	library, dir := os.Getenv("ONNXRUNTIME_LIBRARY"), os.Getenv("MODEL_DIR")
	if library == "" || dir == "" {
		t.Skip("ONNXRUNTIME_LIBRARY and MODEL_DIR are needed for the onnxruntime test")
	}
	m, path, err := model.Load(dir)
	if err != nil {
		t.Fatal(err)
	}
	if err := Init(library); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(Shutdown)
	s, err := Open(path, m, 1)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Close() })
	return s, m
}

func TestRealModelScoresSyntheticImages(t *testing.T) {
	s, m := open(t)
	prep := imageprep.Prep{Side: m.Side(), CropPct: m.CropPct}
	copy(prep.Mean[:], m.Mean)
	copy(prep.Std[:], m.Std)
	img := image.NewNRGBA(image.Rect(0, 0, 320, 200))
	for y := 0; y < 200; y++ {
		for x := 0; x < 320; x++ {
			img.Set(x, y, color.NRGBA{R: uint8(x), G: uint8(y), B: 160, A: 255})
		}
	}
	views := prep.Tensors(img)
	var wg sync.WaitGroup
	results := make([][]float64, 8)
	for i := range results {
		wg.Add(1)
		go func() {
			defer wg.Done()
			raw, err := s.Infer(views[i%len(views)])
			if err != nil {
				t.Error(err)
				return
			}
			results[i] = model.Probabilities(raw, m.Activation)
		}()
	}
	wg.Wait()
	for i, p := range results {
		var sum float64
		for _, v := range p {
			sum += v
		}
		if len(p) != len(m.Labels) || math.Abs(sum-1) > 1e-4 {
			t.Fatalf("result %d = %v", i, p)
		}
		for j := range p {
			if math.Abs(p[j]-results[i%len(views)][j]) > 1e-5 {
				t.Fatalf("inference is not deterministic: %v vs %v", p, results[i%len(views)])
			}
		}
	}
	scores := map[string]float64{}
	model.Merge(scores, m.Labels, results[0])
	t.Logf("synthetic gradient scores: %v", scores)
	if _, err := s.Infer(make([]float32, 7)); err == nil {
		t.Fatal("a short input must fail")
	}
}
