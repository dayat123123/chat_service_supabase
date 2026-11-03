package agent

import (
	"reflect"
	"testing"
	"time"
	_ "time/tzdata"

	"olt-social/backup/internal/pg"
	"olt-social/backup/internal/settings"
	"olt-social/backup/internal/state"
)

func timetable(t *testing.T) settings.Timetable {
	t.Helper()
	tt, err := validSettings(1).Timetable()
	if err != nil {
		t.Fatal(err)
	}
	return tt
}

func TestDecideHandlesSlotAndSystemChanges(t *testing.T) {
	ok := pg.SlotStatus{Exists: true, WALStatus: "reserved", Active: true, Reserved: true}
	lost := pg.SlotStatus{Exists: true, WALStatus: "lost", Reserved: true}
	cases := []struct {
		name             string
		known, system    string
		slot             pg.SlotStatus
		haveLocal, force bool
		want             Decision
	}{
		{"first start", "", "7", pg.SlotStatus{}, false, false, Decision{Create: true}},
		{"normal restart", "7", "7", ok, true, false, Decision{}},
		{"slot exists but unused", "7", "7", pg.SlotStatus{Exists: true}, true, false, Decision{}},
		{"slot missing with local wal", "7", "7", pg.SlotStatus{}, true, false, Decision{Create: true, Detach: true, NeedBase: true}},
		{"slot lost", "7", "7", lost, true, false, Decision{Drop: true, Create: true, Detach: true, NeedBase: true, Lost: true}},
		{"slot lost without wal", "7", "7", lost, false, false, Decision{Drop: true, Create: true, NeedBase: true, Lost: true}},
		{"new cluster", "7", "8", pg.SlotStatus{}, true, false, Decision{Create: true, Detach: true, NeedBase: true}},
		{"new cluster with slot", "7", "8", ok, false, false, Decision{NeedBase: true}},
		{"wal already removed", "7", "7", ok, true, true, Decision{Detach: true, NeedBase: true}},
		{"force without local wal", "7", "7", ok, false, true, Decision{}},
	}
	for _, c := range cases {
		if got := Decide(c.known, c.system, c.slot, c.haveLocal, c.force); got != c.want {
			t.Errorf("%s: got %+v, want %+v", c.name, got, c.want)
		}
	}
}

func TestRetryDelayGrowsAndCaps(t *testing.T) {
	want := []time.Duration{15 * time.Minute, 30 * time.Minute, time.Hour, 2 * time.Hour, 4 * time.Hour, 6 * time.Hour, 6 * time.Hour}
	for i, w := range want {
		if got := RetryDelay(i + 1); got != w {
			t.Errorf("RetryDelay(%d) = %v, want %v", i+1, got, w)
		}
	}
}

func TestDueSchedulesDailyAndWeeklyJobs(t *testing.T) {
	tt := timetable(t)
	jkt, _ := time.LoadLocation("Asia/Jakarta")
	at := func(day, hour, minute int) time.Time { return time.Date(2026, 11, day, hour, minute, 0, 0, jkt) }
	base := &state.Base{Label: "b"}
	ok := func(t time.Time) state.Job { return state.Job{LastOK: t, LastAttempt: t} }
	jobs := func(pairs ...any) map[string]state.Job {
		m := map[string]state.Job{}
		for i := 0; i < len(pairs); i += 2 {
			m[pairs[i].(string)] = pairs[i+1].(state.Job)
		}
		return m
	}
	cases := []struct {
		name        string
		p           state.Persisted
		restoreTest bool
		now         time.Time
		want        []string
	}{
		{"fresh install", state.Persisted{WeeklyFrom: at(3, 10, 0)}, true, at(3, 10, 0), []string{JobBase, JobFiles}},
		{"all done today", state.Persisted{Base: base, WeeklyFrom: at(3, 1, 0), Jobs: jobs(JobBase, ok(at(3, 2, 5)), JobFiles, ok(at(3, 2, 6)))},
			true, at(3, 10, 0), nil},
		{"next base time reached", state.Persisted{Base: base, WeeklyFrom: at(3, 1, 0), Jobs: jobs(JobBase, ok(at(3, 2, 5)), JobFiles, ok(at(3, 2, 6)))},
			true, at(4, 2, 0), []string{JobBase, JobFiles}},
		{"missed while down", state.Persisted{Base: base, WeeklyFrom: at(1, 5, 0), Jobs: jobs(JobBase, ok(at(1, 2, 5)), JobFiles, ok(at(1, 2, 6)))},
			false, at(3, 9, 0), []string{JobBase, JobFiles}},
		{"slot reset needs base", state.Persisted{Base: base, NeedBase: true, WeeklyFrom: at(3, 1, 0), Jobs: jobs(JobBase, ok(at(3, 2, 5)), JobFiles, ok(at(3, 2, 6)))},
			true, at(3, 10, 0), []string{JobBase}},
		{"failed base waits for retry", state.Persisted{Base: base, NeedBase: true, WeeklyFrom: at(3, 1, 0),
			Jobs: jobs(JobBase, state.Job{LastAttempt: at(3, 10, 0), Failures: 2}, JobFiles, ok(at(3, 2, 6)))},
			true, at(3, 10, 29), nil},
		{"failed base retried", state.Persisted{Base: base, NeedBase: true, WeeklyFrom: at(3, 1, 0),
			Jobs: jobs(JobBase, state.Job{LastAttempt: at(3, 10, 0), Failures: 2}, JobFiles, ok(at(3, 2, 6)))},
			true, at(3, 10, 30), []string{JobBase}},
		{"weekly window on sunday", state.Persisted{Base: base, WeeklyFrom: at(3, 1, 0), Jobs: jobs(JobBase, ok(at(8, 2, 5)), JobFiles, ok(at(8, 2, 6)))},
			true, at(8, 4, 0), []string{JobPrune, JobCheck, JobRestoreTest}},
		{"restore test disabled", state.Persisted{Base: base, WeeklyFrom: at(3, 1, 0), Jobs: jobs(JobBase, ok(at(8, 2, 5)), JobFiles, ok(at(8, 2, 6)))},
			false, at(8, 4, 0), []string{JobPrune, JobCheck}},
		{"weekly not before window", state.Persisted{Base: base, WeeklyFrom: at(3, 1, 0), Jobs: jobs(JobBase, ok(at(8, 2, 5)), JobFiles, ok(at(8, 2, 6)))},
			true, at(8, 3, 59), nil},
		{"weekly done this week", state.Persisted{Base: base, WeeklyFrom: at(3, 1, 0), Jobs: jobs(JobBase, ok(at(14, 2, 5)), JobFiles, ok(at(14, 2, 6)),
			JobPrune, ok(at(8, 4, 0)), JobCheck, ok(at(8, 4, 3)), JobRestoreTest, state.Job{LastAttempt: at(8, 4, 5), Failures: 1})},
			true, at(14, 23, 0), nil},
		{"restore test needs a base", state.Persisted{WeeklyFrom: at(3, 1, 0), Jobs: jobs(JobBase, state.Job{LastAttempt: at(8, 3, 0), Failures: 1},
			JobFiles, ok(at(8, 2, 6)), JobPrune, ok(at(8, 4, 0)), JobCheck, ok(at(8, 4, 3)))},
			true, at(8, 4, 1), []string{JobBase}},
	}
	for _, c := range cases {
		if got := Due(c.p, tt, c.restoreTest, c.now); !reflect.DeepEqual(got, c.want) {
			t.Errorf("%s: got %v, want %v", c.name, got, c.want)
		}
	}
}

func TestHelpers(t *testing.T) {
	if human(512) != "512 B" || human(1536) != "1.5 KiB" || human(5<<30) != "5.0 GiB" {
		t.Fatal("human")
	}
	if busyName(JobForget) != JobPrune || busyName(JobOffsite) != "offsite" || busyName("") != "" {
		t.Fatal("busy")
	}
	if sentence("ruang disk") != "Ruang disk" || sentence("") != "" {
		t.Fatal("sentence")
	}
	if at, ok := detachedAt("/x/wal-detached-20261103T010203Z"); !ok || !at.Equal(time.Date(2026, 11, 3, 1, 2, 3, 0, time.UTC)) {
		t.Fatal("detachedAt")
	}
	if _, ok := detachedAt("/x/wal-detached-bad"); ok {
		t.Fatal("bad stamp accepted")
	}
	if grow(0, time.Second, time.Minute) != time.Second || grow(40*time.Second, time.Second, time.Minute) != time.Minute {
		t.Fatal("grow")
	}
}
