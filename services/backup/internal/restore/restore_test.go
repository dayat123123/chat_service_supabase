package restore

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/backup/internal/pg"
	"olt-social/backup/internal/restic"
	"olt-social/backup/internal/runner"
)

var t0 = time.Date(2026, 11, 3, 0, 0, 0, 0, time.UTC)

func snap(id string, at time.Duration, tags ...string) restic.Snapshot {
	paths := []string{"/var/lib/olt-backup/wal"}
	if tags[0] == restic.TagBase {
		paths = []string{"/var/lib/olt-backup/base/" + tags[1]}
	}
	return restic.Snapshot{ID: id, Time: t0.Add(at), Tags: tags, Paths: paths, Summary: &restic.SnapshotSummary{TotalBytesProcessed: 100}}
}

func catalog() []restic.Snapshot {
	return []restic.Snapshot{
		snap("b1", 0, "base", "base-1"),
		snap("w1", 30*time.Minute, "wal"),
		snap("f1", 31*time.Minute, "files"),
		snap("b2", 24*time.Hour, "base", "base-2"),
		snap("w2", 24*time.Hour+5*time.Minute, "wal"),
		snap("w3", 24*time.Hour+10*time.Minute, "wal"),
	}
}

func TestChooseLatest(t *testing.T) {
	p, err := Choose(catalog(), time.Time{})
	if err != nil || p.Base.ID != "b2" || p.WAL == nil || p.WAL.ID != "w3" || !p.Target.IsZero() || p.Bytes() != 200 {
		t.Fatalf("p = %+v err = %v", p, err)
	}
}

func TestChooseTargetPicksLatestBaseBeforeAndFirstWALAfter(t *testing.T) {
	cases := []struct {
		target   time.Duration
		base     string
		walAfter string
	}{
		{10 * time.Minute, "b1", "w1"},
		{24*time.Hour + time.Minute, "b2", "w2"},
		{24*time.Hour + 5*time.Minute, "b2", "w2"},
		{24*time.Hour + 6*time.Minute, "b2", "w3"},
		{12 * time.Hour, "b1", "w2"},
	}
	for _, c := range cases {
		p, err := Choose(catalog(), t0.Add(c.target))
		if err != nil || p.Base.ID != c.base || p.WAL.ID != c.walAfter {
			t.Errorf("target +%v: p = %+v err = %v", c.target, p, err)
		}
	}
}

func TestChooseRejectsTargetsOutsideCoverage(t *testing.T) {
	if _, err := Choose(catalog(), t0.Add(-time.Minute)); err == nil || !strings.Contains(err.Error(), "tidak ada base backup sebelum") {
		t.Fatalf("err = %v", err)
	}
	if _, err := Choose(catalog(), t0.Add(48*time.Hour)); err == nil || !strings.Contains(err.Error(), "melewati kiriman WAL terbaru") {
		t.Fatalf("err = %v", err)
	}
	if _, err := Choose(catalog()[1:3], time.Time{}); err == nil {
		t.Fatal("no base must fail")
	}
	p, err := Choose(catalog()[:1], time.Time{})
	if err != nil || p.WAL != nil {
		t.Fatalf("base only: p = %+v err = %v", p, err)
	}
}

type fakeRepo struct {
	mu    sync.Mutex
	calls []string
	files map[string]map[string]string
	fail  error
}

func (f *fakeRepo) Restore(_ context.Context, spec, target string) error {
	f.mu.Lock()
	f.calls = append(f.calls, spec+" -> "+target)
	f.mu.Unlock()
	if f.fail != nil {
		return f.fail
	}
	for name, content := range f.files[spec] {
		path := filepath.Join(target, name)
		_ = os.MkdirAll(filepath.Dir(path), 0o700)
		_ = os.WriteFile(path, []byte(content), 0o600)
	}
	return nil
}

func segment(n byte) string {
	return fmt.Sprintf("0000000100000000000000%02X", n)
}

func repoWith(walFiles map[string]string) *fakeRepo {
	base := map[string]string{
		"PG_VERSION":                "17",
		"backup_label":              "START WAL LOCATION: 0/27000028 (file 000000010000000000000027)\nLABEL: base-2\n",
		"pg_wal/" + segment(0x27):   strings.Repeat("w", 16),
		"postgresql.auto.conf":      "# auto\n",
		"base/1/1259":               "data",
		"pg_wal/archive_status/.ok": "",
	}
	return &fakeRepo{files: map[string]map[string]string{"b2:/var/lib/olt-backup/base/base-2": base, "w3": walFiles}}
}

func TestPrepareRestoresBaseAndWALAndChecksTheChain(t *testing.T) {
	repo := repoWith(map[string]string{
		"var/lib/olt-backup/wal/" + segment(0x27):                           strings.Repeat("w", 16),
		"var/lib/olt-backup/wal/" + segment(0x28):                           strings.Repeat("w", 16),
		"var/lib/olt-backup/wal/" + segment(0x29) + ".partial":              strings.Repeat("p", 16),
		"var/lib/olt-backup/wal-detached-20261101T000000Z/" + segment(0x10): strings.Repeat("o", 16),
		"var/lib/olt-backup/wal/00000002.history":                           "1\t0/28000000\tno recovery target specified\n",
	})
	plan, _ := Choose(catalog(), time.Time{})
	dir := filepath.Join(t.TempDir(), "data")
	out, err := Prepare(context.Background(), repo, plan, dir)
	if err != nil {
		t.Fatal(err)
	}
	if out.StartWAL != segment(0x27) || out.Segments != 5 || !reflect.DeepEqual(out.Promoted, []string{segment(0x29)}) || out.Bytes == 0 {
		t.Fatalf("out = %+v", out)
	}
	if !reflect.DeepEqual(repo.calls, []string{"b2:/var/lib/olt-backup/base/base-2 -> " + dir, "w3 -> " + filepath.Join(dir, stagingDir)}) {
		t.Fatalf("calls = %v", repo.calls)
	}
	if _, err := os.Stat(filepath.Join(dir, stagingDir)); !os.IsNotExist(err) {
		t.Fatal("staging folder must be removed")
	}
	if _, err := os.Stat(filepath.Join(dir, WALDir, segment(0x29))); err != nil {
		t.Fatal("partial segment must be promoted")
	}
	info, _ := os.Stat(dir)
	if info.Mode().Perm() != 0o700 {
		t.Fatalf("mode = %v", info.Mode())
	}
}

func TestPrepareFailsOnAWALGap(t *testing.T) {
	repo := repoWith(map[string]string{
		"var/lib/olt-backup/wal/" + segment(0x27): strings.Repeat("w", 16),
		"var/lib/olt-backup/wal/" + segment(0x29): strings.Repeat("w", 16),
	})
	plan, _ := Choose(catalog(), time.Time{})
	_, err := Prepare(context.Background(), repo, plan, filepath.Join(t.TempDir(), "data"))
	if err == nil || !strings.Contains(err.Error(), "rantai WAL terputus: segmen 0000000000000028") {
		t.Fatalf("err = %v", err)
	}
}

func TestPrepareRejectsNonBaseSnapshotsAndRestoreErrors(t *testing.T) {
	repo := &fakeRepo{files: map[string]map[string]string{}}
	plan, _ := Choose(catalog(), time.Time{})
	if _, err := Prepare(context.Background(), repo, plan, filepath.Join(t.TempDir(), "d")); err == nil || !strings.Contains(err.Error(), "backup_label") {
		t.Fatalf("err = %v", err)
	}
	repo.fail = errors.New("network down")
	if _, err := Prepare(context.Background(), repo, plan, filepath.Join(t.TempDir(), "d")); err == nil || !strings.Contains(err.Error(), "network down") {
		t.Fatalf("err = %v", err)
	}
}

func TestEnsureEmpty(t *testing.T) {
	root := t.TempDir()
	if err := EnsureEmpty(filepath.Join(root, "new"), false); err != nil {
		t.Fatal(err)
	}
	full := filepath.Join(root, "full")
	_ = os.MkdirAll(filepath.Join(full, "base"), 0o700)
	_ = os.WriteFile(filepath.Join(full, "PG_VERSION"), []byte("17"), 0o600)
	if err := EnsureEmpty(full, false); err == nil || !strings.Contains(err.Error(), "--wipe") {
		t.Fatalf("err = %v", err)
	}
	_ = os.WriteFile(filepath.Join(full, "postmaster.pid"), []byte("1"), 0o600)
	if err := EnsureEmpty(full, true); err == nil || !strings.Contains(err.Error(), "postmaster.pid") {
		t.Fatalf("err = %v", err)
	}
	_ = os.Remove(filepath.Join(full, "postmaster.pid"))
	if err := EnsureEmpty(full, true); err != nil {
		t.Fatal(err)
	}
	if entries, _ := os.ReadDir(full); len(entries) != 0 {
		t.Fatalf("entries = %v", entries)
	}
}

func TestWriteRecovery(t *testing.T) {
	dir := t.TempDir()
	_ = os.WriteFile(filepath.Join(dir, "postgresql.auto.conf"), []byte("# Do not edit this file manually!\n"), 0o600)
	target := time.Date(2026, 11, 3, 10, 0, 0, 0, time.FixedZone("WIB", 7*3600))
	if err := WriteRecovery(dir, target); err != nil {
		t.Fatal(err)
	}
	conf, _ := os.ReadFile(filepath.Join(dir, "postgresql.auto.conf"))
	want := "# Do not edit this file manually!\n\nrestore_command = '[ -f restore_wal/%f ] && cp restore_wal/%f %p'\n" +
		"recovery_target_timeline = 'latest'\nrecovery_target_action = 'promote'\nrecovery_target_time = '2026-11-03 03:00:00+00'\n"
	if string(conf) != want {
		t.Fatalf("conf = %q", conf)
	}
	if _, err := os.Stat(filepath.Join(dir, "recovery.signal")); err != nil {
		t.Fatal("recovery.signal missing")
	}
	if lines := RecoverySettings(time.Time{}); len(lines) != 3 || strings.Contains(strings.Join(lines, "\n"), "recovery_target_time =") {
		t.Fatalf("latest = %v", lines)
	}
	if quote("it's") != "'it''s'" {
		t.Fatal("quote")
	}
}

func TestParseOwnerAndTarget(t *testing.T) {
	if uid, gid, err := ParseOwner("100:101"); err != nil || uid != 100 || gid != 101 {
		t.Fatal("owner")
	}
	for _, bad := range []string{"100", "a:b", "-1:2", ""} {
		if _, _, err := ParseOwner(bad); err == nil {
			t.Fatalf("%q accepted", bad)
		}
	}
	if tt, err := ParseTarget("latest"); err != nil || !tt.IsZero() {
		t.Fatal("latest")
	}
	if tt, err := ParseTarget("2026-11-03T10:00:00+07:00"); err != nil || !tt.Equal(time.Date(2026, 11, 3, 3, 0, 0, 0, time.UTC)) {
		t.Fatal("rfc3339")
	}
	if _, err := ParseTarget("yesterday"); err == nil {
		t.Fatal("bad target accepted")
	}
}

func TestChownWalksTheTree(t *testing.T) {
	dir := t.TempDir()
	_ = os.MkdirAll(filepath.Join(dir, "a"), 0o700)
	_ = os.WriteFile(filepath.Join(dir, "a", "f"), nil, 0o600)
	if err := Chown(dir, os.Getuid(), os.Getgid()); err != nil {
		t.Fatal(err)
	}
}

type fakeServer struct {
	mu        sync.Mutex
	polls     int
	readyAt   int
	counts    string
	queries   []string
	stopped   bool
	proc      *fakeProc
	startErr  error
	exitEarly bool
}

type fakeProc struct {
	done chan struct{}
	once sync.Once
}

func (p *fakeProc) Done() <-chan struct{} { return p.done }
func (p *fakeProc) Wait() error           { <-p.done; return nil }
func (p *fakeProc) Interrupt()            { p.once.Do(func() { close(p.done) }) }

func (f *fakeServer) StartServer(context.Context, pg.LocalServer) (runner.Process, error) {
	if f.startErr != nil {
		return nil, f.startErr
	}
	f.proc = &fakeProc{done: make(chan struct{})}
	if f.exitEarly {
		f.proc.Interrupt()
	}
	return f.proc, nil
}

func (f *fakeServer) Query(_ context.Context, _ pg.LocalServer, user, sql string) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.queries = append(f.queries, user)
	if user != "supabase_admin" {
		return "", errors.New(`role "postgres" is not allowed`)
	}
	if strings.Contains(sql, "pg_is_in_recovery") {
		f.polls++
		if f.polls < f.readyAt {
			return "", errors.New("the database system is starting up")
		}
		return "f", nil
	}
	return f.counts, nil
}

func (f *fakeServer) StopServer(context.Context, pg.LocalServer) error {
	f.mu.Lock()
	f.stopped = true
	f.mu.Unlock()
	f.proc.Interrupt()
	return nil
}

func TestProbeWaitsForPromotionThenCounts(t *testing.T) {
	f := &fakeServer{readyAt: 3, counts: `{"recovered_until":"2026-11-03T01:33:53.17735+00:00","last_message_at":"2026-11-02T10:00:00+00:00","tables":{"public.profiles":12,"public.messages":340,"cs.tickets":7}}`}
	out, err := Probe(context.Background(), f, NewServer(t.TempDir()), time.Millisecond)
	if err != nil {
		t.Fatal(err)
	}
	if out.Tables["public.messages"] != 340 || out.Tables["cs.tickets"] != 7 || out.RecoveredUntil == nil ||
		!out.RecoveredUntil.Equal(time.Date(2026, 11, 3, 1, 33, 53, 177350000, time.UTC)) || out.LastMessageAt == nil {
		t.Fatalf("out = %+v", out)
	}
	if !f.stopped || f.polls != 3 {
		t.Fatalf("stopped = %v polls = %d", f.stopped, f.polls)
	}
}

func TestProbeReportsEarlyExitWithLogTail(t *testing.T) {
	srv := NewServer(t.TempDir())
	_ = os.MkdirAll(filepath.Dir(srv.LogFile), 0o700)
	_ = os.WriteFile(srv.LogFile, []byte("LOG: starting\nFATAL:  recovery ended before configured recovery target was reached\n"), 0o600)
	f := &fakeServer{readyAt: 1000, exitEarly: true}
	_, err := Probe(context.Background(), f, srv, time.Millisecond)
	if err == nil || !strings.Contains(err.Error(), "recovery ended before configured recovery target") {
		t.Fatalf("err = %v", err)
	}
}

func TestProbeHonoursTheDeadline(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Millisecond)
	defer cancel()
	f := &fakeServer{readyAt: 1 << 30}
	_, err := Probe(ctx, f, NewServer(t.TempDir()), time.Millisecond)
	if err == nil || !strings.Contains(err.Error(), "batas waktu") || !f.stopped {
		t.Fatalf("err = %v stopped = %v", err, f.stopped)
	}
	f = &fakeServer{startErr: errors.New("no postgres")}
	if _, err := Probe(context.Background(), f, NewServer(t.TempDir()), time.Millisecond); err == nil {
		t.Fatal("start error must fail")
	}
}

func TestWriteServerConfigAndLogTail(t *testing.T) {
	srv := NewServer(t.TempDir())
	if err := WriteServerConfig(srv); err != nil {
		t.Fatal(err)
	}
	hba, _ := os.ReadFile(srv.HBAFile())
	if string(hba) != "local all all trust\n" {
		t.Fatalf("hba = %q", hba)
	}
	if info, err := os.Stat(srv.SocketDir); err != nil || info.Mode().Perm() != 0o700 {
		t.Fatal("socket dir")
	}
	if LogTail(filepath.Join(t.TempDir(), "none"), 3) != "log tidak tersedia" {
		t.Fatal("missing log")
	}
	big := filepath.Join(t.TempDir(), "big.log")
	_ = os.WriteFile(big, []byte(strings.Repeat("noise line\n", 2000)+"last line\n"), 0o600)
	if got := LogTail(big, 1); got != "last line" {
		t.Fatalf("tail = %q", got)
	}
}
