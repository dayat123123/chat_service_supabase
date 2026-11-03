package logstate

import "testing"

func TestLatchReportsOnlyStateChanges(t *testing.T) {
	var l Latch
	if l.Recover() {
		t.Fatal("recover before any failure must be quiet")
	}
	if !l.Fail("down") || l.Fail("down") || !l.Failing() {
		t.Fatal("the first failure is reported once")
	}
	if !l.Fail("other") {
		t.Fatal("a different error is reported")
	}
	if !l.Recover() || l.Recover() || l.Failing() {
		t.Fatal("recovery is reported once")
	}
}
