package restic

import (
	"context"
	"errors"
	"reflect"
	"slices"
	"strings"
	"testing"
	"time"

	"olt-social/backup/internal/runner"
	"olt-social/backup/internal/runner/runnertest"
)

func client(f *runnertest.Fake) *Client {
	creds := Credentials{Repository: "s3:http://s3:8333/bucket/dev", Password: "restic-pass", AccessKeyID: "key", SecretAccessKey: "secret-key", Region: "id-jkt-1"}
	return &Client{Runner: f, Env: append([]string{"PATH=/usr/bin"}, creds.Env()...), RetryLock: 5 * time.Minute}
}

func exit(code int) error {
	return &runner.ExitError{Name: "restic", Code: code, Stderr: "Fatal: something"}
}

func TestCredentialsEnvPassesSecretsOnlyThroughEnvironment(t *testing.T) {
	f := &runnertest.Fake{}
	c := client(f)
	_ = c.Open(context.Background())
	call := f.Recorded()[0]
	if !reflect.DeepEqual(call.Args, []string{"--retry-lock", "5m0s", "cat", "config", "--no-lock"}) {
		t.Fatalf("args = %v", call.Args)
	}
	for _, arg := range call.Args {
		if strings.Contains(arg, "restic-pass") || strings.Contains(arg, "secret-key") {
			t.Fatal("secret leaked into argv")
		}
	}
	for _, want := range []string{"RESTIC_REPOSITORY=s3:http://s3:8333/bucket/dev", "RESTIC_PASSWORD=restic-pass",
		"AWS_ACCESS_KEY_ID=key", "AWS_SECRET_ACCESS_KEY=secret-key", "AWS_DEFAULT_REGION=id-jkt-1"} {
		if !slices.Contains(call.Env, want) {
			t.Fatalf("env misses %s", want)
		}
	}
	if slices.ContainsFunc((Credentials{Repository: "r"}).Env(), func(s string) bool { return strings.HasPrefix(s, "AWS_DEFAULT_REGION") }) {
		t.Fatal("empty region must not be exported")
	}
}

func TestOpenClassifiesResticExitCodes(t *testing.T) {
	cases := map[int]error{10: ErrNoRepository, 11: ErrLocked, 12: ErrWrongPassword}
	for code, want := range cases {
		f := &runnertest.Fake{Respond: func(runner.Cmd) runnertest.Reply { return runnertest.Reply{Err: exit(code)} }}
		if err := client(f).Open(context.Background()); !errors.Is(err, want) {
			t.Fatalf("code %d: err = %v", code, err)
		}
	}
	f := &runnertest.Fake{Respond: func(runner.Cmd) runnertest.Reply { return runnertest.Reply{Err: exit(1)} }}
	if err := client(f).Open(context.Background()); err == nil || errors.Is(err, ErrNoRepository) {
		t.Fatalf("err = %v", err)
	}
}

func TestBackupBuildsArgumentsAndParsesSummary(t *testing.T) {
	out := `{"message_type":"status","percent_done":0.5}
{"message_type":"summary","snapshot_id":"abc123","files_new":3,"data_added":2048,"total_files_processed":10,"total_bytes_processed":4096}`
	f := &runnertest.Fake{Respond: func(runner.Cmd) runnertest.Reply { return runnertest.Reply{Stdout: out} }}
	sum, err := client(f).Backup(context.Background(), BackupRequest{Paths: []string{"/data/base/base-1"}, Tags: []string{"base", "base-1"}})
	if err != nil {
		t.Fatal(err)
	}
	if sum.SnapshotID != "abc123" || sum.DataAdded != 2048 || sum.TotalBytesProcessed != 4096 || sum.TotalFilesProcessed != 10 {
		t.Fatalf("summary = %+v", sum)
	}
	want := []string{"--retry-lock", "5m0s", "backup", "--json", "--quiet", "--host", "olt-social", "--tag", "base", "--tag", "base-1", "/data/base/base-1"}
	if got := f.Recorded()[0].Args; !reflect.DeepEqual(got, want) {
		t.Fatalf("args = %v", got)
	}
}

func TestBackupReportsIncompleteSnapshots(t *testing.T) {
	f := &runnertest.Fake{Respond: func(runner.Cmd) runnertest.Reply {
		return runnertest.Reply{Stdout: `{"message_type":"summary","snapshot_id":"partial1"}`, Err: exit(3)}
	}}
	sum, err := client(f).Backup(context.Background(), BackupRequest{Paths: []string{"/mnt/storage"}, Tags: []string{"files"}})
	if !errors.Is(err, ErrIncomplete) || sum.SnapshotID != "partial1" {
		t.Fatalf("sum = %+v err = %v", sum, err)
	}
	f = &runnertest.Fake{Respond: func(runner.Cmd) runnertest.Reply { return runnertest.Reply{Stdout: "{}"} }}
	if _, err := client(f).Backup(context.Background(), BackupRequest{Paths: []string{"/x"}}); err == nil {
		t.Fatal("missing summary must fail")
	}
	if _, err := client(f).Backup(context.Background(), BackupRequest{}); err == nil {
		t.Fatal("no paths must fail")
	}
}

func TestSnapshotsParsesAndSortsByTime(t *testing.T) {
	out := `[{"id":"bbbbbbbbbbbb","short_id":"bbbbbbbb","time":"2026-11-03T09:00:00+07:00","paths":["/var/lib/olt-backup/wal"],"tags":["wal"],"hostname":"olt-social"},
{"id":"aaaaaaaaaaaa","time":"2026-11-03T01:00:00Z","paths":["/var/lib/olt-backup/base/base-20261103T010000Z"],"tags":["base","base-20261103T010000Z"],"summary":{"total_bytes_processed":52428800}}]`
	f := &runnertest.Fake{Respond: func(runner.Cmd) runnertest.Reply { return runnertest.Reply{Stdout: out} }}
	snaps, err := client(f).Snapshots(context.Background(), "")
	if err != nil {
		t.Fatal(err)
	}
	if len(snaps) != 2 || snaps[0].ID != "aaaaaaaaaaaa" || snaps[1].ID != "bbbbbbbbbbbb" {
		t.Fatalf("snaps = %+v", snaps)
	}
	if !snaps[0].Has(TagBase) || snaps[0].Label() != "base-20261103T010000Z" || snaps[0].Bytes() != 52428800 || snaps[0].Short() != "aaaaaaaa" {
		t.Fatalf("base = %+v", snaps[0])
	}
	if snaps[1].Label() != "" || snaps[1].Bytes() != 0 || snaps[1].Short() != "bbbbbbbb" {
		t.Fatalf("wal = %+v", snaps[1])
	}
	if got := f.Recorded()[0].Args; !reflect.DeepEqual(got, []string{"--retry-lock", "5m0s", "snapshots", "--json", "--no-lock"}) {
		t.Fatalf("args = %v", got)
	}
	f = &runnertest.Fake{Respond: func(runner.Cmd) runnertest.Reply { return runnertest.Reply{Stdout: "null"} }}
	if snaps, err := client(f).Snapshots(context.Background(), TagWAL); err != nil || len(snaps) != 0 {
		t.Fatalf("snaps = %v err = %v", snaps, err)
	}
	if got := f.Recorded()[0].Args; got[len(got)-1] != "wal" {
		t.Fatalf("args = %v", got)
	}
}

func TestForgetBuildsRetentionFlags(t *testing.T) {
	cases := []struct {
		policy Policy
		want   []string
	}{
		{Policy{Tag: "base", KeepDaily: 7, KeepWeekly: 4, KeepMonthly: 6},
			[]string{"forget", "--json", "--host", "olt-social", "--group-by", "host", "--tag", "base", "--keep-daily", "7", "--keep-weekly", "4", "--keep-monthly", "6"}},
		{Policy{Tag: "files", KeepDaily: 3},
			[]string{"forget", "--json", "--host", "olt-social", "--group-by", "host", "--tag", "files", "--keep-daily", "3"}},
		{Policy{Tag: "wal", KeepWithin: "7d"},
			[]string{"forget", "--json", "--host", "olt-social", "--group-by", "host", "--tag", "wal", "--keep-within", "7d"}},
	}
	for _, c := range cases {
		if got := ForgetArgs(c.policy); !reflect.DeepEqual(got, c.want) {
			t.Fatalf("args = %v\nwant %v", got, c.want)
		}
	}
}

func TestForgetCountsRemovedSnapshots(t *testing.T) {
	out := `[{"host":"olt-social","keep":[{"id":"1"}],"remove":[{"id":"2"},{"id":"3"}]},{"keep":[],"remove":null}]`
	f := &runnertest.Fake{Respond: func(runner.Cmd) runnertest.Reply { return runnertest.Reply{Stdout: out} }}
	n, err := client(f).Forget(context.Background(), Policy{Tag: "wal", KeepWithin: "7d"})
	if err != nil || n != 2 {
		t.Fatalf("n = %d err = %v", n, err)
	}
	if _, err := client(f).Forget(context.Background(), Policy{Tag: "wal"}); err == nil {
		t.Fatal("a policy without keep rules would delete everything")
	}
}

func TestOtherCommands(t *testing.T) {
	f := &runnertest.Fake{}
	c := client(f)
	c.NoCache = true
	c.RetryLock = 0
	ctx := context.Background()
	_ = c.Init(ctx)
	_ = c.Unlock(ctx)
	_ = c.Prune(ctx)
	_ = c.Check(ctx, "2%")
	_ = c.Restore(ctx, "abc:/var/lib/olt-backup/base/base-1", "/restore")
	var got [][]string
	for _, call := range f.Recorded() {
		got = append(got, call.Args)
	}
	want := [][]string{
		{"--no-cache", "init"},
		{"--no-cache", "unlock"},
		{"--no-cache", "prune"},
		{"--no-cache", "check", "--read-data-subset=2%"},
		{"--no-cache", "restore", "abc:/var/lib/olt-backup/base/base-1", "--target", "/restore"},
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v", got)
	}
}

func TestFromEnvRequiresRepositoryAndPassword(t *testing.T) {
	env := map[string]string{"RESTIC_REPOSITORY": "s3:https://s3/b", "RESTIC_PASSWORD_FILE": "/run/secrets/pw", "AWS_ACCESS_KEY_ID": "k", "HOME": "/root"}
	got, err := FromEnv(func(k string) string { return env[k] })
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, []string{"RESTIC_REPOSITORY=s3:https://s3/b", "RESTIC_PASSWORD_FILE=/run/secrets/pw", "AWS_ACCESS_KEY_ID=k"}) {
		t.Fatalf("env = %v", got)
	}
	_, err = FromEnv(func(string) string { return "" })
	if err == nil || !strings.Contains(err.Error(), "RESTIC_REPOSITORY") || !strings.Contains(err.Error(), "RESTIC_PASSWORD") {
		t.Fatalf("err = %v", err)
	}
}

func TestMissingBucketCountsAsMissingRepository(t *testing.T) {
	stuck := &runner.StopError{Name: "restic", Cause: context.DeadlineExceeded, Stderr: "Is there a repository at the following location? | s3:http://s3/b",
		Output: "Stat(<config/>) returned error, retrying after 4s: Stat: The specified bucket does not exist\nIs there a repository at the following location?\ns3:http://s3/b\n"}
	f := &runnertest.Fake{Respond: func(runner.Cmd) runnertest.Reply { return runnertest.Reply{Err: stuck} }}
	if err := client(f).Open(context.Background()); !errors.Is(err, ErrNoRepository) {
		t.Fatalf("err = %v", err)
	}
	other := &runner.StopError{Name: "restic", Cause: context.DeadlineExceeded, Output: "dial tcp: lookup s3: no such host"}
	f = &runnertest.Fake{Respond: func(runner.Cmd) runnertest.Reply { return runnertest.Reply{Err: other} }}
	if err := client(f).Open(context.Background()); errors.Is(err, ErrNoRepository) || !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("err = %v", err)
	}
}
