package protocol

import (
	"crypto/aes"
	"crypto/cipher"
	"encoding/binary"
	"errors"
	"fmt"
	"time"

	"github.com/golang/snappy"
)

const (
	Signature     uint32 = 0x332fad12
	HeaderLength         = 23
	MaxPacket            = 4 << 20
	MaxString            = 4096
	PkgNewOrder   uint16 = 0x0022
	PkgAmendOrder uint16 = 0x0023
	PkgTrade      uint16 = 0x0024
	PkgHeartbeat  uint16 = 0xffff

	FlagEncrypted  uint16 = 0x0001
	FlagCompressed uint16 = 0x0002
)

var (
	ErrShort       = errors.New("packet shorter than header")
	ErrTooLarge    = errors.New("packet too large")
	ErrSignature   = errors.New("invalid package signature")
	ErrTruncated   = errors.New("truncated field")
	ErrString      = errors.New("string too long")
	ErrNoKey       = errors.New("encrypted package without key")
	ErrCipherText  = errors.New("invalid ciphertext length")
	ErrLength      = errors.New("invalid original length")
	ErrDecompress  = errors.New("invalid compressed payload")
	ErrUnsupported = errors.New("unsupported cipher mode")
)

type Header struct {
	PackageID uint16
	Flags     uint16
	ErrorCode uint16
	SourceID  uint8
	Date      uint32
	Time      uint32
}

func ParseHeader(buf []byte) (Header, error) {
	if len(buf) > MaxPacket {
		return Header{}, ErrTooLarge
	}
	if len(buf) < HeaderLength {
		return Header{}, ErrShort
	}
	if binary.BigEndian.Uint32(buf[0:4]) != Signature {
		return Header{}, ErrSignature
	}
	return Header{
		PackageID: binary.BigEndian.Uint16(buf[8:10]),
		Flags:     binary.BigEndian.Uint16(buf[10:12]),
		ErrorCode: binary.BigEndian.Uint16(buf[12:14]),
		SourceID:  buf[14],
		Date:      binary.BigEndian.Uint32(buf[15:19]),
		Time:      binary.BigEndian.Uint32(buf[19:23]),
	}, nil
}

func PeekPackageID(buf []byte) (uint16, bool) {
	if len(buf) < HeaderLength || binary.BigEndian.Uint32(buf[0:4]) != Signature {
		return 0, false
	}
	return binary.BigEndian.Uint16(buf[8:10]), true
}

type Cipher struct {
	block cipher.Block
	mode  string
	iv    []byte
}

func NewCipher(mode, key, iv string) (*Cipher, error) {
	if key == "" {
		return nil, nil
	}
	block, err := aes.NewCipher([]byte(key))
	if err != nil {
		return nil, fmt.Errorf("aes key: %w", err)
	}
	switch mode {
	case "", "ecb":
		return &Cipher{block: block, mode: "ecb"}, nil
	case "cbc":
		if len(iv) != aes.BlockSize {
			return nil, fmt.Errorf("aes iv must be %d bytes", aes.BlockSize)
		}
		return &Cipher{block: block, mode: "cbc", iv: []byte(iv)}, nil
	default:
		return nil, ErrUnsupported
	}
}

func (c *Cipher) decrypt(data []byte) ([]byte, error) {
	if len(data) == 0 || len(data)%aes.BlockSize != 0 {
		return nil, ErrCipherText
	}
	out := make([]byte, len(data))
	if c.mode == "cbc" {
		cipher.NewCBCDecrypter(c.block, c.iv).CryptBlocks(out, data)
		return out, nil
	}
	for i := 0; i < len(data); i += aes.BlockSize {
		c.block.Decrypt(out[i:i+aes.BlockSize], data[i:i+aes.BlockSize])
	}
	return out, nil
}

func (c *Cipher) encrypt(data []byte) []byte {
	padded := make([]byte, (len(data)+aes.BlockSize-1)/aes.BlockSize*aes.BlockSize)
	copy(padded, data)
	out := make([]byte, len(padded))
	if c.mode == "cbc" {
		cipher.NewCBCEncrypter(c.block, c.iv).CryptBlocks(out, padded)
		return out
	}
	for i := 0; i < len(padded); i += aes.BlockSize {
		c.block.Encrypt(out[i:i+aes.BlockSize], padded[i:i+aes.BlockSize])
	}
	return out
}

func originalLength(buf []byte) (int, error) {
	if len(buf) < HeaderLength+4 {
		return 0, ErrTruncated
	}
	n := int(binary.BigEndian.Uint32(buf[HeaderLength : HeaderLength+4]))
	if n < HeaderLength || n > MaxPacket {
		return 0, ErrLength
	}
	return n - HeaderLength, nil
}

func Payload(buf []byte, h Header, c *Cipher) ([]byte, error) {
	body := buf[HeaderLength:]
	if h.Flags&FlagEncrypted != 0 {
		if c == nil {
			return nil, ErrNoKey
		}
		n, err := originalLength(buf)
		if err != nil {
			return nil, err
		}
		plain, err := c.decrypt(buf[HeaderLength+4:])
		if err != nil {
			return nil, err
		}
		if n > len(plain) {
			return nil, ErrLength
		}
		body = plain[:n]
	}
	if h.Flags&FlagCompressed != 0 {
		if len(body) < 4 {
			return nil, ErrTruncated
		}
		n := int(binary.BigEndian.Uint32(body[0:4]))
		if n < HeaderLength || n > MaxPacket {
			return nil, ErrLength
		}
		want := n - HeaderLength
		decoded, err := snappy.DecodedLen(body[4:])
		if err != nil || decoded != want {
			return nil, ErrDecompress
		}
		out, err := snappy.Decode(make([]byte, decoded), body[4:])
		if err != nil {
			return nil, ErrDecompress
		}
		body = out
	}
	return body, nil
}

type Reader struct {
	buf []byte
	pos int
	err error
}

func NewReader(buf []byte) *Reader {
	return &Reader{buf: buf}
}

func (r *Reader) Err() error {
	return r.err
}

func (r *Reader) take(n int) []byte {
	if r.err != nil {
		return nil
	}
	if n < 0 || r.pos+n > len(r.buf) {
		r.err = ErrTruncated
		return nil
	}
	b := r.buf[r.pos : r.pos+n]
	r.pos += n
	return b
}

func (r *Reader) U8() uint8 {
	b := r.take(1)
	if b == nil {
		return 0
	}
	return b[0]
}

func (r *Reader) U16() uint16 {
	b := r.take(2)
	if b == nil {
		return 0
	}
	return binary.BigEndian.Uint16(b)
}

func (r *Reader) U32() uint32 {
	b := r.take(4)
	if b == nil {
		return 0
	}
	return binary.BigEndian.Uint32(b)
}

func (r *Reader) U64() uint64 {
	b := r.take(8)
	if b == nil {
		return 0
	}
	return binary.BigEndian.Uint64(b)
}

func (r *Reader) Str() string {
	n := int(r.U16())
	if r.err != nil {
		return ""
	}
	if n > MaxString {
		r.err = ErrString
		return ""
	}
	b := r.take(n)
	if b == nil {
		return ""
	}
	return trim(b)
}

func (r *Reader) Skip() {
	n := int(r.U16())
	if r.err == nil {
		r.take(n)
	}
}

func trim(b []byte) string {
	start, end := 0, len(b)
	for start < end && isSpace(b[start]) {
		start++
	}
	for end > start && isSpace(b[end-1]) {
		end--
	}
	return string(b[start:end])
}

func isSpace(c byte) bool {
	return c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == 0
}

type Order struct {
	Status       uint8
	OrderID      string
	AmendID      string
	OrderDate    uint32
	Board        string
	CustID       string
	Command      uint8
	StockCode    string
	Price        uint32
	OpenVolume   uint64
	RemainVolume uint64
	TradedVolume uint64
}

type Trade struct {
	OrderID   string
	TradeID   string
	TradeDate uint32
	TradeTime uint32
	Board     string
	CustID    string
	Command   uint8
	StockCode string
	Price     uint32
	Volume    uint64
}

func OrderCustID(payload []byte) (string, error) {
	r := NewReader(payload)
	r.U8()
	r.Skip()
	r.Skip()
	r.Skip()
	r.U32()
	r.U32()
	r.U32()
	r.Skip()
	r.Skip()
	r.U8()
	c := r.Str()
	return c, r.Err()
}

func TradeCustID(payload []byte) (string, error) {
	r := NewReader(payload)
	r.Skip()
	r.Skip()
	r.Skip()
	r.U32()
	r.U32()
	r.Skip()
	r.Skip()
	r.U8()
	c := r.Str()
	return c, r.Err()
}

func DecodeOrder(payload []byte) (Order, error) {
	r := NewReader(payload)
	var o Order
	o.Status = r.U8()
	o.OrderID = r.Str()
	o.AmendID = r.Str()
	r.Skip()
	o.OrderDate = r.U32()
	r.U32()
	r.U32()
	r.Skip()
	o.Board = r.Str()
	r.U8()
	o.CustID = r.Str()
	r.Skip()
	r.U8()
	o.Command = r.U8()
	o.StockCode = r.Str()
	o.Price = r.U32()
	o.OpenVolume = r.U64()
	o.RemainVolume = r.U64()
	o.TradedVolume = r.U64()
	if err := r.Err(); err != nil {
		return Order{}, err
	}
	return o, nil
}

func DecodeTrade(payload []byte) (Trade, error) {
	r := NewReader(payload)
	var t Trade
	t.OrderID = r.Str()
	r.Skip()
	t.TradeID = r.Str()
	t.TradeDate = r.U32()
	t.TradeTime = r.U32()
	r.Skip()
	t.Board = r.Str()
	r.U8()
	t.CustID = r.Str()
	r.Skip()
	r.U8()
	t.Command = r.U8()
	t.StockCode = r.Str()
	t.Price = r.U32()
	t.Volume = r.U64()
	if err := r.Err(); err != nil {
		return Trade{}, err
	}
	return t, nil
}

type Writer struct {
	buf []byte
}

func (w *Writer) U8(v uint8) *Writer {
	w.buf = append(w.buf, v)
	return w
}

func (w *Writer) U16(v uint16) *Writer {
	w.buf = binary.BigEndian.AppendUint16(w.buf, v)
	return w
}

func (w *Writer) U32(v uint32) *Writer {
	w.buf = binary.BigEndian.AppendUint32(w.buf, v)
	return w
}

func (w *Writer) U64(v uint64) *Writer {
	w.buf = binary.BigEndian.AppendUint64(w.buf, v)
	return w
}

func (w *Writer) Str(s string) *Writer {
	w.U16(uint16(len(s)))
	w.buf = append(w.buf, s...)
	return w
}

func (w *Writer) Bytes() []byte {
	return w.buf
}

func header(id, flags uint16, total int, at time.Time) []byte {
	h := make([]byte, HeaderLength)
	binary.BigEndian.PutUint32(h[0:4], Signature)
	binary.BigEndian.PutUint32(h[4:8], uint32(total))
	binary.BigEndian.PutUint16(h[8:10], id)
	binary.BigEndian.PutUint16(h[10:12], flags)
	if !at.IsZero() {
		binary.BigEndian.PutUint32(h[15:19], uint32(at.Year()*10000+int(at.Month())*100+at.Day()))
		binary.BigEndian.PutUint32(h[19:23], uint32(at.Hour()*10000+at.Minute()*100+at.Second()))
	}
	return h
}

func Heartbeat(at time.Time) []byte {
	return header(PkgHeartbeat, 0, HeaderLength, at)
}

type BuildOptions struct {
	Compress bool
	Cipher   *Cipher
	At       time.Time
}

func Build(id uint16, payload []byte, opt BuildOptions) []byte {
	flags := uint16(0)
	body := payload
	total := HeaderLength + len(payload)
	if opt.Compress {
		flags |= FlagCompressed
		compressed := snappy.Encode(nil, payload)
		body = binary.BigEndian.AppendUint32(nil, uint32(total))
		body = append(body, compressed...)
	}
	if opt.Cipher != nil {
		flags |= FlagEncrypted
		plainTotal := HeaderLength + len(body)
		enc := opt.Cipher.encrypt(body)
		body = binary.BigEndian.AppendUint32(nil, uint32(plainTotal))
		body = append(body, enc...)
	}
	out := header(id, flags, HeaderLength+len(body), opt.At)
	return append(out, body...)
}

func EncodeOrder(o Order) []byte {
	w := &Writer{}
	w.U8(o.Status).Str(o.OrderID).Str(o.AmendID).Str("IDX" + o.OrderID).U32(o.OrderDate).U32(90000).U32(90001).
		Str("RG").Str(o.Board).U8(0).Str(o.CustID).Str("").U8(1).U8(o.Command).Str(o.StockCode).U32(o.Price).
		U64(o.OpenVolume).U64(o.RemainVolume).U64(o.TradedVolume).Str("user").Str("").U8(6).U8(0).Str("SID").Str("CLIENT")
	return w.Bytes()
}

func EncodeTrade(t Trade) []byte {
	w := &Writer{}
	w.Str(t.OrderID).Str("IDX" + t.OrderID).Str(t.TradeID).U32(t.TradeDate).U32(t.TradeTime).Str("RG").Str(t.Board).
		U8(0).Str(t.CustID).Str("").U8(1).U8(t.Command).Str(t.StockCode).U32(t.Price).U64(t.Volume).Str("").U8(6)
	return w.Bytes()
}
