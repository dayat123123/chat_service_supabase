package runner

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestRedactHidesSecretEnvValuesAndURLCredentials(t *testing.T) {
	env := []string{
		"PGPASSWORD=db-secret-pw", "RESTIC_PASSWORD=restic-secret", "AWS_SECRET_ACCESS_KEY=aws/secret+key",
		"AWS_ACCESS_KEY_ID=AKIAEXAMPLE", "PGHOST=db", "RESTIC_REPOSITORY=s3:http://seaweed:8333/bucket",
	}
	text := "auth failed for db-secret-pw using restic-secret and aws/secret+key (AKIAEXAMPLE) at s3:https://user:pass@host/b on db"
	got := Redact(text, env)
	for _, leaked := range []string{"db-secret-pw", "restic-secret", "aws/secret+key", "AKIAEXAMPLE", "user:pass"} {
		if strings.Contains(got, leaked) {
			t.Fatalf("%q leaked in %q", leaked, got)
		}
	}
	if !strings.Contains(got, "on db") || !strings.Contains(got, "s3:https://"+Redacted+"@host/b") {
		t.Fatalf("got %q", got)
	}
}

func TestRedactIgnoresTinyValues(t *testing.T) {
	if got := Redact("a b c", []string{"PGPASSWORD=a"}); got != "a b c" {
		t.Fatalf("got %q", got)
	}
	if got := RedactValues("token abcd and xyz", "abcd", "x"); got != "token "+Redacted+" and xyz" {
		t.Fatalf("got %q", got)
	}
}

func TestLastLinesKeepsTheTail(t *testing.T) {
	if got := LastLines("one\n\ntwo\nthree\nfour\n", 3); got != "two | three | four" {
		t.Fatalf("got %q", got)
	}
	if got := LastLines("", 3); got != "" {
		t.Fatalf("got %q", got)
	}
}

func TestEnvOverridesEarlierKeys(t *testing.T) {
	got := Env([]string{"PATH=/bin", "TZ=UTC"}, "TZ=Asia/Jakarta", "HOME=/x")
	if !reflect.DeepEqual(got, []string{"PATH=/bin", "TZ=Asia/Jakarta", "HOME=/x"}) {
		t.Fatalf("got %v", got)
	}
	if Lookup(got, "TZ") != "Asia/Jakarta" || Lookup(got, "NOPE") != "" {
		t.Fatal("lookup")
	}
}

func TestExecRunCapturesOutputAndExitCode(t *testing.T) {
	r := Exec{}
	res, err := r.Run(context.Background(), Cmd{Name: "/bin/sh", Args: []string{"-c", "echo out; echo $SECRETLESS; echo leaked $PGPASSWORD >&2; exit 3"},
		Env: []string{"PGPASSWORD=hunter22", "SECRETLESS=visible"}})
	if string(res.Stdout) != "out\nvisible\n" {
		t.Fatalf("stdout = %q", res.Stdout)
	}
	if Code(err) != 3 || strings.Contains(err.Error(), "hunter22") || !strings.Contains(err.Error(), "leaked "+Redacted) {
		t.Fatalf("err = %v", err)
	}
	if !strings.Contains(Detail(err), "leaked") || Detail(nil) != "" {
		t.Fatalf("detail = %q", Detail(err))
	}
}

func TestExecRunDoesNotInheritTheParentEnvironment(t *testing.T) {
	t.Setenv("JWT_SECRET", "must-not-leak")
	res, err := Exec{}.Run(context.Background(), Cmd{Name: "/bin/sh", Args: []string{"-c", "echo ${JWT_SECRET:-none}"}})
	if err != nil || strings.TrimSpace(string(res.Stdout)) != "none" {
		t.Fatalf("stdout = %q err = %v", res.Stdout, err)
	}
}

func TestExecRunRejectsOversizedOutput(t *testing.T) {
	_, err := Exec{MaxStdout: 4}.Run(context.Background(), Cmd{Name: "/bin/sh", Args: []string{"-c", "echo 123456789"}})
	if err == nil || !strings.Contains(err.Error(), "output larger") {
		t.Fatalf("err = %v", err)
	}
}

func TestExecRunInterruptsOnCancel(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
	defer cancel()
	start := time.Now()
	_, err := Exec{WaitDelay: time.Second}.Run(ctx, Cmd{Name: "/bin/sh", Args: []string{"-c", "sleep 10"}})
	if !errors.Is(err, context.DeadlineExceeded) || time.Since(start) > 5*time.Second {
		t.Fatalf("err = %v after %v", err, time.Since(start))
	}
}

func TestExecStartStreamsRedactedLines(t *testing.T) {
	var mu sync.Mutex
	var lines []string
	p, err := Exec{}.Start(context.Background(), Cmd{Name: "/bin/sh", Args: []string{"-c", "echo starting; echo pw=$PGPASSWORD >&2; exit 1"},
		Env: []string{"PGPASSWORD=topsecret"}}, func(l string) {
		mu.Lock()
		lines = append(lines, l)
		mu.Unlock()
	})
	if err != nil {
		t.Fatal(err)
	}
	<-p.Done()
	err = p.Wait()
	mu.Lock()
	defer mu.Unlock()
	if !reflect.DeepEqual(lines, []string{"starting", "pw=" + Redacted}) {
		t.Fatalf("lines = %q", lines)
	}
	if Code(err) != 1 || strings.Contains(err.Error(), "topsecret") {
		t.Fatalf("err = %v", err)
	}
}

func TestExecStartWritesToLogFileAndInterrupts(t *testing.T) {
	log := filepath.Join(t.TempDir(), "server.log")
	p, err := Exec{WaitDelay: 2 * time.Second}.Start(context.Background(), Cmd{Name: "/bin/sh",
		Args: []string{"-c", "trap 'echo bye; exit 0' INT; echo ready; while true; do sleep 0.1; done"}, LogFile: log}, nil)
	if err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(5 * time.Second)
	for {
		data, _ := os.ReadFile(log)
		if strings.Contains(string(data), "ready") {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("process did not start")
		}
		time.Sleep(20 * time.Millisecond)
	}
	p.Interrupt()
	select {
	case <-p.Done():
	case <-time.After(5 * time.Second):
		t.Fatal("process did not stop")
	}
	if err := p.Wait(); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(log)
	if !strings.Contains(string(data), "bye") {
		t.Fatalf("log = %q", data)
	}
}

func TestExecRunKeepsStderrOnTimeout(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
	defer cancel()
	_, err := Exec{WaitDelay: time.Second}.Run(ctx, Cmd{Name: "/bin/sh", Args: []string{"-c", "echo retrying >&2; echo 'bucket does not exist' >&2; sleep 10"}})
	if !errors.Is(err, context.DeadlineExceeded) || !strings.Contains(err.Error(), "bucket does not exist") || !strings.Contains(Output(err), "retrying") {
		t.Fatalf("err = %v", err)
	}
}
