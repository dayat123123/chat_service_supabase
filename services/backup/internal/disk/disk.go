package disk

import (
	"io/fs"
	"path/filepath"
	"syscall"
)

type Usage struct {
	Total int64
	Avail int64
}

func Stat(path string) (Usage, error) {
	var s syscall.Statfs_t
	if err := syscall.Statfs(path, &s); err != nil {
		return Usage{}, err
	}
	return Usage{Total: int64(s.Blocks) * int64(s.Bsize), Avail: int64(s.Bavail) * int64(s.Bsize)}, nil
}

func Size(root string) (int64, error) {
	var total int64
	err := filepath.WalkDir(root, func(_ string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.Type().IsRegular() {
			info, err := d.Info()
			if err != nil {
				return err
			}
			total += info.Size()
		}
		return nil
	})
	return total, err
}
