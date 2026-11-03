package disk

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"
)

func TestParse(t *testing.T) {
	targets, err := Parse(" data=/mnt/disks/data/ ,storage=/mnt/disks/storage,, wal=/var/lib/../lib/wal")
	if err != nil {
		t.Fatal(err)
	}
	want := []Target{{"data", "/mnt/disks/data"}, {"storage", "/mnt/disks/storage"}, {"wal", "/var/lib/wal"}}
	if !reflect.DeepEqual(targets, want) {
		t.Fatalf("targets = %+v", targets)
	}
	for _, spec := range []string{"data", "data=", "data=relative", "Data=/x", strings.Repeat("d", 41) + "=/x", "a=/x,a=/y"} {
		if _, err := Parse(spec); err == nil {
			t.Errorf("Parse(%q) accepted", spec)
		}
	}
	var many []string
	for i := range MaxTargets + 1 {
		many = append(many, "d"+string(rune('a'+i))+"=/x")
	}
	if _, err := Parse(strings.Join(many, ",")); err == nil {
		t.Fatal("more than MaxTargets disks accepted")
	}
}

func TestUsageEncodesWithoutThePath(t *testing.T) {
	data, _ := json.Marshal(Usage{Name: "data", TotalBytes: 3, FreeBytes: 2, AvailBytes: 1})
	if string(data) != `{"name":"data","total_bytes":3,"free_bytes":2,"avail_bytes":1}` {
		t.Fatalf("json = %s", data)
	}
}
