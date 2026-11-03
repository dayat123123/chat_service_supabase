package restore

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"time"

	"olt-social/backup/internal/pg"
	"olt-social/backup/internal/runner"
)

type Server interface {
	StartServer(ctx context.Context, s pg.LocalServer) (runner.Process, error)
	Query(ctx context.Context, s pg.LocalServer, user, sql string) (string, error)
	StopServer(ctx context.Context, s pg.LocalServer) error
}

type Outcome struct {
	RecoveredUntil *time.Time       `json:"recovered_until"`
	LastMessageAt  *time.Time       `json:"last_message_at"`
	Tables         map[string]int64 `json:"tables"`
}

var Users = []string{"supabase_admin", "postgres"}

const CountsSQL = `select json_build_object(
  'recovered_until', pg_catalog.pg_last_xact_replay_timestamp(),
  'last_message_at', (select max(created_at) from public.messages),
  'tables', json_build_object(
    'public.profiles', (select count(*) from public.profiles),
    'public.messages', (select count(*) from public.messages),
    'cs.tickets', (select count(*) from cs.tickets)))`

func NewServer(root string) pg.LocalServer {
	return pg.LocalServer{
		DataDir:   root + "/data",
		ConfigDir: root + "/conf",
		SocketDir: root + "/sock",
		LogFile:   root + "/postgres.log",
		Port:      5432,
	}
}

func WriteServerConfig(s pg.LocalServer) error {
	for _, dir := range []string{s.ConfigDir, s.SocketDir} {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			return err
		}
	}
	files := map[string]string{
		s.ConfigFile(): "",
		s.HBAFile():    "local all all trust\n",
		s.IdentFile():  "",
	}
	for path, content := range files {
		if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
			return err
		}
	}
	return nil
}

func Probe(ctx context.Context, server Server, s pg.LocalServer, poll time.Duration) (Outcome, error) {
	proc, err := server.StartServer(ctx, s)
	if err != nil {
		return Outcome{}, fmt.Errorf("postgres uji tidak bisa dijalankan: %w", err)
	}
	defer stop(server, s, proc)
	user, err := awaitPromotion(ctx, server, s, proc, poll)
	if err != nil {
		return Outcome{}, err
	}
	out, err := server.Query(ctx, s, user, CountsSQL)
	if err != nil {
		return Outcome{}, fmt.Errorf("query hitung data gagal: %s", runner.Detail(err))
	}
	var outcome Outcome
	if err := json.Unmarshal([]byte(out), &outcome); err != nil {
		return Outcome{}, fmt.Errorf("hasil query hitung data tidak terbaca: %w", err)
	}
	return outcome, nil
}

func awaitPromotion(ctx context.Context, server Server, s pg.LocalServer, proc runner.Process, poll time.Duration) (string, error) {
	timer := time.NewTimer(0)
	defer timer.Stop()
	for {
		select {
		case <-ctx.Done():
			return "", fmt.Errorf("postgres uji belum selesai recovery sebelum batas waktu: %s", LogTail(s.LogFile, 3))
		case <-proc.Done():
			return "", fmt.Errorf("postgres uji berhenti: %s", LogTail(s.LogFile, 3))
		case <-timer.C:
		}
		for _, user := range Users {
			out, err := server.Query(ctx, s, user, "select pg_catalog.pg_is_in_recovery()")
			if err == nil && out == "f" {
				return user, nil
			}
		}
		timer.Reset(poll)
	}
}

func stop(server Server, s pg.LocalServer, proc runner.Process) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	select {
	case <-proc.Done():
		return
	default:
	}
	if err := server.StopServer(ctx, s); err != nil {
		proc.Interrupt()
	}
	select {
	case <-proc.Done():
	case <-ctx.Done():
	}
}

func LogTail(path string, lines int) string {
	f, err := os.Open(path)
	if err != nil {
		return "log tidak tersedia"
	}
	defer f.Close()
	info, err := f.Stat()
	if err != nil {
		return "log tidak tersedia"
	}
	const window = 8 << 10
	if info.Size() > window {
		if _, err := f.Seek(info.Size()-window, io.SeekStart); err != nil {
			return "log tidak tersedia"
		}
	}
	data, err := io.ReadAll(f)
	if err != nil && !errors.Is(err, io.EOF) {
		return "log tidak tersedia"
	}
	if tail := runner.LastLines(string(data), lines); tail != "" {
		return tail
	}
	return "log kosong"
}
