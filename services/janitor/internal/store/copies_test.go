package store

import (
	"context"
	"reflect"
	"testing"
	"time"
)

func TestClaimCopiesSendsTheLeaseAndDecodesJobs(t *testing.T) {
	var seen captured
	reply := `[{"id": 5, "source_bucket": "attachments", "source_name": "posts/u/a.png", "object_name": "e1/01-a.png"}]`
	server := recordingServer(t, reply, &seen)

	jobs, err := newStore(server.URL).ClaimCopies(context.Background(), "janitor-1", 20, 90*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	if seen.path != "/rpc/evidence_copy_claim" || seen.claims["role"] != "service_role" {
		t.Fatalf("request = %+v", seen)
	}
	if !reflect.DeepEqual(seen.args, map[string]any{"p_instance": "janitor-1", "p_limit": float64(20), "p_lease_seconds": float64(90)}) {
		t.Fatalf("args = %v", seen.args)
	}
	want := []CopyJob{{ID: 5, SourceBucket: "attachments", SourceName: "posts/u/a.png", ObjectName: "e1/01-a.png"}}
	if !reflect.DeepEqual(jobs, want) {
		t.Fatalf("jobs = %+v", jobs)
	}
}

func TestReportCopiesSendsOnlyTheFieldsOfEachOutcome(t *testing.T) {
	var seen captured
	server := recordingServer(t, `3`, &seen)
	hash := "9ac0350af7afe97ca5e9474cb60d5a3d877b0bc3d87873aae377f13f9b4b314a"

	updated, err := newStore(server.URL).ReportCopies(context.Background(), "janitor-1", []CopyResult{
		{ID: 1, SHA256: hash, Size: 854361},
		{ID: 2, Missing: true},
		{ID: 3, Error: "  storage copy attachments: status 500  "},
		{ID: 4, Release: true},
	})
	if err != nil || updated != 3 {
		t.Fatalf("updated = %d, err = %v", updated, err)
	}
	if seen.path != "/rpc/evidence_copy_report" || seen.args["p_instance"] != "janitor-1" {
		t.Fatalf("request = %+v", seen)
	}
	want := []any{
		map[string]any{"id": float64(1), "sha256": hash, "size": float64(854361), "missing": false, "error": nil, "release": false},
		map[string]any{"id": float64(2), "sha256": nil, "size": nil, "missing": true, "error": nil, "release": false},
		map[string]any{"id": float64(3), "sha256": nil, "size": nil, "missing": false,
			"error": "storage copy attachments: status 500", "release": false},
		map[string]any{"id": float64(4), "sha256": nil, "size": nil, "missing": false, "error": nil, "release": true},
	}
	if !reflect.DeepEqual(seen.args["p_results"], want) {
		t.Fatalf("results = %v", seen.args["p_results"])
	}
}
