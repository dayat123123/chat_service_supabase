package wal

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"
)

func write(t *testing.T, dir, name string, size int, mod time.Time) {
	t.Helper()
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, name)
	if err := os.WriteFile(path, make([]byte, size), 0o600); err != nil {
		t.Fatal(err)
	}
	if !mod.IsZero() {
		_ = os.Chtimes(path, mod, mod)
	}
}

func names(files []File) []string {
	var out []string
	for _, f := range files {
		out = append(out, f.Name)
	}
	return out
}

func TestParseSegmentAndOrdering(t *testing.T) {
	s, ok := ParseSegment("000000010000000A000000FF")
	if !ok || s != (Segment{TLI: 1, Log: 10, Seg: 255}) || s.Name() != "000000010000000A000000FF" {
		t.Fatalf("s = %+v", s)
	}
	for _, bad := range []string{"00000001000000000000002", "000000010000000000000027.partial", "zz0000010000000000000027", "000000010000000000000027x"} {
		if _, ok := ParseSegment(bad); ok {
			t.Fatalf("%q parsed", bad)
		}
	}
	a, _ := ParseSegment("000000010000000000000027")
	b, _ := ParseSegment("000000020000000000000028")
	c, _ := ParseSegment("000000010000000100000000")
	if !a.Before(b) || b.Before(a) || !b.Before(c) || a.Before(a) {
		t.Fatal("ordering must ignore the timeline")
	}
	if a.Number(16<<20) != 0x27 || c.Number(16<<20) != 256 || c.Number(64<<20) != 64 || c.Number(0) != 256 {
		t.Fatal("segment numbers")
	}
	if Position(256, 16<<20) != "0000000100000000" || Position(0x27, 0) != "0000000000000027" {
		t.Fatal("position")
	}
}

func TestClassifyAndList(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "000000010000000000000027", 10, time.Time{})
	write(t, dir, "000000010000000000000028.partial", 10, time.Time{})
	write(t, dir, "00000002.history", 1, time.Time{})
	write(t, dir, "notes.txt", 1, time.Time{})
	_ = os.Mkdir(filepath.Join(dir, "archive_status"), 0o700)
	files, err := List(dir, filepath.Join(dir, "missing"))
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(names(files), []string{"000000010000000000000027", "000000010000000000000028.partial", "00000002.history"}) {
		t.Fatalf("files = %v", names(files))
	}
	if !files[0].Complete() || files[1].Complete() || !files[1].Partial || !files[2].History || files[2].Complete() {
		t.Fatalf("kinds = %+v", files)
	}
	if files[0].Path() != filepath.Join(dir, "000000010000000000000027") || Bytes(files) != 21 {
		t.Fatal("path or bytes")
	}
}

func TestStartSegmentFromBackupLabel(t *testing.T) {
	label := "START WAL LOCATION: 0/27000028 (file 000000010000000000000027)\nCHECKPOINT LOCATION: 0/27000080\nBACKUP METHOD: streamed\nLABEL: base-1\n"
	s, err := StartSegment([]byte(label))
	if err != nil || s.Name() != "000000010000000000000027" {
		t.Fatalf("s = %v err = %v", s, err)
	}
	if _, err := StartSegment([]byte("LABEL: x")); err == nil {
		t.Fatal("missing start must fail")
	}
}

func TestObsoleteOnlyDropsSentCompleteSegmentsBeforeTheBase(t *testing.T) {
	files := []File{
		{Name: "000000010000000000000025", Segment: Segment{1, 0, 0x25}},
		{Name: "000000010000000000000026", Segment: Segment{1, 0, 0x26}},
		{Name: "000000010000000000000027", Segment: Segment{1, 0, 0x27}},
		{Name: "000000010000000000000024", Segment: Segment{1, 0, 0x24}},
		{Name: "000000010000000000000023.partial", Segment: Segment{1, 0, 0x23}, Partial: true},
		{Name: "00000001.history", History: true},
	}
	sent := map[string]bool{"000000010000000000000025": true, "000000010000000000000027": true,
		"000000010000000000000023.partial": true, "00000001.history": true}
	got := Obsolete(files, sent, Segment{1, 0, 0x27})
	if !reflect.DeepEqual(names(got), []string{"000000010000000000000025"}) {
		t.Fatalf("got %v", names(got))
	}
}

func TestPromotePartials(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "000000010000000000000027", 4, time.Time{})
	write(t, dir, "000000010000000000000027.partial", 4, time.Time{})
	write(t, dir, "000000010000000000000028.partial", 4, time.Time{})
	promoted, err := PromotePartials(dir)
	if err != nil || !reflect.DeepEqual(promoted, []string{"000000010000000000000028"}) {
		t.Fatalf("promoted = %v err = %v", promoted, err)
	}
	files, _ := List(dir)
	if !reflect.DeepEqual(names(files), []string{"000000010000000000000027", "000000010000000000000028"}) {
		t.Fatalf("files = %v", names(files))
	}
}

func TestSegmentSizePrefersTheCommonPowerOfTwo(t *testing.T) {
	files := []File{{Name: "a", Size: 16 << 20}, {Name: "b", Size: 16 << 20}, {Name: "c", Size: 1000}, {Name: "d.partial", Size: 64 << 20, Partial: true}}
	if SegmentSize(files) != 16<<20 {
		t.Fatal("expected 16MiB")
	}
	if SegmentSize(nil) != DefaultSegSize {
		t.Fatal("default")
	}
}

func TestMissingFindsGapsUpToTheTarget(t *testing.T) {
	base := time.Date(2026, 11, 3, 1, 0, 0, 0, time.UTC)
	seg := func(n uint32, mod time.Time) File {
		s := Segment{1, 0, n}
		return File{Name: s.Name(), Segment: s, Size: 16 << 20, ModTime: mod}
	}
	start := Segment{1, 0, 0x27}
	full := []File{seg(0x26, base), seg(0x27, base), seg(0x28, base.Add(time.Hour)), seg(0x29, base.Add(2*time.Hour))}
	if m := Missing(full, start, time.Time{}, 5); len(m) != 0 {
		t.Fatalf("missing = %v", m)
	}
	gap := []File{seg(0x27, base), seg(0x29, base.Add(2*time.Hour)), seg(0x2B, base.Add(3*time.Hour))}
	if m := Missing(gap, start, time.Time{}, 5); !reflect.DeepEqual(m, []string{"0000000000000028", "000000000000002A"}) {
		t.Fatalf("missing = %v", m)
	}
	if m := Missing(gap, start, base.Add(30*time.Minute), 5); !reflect.DeepEqual(m, []string{"0000000000000028"}) {
		t.Fatalf("missing before target = %v", m)
	}
	if m := Missing(gap, start, time.Time{}, 1); len(m) != 1 {
		t.Fatalf("limit ignored: %v", m)
	}
	if m := Missing(nil, start, time.Time{}, 5); !reflect.DeepEqual(m, []string{"0000000000000027"}) {
		t.Fatalf("empty = %v", m)
	}
	switched := []File{seg(0x27, base), {Name: "000000020000000000000028", Segment: Segment{2, 0, 0x28}, Size: 16 << 20, ModTime: base}}
	if m := Missing(switched, start, time.Time{}, 5); len(m) != 0 {
		t.Fatalf("timeline switch = %v", m)
	}
}

func TestCollectFlattensRestoredFolders(t *testing.T) {
	root := t.TempDir()
	write(t, filepath.Join(root, "var/lib/olt-backup/wal"), "000000010000000000000028.partial", 1, time.Time{})
	write(t, filepath.Join(root, "var/lib/olt-backup/wal"), "000000010000000000000027", 1, time.Time{})
	write(t, filepath.Join(root, "var/lib/olt-backup/wal-detached-20261101T000000Z"), "000000010000000000000010", 1, time.Time{})
	write(t, filepath.Join(root, "var/lib/olt-backup/wal-detached-20261101T000000Z"), "000000010000000000000027", 2, time.Time{})
	write(t, filepath.Join(root, "var/lib/olt-backup/wal"), "ignore.me", 1, time.Time{})
	dst := filepath.Join(t.TempDir(), "restore_wal")
	n, err := Collect(root, dst)
	if err != nil || n != 3 {
		t.Fatalf("n = %d err = %v", n, err)
	}
	files, _ := List(dst)
	if !reflect.DeepEqual(names(files), []string{"000000010000000000000010", "000000010000000000000027", "000000010000000000000028.partial"}) {
		t.Fatalf("files = %v", names(files))
	}
	if files[1].Size != 1 {
		t.Fatal("the first copy found wins")
	}
}
