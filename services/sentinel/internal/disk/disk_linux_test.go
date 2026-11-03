//go:build linux

package disk

import "testing"

func TestMeasureReadsTheFilesystem(t *testing.T) {
	u, err := Measure(Target{Name: "tmp", Path: t.TempDir()})
	if err != nil {
		t.Fatal(err)
	}
	if u.Name != "tmp" || u.TotalBytes == 0 || u.FreeBytes > u.TotalBytes || u.AvailBytes > u.FreeBytes {
		t.Fatalf("usage = %+v", u)
	}
	if _, err := Measure(Target{Name: "gone", Path: "/definitely/not/here"}); err == nil {
		t.Fatal("a missing path must fail")
	}
}
