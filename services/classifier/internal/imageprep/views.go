package imageprep

import (
	"image"
	"image/color"
	"math"
)

type Prep struct {
	Side    int
	CropPct float64
	Mean    [3]float32
	Std     [3]float32
}

type sample func(x, y int) (float32, float32, float32)

func (p Prep) Tensors(img image.Image) [][]float32 {
	b := img.Bounds()
	w, h := b.Dx(), b.Dy()
	s := max(1, int(math.Round(float64(min(w, h))*p.CropPct)))
	x0, y0 := b.Min.X+(w-s)/2, b.Min.Y+(h-s)/2
	center := image.Rect(x0, y0, x0+s, y0+s)
	at := sampler(img)
	views := [][]float32{p.tensor(at, center)}
	if center != b {
		views = append(views, p.tensor(at, b))
	}
	return views
}

func (p Prep) tensor(at sample, r image.Rectangle) []float32 {
	side := p.Side
	plane := side * side
	out := make([]float32, 3*plane)
	rw, rh := r.Dx(), r.Dy()
	for ty := 0; ty < side; ty++ {
		ya := r.Min.Y + ty*rh/side
		yb := max(ya+1, r.Min.Y+(ty+1)*rh/side)
		for tx := 0; tx < side; tx++ {
			xa := r.Min.X + tx*rw/side
			xb := max(xa+1, r.Min.X+(tx+1)*rw/side)
			var sr, sg, sb float32
			for y := ya; y < yb; y++ {
				for x := xa; x < xb; x++ {
					cr, cg, cb := at(x, y)
					sr, sg, sb = sr+cr, sg+cg, sb+cb
				}
			}
			n := float32((yb-ya)*(xb-xa)) * 255
			i := ty*side + tx
			out[i] = (sr/n - p.Mean[0]) / p.Std[0]
			out[plane+i] = (sg/n - p.Mean[1]) / p.Std[1]
			out[2*plane+i] = (sb/n - p.Mean[2]) / p.Std[2]
		}
	}
	return out
}

func sampler(img image.Image) sample {
	switch m := img.(type) {
	case *image.YCbCr:
		return func(x, y int) (float32, float32, float32) {
			ci := m.COffset(x, y)
			r, g, b := color.YCbCrToRGB(m.Y[m.YOffset(x, y)], m.Cb[ci], m.Cr[ci])
			return float32(r), float32(g), float32(b)
		}
	case *image.NYCbCrA:
		return func(x, y int) (float32, float32, float32) {
			ci := m.COffset(x, y)
			r, g, b := color.YCbCrToRGB(m.Y[m.YOffset(x, y)], m.Cb[ci], m.Cr[ci])
			return straight(float32(r), float32(g), float32(b), float32(m.A[m.AOffset(x, y)]))
		}
	case *image.RGBA:
		return func(x, y int) (float32, float32, float32) {
			p := m.Pix[m.PixOffset(x, y):]
			white := 255 - float32(p[3])
			return float32(p[0]) + white, float32(p[1]) + white, float32(p[2]) + white
		}
	case *image.NRGBA:
		return func(x, y int) (float32, float32, float32) {
			p := m.Pix[m.PixOffset(x, y):]
			return straight(float32(p[0]), float32(p[1]), float32(p[2]), float32(p[3]))
		}
	case *image.Gray:
		return func(x, y int) (float32, float32, float32) {
			v := float32(m.Pix[m.PixOffset(x, y)])
			return v, v, v
		}
	case *image.Paletted:
		var palette [256][3]float32
		for i := range palette {
			palette[i] = [3]float32{255, 255, 255}
		}
		for i, c := range m.Palette {
			if i == len(palette) {
				break
			}
			palette[i] = premultipliedOverWhite(c)
		}
		return func(x, y int) (float32, float32, float32) {
			c := palette[m.Pix[m.PixOffset(x, y)]]
			return c[0], c[1], c[2]
		}
	}
	return func(x, y int) (float32, float32, float32) {
		c := premultipliedOverWhite(img.At(x, y))
		return c[0], c[1], c[2]
	}
}

func straight(r, g, b, a float32) (float32, float32, float32) {
	white := 255 - a
	return r*a/255 + white, g*a/255 + white, b*a/255 + white
}

func premultipliedOverWhite(c color.Color) [3]float32 {
	r, g, b, a := c.RGBA()
	white := float32(0xFFFF-a) / 257
	return [3]float32{float32(r)/257 + white, float32(g)/257 + white, float32(b)/257 + white}
}
