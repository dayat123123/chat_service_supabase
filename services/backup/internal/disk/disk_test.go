package disk

import (
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
