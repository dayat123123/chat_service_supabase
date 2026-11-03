package pg

import (
	"context"
	"reflect"
	"slices"
	"strings"
	"testing"

	"olt-social/backup/internal/runner"
	"olt-social/backup/internal/runner/runnertest"
)

func tools(f *runnertest.Fake) Tools {
	return Tools{Runner: f, Base: []string{"PATH=/usr/bin", "TZ=UTC"},
		Conn: Conn{Host: "db", Port: 5432, User: "olt_backup", Password: "db-pw-secret", Database: "postgres"}}
}

func reply(out string) func(runner.Cmd) runnertest.Reply {
	return func(runner.Cmd) runnertest.Reply { return runnertest.Reply{Stdout: out} }
}

func noSecretInArgs(t *testing.T, calls []runner.Cmd) {
	t.Helper()
	for _, call := range calls {
		for _, arg := range call.Args {
			if strings.Contains(arg, "db-pw-secret") {
				t.Fatalf("password in argv of %s", call.Name)
			}
		}
	}
}

func TestConnEnvCarriesThePassword(t *testing.T) {
	env := Conn{Host: "db", Port: 5432, User: "olt_backup", Password: "pw", Database: "postgres"}.Env()
	want := []string{"PGHOST=db", "PGPORT=5432", "PGUSER=olt_backup", "PGPASSWORD=pw", "PGDATABASE=postgres", "PGAPPNAME=olt-backup", "PGCONNECT_TIMEOUT=10"}
	if !reflect.DeepEqual(env, want) {
		t.Fatalf("env = %v", env)
	}
}

func TestReceiverCommand(t *testing.T) {
	f := &runnertest.Fake{}
	tl := tools(f)
	cmd := tl.ReceiverCmd("/var/lib/olt-backup/wal")
	want := []string{"--directory=/var/lib/olt-backup/wal", "--slot=olt_backup", "--no-loop", "--no-password", "--verbose", "--status-interval=10"}
	if cmd.Name != "pg_receivewal" || !reflect.DeepEqual(cmd.Args, want) {
		t.Fatalf("cmd = %v", cmd)
	}
	if !slices.Contains(cmd.Env, "PGPASSWORD=db-pw-secret") || !slices.Contains(cmd.Env, "PATH=/usr/bin") {
		t.Fatalf("env = %v", cmd.Env)
	}
	_ = tl.CreateSlot(context.Background())
	_ = tl.DropSlot(context.Background())
	calls := f.Recorded()
	if !reflect.DeepEqual(calls[0].Args, []string{"--slot=olt_backup", "--create-slot", "--if-not-exists", "--no-password"}) ||
		!reflect.DeepEqual(calls[1].Args, []string{"--slot=olt_backup", "--drop-slot", "--no-password"}) {
		t.Fatalf("calls = %v", calls)
	}
	noSecretInArgs(t, calls)
}

func TestBaseBackupAndVerifyCommands(t *testing.T) {
	f := &runnertest.Fake{}
	tl := tools(f)
	_ = tl.BaseBackup(context.Background(), "/data/base/base-1", "base-1")
	_ = tl.VerifyBackup(context.Background(), "/restore/data", "restore_wal")
	calls := f.Recorded()
	wantBase := []string{"--pgdata=/data/base/base-1", "--format=plain", "--wal-method=stream", "--checkpoint=fast",
		"--manifest-checksums=SHA256", "--label=base-1", "--no-password"}
	if calls[0].Name != "pg_basebackup" || !reflect.DeepEqual(calls[0].Args, wantBase) {
		t.Fatalf("base = %v", calls[0])
	}
	if calls[1].Name != "pg_verifybackup" || !reflect.DeepEqual(calls[1].Args, []string{"--ignore=restore_wal", "/restore/data"}) {
		t.Fatalf("verify = %v", calls[1])
	}
	if slices.ContainsFunc(calls[1].Env, func(s string) bool { return strings.HasPrefix(s, "PGPASSWORD") }) {
		t.Fatal("pg_verifybackup does not need the password")
	}
	noSecretInArgs(t, calls)
}

func TestSlotStatusParsing(t *testing.T) {
	cases := map[string]SlotStatus{
		"":                {},
		"reserved|t|t":    {Exists: true, WALStatus: "reserved", Active: true, Reserved: true},
		"lost|f|t":        {Exists: true, WALStatus: "lost", Reserved: true},
		"|f|f":            {Exists: true},
		"unreserved|t|t ": {Exists: true, WALStatus: "unreserved", Active: true, Reserved: true},
	}
	for out, want := range cases {
		got, err := ParseSlot(out)
		if err != nil || got != want {
			t.Fatalf("%q: got %+v err %v", out, got, err)
		}
	}
	if s, _ := ParseSlot("lost|f|t"); !s.Lost() || s.AtRisk() {
		t.Fatal("lost")
	}
	if s, _ := ParseSlot("unreserved|t|t"); !s.AtRisk() || s.Lost() {
		t.Fatal("at risk")
	}
	if _, err := ParseSlot("garbage"); err == nil {
		t.Fatal("garbage must fail")
	}
}

func TestSlotQueryUsesNormalConnection(t *testing.T) {
	f := &runnertest.Fake{Respond: reply("reserved|t|t\n")}
	s, err := tools(f).Slot(context.Background())
	if err != nil || !s.Exists || !s.Active {
		t.Fatalf("s = %+v err = %v", s, err)
	}
	call := f.Recorded()[0]
	if call.Name != "psql" || !slices.Contains(call.Args, slotSQL) || slices.Contains(call.Args, "replication=true") {
		t.Fatalf("call = %v", call)
	}
}

func TestIdentifyUsesReplicationConnection(t *testing.T) {
	f := &runnertest.Fake{Respond: reply("7702039750691532834|1|0/2678D118|\n")}
	sys, err := tools(f).Identify(context.Background())
	if err != nil || sys != (System{ID: "7702039750691532834", Timeline: 1, LSN: "0/2678D118"}) {
		t.Fatalf("sys = %+v err = %v", sys, err)
	}
	if args := f.Recorded()[0].Args; !slices.Contains(args, "dbname=postgres replication=true") || !slices.Contains(args, "IDENTIFY_SYSTEM") {
		t.Fatalf("args = %v", args)
	}
	if _, err := ParseIdentify("x"); err == nil {
		t.Fatal("bad reply must fail")
	}
}

func TestDatabaseBytes(t *testing.T) {
	f := &runnertest.Fake{Respond: reply("49854758\n")}
	n, err := tools(f).DatabaseBytes(context.Background())
	if err != nil || n != 49854758 {
		t.Fatalf("n = %d err = %v", n, err)
	}
	f = &runnertest.Fake{Respond: reply("nope")}
	if _, err := tools(f).DatabaseBytes(context.Background()); err == nil {
		t.Fatal("bad number must fail")
	}
}

func TestLocalServerIsSocketOnlyWithoutPreloadLibraries(t *testing.T) {
	s := LocalServer{DataDir: "/x/data", ConfigDir: "/x/conf", SocketDir: "/x/sock", LogFile: "/x/server.log", Port: 5432}
	cmd := s.Cmd([]string{"PATH=/usr/bin"})
	if cmd.Name != "postgres" || cmd.LogFile != "/x/server.log" || cmd.Args[0] != "-D" || cmd.Args[1] != "/x/data" {
		t.Fatalf("cmd = %v", cmd)
	}
	settings := map[string]string{}
	for i := 2; i < len(cmd.Args); i += 2 {
		if cmd.Args[i] != "-c" {
			t.Fatalf("arg %d = %q", i, cmd.Args[i])
		}
		k, v, _ := strings.Cut(cmd.Args[i+1], "=")
		settings[k] = v
	}
	want := map[string]string{
		"listen_addresses": "", "unix_socket_directories": "/x/sock", "shared_preload_libraries": "",
		"session_preload_libraries": "", "config_file": "/x/conf/postgresql.conf", "hba_file": "/x/conf/pg_hba.conf",
		"restore_command": RestoreCommand, "recovery_target_action": "promote", "hot_standby": "off", "archive_mode": "off",
	}
	for k, v := range want {
		if got, ok := settings[k]; !ok || got != v {
			t.Fatalf("%s = %q (present %v), want %q", k, got, ok, v)
		}
	}
	f := &runnertest.Fake{Respond: reply("f\n")}
	tl := tools(f)
	out, err := tl.Query(context.Background(), s, "supabase_admin", "select pg_is_in_recovery()")
	if err != nil || out != "f" {
		t.Fatalf("out = %q err = %v", out, err)
	}
	_ = tl.StopServer(context.Background(), s)
	calls := f.Recorded()
	if !slices.Contains(calls[0].Args, "/x/sock") || slices.ContainsFunc(calls[0].Env, func(e string) bool { return strings.HasPrefix(e, "PGPASSWORD") }) {
		t.Fatalf("query = %v", calls[0])
	}
	if calls[1].Name != "pg_ctl" || !reflect.DeepEqual(calls[1].Args, []string{"--pgdata=/x/data", "--mode=fast", "--wait", "--timeout=120", "stop"}) {
		t.Fatalf("stop = %v", calls[1])
	}
	if _, err := tl.Query(context.Background(), s, "x; drop", "select 1"); err == nil {
		t.Fatal("role name must be validated")
	}
}
