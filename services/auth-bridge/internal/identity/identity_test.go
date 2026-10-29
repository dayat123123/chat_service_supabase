package identity

import "testing"

func TestUUIDv5RFCVector(t *testing.T) {
	// Namespace DNS (RFC 9562) + "www.example.com"; nilai pembanding dari
	// PostgreSQL uuid_generate_v5.
	dns := [16]byte{0x6b, 0xa7, 0xb8, 0x10, 0x9d, 0xad, 0x11, 0xd1, 0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8}
	if got, want := UUIDv5(dns, "www.example.com"), "2ed6657d-e927-568b-95e1-2665a8aea6a2"; got != want {
		t.Fatalf("UUIDv5 = %s, want %s", got, want)
	}
}

func TestUserIDMatchesSeed(t *testing.T) {
	// Harus sama dengan extensions.uuid_generate_v5('0b7f6c1e-...', '1001') di seed.sql.
	if got, want := UserID("1001"), "72689cd3-ea55-584f-9e84-c257af0564e0"; got != want {
		t.Fatalf("UserID(1001) = %s, want %s", got, want)
	}
}

func TestUserIDStable(t *testing.T) {
	if UserID("abc") != UserID("abc") {
		t.Fatal("UserID harus deterministik")
	}
	if UserID("abc") == UserID("abd") {
		t.Fatal("id OLT berbeda harus menghasilkan UUID berbeda")
	}
}
