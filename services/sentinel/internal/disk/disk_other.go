//go:build !linux

package disk

func statfs(string) (uint64, uint64, uint64, error) {
	return 0, 0, 0, ErrUnsupported
}
