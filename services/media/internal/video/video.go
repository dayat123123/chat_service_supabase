package video

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"

	"olt-social/media/internal/sanitize"
	"olt-social/media/internal/sniff"
)

const (
	ThumbnailWidth = 480
	maxOutput      = 1 << 20
	maxStreams     = 16
)

var (
	ErrInvalid = errors.New("invalid video")
	ErrTooLong = errors.New("video too long")
	ErrBusy    = errors.New("video processing is busy")
	ErrTool    = errors.New("video tool failed")
)

var (
	videoCodecs = []string{"h264", "hevc", "vp8", "vp9", "av1"}
	audioCodecs = []string{"aac", "opus", "vorbis", "mp3"}
	containers  = map[sniff.Kind]struct{ demuxer, muxer, format string }{
		sniff.MP4:  {"mov", "mp4", "mov,mp4,m4a,3gp,3g2,mj2"},
		sniff.MOV:  {"mov", "mov", "mov,mp4,m4a,3gp,3g2,mj2"},
		sniff.WebM: {"matroska", "webm", "matroska,webm"},
	}
)

type Result struct {
	Body      []byte
	Thumbnail []byte
	Duration  float64
	Width     int
	Height    int
}

type Runner interface {
	Run(ctx context.Context, name string, args ...string) ([]byte, error)
}

type Options struct {
	FFmpeg      string
	FFprobe     string
	TempDir     string
	Concurrent  int
	QueueWait   time.Duration
	StepTimeout time.Duration
	Runner      Runner
}

type Processor struct {
	opts  Options
	slots chan struct{}
}

func New(opts Options) *Processor {
	if opts.FFmpeg == "" {
		opts.FFmpeg = "ffmpeg"
	}
	if opts.FFprobe == "" {
		opts.FFprobe = "ffprobe"
	}
	if opts.Concurrent <= 0 {
		opts.Concurrent = 1
	}
	if opts.QueueWait <= 0 {
		opts.QueueWait = 5 * time.Second
	}
	if opts.StepTimeout <= 0 {
		opts.StepTimeout = 20 * time.Second
	}
	if opts.Runner == nil {
		opts.Runner = execRunner{}
	}
	return &Processor{opts: opts, slots: make(chan struct{}, opts.Concurrent)}
}

func (p *Processor) Process(ctx context.Context, body []byte, kind sniff.Kind, maxSeconds float64) (Result, error) {
	c, ok := containers[kind]
	if !ok {
		return Result{}, fmt.Errorf("%w: %s is not a video kind", ErrInvalid, kind)
	}
	if !p.acquire(ctx) {
		return Result{}, ErrBusy
	}
	defer func() { <-p.slots }()
	dir, err := os.MkdirTemp(p.opts.TempDir, "media-video-")
	if err != nil {
		return Result{}, fmt.Errorf("%w: temp dir: %v", ErrTool, err)
	}
	defer os.RemoveAll(dir)
	in, out, thumb := filepath.Join(dir, "in"), filepath.Join(dir, "out."+kind.Ext()), filepath.Join(dir, "thumb.jpg")
	if err := os.WriteFile(in, body, 0o600); err != nil {
		return Result{}, fmt.Errorf("%w: write input: %v", ErrTool, err)
	}

	source, err := p.probe(ctx, c.demuxer, in)
	if err != nil {
		return Result{}, err
	}
	picked, err := source.pick(c.format)
	if err != nil {
		return Result{}, err
	}
	if source.duration() > maxSeconds {
		return Result{}, fmt.Errorf("%w: %.2f s", ErrTooLong, source.duration())
	}

	args := []string{"-nostdin", "-hide_banner", "-v", "error", "-f", c.demuxer, "-i", in,
		"-map", "0:" + strconv.Itoa(picked.video.Index)}
	if picked.audio != nil {
		args = append(args, "-map", "0:"+strconv.Itoa(picked.audio.Index))
	}
	args = append(args, "-c", "copy", "-map_metadata", "-1", "-map_metadata:s:v", "-1", "-map_metadata:s:a", "-1",
		"-map_chapters", "-1", "-fflags", "+bitexact", "-flags:v", "+bitexact", "-flags:a", "+bitexact")
	if c.muxer != "webm" {
		args = append(args, "-movflags", "+faststart", "-write_tmcd", "0")
	}
	args = append(args, "-f", c.muxer, "-y", out)
	if _, err := p.run(ctx, p.opts.FFmpeg, args...); err != nil {
		return Result{}, failed("remux", err)
	}

	clean, err := p.probe(ctx, c.demuxer, out)
	if err != nil {
		return Result{}, err
	}
	stored, err := clean.pick(c.format)
	if err != nil {
		return Result{}, err
	}
	duration := clean.duration()
	switch {
	case duration <= 0 || math.IsNaN(duration):
		return Result{}, fmt.Errorf("%w: unknown duration", ErrInvalid)
	case duration > maxSeconds:
		return Result{}, fmt.Errorf("%w: %.2f s", ErrTooLong, duration)
	}

	at := min(1.0, duration/2)
	if _, err := p.run(ctx, p.opts.FFmpeg, "-nostdin", "-hide_banner", "-v", "error", "-threads", "1",
		"-ss", strconv.FormatFloat(at, 'f', 3, 64), "-f", c.demuxer, "-i", out, "-map", "0:v:0", "-frames:v", "1",
		"-vf", fmt.Sprintf("scale='min(%d,iw)':-2", ThumbnailWidth), "-map_metadata", "-1",
		"-fflags", "+bitexact", "-flags:v", "+bitexact", "-c:v", "mjpeg", "-q:v", "4", "-f", "image2", "-y", thumb); err != nil {
		return Result{}, failed("thumbnail", err)
	}
	remuxed, err := os.ReadFile(out)
	if err != nil {
		return Result{}, fmt.Errorf("%w: read output: %v", ErrTool, err)
	}
	raw, err := os.ReadFile(thumb)
	if err != nil || len(raw) == 0 {
		return Result{}, fmt.Errorf("%w: thumbnail missing", ErrInvalid)
	}
	preview, _, err := sanitize.JPEG(raw)
	if err != nil {
		return Result{}, fmt.Errorf("%w: thumbnail: %v", ErrInvalid, err)
	}
	width, height := stored.video.display()
	return Result{Body: remuxed, Thumbnail: preview, Duration: math.Round(duration*1000) / 1000, Width: width, Height: height}, nil
}

func (p *Processor) acquire(ctx context.Context) bool {
	select {
	case p.slots <- struct{}{}:
		return true
	default:
	}
	timer := time.NewTimer(p.opts.QueueWait)
	defer timer.Stop()
	select {
	case p.slots <- struct{}{}:
		return true
	case <-timer.C:
	case <-ctx.Done():
	}
	return false
}

func (p *Processor) probe(ctx context.Context, demuxer, file string) (probeReply, error) {
	out, err := p.run(ctx, p.opts.FFprobe, "-hide_banner", "-v", "error", "-f", demuxer,
		"-print_format", "json", "-show_format", "-show_streams", file)
	if err != nil {
		return probeReply{}, failed("probe", err)
	}
	var reply probeReply
	if err := json.Unmarshal(out, &reply); err != nil {
		return probeReply{}, fmt.Errorf("%w: probe reply: %v", ErrInvalid, err)
	}
	return reply, nil
}

func (p *Processor) run(ctx context.Context, name string, args ...string) ([]byte, error) {
	step, cancel := context.WithTimeout(ctx, p.opts.StepTimeout)
	defer cancel()
	out, err := p.opts.Runner.Run(step, name, args...)
	switch {
	case ctx.Err() != nil:
		return nil, ctx.Err()
	case step.Err() != nil:
		return nil, fmt.Errorf("%w: %s timed out after %s", ErrTool, filepath.Base(name), p.opts.StepTimeout)
	case errors.Is(err, exec.ErrNotFound):
		return nil, fmt.Errorf("%w: %v", ErrTool, err)
	}
	return out, err
}

func failed(step string, err error) error {
	if errors.Is(err, ErrTool) || errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
		return err
	}
	return fmt.Errorf("%w: %s: %v", ErrInvalid, step, err)
}

type stream struct {
	Index       int               `json:"index"`
	CodecType   string            `json:"codec_type"`
	CodecName   string            `json:"codec_name"`
	Width       int               `json:"width"`
	Height      int               `json:"height"`
	Disposition map[string]int    `json:"disposition"`
	Tags        map[string]string `json:"tags"`
	SideData    []struct {
		Rotation *float64 `json:"rotation"`
	} `json:"side_data_list"`
}

func (s stream) display() (int, int) {
	rotation := 0.0
	for _, sd := range s.SideData {
		if sd.Rotation != nil {
			rotation = *sd.Rotation
		}
	}
	if r, err := strconv.ParseFloat(s.Tags["rotate"], 64); err == nil {
		rotation = r
	}
	if int(math.Abs(rotation))%180 == 90 {
		return s.Height, s.Width
	}
	return s.Width, s.Height
}

type probeReply struct {
	Streams []stream `json:"streams"`
	Format  struct {
		FormatName string `json:"format_name"`
		Duration   string `json:"duration"`
	} `json:"format"`
}

type picked struct {
	video *stream
	audio *stream
}

func (r probeReply) duration() float64 {
	d, err := strconv.ParseFloat(strings.TrimSpace(r.Format.Duration), 64)
	if err != nil {
		return 0
	}
	return d
}

func (r probeReply) pick(format string) (picked, error) {
	if r.Format.FormatName != format {
		return picked{}, fmt.Errorf("%w: container %q", ErrInvalid, r.Format.FormatName)
	}
	if len(r.Streams) > maxStreams {
		return picked{}, fmt.Errorf("%w: %d streams", ErrInvalid, len(r.Streams))
	}
	var out picked
	for i := range r.Streams {
		s := &r.Streams[i]
		switch {
		case s.CodecType == "video" && s.Disposition["attached_pic"] == 1:
		case s.CodecType == "video" && out.video == nil:
			if !slices.Contains(videoCodecs, s.CodecName) {
				return picked{}, fmt.Errorf("%w: video codec %q", ErrInvalid, s.CodecName)
			}
			if s.Width <= 0 || s.Height <= 0 || s.Width > 8192 || s.Height > 8192 {
				return picked{}, fmt.Errorf("%w: dimensions %dx%d", ErrInvalid, s.Width, s.Height)
			}
			out.video = s
		case s.CodecType == "audio" && out.audio == nil:
			if !slices.Contains(audioCodecs, s.CodecName) {
				return picked{}, fmt.Errorf("%w: audio codec %q", ErrInvalid, s.CodecName)
			}
			out.audio = s
		}
	}
	if out.video == nil {
		return picked{}, fmt.Errorf("%w: no video stream", ErrInvalid)
	}
	return out, nil
}

type execRunner struct{}

func (execRunner) Run(ctx context.Context, name string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = []string{"PATH=/usr/bin:/bin", "HOME=/tmp"}
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &limitedBuffer{buf: &stdout, left: maxOutput}
	cmd.Stderr = &limitedBuffer{buf: &stderr, left: 4 << 10}
	if err := cmd.Run(); err != nil {
		msg := strings.TrimSpace(stderr.String())
		if len(msg) > 300 {
			msg = msg[:300]
		}
		if msg == "" {
			return nil, err
		}
		return nil, fmt.Errorf("%v: %s", err, msg)
	}
	return stdout.Bytes(), nil
}

type limitedBuffer struct {
	buf  *bytes.Buffer
	left int
}

func (l *limitedBuffer) Write(p []byte) (int, error) {
	if l.left > 0 {
		n := min(len(p), l.left)
		l.buf.Write(p[:n])
		l.left -= n
	}
	return len(p), nil
}
