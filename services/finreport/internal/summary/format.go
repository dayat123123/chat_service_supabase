package summary

import (
	"math"
	"strconv"
	"strings"
)

func number(v float64, decimals int) string {
	scale := math.Pow10(decimals)
	rounded := math.Floor(math.Abs(v)*scale+0.5+1e-9) / scale
	text := strconv.FormatFloat(rounded, 'f', decimals, 64)
	whole, frac, _ := strings.Cut(text, ".")
	var b strings.Builder
	if v < 0 && strings.Trim(text, "0.") != "" {
		b.WriteByte('-')
	}
	for i, r := range whole {
		if i > 0 && (len(whole)-i)%3 == 0 {
			b.WriteByte('.')
		}
		b.WriteRune(r)
	}
	if frac != "" {
		b.WriteByte(',')
		b.WriteString(frac)
	}
	return b.String()
}

func money(v float64, currency string) string {
	a := math.Abs(v)
	sign := ""
	if v < 0 {
		sign = "-"
	}
	if currency == "IDR" {
		switch {
		case a >= 1e12:
			return sign + "Rp" + number(a/1e12, 2) + " T"
		case a >= 1e9:
			return sign + "Rp" + number(a/1e9, 2) + " M"
		case a >= 1e6:
			return sign + "Rp" + number(a/1e6, 1) + " jt"
		}
		return sign + "Rp" + number(a, 0)
	}
	symbol := currency + " "
	if currency == "USD" {
		symbol = "US$"
	}
	switch {
	case a >= 1e9:
		return sign + symbol + number(a/1e9, 2) + " miliar"
	case a >= 1e6:
		return sign + symbol + number(a/1e6, 2) + " juta"
	case a >= 1e3:
		return sign + symbol + number(a/1e3, 1) + " ribu"
	}
	return sign + symbol + number(a, 0)
}

func perShare(v float64, currency string) string {
	decimals := 4
	switch a := math.Abs(v); {
	case a >= 100:
		decimals = 0
	case a >= 1:
		decimals = 2
	}
	text := number(math.Abs(v), decimals)
	if strings.Contains(text, ",") {
		text = strings.TrimRight(strings.TrimRight(text, "0"), ",")
	}
	sign := ""
	if v < 0 && strings.Trim(text, "0,") != "" {
		sign = "-"
	}
	switch currency {
	case "IDR":
		return sign + "Rp" + text
	case "USD":
		return sign + "US$" + text
	}
	return sign + currency + " " + text
}

func change(cur, prior float64) (float64, bool) {
	if prior <= 0 || cur < 0 {
		return 0, false
	}
	return (cur/prior - 1) * 100, true
}

func signed(p float64) string {
	if math.Abs(p) < 0.05 {
		return "0,0%"
	}
	if p > 0 {
		return "+" + number(p, 1) + "%"
	}
	return number(p, 1) + "%"
}

func words(p float64) string {
	switch {
	case math.Abs(p) < 0.05:
		return "stabil"
	case p > 0:
		return "naik " + number(p, 1) + "%"
	}
	return "turun " + number(-p, 1) + "%"
}

func percent(v float64) string {
	return number(v*100, 1) + "%"
}

func times(v float64) string {
	return number(v, 2) + "x"
}
