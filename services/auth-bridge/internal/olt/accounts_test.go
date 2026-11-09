package olt

import (
	"context"
	"encoding/json"
	"fmt"
	"reflect"
	"testing"
)

func TestParseAccounts(t *testing.T) {
	many := make([]string, 0, MaxAccounts+10)
	for i := range MaxAccounts + 10 {
		many = append(many, fmt.Sprintf("A%d", i))
	}
	manyJSON, _ := json.Marshal(many)

	cases := map[string]struct {
		raw  string
		want *AccountClaim
	}{
		"tidak ada":          {"", nil},
		"null":               {"null", nil},
		"kosong":             {"[]", &AccountClaim{IDs: []string{}}},
		"rekening valid":     {`["W137","C1626"]`, &AccountClaim{IDs: []string{"W137", "C1626"}}},
		"entri tidak valid":  {`["W137",5,null,"bad id!","","x/y",{"a":1}]`, &AccountClaim{IDs: []string{"W137"}, Ignored: 6}},
		"duplikat":           {`["w137","W137","S2001"]`, &AccountClaim{IDs: []string{"w137", "S2001"}, Ignored: 1}},
		"terlalu panjang":    {`["ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"]`, &AccountClaim{IDs: []string{}, Ignored: 1}},
		"lebih dari 200":     {string(manyJSON), &AccountClaim{IDs: many[:MaxAccounts], Ignored: 10}},
		"bukan array":        {`"W137"`, &AccountClaim{Malformed: true}},
		"objek bukan array":  {`{"W137":true}`, &AccountClaim{Malformed: true}},
		"karakter titik dll": {`["a.b_c-1"]`, &AccountClaim{IDs: []string{"a.b_c-1"}}},
	}
	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			got := ParseAccounts(json.RawMessage(tc.raw))
			if !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("ParseAccounts(%s) = %+v, want %+v", tc.raw, got, tc.want)
			}
		})
	}
}

func TestJWTVerifierReadsAccountsClaim(t *testing.T) {
	k := newTestKeys(t)
	v := newTestVerifier(t, k)

	u, err := v.Verify(context.Background(), k.edToken(t, with(validClaims(), "accounts", []any{"W137", "C1626", 42})))
	if err != nil {
		t.Fatal(err)
	}
	want := &AccountClaim{IDs: []string{"W137", "C1626"}, Ignored: 1}
	if !reflect.DeepEqual(u.Accounts, want) {
		t.Fatalf("accounts = %+v, want %+v", u.Accounts, want)
	}

	u, err = v.Verify(context.Background(), k.edToken(t, with(validClaims(), "accounts", "W137")))
	if err != nil {
		t.Fatalf("klaim accounts yang salah bentuk tidak boleh menolak token: %v", err)
	}
	if u.Accounts == nil || !u.Accounts.Malformed {
		t.Fatalf("accounts = %+v, want malformed", u.Accounts)
	}

	u, err = v.Verify(context.Background(), k.edToken(t, validClaims()))
	if err != nil || u.Accounts != nil {
		t.Fatalf("tanpa klaim accounts: user=%+v err=%v", u, err)
	}
}

func TestJWTVerifierAcceptsTheFullAccountsClaim(t *testing.T) {
	k := newTestKeys(t)
	v := newTestVerifier(t, k)
	accounts := make([]any, MaxAccounts)
	for i := range accounts {
		accounts[i] = fmt.Sprintf("ACC%029d", i)
	}
	token := k.edToken(t, with(validClaims(), "accounts", accounts))
	if len(token) <= 8<<10 || len(token) > MaxTokenBytes {
		t.Fatalf("token length = %d, want between 8 KB and the limit", len(token))
	}
	u, err := v.Verify(context.Background(), token)
	if err != nil {
		t.Fatal(err)
	}
	if u.Accounts == nil || len(u.Accounts.IDs) != MaxAccounts || u.Accounts.Ignored != 0 {
		t.Fatalf("accounts = %d ids, %d ignored", len(u.Accounts.IDs), u.Accounts.Ignored)
	}
}
