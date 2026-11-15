package zsock

import (
	"fmt"
	"syscall"
	"time"

	zmq "github.com/pebbe/zmq4"

	"olt-social/trade-relay/internal/relay"
)

type Socket struct {
	s *zmq.Socket
}

func Dial(addr, identity string, hwm int, recvTimeout time.Duration) (relay.Socket, error) {
	s, err := zmq.NewSocket(zmq.DEALER)
	if err != nil {
		return nil, fmt.Errorf("zmq socket: %w", err)
	}
	setup := []func() error{
		func() error { return s.SetIdentity(identity) },
		func() error { return s.SetRcvhwm(hwm) },
		func() error { return s.SetSndhwm(1000) },
		func() error { return s.SetLinger(500 * time.Millisecond) },
		func() error { return s.SetRcvtimeo(recvTimeout) },
		func() error { return s.SetSndtimeo(time.Second) },
		func() error { return s.SetReconnectIvl(time.Second) },
		func() error { return s.SetReconnectIvlMax(30 * time.Second) },
		func() error { return s.SetMaxmsgsize(8 << 20) },
		func() error { return s.Connect(addr) },
	}
	for _, f := range setup {
		if err := f(); err != nil {
			_ = s.Close()
			return nil, fmt.Errorf("zmq setup: %w", err)
		}
	}
	return &Socket{s: s}, nil
}

func (z *Socket) Recv() ([][]byte, error) {
	frames, err := z.s.RecvMessageBytes(0)
	if err != nil {
		if zmq.AsErrno(err) == zmq.Errno(syscall.EAGAIN) || zmq.AsErrno(err) == zmq.Errno(syscall.EINTR) {
			return nil, nil
		}
		return nil, err
	}
	return frames, nil
}

func (z *Socket) Send(b []byte) error {
	_, err := z.s.SendBytes(b, zmq.DONTWAIT)
	return err
}

func (z *Socket) Close() error {
	return z.s.Close()
}
