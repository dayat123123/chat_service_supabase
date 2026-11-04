package settings

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
	"testing"
	"time"
	_ "time/tzdata"
)

const localDir = "/var/lib/olt-backup-repo"

func validLocal() Settings {
	s := valid()
	s.Kind, s.Repository, s.S3 = KindLocal, localDir, S3{}
	return s
}

func TestLocalTargetNeedsOnlyThePasswordAndTheMountedFolder(t *testing.T) {
	raw := `{"revision":5,"configured":true,"kind":"local","repository":"/var/lib/olt-backup-repo","s3":null,"password":"pw",
"schedule":{"base_time":"02:00","timezone":"Asia/Jakarta","offsite_minutes":5,"restore_test_weekday":0,"restore_test_time":"04:00"},
"retention":{"daily":7,"weekly":4,"monthly":6,"wal_days":7},"restore_test":true}`
	var s Settings
	if err := json.Unmarshal([]byte(raw), &s); err != nil {
		t.Fatal(err)
	}
	if !s.Local() || s.TargetKind() != KindLocal {
		t.Fatalf("s = %v", s)
	}
	if err := s.Validate(localDir); err != nil {
		t.Fatal(err)
	}
	creds := s.Credentials()
	if creds.Repository != localDir || creds.Password != "pw" || creds.AccessKeyID != "" || creds.SecretAccessKey != "" || creds.Region != "" {
		t.Fatalf("creds = %+v", creds)
	}
	if err := s.Validate("/mnt/backup"); err == nil || !strings.Contains(err.Error(), "LOCAL_REPO_DIR") {
		t.Fatalf("err = %v", err)
	}
	cases := map[string]func(*Settings){
		"relative":    func(s *Settings) { s.Repository = "backups/restic" },
		"unclean":     func(s *Settings) { s.Repository = "/var/lib/../lib/olt-backup-repo" },
		"s3 address":  func(s *Settings) { s.Repository = "s3:https://h/b" },
		"no password": func(s *Settings) { s.Password = "" },
	}
	for name, mutate := range cases {
		s := validLocal()
		mutate(&s)
		if err := s.Validate(localDir); err == nil {
			t.Errorf("%s accepted", name)
		}
	}
	if !strings.Contains(validLocal().String(), "kind=local") || !strings.Contains(validLocal().String(), localDir) {
		t.Fatalf("string = %s", validLocal())
	}
}

func TestKindDefaultsToS3AndRejectsUnknown(t *testing.T) {
	s := valid()
	s.Kind = ""
	if s.Local() || s.TargetKind() != KindS3 || s.Validate(localDir) != nil {
		t.Fatal("missing kind must behave as s3")
	}
	creds := s.Credentials()
	if creds.AccessKeyID != "AKIA123" || creds.SecretAccessKey != "very-secret-key" || creds.Region != "id-jkt-1" {
		t.Fatalf("creds = %+v", creds)
	}
	s.Kind = "ftp"
	if err := s.Validate(localDir); err == nil || !strings.Contains(err.Error(), "jenis tujuan backup") {
		t.Fatalf("err = %v", err)
	}
}

func valid() Settings {
	region := "id-jkt-1"
	return Settings{
		Revision: 4, Configured: true,
		Repository:  "s3:https://s3.example.com/olt-backup/prod",
		S3:          S3{AccessKeyID: "AKIA123", SecretAccessKey: "very-secret-key", Region: &region},
		Password:    "restic-password-0123456789",
		Schedule:    Schedule{BaseTime: "02:00", Timezone: "Asia/Jakarta", OffsiteMinutes: 5, RestoreTestWeekday: 0, RestoreTestTime: "04:00"},
		Retention:   Retention{Daily: 7, Weekly: 4, Monthly: 6, WALDays: 7},
		RestoreTest: true,
	}
}

func TestDecodesTheContractShape(t *testing.T) {
	raw := `{"revision":3,"configured":true,"repository":"s3:http://seaweed:8333/b/p","s3":{"access_key_id":"k","secret_access_key":"s","region":null},
"password":"pw","schedule":{"base_time":"02:00","timezone":"Asia/Jakarta","offsite_minutes":5,"restore_test_weekday":0,"restore_test_time":"04:00"},
"retention":{"daily":7,"weekly":4,"monthly":6,"wal_days":7},"restore_test":true}`
	var s Settings
	if err := json.Unmarshal([]byte(raw), &s); err != nil {
		t.Fatal(err)
	}
	if s.Revision != 3 || !s.Configured || s.Region() != "" || s.Retention.WALDays != 7 || !s.RestoreTest || s.Schedule.OffsiteMinutes != 5 {
		t.Fatalf("s = %#v", s)
	}
	if err := s.Validate(localDir); err != nil {
		t.Fatal(err)
	}
	if valid().Region() != "id-jkt-1" {
		t.Fatal("region")
	}
}

func TestValidateRejectsBadValues(t *testing.T) {
	cases := map[string]struct {
		mutate func(*Settings)
		want   string
	}{
		"repo scheme":    {func(s *Settings) { s.Repository = "sftp:host:/x" }, "alamat repositori"},
		"repo no bucket": {func(s *Settings) { s.Repository = "s3:https://host" }, "alamat repositori"},
		"no secret":      {func(s *Settings) { s.S3.SecretAccessKey = "" }, "secret access key"},
		"no password":    {func(s *Settings) { s.Password = "" }, "password enkripsi"},
		"base time":      {func(s *Settings) { s.Schedule.BaseTime = "2:00" }, "jam base backup"},
		"test time":      {func(s *Settings) { s.Schedule.RestoreTestTime = "24:00" }, "jam uji restore"},
		"zone":           {func(s *Settings) { s.Schedule.Timezone = "Mars/Olympus" }, "zona waktu"},
		"weekday":        {func(s *Settings) { s.Schedule.RestoreTestWeekday = 7 }, "hari uji restore"},
		"offsite":        {func(s *Settings) { s.Schedule.OffsiteMinutes = 0 }, "interval kirim WAL"},
		"daily":          {func(s *Settings) { s.Retention.Daily = 0 }, "retensi harian"},
		"wal days":       {func(s *Settings) { s.Retention.WALDays = 0 }, "retensi WAL"},
	}
	for name, c := range cases {
		s := valid()
		c.mutate(&s)
		if err := s.Validate(localDir); err == nil || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: err = %v", name, err)
		}
	}
}

func TestSettingsNeverPrintSecrets(t *testing.T) {
	s := valid()
	s.Repository = "s3:https://user:pass@s3.example.com/b"
	var logged bytes.Buffer
	slog.New(slog.NewJSONHandler(&logged, nil)).Info("loaded", "settings", s)
	outputs := []string{fmt.Sprintf("%v", s), fmt.Sprintf("%+v", s), fmt.Sprintf("%#v", s), fmt.Sprint(s), logged.String()}
	for _, out := range outputs {
		for _, secret := range []string{"very-secret-key", "restic-password-0123456789", "user:pass"} {
			if strings.Contains(out, secret) {
				t.Fatalf("%q leaked in %q", secret, out)
			}
		}
	}
	if !strings.Contains(logged.String(), `"revision":4`) || !strings.Contains(outputs[0], "s3:https://s3.example.com/b") {
		t.Fatalf("outputs = %q", outputs)
	}
	if SafeRepository("s3:https://h/b") != "s3:https://h/b" || SafeRepository("/local") != "/local" || SafeRepository(localDir) != localDir {
		t.Fatal("safe repository")
	}
}

func jakarta(t *testing.T) *time.Location {
	t.Helper()
	loc, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		t.Fatal(err)
	}
	return loc
}

func TestNextBaseUsesTheConfiguredZone(t *testing.T) {
	tt, err := valid().Timetable()
	if err != nil {
		t.Fatal(err)
	}
	cases := []struct{ after, want time.Time }{
		{time.Date(2026, 11, 2, 18, 59, 0, 0, time.UTC), time.Date(2026, 11, 2, 19, 0, 0, 0, time.UTC)},
		{time.Date(2026, 11, 2, 19, 0, 0, 0, time.UTC), time.Date(2026, 11, 3, 19, 0, 0, 0, time.UTC)},
		{time.Date(2026, 11, 3, 1, 0, 0, 0, time.UTC), time.Date(2026, 11, 3, 19, 0, 0, 0, time.UTC)},
		{time.Date(2026, 12, 31, 20, 0, 0, 0, time.UTC), time.Date(2027, 1, 1, 19, 0, 0, 0, time.UTC)},
	}
	for _, c := range cases {
		if got := tt.NextBase(c.after); !got.Equal(c.want) {
			t.Errorf("NextBase(%v) = %v, want %v", c.after, got.UTC(), c.want)
		}
	}
	if got := tt.NextBase(time.Time{}); got.IsZero() || got.Year() > 2 {
		t.Fatalf("zero = %v", got)
	}
	if tt.Offsite != 5*time.Minute {
		t.Fatal("offsite")
	}
}

func TestNextWeeklyHonoursWeekday(t *testing.T) {
	s := valid()
	s.Schedule.RestoreTestWeekday = 0
	tt, _ := s.Timetable()
	loc := jakarta(t)
	cases := []struct{ after, want time.Time }{
		{time.Date(2026, 11, 3, 10, 0, 0, 0, loc), time.Date(2026, 11, 8, 4, 0, 0, 0, loc)},
		{time.Date(2026, 11, 8, 3, 59, 0, 0, loc), time.Date(2026, 11, 8, 4, 0, 0, 0, loc)},
		{time.Date(2026, 11, 8, 4, 0, 0, 0, loc), time.Date(2026, 11, 15, 4, 0, 0, 0, loc)},
		{time.Date(2026, 11, 7, 21, 30, 0, 0, time.UTC), time.Date(2026, 11, 15, 4, 0, 0, 0, loc)},
		{time.Date(2026, 11, 7, 20, 30, 0, 0, time.UTC), time.Date(2026, 11, 8, 4, 0, 0, 0, loc)},
	}
	for _, c := range cases {
		if got := tt.NextWeekly(c.after); !got.Equal(c.want) {
			t.Errorf("NextWeekly(%v) = %v, want %v", c.after, got, c.want)
		}
	}
	s.Schedule.RestoreTestWeekday = 3
	tt, _ = s.Timetable()
	if got := tt.NextWeekly(time.Date(2026, 11, 3, 10, 0, 0, 0, loc)); !got.Equal(time.Date(2026, 11, 4, 4, 0, 0, 0, loc)) || got.In(loc).Weekday() != time.Wednesday {
		t.Fatalf("got %v", got)
	}
}

func TestTimetableHandlesDaylightSaving(t *testing.T) {
	s := valid()
	s.Schedule.Timezone = "Europe/Amsterdam"
	s.Schedule.BaseTime = "02:30"
	tt, err := s.Timetable()
	if err != nil {
		t.Fatal(err)
	}
	loc, _ := time.LoadLocation("Europe/Amsterdam")
	got := tt.NextBase(time.Date(2027, 3, 27, 12, 0, 0, 0, loc))
	if !got.After(time.Date(2027, 3, 27, 12, 0, 0, 0, loc)) || got.Day() != 28 {
		t.Fatalf("got %v", got)
	}
}

func TestParseClock(t *testing.T) {
	if c, ok := ParseClock("23:59"); !ok || c != (Clock{23, 59}) {
		t.Fatal("23:59")
	}
	for _, bad := range []string{"", "1:00", "24:00", "12:60", "12-00"} {
		if _, ok := ParseClock(bad); ok {
			t.Fatalf("%q accepted", bad)
		}
	}
}
