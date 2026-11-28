package stats

import (
	"context"
	"errors"
	"slices"
	"strings"
	"testing"
)

type sink struct {
	rows [][]Row
	err  error
}

func (s *sink) RecordStats(_ context.Context, rows []Row) error {
	if s.err != nil {
		return s.err
	}
	s.rows = append(s.rows, rows)
	return nil
}

func sorted(rows []Row) []Row {
	out := slices.Clone(rows)
	slices.SortFunc(out, func(a, b Row) int { return strings.Compare(a.Code, b.Code) })
	return out
}

func TestFlushGroupsEventsPerCode(t *testing.T) {
	tr := New(10)
	tr.Add("AAAAAAAAAA", View)
	tr.Add("AAAAAAAAAA", View)
	tr.Add("AAAAAAAAAA", Open)
	tr.Add("BBBBBBBBBB", Preview)
	tr.Add("BBBBBBBBBB", Mac)
	s := &sink{}
	if err := tr.Flush(context.Background(), s); err != nil {
		t.Fatal(err)
	}
	got := sorted(s.rows[0])
	want := []Row{{Code: "AAAAAAAAAA", Views: 2, Opens: 1}, {Code: "BBBBBBBBBB", Previews: 1, Mac: 1}}
	if !slices.Equal(got, want) {
		t.Fatalf("rows = %+v, want %+v", got, want)
	}
	if tr.Pending() != 0 || tr.Sent() != 2 {
		t.Fatalf("pending=%d sent=%d", tr.Pending(), tr.Sent())
	}
	if err := tr.Flush(context.Background(), s); err != nil || len(s.rows) != 1 {
		t.Fatalf("empty flush should not call the sink: %v %d", err, len(s.rows))
	}
}

func TestFailedFlushKeepsCounts(t *testing.T) {
	tr := New(10)
	tr.Add("AAAAAAAAAA", View)
	s := &sink{err: errors.New("down")}
	if err := tr.Flush(context.Background(), s); err == nil {
		t.Fatal("expected an error")
	}
	tr.Add("AAAAAAAAAA", Android)
	s.err = nil
	if err := tr.Flush(context.Background(), s); err != nil {
		t.Fatal(err)
	}
	if want := (Row{Code: "AAAAAAAAAA", Views: 1, Android: 1}); s.rows[0][0] != want {
		t.Fatalf("row = %+v, want %+v", s.rows[0][0], want)
	}
	if tr.Failed() != 1 {
		t.Fatalf("failed = %d", tr.Failed())
	}
}

func TestLimitDropsNewCodes(t *testing.T) {
	tr := New(1)
	tr.Add("AAAAAAAAAA", View)
	tr.Add("BBBBBBBBBB", View)
	tr.Add("AAAAAAAAAA", IOS)
	if tr.Pending() != 1 || tr.Dropped() != 1 {
		t.Fatalf("pending=%d dropped=%d", tr.Pending(), tr.Dropped())
	}
}
