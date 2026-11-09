package video

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/media/internal/sniff"
)

type call struct {
	name string
	args []string
}

type fakeRunner struct {
	mu     sync.Mutex
	calls  []call
	input  string
	output string
	remux  error
	thumb  error
	block  time.Duration
}

func (f *fakeRunner) Run(ctx context.Context, name string, args ...string) ([]byte, error) {
	f.mu.Lock()
	f.calls = append(f.calls, call{name, args})
	f.mu.Unlock()
	if f.block > 0 {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(f.block):
		}
	}
	target := args[len(args)-1]
	switch {
	case name == "ffprobe" && filepath.Base(target) == "in":
		return []byte(f.input), nil
	case name == "ffprobe":
		return []byte(f.output), nil
	case strings.HasSuffix(target, ".jpg"):
		if f.thumb != nil {
			return nil, f.thumb
		}
		var buf bytes.Buffer
		img := image.NewRGBA(image.Rect(0, 0, 8, 4))
		img.Set(1, 1, color.RGBA{R: 200, A: 255})
		_ = jpeg.Encode(&buf, img, nil)
		return nil, os.WriteFile(target, buf.Bytes(), 0o600)
	default:
		if f.remux != nil {
			return nil, f.remux
		}
		return nil, os.WriteFile(target, []byte("remuxed"), 0o600)
	}
}

func (f *fakeRunner) ffmpegCalls() [][]string {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out [][]string
	for _, c := range f.calls {
		if c.name == "ffmpeg" {
			out = append(out, c.args)
		}
	}
	return out
}

func probeJSON(format, duration string, streams ...string) string {
	return fmt.Sprintf(`{"streams":[%s],"format":{"format_name":%q,"duration":%q}}`, strings.Join(streams, ","), format, duration)
}

const (
	mov      = "mov,mp4,m4a,3gp,3g2,mj2"
	h264     = `{"index":0,"codec_type":"video","codec_name":"h264","width":1920,"height":1080,"disposition":{"attached_pic":0}}`
	aac      = `{"index":1,"codec_type":"audio","codec_name":"aac"}`
	timecode = `{"index":2,"codec_type":"data","codec_name":"none","tags":{"handler_name":"Core Media Metadata"}}`
)

func newProcessor(r *fakeRunner) *Processor {
	return New(Options{Runner: r, TempDir: os.TempDir(), StepTimeout: time.Second})
}

func TestProcessRemuxesWithoutMetadataAndMakesAThumbnail(t *testing.T) {
	rotated := `{"index":0,"codec_type":"video","codec_name":"hevc","width":1920,"height":1080,"side_data_list":[{"rotation":-90}]}`
	r := &fakeRunner{
		input:  probeJSON(mov, "12.3456", rotated, aac, timecode),
		output: probeJSON(mov, "12.3456", rotated, aac),
	}
	res, err := newProcessor(r).Process(context.Background(), []byte("raw-video"), sniff.MOV, 120)
	if err != nil {
		t.Fatal(err)
	}
	if string(res.Body) != "remuxed" || res.Duration != 12.346 || res.Width != 1080 || res.Height != 1920 {
		t.Fatalf("result = %+v", res)
	}
	if _, err := jpeg.DecodeConfig(bytes.NewReader(res.Thumbnail)); err != nil {
		t.Fatalf("thumbnail: %v", err)
	}
	calls := r.ffmpegCalls()
	if len(calls) != 2 {
		t.Fatalf("ffmpeg calls = %v", calls)
	}
	remux := strings.Join(calls[0], " ")
	for _, want := range []string{"-f mov -i", "-map 0:0 -map 0:1", "-c copy", "-map_metadata -1", "-map_metadata:s:v -1",
		"-map_metadata:s:a -1", "-map_chapters -1", "-movflags +faststart", "-f mov -y"} {
		if !strings.Contains(remux, want) {
			t.Fatalf("remux args %q miss %q", remux, want)
		}
	}
	if strings.Contains(remux, "0:2") {
		t.Fatal("data streams must not be copied")
	}
	thumb := strings.Join(calls[1], " ")
	for _, want := range []string{"-ss 1.000", "-frames:v 1", "scale='min(480,iw)':-2", "-c:v mjpeg"} {
		if !strings.Contains(thumb, want) {
			t.Fatalf("thumbnail args %q miss %q", thumb, want)
		}
	}
	dir := t.TempDir()
	p := New(Options{Runner: r, TempDir: dir, StepTimeout: time.Second})
	if _, err := p.Process(context.Background(), []byte("raw-video"), sniff.MOV, 120); err != nil {
		t.Fatal(err)
	}
	if left, _ := os.ReadDir(dir); len(left) != 0 {
		t.Fatalf("temporary files left behind: %v", left)
	}
}

func TestProcessWebMHasNoFaststartAndShortClipsSeekToTheMiddle(t *testing.T) {
	vp9 := `{"index":0,"codec_type":"video","codec_name":"vp9","width":640,"height":360}`
	opus := `{"index":1,"codec_type":"audio","codec_name":"opus"}`
	r := &fakeRunner{input: probeJSON("matroska,webm", "", vp9, opus), output: probeJSON("matroska,webm", "0.8", vp9, opus)}
	res, err := newProcessor(r).Process(context.Background(), []byte("raw"), sniff.WebM, 120)
	if err != nil || res.Width != 640 || res.Height != 360 || res.Duration != 0.8 {
		t.Fatalf("res = %+v err = %v", res, err)
	}
	calls := r.ffmpegCalls()
	if remux := strings.Join(calls[0], " "); strings.Contains(remux, "faststart") || !strings.Contains(remux, "-f webm") ||
		!strings.Contains(remux, "-f matroska -i") {
		t.Fatalf("remux = %s", remux)
	}
	if !slices.Contains(calls[1], "0.400") {
		t.Fatalf("thumbnail = %v", calls[1])
	}
}

func TestProcessRejectsLongVideos(t *testing.T) {
	r := &fakeRunner{input: probeJSON(mov, "150.2", h264, aac)}
	_, err := newProcessor(r).Process(context.Background(), []byte("raw"), sniff.MP4, 120)
	if !errors.Is(err, ErrTooLong) || len(r.ffmpegCalls()) != 0 {
		t.Fatalf("err = %v calls = %v", err, r.ffmpegCalls())
	}
	r = &fakeRunner{input: probeJSON("matroska,webm", "N/A", h264), output: probeJSON("matroska,webm", "121.5", h264)}
	if _, err := newProcessor(r).Process(context.Background(), []byte("raw"), sniff.WebM, 120); !errors.Is(err, ErrTooLong) {
		t.Fatalf("duration known only after remux: err = %v", err)
	}
}

func TestProcessRejectsInvalidVideos(t *testing.T) {
	mpeg4 := `{"index":0,"codec_type":"video","codec_name":"mpeg4","width":320,"height":240}`
	pcm := `{"index":1,"codec_type":"audio","codec_name":"pcm_s16le"}`
	cover := `{"index":0,"codec_type":"video","codec_name":"mjpeg","width":300,"height":300,"disposition":{"attached_pic":1}}`
	huge := `{"index":0,"codec_type":"video","codec_name":"h264","width":20000,"height":100}`
	cases := map[string]*fakeRunner{
		"video codec":     {input: probeJSON(mov, "5", mpeg4)},
		"audio codec":     {input: probeJSON(mov, "5", h264, pcm)},
		"audio only":      {input: probeJSON(mov, "5", aac)},
		"only cover art":  {input: probeJSON(mov, "5", cover, aac)},
		"dimensions":      {input: probeJSON(mov, "5", huge)},
		"container":       {input: probeJSON("avi", "5", h264)},
		"probe garbage":   {input: "not json"},
		"remux fails":     {input: probeJSON(mov, "5", h264), remux: errors.New("exit status 1: moov atom not found")},
		"no duration":     {input: probeJSON(mov, "", h264), output: probeJSON(mov, "", h264)},
		"thumbnail fails": {input: probeJSON(mov, "5", h264), output: probeJSON(mov, "5", h264), thumb: errors.New("exit status 1")},
	}
	for name, r := range cases {
		t.Run(name, func(t *testing.T) {
			_, err := newProcessor(r).Process(context.Background(), []byte("raw"), sniff.MP4, 120)
			if !errors.Is(err, ErrInvalid) {
				t.Fatalf("err = %v", err)
			}
		})
	}
	if _, err := newProcessor(&fakeRunner{}).Process(context.Background(), []byte("raw"), sniff.PDF, 120); !errors.Is(err, ErrInvalid) {
		t.Fatalf("pdf err = %v", err)
	}
}

func TestProcessCoverArtIsSkippedForTheMainStream(t *testing.T) {
	cover := `{"index":0,"codec_type":"video","codec_name":"mjpeg","width":300,"height":300,"disposition":{"attached_pic":1}}`
	main := `{"index":1,"codec_type":"video","codec_name":"h264","width":1280,"height":720}`
	r := &fakeRunner{input: probeJSON(mov, "3", cover, main), output: probeJSON(mov, "3", main)}
	if _, err := newProcessor(r).Process(context.Background(), []byte("raw"), sniff.MP4, 120); err != nil {
		t.Fatal(err)
	}
	if remux := strings.Join(r.ffmpegCalls()[0], " "); !strings.Contains(remux, "-map 0:1") || strings.Contains(remux, "-map 0:0") {
		t.Fatalf("remux = %s", remux)
	}
}

func TestProcessToolProblems(t *testing.T) {
	slow := &fakeRunner{input: probeJSON(mov, "3", h264), block: time.Minute}
	p := New(Options{Runner: slow, StepTimeout: 50 * time.Millisecond})
	if _, err := p.Process(context.Background(), []byte("raw"), sniff.MP4, 120); !errors.Is(err, ErrTool) {
		t.Fatalf("timeout err = %v", err)
	}
	missing := New(Options{FFprobe: "ffprobe-that-does-not-exist-olt", StepTimeout: time.Second})
	if _, err := missing.Process(context.Background(), []byte("raw"), sniff.MP4, 120); !errors.Is(err, ErrTool) {
		t.Fatalf("missing binary err = %v", err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := newProcessor(&fakeRunner{input: probeJSON(mov, "3", h264)}).Process(ctx, []byte("raw"), sniff.MP4, 120); !errors.Is(err, context.Canceled) && !errors.Is(err, ErrBusy) {
		t.Fatalf("canceled err = %v", err)
	}
}

func TestProcessLimitsConcurrency(t *testing.T) {
	r := &fakeRunner{input: probeJSON(mov, "3", h264), block: 300 * time.Millisecond}
	p := New(Options{Runner: r, Concurrent: 1, QueueWait: 20 * time.Millisecond, StepTimeout: time.Second})
	done := make(chan struct{})
	go func() {
		_, _ = p.Process(context.Background(), []byte("raw"), sniff.MP4, 120)
		close(done)
	}()
	time.Sleep(50 * time.Millisecond)
	if _, err := p.Process(context.Background(), []byte("raw"), sniff.MP4, 120); !errors.Is(err, ErrBusy) {
		t.Fatalf("err = %v", err)
	}
	<-done
}

func TestExecRunnerReportsStderr(t *testing.T) {
	if _, err := exec.LookPath("go"); err != nil {
		t.Skip("go binary not on PATH")
	}
	_, err := execRunner{}.Run(context.Background(), "go", "definitely-not-a-go-command")
	if err == nil || !strings.Contains(err.Error(), "unknown command") {
		t.Fatalf("err = %v", err)
	}
}
