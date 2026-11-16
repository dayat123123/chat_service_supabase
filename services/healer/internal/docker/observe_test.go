package docker

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"testing"
	"time"
)

func TestListAllIncludesStoppedContainersAndReadsReplicaNumber(t *testing.T) {
	var rawQuery string
	client, _ := fakeEngine(t, func(w http.ResponseWriter, r *http.Request) {
		rawQuery = r.URL.RawQuery
		_, _ = w.Write([]byte(`[
			{"Id":"` + fullID + `","Names":["/olt-social-rest-2"],"State":"running","Labels":{"com.docker.compose.service":"rest","com.docker.compose.container-number":"2"}},
			{"Id":"` + fullID[:12] + `","Names":["/olt-social-trade-relay-1"],"State":"exited","Labels":{"com.docker.compose.service":"trade-relay"}},
			{"Id":"nope","Names":["/evil"],"State":"running","Labels":{}}
		]`))
	})
	got, err := client.ListAll(context.Background(), "com.docker.compose.project=olt-social")
	if err != nil {
		t.Fatal(err)
	}
	q, _ := url.ParseQuery(rawQuery)
	var filters map[string][]string
	_ = json.Unmarshal([]byte(q.Get("filters")), &filters)
	if q.Get("all") != "1" || filters["label"][0] != "com.docker.compose.project=olt-social" {
		t.Fatalf("query = %s", rawQuery)
	}
	if len(got) != 2 || got[0].Service != "rest" || got[0].Number != 2 || got[0].State != "running" ||
		got[1].Service != "trade-relay" || got[1].Number != 0 || got[1].State != "exited" {
		t.Fatalf("summaries = %+v", got)
	}
}

func TestStatusReadsLifecycleAndImage(t *testing.T) {
	client, calls := fakeEngine(t, func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"RestartCount":3,"State":{"Status":"exited","Running":false,"ExitCode":137,
			"StartedAt":"2026-11-16T01:00:00Z","FinishedAt":"2026-11-16T02:00:00Z","Health":{"Status":"unhealthy"}},
			"Config":{"Image":"olt-social/trade-relay:0.1.0","Env":["SECRET=x"]}}`))
	})
	s, err := client.Status(context.Background(), fullID)
	if err != nil {
		t.Fatal(err)
	}
	if s.State != "exited" || s.Running || s.ExitCode != 137 || s.RestartCount != 3 || s.Health != "unhealthy" ||
		s.Image != "olt-social/trade-relay:0.1.0" || !s.FinishedAt.Equal(time.Date(2026, 11, 16, 2, 0, 0, 0, time.UTC)) {
		t.Fatalf("status = %+v", s)
	}
	if (*calls)[0].path != "/containers/"+fullID+"/json" {
		t.Fatalf("path = %s", (*calls)[0].path)
	}
	if _, err := client.Status(context.Background(), "olt-social-rest-1"); err == nil {
		t.Fatal("status by name accepted")
	}
}

func TestStatusTreatsZeroTimesAsUnknown(t *testing.T) {
	client, _ := fakeEngine(t, func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"State":{"Status":"created","StartedAt":"0001-01-01T00:00:00Z","FinishedAt":""},"Config":{}}`))
	})
	s, err := client.Status(context.Background(), fullID)
	if err != nil {
		t.Fatal(err)
	}
	if !s.StartedAt.IsZero() || !s.FinishedAt.IsZero() || s.Health != "" {
		t.Fatalf("status = %+v", s)
	}
}

func TestUsageUsesOneShotStatsAndSubtractsPageCache(t *testing.T) {
	var rawQuery string
	client, _ := fakeEngine(t, func(w http.ResponseWriter, r *http.Request) {
		rawQuery = r.URL.RawQuery
		_, _ = w.Write([]byte(`{"read":"2026-11-16T02:00:00Z",
			"cpu_stats":{"cpu_usage":{"total_usage":500},"system_cpu_usage":10000,"online_cpus":4},
			"memory_stats":{"usage":3000,"limit":8000,"stats":{"inactive_file":1000}}}`))
	})
	u, err := client.Usage(context.Background(), fullID)
	if err != nil {
		t.Fatal(err)
	}
	q, _ := url.ParseQuery(rawQuery)
	if q.Get("stream") != "false" || q.Get("one-shot") != "true" {
		t.Fatalf("query = %s", rawQuery)
	}
	if u.CPUTotal != 500 || u.SystemTotal != 10000 || u.OnlineCPUs != 4 || u.Memory != 2000 || u.MemoryLimit != 8000 {
		t.Fatalf("usage = %+v", u)
	}
}

func TestUsageReadsCgroupV1Cache(t *testing.T) {
	client, _ := fakeEngine(t, func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"memory_stats":{"usage":3000,"limit":0,"stats":{"total_inactive_file":500}}}`))
	})
	u, err := client.Usage(context.Background(), fullID)
	if err != nil || u.Memory != 2500 {
		t.Fatalf("usage = %+v err = %v", u, err)
	}
}

func TestInfoReadsHostCapacity(t *testing.T) {
	client, calls := fakeEngine(t, func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"Name":"srv-1","NCPU":8,"MemTotal":33554432000,"OperatingSystem":"Ubuntu 24.04","ServerVersion":"28.1.1"}`))
	})
	info, err := client.Info(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if info.Name != "srv-1" || info.CPUs != 8 || info.Memory != 33554432000 || info.OS != "Ubuntu 24.04" || info.ServerVersion != "28.1.1" {
		t.Fatalf("info = %+v", info)
	}
	if (*calls)[0].path != "/info" {
		t.Fatalf("path = %s", (*calls)[0].path)
	}
}
