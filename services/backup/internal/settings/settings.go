package settings

import (
	"errors"
	"fmt"
	"log/slog"
	"net/url"
	"path/filepath"
	"strings"
	"time"

	"olt-social/backup/internal/restic"
)

const (
	UnknownRevision int64 = -1
	KindS3                = "s3"
	KindLocal             = "local"
)

type S3 struct {
	AccessKeyID     string  `json:"access_key_id"`
	SecretAccessKey string  `json:"secret_access_key"`
	Region          *string `json:"region"`
}

type Schedule struct {
	BaseTime           string `json:"base_time"`
	Timezone           string `json:"timezone"`
	OffsiteMinutes     int    `json:"offsite_minutes"`
	RestoreTestWeekday int    `json:"restore_test_weekday"`
	RestoreTestTime    string `json:"restore_test_time"`
}

type Retention struct {
	Daily   int `json:"daily"`
	Weekly  int `json:"weekly"`
	Monthly int `json:"monthly"`
	WALDays int `json:"wal_days"`
}

type Settings struct {
	Revision    int64     `json:"revision"`
	Unchanged   bool      `json:"unchanged"`
	Configured  bool      `json:"configured"`
	Kind        string    `json:"kind"`
	Repository  string    `json:"repository"`
	S3          S3        `json:"s3"`
	Password    string    `json:"password"`
	Schedule    Schedule  `json:"schedule"`
	Retention   Retention `json:"retention"`
	RestoreTest bool      `json:"restore_test"`
}

func (s Settings) String() string {
	return fmt.Sprintf("backup settings revision %d (configured=%t, kind=%s, repository=%s)", s.Revision, s.Configured, s.TargetKind(), SafeRepository(s.Repository))
}

func (s Settings) TargetKind() string {
	if s.Kind == "" {
		return KindS3
	}
	return s.Kind
}

func (s Settings) Local() bool {
	return s.TargetKind() == KindLocal
}

func (s Settings) Credentials() restic.Credentials {
	if s.Local() {
		return restic.Credentials{Repository: s.Repository, Password: s.Password}
	}
	return restic.Credentials{Repository: s.Repository, Password: s.Password, AccessKeyID: s.S3.AccessKeyID,
		SecretAccessKey: s.S3.SecretAccessKey, Region: s.Region()}
}

func (s Settings) GoString() string {
	return s.String()
}

func (s Settings) LogValue() slog.Value {
	return slog.GroupValue(
		slog.Int64("revision", s.Revision),
		slog.Bool("configured", s.Configured),
		slog.String("kind", s.TargetKind()),
		slog.String("repository", SafeRepository(s.Repository)),
	)
}

func SafeRepository(repo string) string {
	rest, ok := strings.CutPrefix(repo, "s3:")
	if !ok {
		return repo
	}
	u, err := url.Parse(rest)
	if err != nil || u.User == nil {
		return repo
	}
	u.User = nil
	return "s3:" + u.String()
}

func (s Settings) Region() string {
	if s.S3.Region == nil {
		return ""
	}
	return *s.S3.Region
}

func (s Settings) Validate(localDir string) error {
	var errs []error
	add := func(ok bool, msg string) {
		if !ok {
			errs = append(errs, errors.New(msg))
		}
	}
	switch s.TargetKind() {
	case KindLocal:
		add(filepath.IsAbs(s.Repository) && filepath.Clean(s.Repository) == s.Repository && s.Repository != "/",
			"folder repositori lokal harus berupa path absolut")
		add(s.Repository == localDir, fmt.Sprintf("folder repositori lokal %q tidak sama dengan LOCAL_REPO_DIR %q layanan backup", s.Repository, localDir))
	case KindS3:
		rest, isS3 := strings.CutPrefix(s.Repository, "s3:")
		u, err := url.Parse(rest)
		add(isS3 && err == nil && (u.Scheme == "http" || u.Scheme == "https") && u.Host != "" && strings.Trim(u.Path, "/") != "",
			"alamat repositori harus berbentuk s3:https://host/bucket[/prefix]")
		add(s.S3.AccessKeyID != "", "access key S3 kosong")
		add(s.S3.SecretAccessKey != "", "secret access key S3 tidak bisa dibaca (simpan ulang dari web)")
	default:
		add(false, fmt.Sprintf("jenis tujuan backup %q tidak dikenal", s.Kind))
	}
	add(s.Password != "", "password enkripsi tidak bisa dibaca (simpan ulang dari web)")
	_, err := s.Timetable()
	if err != nil {
		errs = append(errs, err)
	}
	add(s.Retention.Daily >= 1 && s.Retention.Daily <= 3650, "retensi harian harus 1–3650")
	add(s.Retention.Weekly >= 0 && s.Retention.Weekly <= 520, "retensi mingguan harus 0–520")
	add(s.Retention.Monthly >= 0 && s.Retention.Monthly <= 240, "retensi bulanan harus 0–240")
	add(s.Retention.WALDays >= 1 && s.Retention.WALDays <= 365, "retensi WAL harus 1–365 hari")
	return errors.Join(errs...)
}

type Clock struct {
	Hour   int
	Minute int
}

func ParseClock(text string) (Clock, bool) {
	t, err := time.Parse("15:04", text)
	if err != nil || len(text) != 5 {
		return Clock{}, false
	}
	return Clock{Hour: t.Hour(), Minute: t.Minute()}, true
}

type Timetable struct {
	Location *time.Location
	Base     Clock
	Offsite  time.Duration
	Weekday  time.Weekday
	Weekly   Clock
}

func (s Settings) Timetable() (Timetable, error) {
	var errs []error
	loc, err := time.LoadLocation(s.Schedule.Timezone)
	if err != nil || s.Schedule.Timezone == "" {
		errs = append(errs, fmt.Errorf("zona waktu %q tidak dikenal", s.Schedule.Timezone))
	}
	base, ok := ParseClock(s.Schedule.BaseTime)
	if !ok {
		errs = append(errs, errors.New("jam base backup harus berformat HH:MM"))
	}
	weekly, ok := ParseClock(s.Schedule.RestoreTestTime)
	if !ok {
		errs = append(errs, errors.New("jam uji restore harus berformat HH:MM"))
	}
	if s.Schedule.OffsiteMinutes < 1 || s.Schedule.OffsiteMinutes > 1440 {
		errs = append(errs, errors.New("interval kirim WAL harus 1–1440 menit"))
	}
	if s.Schedule.RestoreTestWeekday < 0 || s.Schedule.RestoreTestWeekday > 6 {
		errs = append(errs, errors.New("hari uji restore harus 0 (Minggu) sampai 6 (Sabtu)"))
	}
	if len(errs) > 0 {
		return Timetable{}, errors.Join(errs...)
	}
	return Timetable{
		Location: loc,
		Base:     base,
		Offsite:  time.Duration(s.Schedule.OffsiteMinutes) * time.Minute,
		Weekday:  time.Weekday(s.Schedule.RestoreTestWeekday),
		Weekly:   weekly,
	}, nil
}

func (t Timetable) NextBase(after time.Time) time.Time {
	local := after.In(t.Location)
	for days := 0; ; days++ {
		at := time.Date(local.Year(), local.Month(), local.Day()+days, t.Base.Hour, t.Base.Minute, 0, 0, t.Location)
		if at.After(after) {
			return at
		}
	}
}

func (t Timetable) NextWeekly(after time.Time) time.Time {
	local := after.In(t.Location)
	offset := (int(t.Weekday) - int(local.Weekday()) + 7) % 7
	for days := offset; ; days += 7 {
		at := time.Date(local.Year(), local.Month(), local.Day()+days, t.Weekly.Hour, t.Weekly.Minute, 0, 0, t.Location)
		if at.After(after) {
			return at
		}
	}
}
