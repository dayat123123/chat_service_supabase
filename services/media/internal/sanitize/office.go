package sanitize

import (
	"archive/zip"
	"bytes"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"path"
	"slices"
	"strings"
	"unicode/utf8"
)

const (
	MaxArchiveEntries = 1000
	MaxArchiveBytes   = 100 << 20
	MaxArchiveRatio   = 100

	ratioFloor = 1 << 20
	maxPartXML = 1 << 20
)

var (
	ErrOfficeMacro  = errors.New("office document has macros")
	ErrOfficeUnsafe = errors.New("office document has unsafe content")
	ErrArchiveBomb  = errors.New("office archive exceeds the unpack limits")
	ErrInvalidText  = errors.New("text is not valid UTF-8")
)

var macroNames = []string{"vbaproject.bin", "vbadata.xml", "vbaprojectsignature.bin"}

var executableExtensions = map[string]bool{
	"exe": true, "dll": true, "scr": true, "com": true, "bat": true, "cmd": true, "ps1": true, "vbs": true,
	"vbe": true, "js": true, "jse": true, "wsf": true, "wsh": true, "msi": true, "msp": true, "jar": true,
	"hta": true, "cpl": true, "lnk": true, "pif": true, "reg": true, "apk": true, "sh": true, "elf": true,
}

var macroExtensions = map[string]bool{
	"docm": true, "dotm": true, "xlsm": true, "xltm": true, "xlam": true, "xlsb": true, "pptm": true,
	"potm": true, "ppsm": true, "ppam": true,
}

var legacyExtensions = map[string]bool{"doc": true, "xls": true, "ppt": true, "dot": true, "xlt": true, "pot": true}

var autoLoadRelations = []string{"/attachedtemplate", "/oleobject", "/frame", "/subdocument", "/control", "/package"}

func Office(data []byte) ([]byte, Info, error) {
	r, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return nil, Info{}, fmt.Errorf("%w: not a readable zip: %v", ErrOfficeUnsafe, err)
	}
	if len(r.File) > MaxArchiveEntries {
		return nil, Info{}, fmt.Errorf("%w: %d entries", ErrArchiveBomb, len(r.File))
	}
	var total uint64
	for _, f := range r.File {
		total += f.UncompressedSize64
		if total > MaxArchiveBytes {
			return nil, Info{}, fmt.Errorf("%w: more than %d bytes unpacked", ErrArchiveBomb, MaxArchiveBytes)
		}
		if f.UncompressedSize64 >= ratioFloor && f.UncompressedSize64 > MaxArchiveRatio*max(f.CompressedSize64, 1) {
			return nil, Info{}, fmt.Errorf("%w: entry ratio over %d", ErrArchiveBomb, MaxArchiveRatio)
		}
		if err := checkEntry(f); err != nil {
			return nil, Info{}, err
		}
	}
	for _, f := range r.File {
		name := strings.ToLower(f.Name)
		switch {
		case name == "[content_types].xml":
			err = checkContentTypes(f)
		case strings.HasSuffix(name, ".rels"):
			err = checkRelations(f)
		}
		if err != nil {
			return nil, Info{}, err
		}
	}
	return data, Info{}, nil
}

func checkEntry(f *zip.File) error {
	name := strings.ToLower(strings.ReplaceAll(f.Name, "\\", "/"))
	base := path.Base(name)
	ext := strings.TrimPrefix(path.Ext(base), ".")
	switch {
	case f.Flags&0x1 != 0:
		return fmt.Errorf("%w: encrypted entry", ErrOfficeUnsafe)
	case strings.HasPrefix(name, "/") || strings.Contains("/"+name+"/", "/../"):
		return fmt.Errorf("%w: entry path escapes the archive", ErrOfficeUnsafe)
	case slices.Contains(macroNames, base), macroExtensions[ext]:
		return fmt.Errorf("%w: %s", ErrOfficeMacro, base)
	case strings.Contains(name, "/activex/"):
		return fmt.Errorf("%w: activex control", ErrOfficeUnsafe)
	case executableExtensions[ext], legacyExtensions[ext]:
		return fmt.Errorf("%w: embedded %s file", ErrOfficeUnsafe, ext)
	case strings.Contains(name, "/embeddings/") && (ext == "bin" || strings.HasPrefix(base, "oleobject")):
		return fmt.Errorf("%w: embedded OLE object", ErrOfficeUnsafe)
	}
	return nil
}

func checkContentTypes(f *zip.File) error {
	var types struct {
		Defaults []struct {
			ContentType string `xml:"ContentType,attr"`
		} `xml:"Default"`
		Overrides []struct {
			ContentType string `xml:"ContentType,attr"`
		} `xml:"Override"`
	}
	if err := decodePart(f, &types); err != nil {
		return err
	}
	all := make([]string, 0, len(types.Defaults)+len(types.Overrides))
	for _, d := range types.Defaults {
		all = append(all, d.ContentType)
	}
	for _, o := range types.Overrides {
		all = append(all, o.ContentType)
	}
	for _, ct := range all {
		ct = strings.ToLower(ct)
		switch {
		case strings.Contains(ct, "macroenabled"), strings.Contains(ct, "vbaproject"), strings.Contains(ct, "ms-office.vba"):
			return fmt.Errorf("%w: content type %s", ErrOfficeMacro, ct)
		case strings.Contains(ct, "activex"), strings.Contains(ct, "oleobject"):
			return fmt.Errorf("%w: content type %s", ErrOfficeUnsafe, ct)
		}
	}
	return nil
}

func checkRelations(f *zip.File) error {
	var rels struct {
		Items []struct {
			Type       string `xml:"Type,attr"`
			Target     string `xml:"Target,attr"`
			TargetMode string `xml:"TargetMode,attr"`
		} `xml:"Relationship"`
	}
	if err := decodePart(f, &rels); err != nil {
		return err
	}
	for _, rel := range rels.Items {
		kind := strings.ToLower(rel.Type)
		if strings.Contains(kind, "vbaproject") {
			return fmt.Errorf("%w: vba relationship", ErrOfficeMacro)
		}
		if !strings.EqualFold(rel.TargetMode, "External") {
			continue
		}
		target := strings.ToLower(strings.TrimSpace(rel.Target))
		for _, auto := range autoLoadRelations {
			if strings.HasSuffix(kind, auto) {
				return fmt.Errorf("%w: external %s relationship", ErrOfficeUnsafe, strings.TrimPrefix(auto, "/"))
			}
		}
		if !safeExternal(target) {
			return fmt.Errorf("%w: external relationship target %q", ErrOfficeUnsafe, clipTarget(target))
		}
	}
	return nil
}

func safeExternal(target string) bool {
	if strings.HasPrefix(target, `\\`) || strings.HasPrefix(target, "//") {
		return false
	}
	scheme, _, found := strings.Cut(target, ":")
	if !found || strings.ContainsAny(scheme, "/?#") {
		return true
	}
	switch scheme {
	case "http", "https", "mailto":
		return true
	}
	return false
}

func clipTarget(s string) string {
	if len(s) > 60 {
		return s[:60]
	}
	return s
}

func decodePart(f *zip.File, out any) error {
	rc, err := f.Open()
	if err != nil {
		return fmt.Errorf("%w: cannot open %s: %v", ErrOfficeUnsafe, f.Name, err)
	}
	defer rc.Close()
	if err := xml.NewDecoder(io.LimitReader(rc, maxPartXML)).Decode(out); err != nil {
		return fmt.Errorf("%w: cannot read %s: %v", ErrOfficeUnsafe, f.Name, err)
	}
	return nil
}

func Text(data []byte) ([]byte, Info, error) {
	body := bytes.TrimPrefix(data, []byte("\xEF\xBB\xBF"))
	if len(body) == 0 || bytes.IndexByte(body, 0) >= 0 || !utf8.Valid(body) {
		return nil, Info{}, ErrInvalidText
	}
	return data, Info{}, nil
}
