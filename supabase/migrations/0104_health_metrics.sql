create table private.health_metric_sources (
  source     text not null check (source ~ '^[a-z0-9][a-z0-9_.-]{0,59}$'),
  instance   text not null default '' check (char_length(instance) <= 100),
  ok         boolean not null,
  error      text,
  checked_at timestamptz not null,
  primary key (source, instance)
);
alter table private.health_metric_sources enable row level security;

create table private.health_metric_samples (
  source     text not null,
  instance   text not null default '',
  name       text not null,
  value      double precision not null,
  sampled_at timestamptz not null default now()
);
create index health_metric_samples_name_idx on private.health_metric_samples (name, sampled_at);
alter table private.health_metric_samples enable row level security;

insert into private.settings (key, value, description) values
  ('health.rest_pool_timeouts_warn', '1',
   'Timeout pool PostgREST (PGRST003, HTTP 504) dalam 5 menit yang memicu peringatan'),
  ('health.rest_pool_timeouts_critical', '20',
   'Timeout pool PostgREST (PGRST003, HTTP 504) dalam 5 menit yang memicu alert kritis'),
  ('health.rest_pool_waiting_warn', '1',
   'Request yang menunggu koneksi saat pool PostgREST kosong (available 0, sampel terakhir) yang memicu peringatan'),
  ('health.realtime_events_warn_ratio', '0.7',
   'Laju event Realtime dibanding batas tenant (max_events_per_second) yang memicu peringatan (0–1)'),
  ('health.realtime_events_critical_ratio', '0.9',
   'Laju event Realtime dibanding batas tenant yang memicu alert kritis (0–1)'),
  ('health.realtime_events_limit', '10000',
   'Batas event/dtk tenant Realtime yang dipakai bila _realtime.tenants tidak terbaca'),
  ('health.pgbouncer_waiting_warn', '1',
   'Klien PgBouncer yang mengantre koneksi server (cl_waiting) yang memicu peringatan'),
  ('health.pgbouncer_maxwait_warn_seconds', '1',
   'Tunggu terlama klien PgBouncer (maxwait, detik) yang memicu peringatan'),
  ('health.pgbouncer_maxwait_critical_seconds', '5',
   'Tunggu terlama klien PgBouncer (maxwait, detik) yang memicu alert kritis'),
  ('health.lock_waiters_warn', '5',
   'Jumlah proses database yang menunggu lock yang memicu peringatan'),
  ('health.lock_waiters_critical', '20',
   'Jumlah proses database yang menunggu lock yang memicu alert kritis'),
  ('health.lock_wait_warn_seconds', '5',
   'Tunggu lock terlama (detik) yang memicu peringatan'),
  ('health.lock_wait_critical_seconds', '30',
   'Tunggu lock terlama (detik) yang memicu alert kritis'),
  ('health.room_preview_lag_warn_seconds', '60',
   'Umur antrean pratinjau room (chat-room-preview, detik) yang memicu peringatan'),
  ('health.room_preview_lag_critical_seconds', '300',
   'Umur antrean pratinjau room (chat-room-preview, detik) yang memicu alert kritis')
on conflict (key) do nothing;

create or replace function private.health_realtime_events_limit()
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit numeric;
begin
  if to_regclass('_realtime.tenants') is not null then
    begin
      execute 'select max(t.max_events_per_second) from _realtime.tenants t' into v_limit;
    exception when others then
      v_limit := null;
    end;
  end if;
  return coalesce(nullif(v_limit, 0), private.setting_num('health.realtime_events_limit', 10000));
end;
$$;

create or replace function private.health_checks_metrics()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  with latest as (
    select distinct on (s.source, s.instance, s.name) s.source, s.instance, s.name, s.value
    from private.health_metric_samples s
    where s.sampled_at > now() - interval '90 seconds'
    order by s.source, s.instance, s.name, s.sampled_at desc
  ),
  increments as (
    select x.source, x.instance, x.name, x.sampled_at, x.prev_at,
           case when x.value >= x.prev then x.value - x.prev else x.value end as inc
    from (
      select s.source, s.instance, s.name, s.value, s.sampled_at,
             lag(s.value) over w as prev, lag(s.sampled_at) over w as prev_at
      from private.health_metric_samples s
      where s.name in ('pgrst_db_pool_timeouts_total', 'realtime_channel_global_events')
        and s.sampled_at > now() - interval '5 minutes'
      window w as (partition by s.source, s.instance, s.name order by s.sampled_at)
    ) x
    where x.prev is not null
  ),
  rest as (
    select (select coalesce(sum(i.inc), 0) from increments i where i.name = 'pgrst_db_pool_timeouts_total') as timeouts,
           (select coalesce(sum(w.value), 0)
              from latest w
              join latest a on a.source = w.source and a.instance = w.instance and a.name = 'pgrst_db_pool_available'
             where w.name = 'pgrst_db_pool_waiting' and a.value <= 0) as waiting,
           (select coalesce(sum(l.value), 0) from latest l where l.name = 'pgrst_db_pool_max') as pool
  ),
  realtime as (
    select r.rate, private.health_realtime_events_limit() as max_rate
    from (
      select sum(p.rate) as rate
      from (
        select sum(i.inc) / extract(epoch from max(i.sampled_at) - min(i.prev_at)) as rate
        from increments i
        where i.name = 'realtime_channel_global_events' and i.prev_at > now() - interval '150 seconds'
        group by i.source, i.instance
        having extract(epoch from max(i.sampled_at) - min(i.prev_at)) >= 20
      ) p
    ) r
    where r.rate is not null
  ),
  bouncer as (
    select coalesce(sum(l.value) filter (where l.name = 'pgbouncer_cl_waiting'), 0) as waiting,
           coalesce(max(l.value) filter (where l.name = 'pgbouncer_maxwait_seconds'), 0) as maxwait,
           count(*) filter (where l.name = 'pgbouncer_cl_waiting') as instances
    from latest l
  ),
  locks as (
    select count(distinct l.pid) as waiters,
           coalesce(extract(epoch from max(now() - l.waitstart)), 0) as longest
    from pg_catalog.pg_locks l
    where not l.granted
  )
  select 'rest:pool',
         case when r.timeouts >= private.setting_num('health.rest_pool_timeouts_critical', 20) then 'critical' else 'warning' end,
         'Pool koneksi API (PostgREST) penuh',
         r.waiting::bigint || ' request menunggu koneksi pool (maks. ' || r.pool::bigint || ' koneksi), '
           || r.timeouts::bigint || ' timeout PGRST003 (HTTP 504) dalam 5 menit terakhir'
  from rest r
  where r.timeouts >= private.setting_num('health.rest_pool_timeouts_warn', 1)
     or r.waiting >= private.setting_num('health.rest_pool_waiting_warn', 1)
  union all
  select 'realtime:events',
         case when r.rate >= r.max_rate * private.setting_num('health.realtime_events_critical_ratio', 0.9)
              then 'critical' else 'warning' end,
         case when r.rate >= r.max_rate then 'Realtime membuang event: batas tenant tercapai'
              else 'Realtime mendekati batas event tenant' end,
         round(r.rate) || ' event/dtk dari batas ' || r.max_rate || ' (' || round(r.rate * 100 / r.max_rate) || '%), '
           || 'rata-rata 2 menit terakhir. Di atas batas, pesan tidak sampai lewat Realtime'
  from realtime r
  where r.rate >= r.max_rate * private.setting_num('health.realtime_events_warn_ratio', 0.7)
  union all
  select 'pgbouncer:queue',
         case when b.maxwait >= private.setting_num('health.pgbouncer_maxwait_critical_seconds', 5)
              then 'critical' else 'warning' end,
         'PgBouncer mengantre koneksi',
         b.waiting::bigint || ' klien menunggu koneksi server, tunggu terlama ' || round(b.maxwait::numeric, 1) || ' dtk'
  from bouncer b
  where b.instances > 0
    and (b.waiting >= private.setting_num('health.pgbouncer_waiting_warn', 1)
         or b.maxwait >= private.setting_num('health.pgbouncer_maxwait_warn_seconds', 1))
  union all
  select 'db:lock_waits',
         case when k.waiters >= private.setting_num('health.lock_waiters_critical', 20)
                or k.longest >= private.setting_num('health.lock_wait_critical_seconds', 30)
              then 'critical' else 'warning' end,
         'Proses database menunggu lock',
         k.waiters || ' proses menunggu lock, terlama ' || round(k.longest::numeric, 1) || ' dtk'
  from locks k
  where k.waiters >= private.setting_num('health.lock_waiters_warn', 5)
     or k.longest >= private.setting_num('health.lock_wait_warn_seconds', 5)
  union all
  select 'metrics:' || m.source, 'warning',
         'Metrik ' || private.health_service_label(m.source) || ' tidak bisa dibaca',
         string_agg(case when m.instance = '' then '' else m.instance || ': ' end || coalesce(m.error, 'gagal'), '; '
                    order by m.instance)
  from private.health_metric_sources m
  where not m.ok and m.checked_at > now() - interval '90 seconds'
  group by m.source;
$$;

create or replace function private.health_checks_room_preview()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  select 'queue:room_preview',
         case when q.lag >= private.setting_num('health.room_preview_lag_critical_seconds', 300) then 'critical' else 'warning' end,
         'Pratinjau room tertahan',
         q.rooms || ' room menunggu pembaruan pratinjau, terlama ' || private.health_fmt_duration(make_interval(secs => q.lag))
           || ' (' || round(q.lag) || ' dtk). Job terjadwal chat-room-preview mati atau macet'
  from (
    select count(distinct r.room_id) as rooms, extract(epoch from now() - min(r.queued_at)) as lag
    from private.room_preview_queue r
  ) q
  where q.lag >= private.setting_num('health.room_preview_lag_warn_seconds', 60);
$$;

create or replace function private.health_current()
returns table (key text, severity text, title text, detail text)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct on (c.key) c.key, c.severity, left(c.title, 200), left(c.detail, 500)
  from (
    select * from private.health_checks_services()
    union all select * from private.health_checks_probes()
    union all select * from private.health_checks_disks()
    union all select * from private.health_checks_database()
    union all select * from private.health_checks_queues()
    union all select * from private.health_checks_backup()
    union all select * from private.health_checks_secrets()
    union all select * from private.health_checks_metrics()
    union all select * from private.health_checks_room_preview()
  ) c
  where c.key is not null
  order by c.key, case c.severity when 'critical' then 0 else 1 end;
$$;

drop function public.health_report(text, text, timestamptz, jsonb, jsonb);

create function public.health_report(
  p_instance text, p_version text, p_started_at timestamptz, p_probes jsonb default '[]', p_disks jsonb default '[]',
  p_metrics jsonb default '[]'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if jsonb_typeof(p_probes) is distinct from 'array' or jsonb_typeof(p_disks) is distinct from 'array'
     or jsonb_array_length(p_probes) > 100 or jsonb_array_length(p_disks) > 20 then
    perform private.api_error(400, 'invalid_health_report', 'Probe dan disk harus berupa array (maks 100/20)');
  end if;
  if jsonb_typeof(p_metrics) is distinct from 'array' or jsonb_array_length(p_metrics) > 200
     or pg_column_size(p_metrics) > 262144 then
    perform private.api_error(400, 'invalid_health_report', 'Metrik harus berupa array (maks 200 sumber)');
  end if;
  perform public.service_heartbeat('sentinel', p_instance, p_version, p_started_at, 'ok', null,
    jsonb_build_object('probes', jsonb_array_length(p_probes), 'disks', jsonb_array_length(p_disks),
                       'metrics', jsonb_array_length(p_metrics)));

  insert into private.health_probes as h (name, target, ok, status, latency_ms, error, checked_at, last_ok_at, failing_since)
  select distinct on (x.name) x.name, left(x.target, 300), coalesce(x.ok, false), x.status, x.latency_ms,
         left(nullif(btrim(x.error), ''), 300), now(),
         case when coalesce(x.ok, false) then now() end,
         case when coalesce(x.ok, false) then null else now() end
  from jsonb_to_recordset(p_probes) as x(name text, target text, ok boolean, status integer, latency_ms integer, error text)
  where x.name ~ '^[a-z0-9][a-z0-9_.-]{0,59}$'
  order by x.name
  on conflict (name) do update
     set target = excluded.target, ok = excluded.ok, status = excluded.status, latency_ms = excluded.latency_ms,
         error = excluded.error, checked_at = now(),
         last_ok_at = case when excluded.ok then now() else h.last_ok_at end,
         failing_since = case when excluded.ok then null else coalesce(h.failing_since, now()) end;
  delete from private.health_probes h
   where h.name not in (select x.name from jsonb_to_recordset(p_probes) as x(name text) where x.name is not null);

  insert into private.health_disks as h (name, total_bytes, free_bytes, avail_bytes, checked_at)
  select distinct on (x.name) x.name, greatest(x.total_bytes, 0), greatest(x.free_bytes, 0), greatest(x.avail_bytes, 0), now()
  from jsonb_to_recordset(p_disks) as x(name text, total_bytes bigint, free_bytes bigint, avail_bytes bigint)
  where x.name ~ '^[a-z0-9][a-z0-9_.-]{0,39}$' and x.total_bytes > 0
  order by x.name
  on conflict (name) do update
     set total_bytes = excluded.total_bytes, free_bytes = excluded.free_bytes, avail_bytes = excluded.avail_bytes,
         checked_at = now();
  delete from private.health_disks h
   where h.name not in (select x.name from jsonb_to_recordset(p_disks) as x(name text) where x.name is not null);

  with reported as (
    select distinct on (x.source, coalesce(left(x.instance, 100), ''))
           x.source, coalesce(left(x.instance, 100), '') as instance, coalesce(x.ok, false) as ok,
           left(nullif(btrim(x.error), ''), 300) as error
    from jsonb_to_recordset(p_metrics) as x(source text, instance text, ok boolean, error text)
    where x.source ~ '^[a-z0-9][a-z0-9_.-]{0,59}$'
    order by x.source, coalesce(left(x.instance, 100), '')
  ),
  saved as (
    insert into private.health_metric_sources as h (source, instance, ok, error, checked_at)
    select r.source, r.instance, r.ok, r.error, now() from reported r
    on conflict (source, instance) do update
       set ok = excluded.ok, error = excluded.error, checked_at = now()
    returning h.source, h.instance
  )
  delete from private.health_metric_sources h
   where not exists (select 1 from saved s where s.source = h.source and s.instance = h.instance);

  insert into private.health_metric_samples (source, instance, name, value, sampled_at)
  select x.source, coalesce(left(x.instance, 100), ''), v.key, (v.value #>> '{}')::double precision, now()
  from jsonb_to_recordset(p_metrics) as x(source text, instance text, ok boolean, "values" jsonb)
  cross join lateral jsonb_each(case when jsonb_typeof(x."values") = 'object' then x."values" else '{}' end) v
  where coalesce(x.ok, false) and x.source ~ '^[a-z0-9][a-z0-9_.-]{0,59}$'
    and v.key ~ '^[a-z][a-z0-9_]{0,79}$' and jsonb_typeof(v.value) = 'number';
  delete from private.health_metric_samples s where s.sampled_at < now() - interval '15 minutes';

  perform private.health_evaluate();
  return jsonb_build_object('evaluated_at', now());
end;
$$;

revoke execute on function private.health_realtime_events_limit() from public;
revoke execute on function private.health_checks_metrics() from public;
revoke execute on function private.health_checks_room_preview() from public;
revoke execute on function private.health_current() from public;
revoke execute on function public.health_report(text, text, timestamptz, jsonb, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.health_report(text, text, timestamptz, jsonb, jsonb, jsonb) to service_role;
