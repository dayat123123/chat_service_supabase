package server

import (
	"strings"
)

const (
	maxSegments      = 6
	maxSegmentLength = 128
	maxPathLength    = 400
)

func splitPath(escaped string) (string, []string, bool) {
	rest, ok := strings.CutPrefix(escaped, "/object/")
	if !ok {
		return "", nil, false
	}
	name, path, _ := strings.Cut(rest, "/")
	if path == "" || len(path) > maxPathLength {
		return name, nil, false
	}
	segments := strings.Split(path, "/")
	if len(segments) > maxSegments {
		return name, nil, false
	}
	for _, s := range segments {
		if len(s) == 0 || len(s) > maxSegmentLength || s == "." || s == ".." || !validChars(s) {
			return name, nil, false
		}
	}
	return name, segments, true
}

func validChars(s string) bool {
	for i := 0; i < len(s); i++ {
		c := s[i]
		if (c < 'a' || c > 'z') && (c < 'A' || c > 'Z') && (c < '0' || c > '9') && c != '.' && c != '_' && c != '-' {
			return false
		}
	}
	return true
}

func finalPath(segments []string, ext string) string {
	last := segments[len(segments)-1]
	if i := strings.LastIndexByte(last, '.'); i > 0 {
		last = last[:i]
	}
	out := make([]string, 0, len(segments))
	out = append(out, segments[:len(segments)-1]...)
	return strings.Join(append(out, last+"."+ext), "/")
}
