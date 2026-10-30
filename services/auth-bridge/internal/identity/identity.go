package identity

import (
	"crypto/sha1" //nolint:gosec // SHA-1 diwajibkan oleh spesifikasi UUID v5 (RFC 9562), bukan untuk keamanan.
	"fmt"
)

var Namespace = [16]byte{
	0x0b, 0x7f, 0x6c, 0x1e, 0x5a, 0x2d, 0x4c, 0x8e,
	0x9f, 0x3b, 0x7d, 0x1a, 0x2e, 0x4c, 0x6f, 0x80,
}

func UserID(oltUserID string) string {
	return UUIDv5(Namespace, oltUserID)
}

func UUIDv5(namespace [16]byte, name string) string {
	h := sha1.New() //nolint:gosec
	h.Write(namespace[:])
	h.Write([]byte(name))
	sum := h.Sum(nil)

	var u [16]byte
	copy(u[:], sum[:16])
	u[6] = (u[6] & 0x0f) | 0x50
	u[8] = (u[8] & 0x3f) | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", u[0:4], u[4:6], u[6:8], u[8:10], u[10:16])
}
