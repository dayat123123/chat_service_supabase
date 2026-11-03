//go:build linux

package disk

import "syscall"

func statfs(dir string) (total, free, avail uint64, err error) {
	var st syscall.Statfs_t
	if err := syscall.Statfs(dir, &st); err != nil {
		return 0, 0, 0, err
	}
	size := uint64(st.Frsize)
	if size == 0 {
		size = uint64(st.Bsize)
	}
	return uint64(st.Blocks) * size, uint64(st.Bfree) * size, uint64(st.Bavail) * size, nil
}
