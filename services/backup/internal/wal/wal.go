package wal

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"
)

const (
	PartialSuffix  = ".partial"
	DefaultSegSize = 16 << 20
)

type Segment struct {
	TLI uint32
	Log uint32
	Seg uint32
}

var (
	segmentName = regexp.MustCompile(`^[0-9A-F]{24}$`)
	historyName = regexp.MustCompile(`^[0-9A-F]{8}\.history$`)
	labelStart  = regexp.MustCompile(`(?m)^START WAL LOCATION: \S+ \(file ([0-9A-F]{24})\)`)
)

func ParseSegment(name string) (Segment, bool) {
	if !segmentName.MatchString(name) {
		return Segment{}, false
	}
	tli, _ := strconv.ParseUint(name[0:8], 16, 32)
	log, _ := strconv.ParseUint(name[8:16], 16, 32)
	seg, _ := strconv.ParseUint(name[16:24], 16, 32)
	return Segment{TLI: uint32(tli), Log: uint32(log), Seg: uint32(seg)}, true
}

func (s Segment) Name() string {
	return fmt.Sprintf("%08X%08X%08X", s.TLI, s.Log, s.Seg)
}

func (s Segment) Before(o Segment) bool {
	if s.Log != o.Log {
		return s.Log < o.Log
	}
	return s.Seg < o.Seg
}

func (s Segment) Number(segSize int64) uint64 {
	if segSize <= 0 {
		segSize = DefaultSegSize
	}
	return uint64(s.Log)*(0x100000000/uint64(segSize)) + uint64(s.Seg)
}

func Position(n uint64, segSize int64) string {
	if segSize <= 0 {
		segSize = DefaultSegSize
	}
	per := 0x100000000 / uint64(segSize)
	return fmt.Sprintf("%08X%08X", n/per, n%per)
}

type File struct {
	Name    string
	Dir     string
	Size    int64
	ModTime time.Time
	Segment Segment
	Partial bool
	History bool
}

func (f File) Path() string {
	return filepath.Join(f.Dir, f.Name)
}

func (f File) Complete() bool {
	return !f.Partial && !f.History
}

func Classify(name string) (File, bool) {
	if historyName.MatchString(name) {
		return File{Name: name, History: true}, true
	}
	base, partial := strings.CutSuffix(name, PartialSuffix)
	seg, ok := ParseSegment(base)
	if !ok {
		return File{}, false
	}
	return File{Name: name, Segment: seg, Partial: partial}, true
}

func List(dirs ...string) ([]File, error) {
	var files []File
	for _, dir := range dirs {
		entries, err := os.ReadDir(dir)
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		if err != nil {
			return nil, err
		}
		for _, entry := range entries {
			if !entry.Type().IsRegular() {
				continue
			}
			f, ok := Classify(entry.Name())
			if !ok {
				continue
			}
			info, err := entry.Info()
			if err != nil {
				continue
			}
			f.Dir, f.Size, f.ModTime = dir, info.Size(), info.ModTime()
			files = append(files, f)
		}
	}
	slices.SortStableFunc(files, func(a, b File) int { return strings.Compare(a.Name, b.Name) })
	return files, nil
}

func StartSegment(label []byte) (Segment, error) {
	m := labelStart.FindSubmatch(label)
	if m == nil {
		return Segment{}, errors.New("backup_label has no START WAL LOCATION")
	}
	seg, _ := ParseSegment(string(m[1]))
	return seg, nil
}

func Obsolete(files []File, sent map[string]bool, keepFrom Segment) []File {
	var out []File
	for _, f := range files {
		if f.Complete() && sent[f.Name] && f.Segment.Before(keepFrom) {
			out = append(out, f)
		}
	}
	return out
}

func PromotePartials(dir string) ([]string, error) {
	files, err := List(dir)
	if err != nil {
		return nil, err
	}
	have := map[string]bool{}
	for _, f := range files {
		if f.Complete() {
			have[f.Name] = true
		}
	}
	var promoted []string
	for _, f := range files {
		if !f.Partial {
			continue
		}
		full := strings.TrimSuffix(f.Name, PartialSuffix)
		if have[full] {
			if err := os.Remove(f.Path()); err != nil {
				return promoted, err
			}
			continue
		}
		if err := os.Rename(f.Path(), filepath.Join(dir, full)); err != nil {
			return promoted, err
		}
		promoted = append(promoted, full)
	}
	return promoted, nil
}

func SegmentSize(files []File) int64 {
	counts := map[int64]int{}
	for _, f := range files {
		if f.Complete() && f.Size > 0 && f.Size&(f.Size-1) == 0 {
			counts[f.Size]++
		}
	}
	best, bestCount := int64(DefaultSegSize), 0
	for size, n := range counts {
		if n > bestCount || (n == bestCount && size < best) {
			best, bestCount = size, n
		}
	}
	return best
}

func Missing(files []File, start Segment, until time.Time, limit int) []string {
	segSize := SegmentSize(files)
	have := map[uint64]time.Time{}
	var last uint64
	found := false
	for _, f := range files {
		if !f.Complete() {
			continue
		}
		n := f.Segment.Number(segSize)
		if t, ok := have[n]; !ok || f.ModTime.After(t) {
			have[n] = f.ModTime
		}
		if !found || n > last {
			last, found = n, true
		}
	}
	first := start.Number(segSize)
	if !found || last < first {
		return []string{Position(first, segSize)}
	}
	end := last
	if !until.IsZero() {
		for n := first; n <= last; n++ {
			if t, ok := have[n]; ok && !t.Before(until) {
				end = n
				break
			}
		}
	}
	var missing []string
	for n := first; n <= end && len(missing) < limit; n++ {
		if _, ok := have[n]; !ok {
			missing = append(missing, Position(n, segSize))
		}
	}
	return missing
}

func Collect(root, dst string) (int, error) {
	if err := os.MkdirAll(dst, 0o700); err != nil {
		return 0, err
	}
	moved := 0
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.Type().IsRegular() {
			return nil
		}
		if _, ok := Classify(d.Name()); !ok {
			return nil
		}
		target := filepath.Join(dst, d.Name())
		if _, err := os.Lstat(target); err == nil {
			return nil
		}
		if err := os.Rename(path, target); err != nil {
			return err
		}
		moved++
		return nil
	})
	return moved, err
}

func Bytes(files []File) int64 {
	var n int64
	for _, f := range files {
		n += f.Size
	}
	return n
}
