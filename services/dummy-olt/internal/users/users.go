package users

import (
	"crypto/subtle"
	"errors"
	"sort"
	"strconv"
	"strings"
)

const DefaultPassword = "olt12345"

type Status string

const (
	StatusActive    Status = "active"
	StatusSuspended Status = "suspended"
)

type User struct {
	ID       int64
	Username string
	Email    string
	FullName string
	Status   Status

	SlowLogin bool

	password string
}

var (
	ErrInvalidCredentials = errors.New("username/email atau password salah")
	ErrSuspended          = errors.New("akun ditangguhkan")
)

type Directory struct {
	users []*User
}

func Default() *Directory {
	user := func(id int64, username, email, name string) *User {
		return &User{ID: id, Username: username, Email: email, FullName: name, Status: StatusActive, password: DefaultPassword}
	}
	suspended := user(1009, "akun_suspend", "suspend@olt.test", "Akun Ditangguhkan")
	suspended.Status = StatusSuspended
	slow := user(1010, "lambat_test", "lambat@olt.test", "Simulasi OLT Lambat")
	slow.SlowLogin = true

	return &Directory{users: []*User{
		user(1001, "budi_santoso", "budi@olt.test", "Budi Santoso"),
		user(1002, "sari_invest", "sari@olt.test", "Sari Wulandari"),
		user(1003, "andi_trader", "andi@olt.test", "Andi Pratama"),
		user(1004, "rina_saham", "rina@olt.test", "Rina Kartika"),
		user(1005, "dewi_cuan", "dewi@olt.test", "Dewi Lestari"),
		user(1006, "olt_official", "official@olt.test", "Rendezvous OLT"),
		user(1007, "joko_prasetyo", "joko@olt.test", "Joko Prasetyo"),
		user(1008, "rudi.setiawan", "rudi@olt.test", "Rudi Setiawan"),
		suspended,
		slow,
	}}
}

func (d *Directory) Find(identifier string) (*User, bool) {
	key := strings.TrimSpace(identifier)
	for _, u := range d.users {
		if strconv.FormatInt(u.ID, 10) == key || strings.EqualFold(u.Username, key) || strings.EqualFold(u.Email, key) {
			return u, true
		}
	}
	return nil, false
}

func (d *Directory) Authenticate(identifier, password string) (*User, error) {
	u, ok := d.Find(identifier)
	expected := DefaultPassword
	if ok {
		expected = u.password
	}
	match := subtle.ConstantTimeCompare([]byte(expected), []byte(password)) == 1
	if !ok || !match {
		return nil, ErrInvalidCredentials
	}
	if u.Status == StatusSuspended {
		return nil, ErrSuspended
	}
	return u, nil
}

func (d *Directory) All() []User {
	out := make([]User, 0, len(d.users))
	for _, u := range d.users {
		out = append(out, *u)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}
