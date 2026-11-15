package queue

import "sync"

type Queue[T any] struct {
	mu    sync.Mutex
	items []T
	head  int
	size  int
}

func New[T any](capacity int) *Queue[T] {
	if capacity < 1 {
		capacity = 1
	}
	return &Queue[T]{items: make([]T, capacity)}
}

func (q *Queue[T]) Push(v T) bool {
	q.mu.Lock()
	defer q.mu.Unlock()
	dropped := false
	if q.size == len(q.items) {
		var zero T
		q.items[q.head] = zero
		q.head = (q.head + 1) % len(q.items)
		q.size--
		dropped = true
	}
	q.items[(q.head+q.size)%len(q.items)] = v
	q.size++
	return dropped
}

func (q *Queue[T]) Peek(n int) []T {
	q.mu.Lock()
	defer q.mu.Unlock()
	if n > q.size {
		n = q.size
	}
	out := make([]T, n)
	for i := 0; i < n; i++ {
		out[i] = q.items[(q.head+i)%len(q.items)]
	}
	return out
}

func (q *Queue[T]) Drop(n int) {
	q.mu.Lock()
	defer q.mu.Unlock()
	if n > q.size {
		n = q.size
	}
	var zero T
	for i := 0; i < n; i++ {
		q.items[q.head] = zero
		q.head = (q.head + 1) % len(q.items)
	}
	q.size -= n
}

func (q *Queue[T]) Len() int {
	q.mu.Lock()
	defer q.mu.Unlock()
	return q.size
}
