package pg

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"olt-social/backup/internal/runner"
)

const Slot = "olt_backup"

type Conn struct {
	Host     string
	Port     int
	User     string
	Password string
	Database string
	AppName  string
}

func (c Conn) Env() []string {
	app := c.AppName
	if app == "" {
		app = "olt-backup"
	}
	return []string{
		"PGHOST=" + c.Host,
		"PGPORT=" + strconv.Itoa(c.Port),
		"PGUSER=" + c.User,
		"PGPASSWORD=" + c.Password,
		"PGDATABASE=" + c.Database,
		"PGAPPNAME=" + app,
		"PGCONNECT_TIMEOUT=10",
	}
}

type Tools struct {
	Runner runner.Runner
	Base   []string
	Conn   Conn
}

func (t Tools) remote(name string, args ...string) runner.Cmd {
	return runner.Cmd{Name: name, Args: args, Env: runner.Env(t.Base, t.Conn.Env()...)}
}

func (t Tools) query(ctx context.Context, sql string, extra ...string) (string, error) {
	args := append([]string{"-X", "-A", "-t", "-q", "-v", "ON_ERROR_STOP=1"}, extra...)
	args = append(args, "-c", sql)
	res, err := t.Runner.Run(ctx, t.remote("psql", args...))
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(res.Stdout)), nil
}

type System struct {
	ID       string
	Timeline int
	LSN      string
}

func (t Tools) Identify(ctx context.Context) (System, error) {
	out, err := t.query(ctx, "IDENTIFY_SYSTEM", "-d", fmt.Sprintf("dbname=%s replication=true", t.Conn.Database))
	if err != nil {
		return System{}, err
	}
	return ParseIdentify(out)
}

func ParseIdentify(out string) (System, error) {
	fields := strings.Split(strings.TrimSpace(out), "|")
	if len(fields) < 3 || fields[0] == "" {
		return System{}, fmt.Errorf("unexpected IDENTIFY_SYSTEM reply %q", out)
	}
	tli, err := strconv.Atoi(fields[1])
	if err != nil {
		return System{}, fmt.Errorf("unexpected timeline %q", fields[1])
	}
	return System{ID: fields[0], Timeline: tli, LSN: fields[2]}, nil
}

type SlotStatus struct {
	Exists    bool
	WALStatus string
	Active    bool
	Reserved  bool
}

func (s SlotStatus) Lost() bool {
	return s.Exists && s.WALStatus == "lost"
}

func (s SlotStatus) AtRisk() bool {
	return s.Exists && s.WALStatus == "unreserved"
}

const slotSQL = "select coalesce(wal_status, ''), active, restart_lsn is not null from pg_catalog.pg_replication_slots where slot_name = '" + Slot + "'"

func (t Tools) Slot(ctx context.Context) (SlotStatus, error) {
	out, err := t.query(ctx, slotSQL, "-F", "|")
	if err != nil {
		return SlotStatus{}, err
	}
	return ParseSlot(out)
}

func ParseSlot(out string) (SlotStatus, error) {
	out = strings.TrimSpace(out)
	if out == "" {
		return SlotStatus{}, nil
	}
	fields := strings.Split(out, "|")
	if len(fields) != 3 {
		return SlotStatus{}, fmt.Errorf("unexpected slot row %q", out)
	}
	return SlotStatus{Exists: true, WALStatus: fields[0], Active: fields[1] == "t", Reserved: fields[2] == "t"}, nil
}

func (t Tools) DatabaseBytes(ctx context.Context) (int64, error) {
	out, err := t.query(ctx, "select coalesce(sum(pg_catalog.pg_database_size(oid)), 0)::bigint from pg_catalog.pg_database where datallowconn")
	if err != nil {
		return 0, err
	}
	n, err := strconv.ParseInt(out, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("unexpected database size %q", out)
	}
	return n, nil
}

func (t Tools) CreateSlot(ctx context.Context) error {
	_, err := t.Runner.Run(ctx, t.remote("pg_receivewal", "--slot="+Slot, "--create-slot", "--if-not-exists", "--no-password"))
	return err
}

func (t Tools) DropSlot(ctx context.Context) error {
	_, err := t.Runner.Run(ctx, t.remote("pg_receivewal", "--slot="+Slot, "--drop-slot", "--no-password"))
	return err
}

func (t Tools) ReceiverCmd(dir string) runner.Cmd {
	return t.remote("pg_receivewal", "--directory="+dir, "--slot="+Slot, "--no-loop", "--no-password", "--verbose", "--status-interval=10")
}

func (t Tools) StartReceiver(ctx context.Context, dir string, line func(string)) (runner.Process, error) {
	return t.Runner.Start(ctx, t.ReceiverCmd(dir), line)
}

func BaseBackupArgs(dir, label string) []string {
	return []string{"--pgdata=" + dir, "--format=plain", "--wal-method=stream", "--checkpoint=fast",
		"--manifest-checksums=SHA256", "--label=" + label, "--no-password"}
}

func (t Tools) BaseBackup(ctx context.Context, dir, label string) error {
	_, err := t.Runner.Run(ctx, t.remote("pg_basebackup", BaseBackupArgs(dir, label)...))
	return err
}

func (t Tools) VerifyBackup(ctx context.Context, dir string, ignore ...string) error {
	var args []string
	for _, name := range ignore {
		args = append(args, "--ignore="+name)
	}
	args = append(args, dir)
	_, err := t.Runner.Run(ctx, runner.Cmd{Name: "pg_verifybackup", Args: args, Env: t.Base})
	return err
}

type LocalServer struct {
	DataDir   string
	ConfigDir string
	SocketDir string
	LogFile   string
	Port      int
}

func (s LocalServer) ConfigFile() string { return filepath.Join(s.ConfigDir, "postgresql.conf") }
func (s LocalServer) HBAFile() string    { return filepath.Join(s.ConfigDir, "pg_hba.conf") }
func (s LocalServer) IdentFile() string  { return filepath.Join(s.ConfigDir, "pg_ident.conf") }

const RestoreCommand = "[ -f restore_wal/%f ] && cp restore_wal/%f %p"

func (s LocalServer) Settings() []string {
	return []string{
		"config_file=" + s.ConfigFile(),
		"hba_file=" + s.HBAFile(),
		"ident_file=" + s.IdentFile(),
		"listen_addresses=",
		"unix_socket_directories=" + s.SocketDir,
		"unix_socket_permissions=0700",
		"port=" + strconv.Itoa(s.Port),
		"shared_preload_libraries=",
		"session_preload_libraries=",
		"local_preload_libraries=",
		"restore_command=" + RestoreCommand,
		"recovery_target_timeline=latest",
		"recovery_target_action=promote",
		"hot_standby=off",
		"archive_mode=off",
		"wal_level=replica",
		"max_wal_senders=0",
		"max_replication_slots=0",
		"autovacuum=off",
		"jit=off",
		"fsync=off",
		"synchronous_commit=off",
		"shared_buffers=64MB",
		"max_connections=20",
		"max_wal_size=1GB",
		"dynamic_shared_memory_type=mmap",
		"logging_collector=off",
		"log_destination=stderr",
		"cluster_name=olt-restore-test",
		"timezone=UTC",
		"log_timezone=UTC",
	}
}

func (s LocalServer) Cmd(base []string) runner.Cmd {
	args := []string{"-D", s.DataDir}
	for _, setting := range s.Settings() {
		args = append(args, "-c", setting)
	}
	return runner.Cmd{Name: "postgres", Args: args, Env: base, LogFile: s.LogFile}
}

func (t Tools) StartServer(ctx context.Context, s LocalServer) (runner.Process, error) {
	return t.Runner.Start(ctx, s.Cmd(t.Base), nil)
}

func (t Tools) StopServer(ctx context.Context, s LocalServer) error {
	_, err := t.Runner.Run(ctx, runner.Cmd{Name: "pg_ctl", Args: []string{"--pgdata=" + s.DataDir, "--mode=fast", "--wait", "--timeout=120", "stop"}, Env: t.Base})
	return err
}

var roleName = regexp.MustCompile(`^[a-z_][a-z0-9_]{0,62}$`)

func (t Tools) Query(ctx context.Context, s LocalServer, user, sql string) (string, error) {
	if !roleName.MatchString(user) {
		return "", errors.New("invalid role name")
	}
	cmd := runner.Cmd{Name: "psql", Env: runner.Env(t.Base, "PGCONNECT_TIMEOUT=5"),
		Args: []string{"-X", "-A", "-t", "-q", "-v", "ON_ERROR_STOP=1", "-h", s.SocketDir, "-p", strconv.Itoa(s.Port), "-U", user, "-d", "postgres", "-c", sql}}
	res, err := t.Runner.Run(ctx, cmd)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(res.Stdout)), nil
}
