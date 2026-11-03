package main

import (
	"fmt"
	"go/scanner"
	"go/token"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

var directives = []string{"//go:", "//line ", "// +build", "//nolint", "//export "}

type finding struct {
	file string
	line int
	text string
}

func main() {
	roots := os.Args[1:]
	if len(roots) == 0 {
		roots = []string{"."}
	}
	var findings []finding
	for _, root := range roots {
		err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() {
				name := d.Name()
				if path != root && (name == "vendor" || name == "node_modules" || strings.HasPrefix(name, ".")) {
					return filepath.SkipDir
				}
				return nil
			}
			if !strings.HasSuffix(path, ".go") {
				return nil
			}
			found, err := scan(path)
			if err != nil {
				return err
			}
			findings = append(findings, found...)
			return nil
		})
		if err != nil {
			fmt.Fprintln(os.Stderr, "check-go-comments:", err)
			os.Exit(2)
		}
	}
	if len(findings) == 0 {
		return
	}
	sort.Slice(findings, func(i, j int) bool {
		if findings[i].file != findings[j].file {
			return findings[i].file < findings[j].file
		}
		return findings[i].line < findings[j].line
	})
	for _, f := range findings {
		fmt.Printf("%s:%d: %s\n", f.file, f.line, f.text)
	}
	fmt.Fprintf(os.Stderr, "check-go-comments: %d komentar ditemukan; kode Go harus tanpa komentar (penjelasan taruh di README)\n", len(findings))
	os.Exit(1)
}

func scan(path string) ([]finding, error) {
	src, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	fset := token.NewFileSet()
	file := fset.AddFile(path, fset.Base(), len(src))
	var s scanner.Scanner
	var scanErr error
	s.Init(file, src, func(pos token.Position, msg string) {
		if scanErr == nil {
			scanErr = fmt.Errorf("%s: %s", pos, msg)
		}
	}, scanner.ScanComments)
	var found []finding
	for {
		pos, tok, lit := s.Scan()
		if tok == token.EOF {
			break
		}
		if tok != token.COMMENT || isDirective(lit) {
			continue
		}
		text := lit
		if i := strings.IndexByte(text, '\n'); i >= 0 {
			text = text[:i] + " …"
		}
		if len(text) > 100 {
			text = text[:100] + "…"
		}
		found = append(found, finding{file: path, line: fset.Position(pos).Line, text: text})
	}
	return found, scanErr
}

func isDirective(comment string) bool {
	for _, d := range directives {
		if strings.HasPrefix(comment, d) {
			return true
		}
	}
	return false
}
