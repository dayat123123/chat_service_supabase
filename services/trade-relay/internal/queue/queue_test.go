package queue

import "testing"

func TestDropsOldestWhenFull(t *testing.T) {
	q := New[int](3)
	for i := 1; i <= 3; i++ {
		if q.Push(i) {
			t.Fatalf("push %d dropped", i)
		}
	}
	if !q.Push(4) {
		t.Fatal("full push did not report a drop")
	}
	got := q.Peek(10)
	if len(got) != 3 || got[0] != 2 || got[2] != 4 {
		t.Fatalf("got %v", got)
	}
	q.Drop(2)
	if q.Len() != 1 || q.Peek(1)[0] != 4 {
		t.Fatalf("after drop %v", q.Peek(5))
	}
	q.Drop(10)
	if q.Len() != 0 {
		t.Fatal("not empty")
	}
}
