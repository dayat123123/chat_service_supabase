package disk

import (
	"errors"
	"fmt"
	"path"
	"regexp"
	"strings"
)

const MaxTargets = 20

var (
	ErrUnsupported = errors.New("disk usage can only be measured on Linux")
	namePattern    = regexp.MustCompile(`^[a-z0-9][a-z0-9_.-]{0,39}$`)
)

type Target struct {
	Name string
	Path string
}

type Usage struct {
	Name       string `json:"name"`
	TotalBytes uint64 `json:"total_bytes"`
	FreeBytes  uint64 `json:"free_bytes"`
	AvailBytes uint64 `json:"avail_bytes"`
}

func Parse(spec string) ([]Target, error) {
	var targets []Target
	seen := map[string]bool{}
	for item := range strings.SplitSeq(spec, ",") {
		item = strings.TrimSpace(item)
		if item == "" {
			continue
		}
		name, dir, ok := strings.Cut(item, "=")
		name, dir = strings.TrimSpace(name), strings.TrimSpace(dir)
		if !ok || !namePattern.MatchString(name) {
			return nil, fmt.Errorf("each entry must look like name=/path, with a lowercase name of letters, digits, '.', '_' or '-' (max. 40)")
		}
		if !path.IsAbs(dir) {
			return nil, fmt.Errorf("disk %q needs an absolute path such as /mnt/disks/%s", name, name)
		}
		if seen[name] {
			return nil, fmt.Errorf("disk %q is listed twice", name)
		}
		seen[name] = true
		targets = append(targets, Target{Name: name, Path: path.Clean(dir)})
	}
	if len(targets) > MaxTargets {
		return nil, fmt.Errorf("at most %d disks are allowed", MaxTargets)
	}
	return targets, nil
}

func Measure(target Target) (Usage, error) {
	total, free, avail, err := statfs(target.Path)
	if err != nil {
		return Usage{}, err
	}
	return Usage{Name: target.Name, TotalBytes: total, FreeBytes: free, AvailBytes: avail}, nil
}
