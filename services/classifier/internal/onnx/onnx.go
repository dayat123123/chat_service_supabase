package onnx

import (
	"errors"
	"fmt"
	"slices"

	ort "github.com/yalue/onnxruntime_go"

	"olt-social/classifier/internal/model"
)

type Session struct {
	session *ort.DynamicAdvancedSession
	shape   ort.Shape
	outputs int
}

func Init(library string) error {
	ort.SetSharedLibraryPath(library)
	if err := ort.InitializeEnvironment(ort.WithLogLevelError()); err != nil {
		return fmt.Errorf("initialize onnxruntime: %w", err)
	}
	return nil
}

func Shutdown() {
	if ort.IsInitialized() {
		_ = ort.DestroyEnvironment()
	}
}

func Open(path string, m model.Manifest, threads int) (*Session, error) {
	inputs, outputs, err := ort.GetInputOutputInfo(path)
	if err != nil {
		return nil, fmt.Errorf("read model inputs: %w", err)
	}
	in := slices.IndexFunc(inputs, func(i ort.InputOutputInfo) bool { return i.Name == m.Input })
	out := slices.IndexFunc(outputs, func(o ort.InputOutputInfo) bool { return o.Name == m.Output })
	if in < 0 || out < 0 {
		return nil, errors.New("model has no input " + m.Input + " or output " + m.Output)
	}
	if got := len(inputs[in].Dimensions); got != len(m.Shape) {
		return nil, fmt.Errorf("model input has rank %d, manifest says %d", got, len(m.Shape))
	}
	if dims := outputs[out].Dimensions; len(dims) == 0 || (dims[len(dims)-1] > 0 && int(dims[len(dims)-1]) != len(m.Labels)) {
		return nil, fmt.Errorf("model output %v does not match %d labels", dims, len(m.Labels))
	}
	options, err := ort.NewSessionOptions()
	if err != nil {
		return nil, fmt.Errorf("session options: %w", err)
	}
	defer options.Destroy()
	if err := options.SetIntraOpNumThreads(threads); err != nil {
		return nil, err
	}
	if err := options.SetInterOpNumThreads(1); err != nil {
		return nil, err
	}
	session, err := ort.NewDynamicAdvancedSession(path, []string{m.Input}, []string{m.Output}, options)
	if err != nil {
		return nil, fmt.Errorf("open model: %w", err)
	}
	return &Session{session: session, shape: ort.NewShape(m.Shape...), outputs: len(m.Labels)}, nil
}

func (s *Session) Infer(input []float32) ([]float32, error) {
	tensor, err := ort.NewTensor(s.shape, input)
	if err != nil {
		return nil, err
	}
	defer tensor.Destroy()
	outputs := []ort.Value{nil}
	if err := s.session.Run([]ort.Value{tensor}, outputs); err != nil {
		return nil, err
	}
	defer outputs[0].Destroy()
	result, ok := outputs[0].(*ort.Tensor[float32])
	if !ok {
		return nil, errors.New("model output is not float32")
	}
	data := result.GetData()
	if len(data) != s.outputs {
		return nil, fmt.Errorf("model returned %d values for %d labels", len(data), s.outputs)
	}
	return slices.Clone(data), nil
}

func (s *Session) Close() error {
	return s.session.Destroy()
}
