package disk

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"syscall"
)

type Usage struct {
	Total int64
	Avail int64
}

var (
	ErrNotDirectory = errors.New("folder tidak ada")
	ErrNotMounted   = errors.New("folder bukan volume atau bind mount terpisah")
	ErrNotWritable  = errors.New("folder tidak bisa ditulis")
)

func Stat(path string) (Usage, error) {
	var s syscall.Statfs_t
	if err := syscall.Statfs(path, &s); err != nil {
		return Usage{}, err
	}
	return Usage{Total: int64(s.Blocks) * int64(s.Bsize), Avail: int64(s.Bavail) * int64(s.Bsize)}, nil
}

func MountPoint(dir string) (bool, error) {
	var self, parent syscall.Stat_t
	if err := syscall.Stat(dir, &self); err != nil {
		return false, err
	}
	if err := syscall.Stat(filepath.Dir(filepath.Clean(dir)), &parent); err != nil {
		return false, err
	}
	return self.Dev != parent.Dev || self.Ino == parent.Ino, nil
}

func CheckRepository(dir string) error {
	info, err := os.Stat(dir)
	if err != nil {
		return fmt.Errorf("%w: %s", ErrNotDirectory, dir)
	}
	if !info.IsDir() {
		return fmt.Errorf("%w: %s", ErrNotDirectory, dir)
	}
	mounted, err := MountPoint(dir)
	if err != nil {
		return err
	}
	if !mounted {
		return fmt.Errorf("%w: %s", ErrNotMounted, dir)
	}
	f, err := os.CreateTemp(dir, ".olt-write-test-*")
	if err != nil {
		return fmt.Errorf("%w: %s (uid %d)", ErrNotWritable, dir, os.Geteuid())
	}
	name := f.Name()
	_ = f.Close()
	return os.Remove(name)
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
