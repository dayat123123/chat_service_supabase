package disk

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestStatReportsSpace(t *testing.T) {
	u, err := Stat(t.TempDir())
	if err != nil || u.Total <= 0 || u.Avail < 0 || u.Avail > u.Total {
		t.Fatalf("u = %+v err = %v", u, err)
	}
	if _, err := Stat("/does/not/exist"); err == nil {
		t.Fatal("missing path must fail")
	}
}

func TestMountPointTellsMountsFromPlainFolders(t *testing.T) {
	if root, err := MountPoint("/"); err != nil || !root {
		t.Fatalf("root = %v err = %v", root, err)
	}
	if plain, err := MountPoint(t.TempDir()); err != nil || plain {
		t.Fatalf("temp dir counted as mount: %v err = %v", plain, err)
	}
	if _, err := MountPoint("/does/not/exist"); err == nil {
		t.Fatal("missing path must fail")
	}
}

func TestCheckRepositoryRejectsMissingFilesAndPlainFolders(t *testing.T) {
	dir := t.TempDir()
	file := filepath.Join(dir, "file")
	_ = os.WriteFile(file, nil, 0o600)
	cases := map[string]struct {
		path string
		want error
	}{
		"missing": {filepath.Join(dir, "missing"), ErrNotDirectory},
		"file":    {file, ErrNotDirectory},
		"plain":   {dir, ErrNotMounted},
	}
	for name, c := range cases {
		if err := CheckRepository(c.path); !errors.Is(err, c.want) {
			t.Errorf("%s: err = %v, want %v", name, err, c.want)
		}
	}
}

func TestCheckRepositoryAcceptsAWritableMount(t *testing.T) {
	const shm = "/dev/shm"
	if mounted, err := MountPoint(shm); err != nil || !mounted {
		t.Skip("no tmpfs mount at /dev/shm")
	}
	before, _ := os.ReadDir(shm)
	if err := CheckRepository(shm); err != nil {
		t.Fatal(err)
	}
	after, _ := os.ReadDir(shm)
	if len(after) != len(before) {
		t.Fatalf("write test left files behind: %d -> %d", len(before), len(after))
	}
}

func TestCheckRepositoryReportsReadOnlyMount(t *testing.T) {
	if mounted, err := MountPoint("/proc"); err != nil || !mounted {
		t.Skip("no /proc mount")
	}
	if err := CheckRepository("/proc"); !errors.Is(err, ErrNotWritable) {
		t.Fatalf("err = %v", err)
	}
}

func TestSizeSumsRegularFiles(t *testing.T) {
	dir := t.TempDir()
	_ = os.MkdirAll(filepath.Join(dir, "a", "b"), 0o700)
	_ = os.WriteFile(filepath.Join(dir, "x"), make([]byte, 10), 0o600)
	_ = os.WriteFile(filepath.Join(dir, "a", "b", "y"), make([]byte, 5), 0o600)
	_ = os.Symlink(filepath.Join(dir, "x"), filepath.Join(dir, "link"))
	n, err := Size(dir)
	if err != nil || n != 15 {
		t.Fatalf("n = %d err = %v", n, err)
	}
}
