// Package identity menurunkan id user Supabase yang stabil dari id user OLT.
package identity

import (
	"crypto/sha1" //nolint:gosec // SHA-1 diwajibkan oleh spesifikasi UUID v5 (RFC 9562), bukan untuk keamanan.
	"fmt"
)

// Namespace UUID v5 untuk id user. JANGAN PERNAH DIUBAH: id user Supabase =
// UUIDv5(Namespace, olt_user_id). Nilai yang sama dipakai supabase/seed/seed.sql.
//
//	0b7f6c1e-5a2d-4c8e-9f3b-7d1a2e4c6f80
var Namespace = [16]byte{
	0x0b, 0x7f, 0x6c, 0x1e, 0x5a, 0x2d, 0x4c, 0x8e,
	0x9f, 0x3b, 0x7d, 0x1a, 0x2e, 0x4c, 0x6f, 0x80,
}

// UserID mengembalikan UUID user Supabase untuk id user OLT.
func UserID(oltUserID string) string {
	return UUIDv5(Namespace, oltUserID)
}

// UUIDv5 membuat UUID versi 5 (berbasis SHA-1) sesuai RFC 9562.
func UUIDv5(namespace [16]byte, name string) string {
	h := sha1.New() //nolint:gosec
	h.Write(namespace[:])
	h.Write([]byte(name))
	sum := h.Sum(nil)

	var u [16]byte
	copy(u[:], sum[:16])
	u[6] = (u[6] & 0x0f) | 0x50 // versi 5
	u[8] = (u[8] & 0x3f) | 0x80 // varian RFC 4122/9562
	return fmt.Sprintf("%x-%x-%x-%x-%x", u[0:4], u[4:6], u[6:8], u[8:10], u[10:16])
}
